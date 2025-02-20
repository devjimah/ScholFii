
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@chainlink/contracts/src/v0.8/vrf/interfaces/AggregatorV3Interface.sol"; // For oracle data (bets)
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol"; // For VRF (raffles)
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; // Prevent reentrancy
import "@openzeppelin/contracts/access/Ownable.sol"; // For admin controls

contract UniGame is VRFConsumerBaseV2, ReentrancyGuard, Ownable {
    // --------------------------------------
    // Shared Variables
    // --------------------------------------
    uint256 public platformFeePercent = 2; // 2% fee for platform sustainability
    address public oracle; // Chainlink oracle for bet resolution

    // Chainlink VRF setup for raffles
    VRFCoordinatorV2Interface COORDINATOR;
    uint64 public s_subscriptionId;
    bytes32 public keyHash;

    constructor(
        address _oracle,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId
    ) VRFConsumerBaseV2(_vrfCoordinator) Ownable(msg.sender) {
        oracle = _oracle;
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        keyHash = _keyHash;
        s_subscriptionId = _subscriptionId;
    }

    // --------------------------------------
    // Bet Struct & Logic
    // --------------------------------------
    enum BetState { Pending, Accepted, Resolved, Cancelled }

    struct Bet {
        address creator;
        string description;
        bytes32 eventId;
        uint256 amount;
        address challenger;
        uint256 challengerAmount;
        BetState state;
        address winner;
        uint256 deadline;
    }

    mapping(uint256 => Bet) public bets;
    uint256 public betCounter;
    mapping(bytes32 => bool) public usedEventIds;

    event BetCreated(uint256 indexed betId, address creator, string description, bytes32 eventId, uint256 amount, uint256 deadline);
    event BetAccepted(uint256 indexed betId, address challenger, uint256 amount);
    event BetResolved(uint256 indexed betId, address winner, uint256 payout);
    event BetCancelled(uint256 indexed betId, address creator);

    function createBet(string memory _description, bytes32 _eventId, uint256 _deadline) external payable nonReentrant {
        require(msg.value > 0, "Must bet a positive amount");
        require(_deadline > block.timestamp, "Deadline must be in the future");
        require(!usedEventIds[_eventId], "Event ID already used");

        betCounter++;
        bets[betCounter] = Bet(msg.sender, _description, _eventId, msg.value, address(0), 0, BetState.Pending, address(0), _deadline);
        usedEventIds[_eventId] = true;

        emit BetCreated(betCounter, msg.sender, _description, _eventId, msg.value, _deadline);
    }

    function acceptBet(uint256 _betId) external payable nonReentrant {
        Bet storage bet = bets[_betId];
        require(bet.state == BetState.Pending, "Bet not pending");
        require(msg.value == bet.amount, "Must match bet amount");
        require(block.timestamp < bet.deadline, "Bet deadline passed");
        require(bet.challenger == address(0), "Bet already accepted");

        bet.challenger = msg.sender;
        bet.challengerAmount = msg.value;
        bet.state = BetState.Accepted;

        emit BetAccepted(_betId, msg.sender, msg.value);
    }

    function cancelBet(uint256 _betId) external nonReentrant {
        Bet storage bet = bets[_betId];
        require(msg.sender == bet.creator, "Only creator can cancel");
        require(bet.state == BetState.Pending, "Bet already accepted or resolved");
        require(block.timestamp >= bet.deadline, "Deadline not reached");

        bet.state = BetState.Cancelled;
        uint256 amount = bet.amount;
        bet.amount = 0;
        payable(bet.creator).transfer(amount);

        emit BetCancelled(_betId, msg.sender);
    }

    function resolveBet(uint256 _betId, address _winner) external nonReentrant {
        require(msg.sender == oracle, "Only oracle can resolve");
        Bet storage bet = bets[_betId];
        require(bet.state == BetState.Accepted, "Bet not accepted yet");
        require(bet.state != BetState.Resolved, "Bet already resolved");
        require(_winner == bet.creator || _winner == bet.challenger, "Invalid winner");

        bet.state = BetState.Resolved;
        bet.winner = _winner;

        uint256 totalPool = bet.amount + bet.challengerAmount;
        uint256 fee = (totalPool * platformFeePercent) / 100;
        uint256 payout = totalPool - fee;

        payable(_winner).transfer(payout);
        emit BetResolved(_betId, _winner, payout);
    }

    // --------------------------------------
    // Poll Struct & Logic
    // --------------------------------------
    struct Poll {
        string question;
        uint256[] votes; // Fixed-size array for gas efficiency
        uint256 endTime;
        address creator;
        bool active;
        mapping(address => bool) hasVoted;
    }

    Poll[] public polls;

    event PollCreated(uint256 indexed pollId, string question, uint256 endTime);
    event Voted(uint256 indexed pollId, address voter, uint256 optionIndex);
    event PollClosed(uint256 indexed pollId);

    function createPoll(string memory _question, uint256 _duration, uint256 _optionCount) external {
        require(_optionCount >= 2 && _optionCount <= 10, "Options must be between 2 and 10");
        require(_duration > 0, "Duration must be positive");

        Poll storage newPoll = polls.push();
        newPoll.question = _question;
        newPoll.votes = new uint256[](_optionCount);
        newPoll.endTime = block.timestamp + _duration;
        newPoll.creator = msg.sender;
        newPoll.active = true;

        emit PollCreated(polls.length - 1, _question, newPoll.endTime);
    }

    function vote(uint256 _pollId, uint256 _optionIndex) external nonReentrant {
        Poll storage poll = polls[_pollId];
        require(poll.active, "Poll is not active");
        require(block.timestamp < poll.endTime, "Poll has ended");
        require(!poll.hasVoted[msg.sender], "Already voted");
        require(_optionIndex < poll.votes.length, "Invalid option");

        poll.votes[_optionIndex]++;
        poll.hasVoted[msg.sender] = true;

        emit Voted(_pollId, msg.sender, _optionIndex);
    }

    function closePoll(uint256 _pollId) external {
        Poll storage poll = polls[_pollId];
        require(poll.active, "Poll already closed");
        if (msg.sender != poll.creator) {
            require(block.timestamp >= poll.endTime, "Poll still active and not creator");
        }

        poll.active = false;
        emit PollClosed(_pollId);
    }

    // --------------------------------------
    // Raffle Struct & Logic
    // --------------------------------------
    struct Raffle {
        address creator;
        uint256 ticketPrice;
        uint256 totalPool; // Tracks ticket sales
        mapping(address => uint256) ticketsBought; // Tickets per user
        address[] participants; // List of unique participants
        uint256 endTime;
        bool active;
        address winner;
    }

    mapping(uint256 => Raffle) public raffles;
    uint256 public raffleCount;
    mapping(uint256 => uint256) public requestIdToRaffle;

    event RaffleCreated(uint256 indexed raffleId, uint256 ticketPrice, uint256 endTime);
    event TicketBought(uint256 indexed raffleId, address buyer, uint256 ticketCount);
    event WinnerPicked(uint256 indexed raffleId, address winner);

    function createRaffle(uint256 _ticketPrice, uint256 _duration) external {
        require(_ticketPrice > 0, "Invalid ticket price");
        require(_duration > 0, "Duration must be positive");

        Raffle storage newRaffle = raffles[raffleCount];
        newRaffle.creator = msg.sender;
        newRaffle.ticketPrice = _ticketPrice;
        newRaffle.endTime = block.timestamp + _duration;
        newRaffle.active = true;

        emit RaffleCreated(raffleCount, _ticketPrice, newRaffle.endTime);
        raffleCount++;
    }

    function buyTicket(uint256 _raffleId, uint256 _ticketCount) external payable nonReentrant {
        Raffle storage raffle = raffles[_raffleId];
        require(raffle.active, "Raffle is not active");
        require(msg.value == raffle.ticketPrice * _ticketCount, "Incorrect payment");
        require(block.timestamp < raffle.endTime, "Raffle has ended");
        require(_ticketCount > 0, "Must buy at least one ticket");

        if (raffle.ticketsBought[msg.sender] == 0) {
            raffle.participants.push(msg.sender);
        }
        raffle.ticketsBought[msg.sender] += _ticketCount;
        raffle.totalPool += msg.value;

        emit TicketBought(_raffleId, msg.sender, _ticketCount);
    }

    function requestRandomWinner(uint256 _raffleId) external {
        Raffle storage raffle = raffles[_raffleId];
        require(msg.sender == raffle.creator, "Only creator can pick winner");
        require(raffle.active, "Raffle already ended");
        require(block.timestamp >= raffle.endTime, "Raffle still active");
        require(raffle.participants.length > 0, "No participants");

        uint256 requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            3, // Confirmation blocks
            500000, // Gas limit
            1 // Number of random words
        );
        requestIdToRaffle[requestId] = _raffleId;
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override nonReentrant {
        uint256 raffleId = requestIdToRaffle[_requestId];
        Raffle storage raffle = raffles[raffleId];
        require(raffle.active, "Raffle already resolved");

        uint256 totalTickets = 0;
        for (uint256 i = 0; i < raffle.participants.length; i++) {
            totalTickets += raffle.ticketsBought[raffle.participants[i]];
        }

        uint256 winnerIndex = _randomWords[0] % totalTickets;
        uint256 ticketSum = 0;
        for (uint256 i = 0; i < raffle.participants.length; i++) {
            ticketSum += raffle.ticketsBought[raffle.participants[i]];
            if (winnerIndex < ticketSum) {
                raffle.winner = raffle.participants[i];
                break;
            }
        }

        raffle.active = false;
        uint256 fee = (raffle.totalPool * platformFeePercent) / 100;
        uint256 payout = raffle.totalPool - fee;
        payable(raffle.winner).transfer(payout);

        emit WinnerPicked(raffleId, raffle.winner);
    }

    // --------------------------------------
    // Staking Struct & Logic
    // --------------------------------------
    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 duration; // In seconds
        bool active;
    }

    mapping(address => Stake) public stakes;
    uint256 public rewardRate = 5; // 5% annualized reward (simplified)

    event Staked(address indexed user, uint256 amount, uint256 duration);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);

    function stake(uint256 _duration) external payable nonReentrant {
        require(msg.value > 0, "Must stake a positive amount");
        require(_duration >= 1 days, "Minimum stake duration is 1 day");
        require(!stakes[msg.sender].active, "Already staking");

        stakes[msg.sender] = Stake({
            amount: msg.value,
            startTime: block.timestamp,
            duration: _duration,
            active: true
        });

        emit Staked(msg.sender, msg.value, _duration);
    }

    function unstake() external nonReentrant {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.active, "No active stake");
        require(block.timestamp >= userStake.startTime + userStake.duration, "Stake still locked");

        uint256 amount = userStake.amount;
        uint256 timeStaked = block.timestamp - userStake.startTime;
        uint256 reward = (amount * rewardRate * timeStaked) / (365 days * 100); // Simplified reward calculation
        uint256 totalPayout = amount + reward;

        userStake.active = false;
        userStake.amount = 0; // Prevent reentrancy
        payable(msg.sender).transfer(totalPayout);

        emit Unstaked(msg.sender, amount, reward);
    }

    // --------------------------------------
    // Admin & Utility Functions
    // --------------------------------------
    function setOracle(address _newOracle) external onlyOwner {
        oracle = _newOracle;
    }

    function setPlatformFee(uint256 _feePercent) external onlyOwner {
        require(_feePercent <= 10, "Fee too high");
        platformFeePercent = _feePercent;
    }

    function setRewardRate(uint256 _rate) external onlyOwner {
        require(_rate <= 20, "Reward rate too high"); // Cap at 20%
        rewardRate = _rate;
    }

    function withdrawFees() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner()).transfer(balance);
    }

    receive() external payable {}
}