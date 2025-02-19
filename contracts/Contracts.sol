// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

contract UniGame is VRFConsumerBaseV2 {
    // --------------------------------------
    // Bet Struct & Logic
    // --------------------------------------
    struct Bet {
        address creator;
        string description;
        uint256 amount;
        address challenger;
        bool resolved;
        address winner;
    }

    mapping(uint256 => Bet) public bets;
    uint256 public betCounter;

    event BetCreated(uint256 indexed betId, address creator, string description, uint256 amount);
    event BetAccepted(uint256 indexed betId, address challenger);
    event BetResolved(uint256 indexed betId, address winner);

    function createBet(string memory _description) external payable {
        require(msg.value > 0, "Must bet a positive amount");

        betCounter++;
        bets[betCounter] = Bet(msg.sender, _description, msg.value, address(0), false, address(0));

        emit BetCreated(betCounter, msg.sender, _description, msg.value);
    }

    function acceptBet(uint256 _betId) external payable {
        Bet storage bet = bets[_betId];
        require(bet.challenger == address(0), "Bet already accepted");
        require(msg.value == bet.amount, "Must match bet amount");

        bet.challenger = msg.sender;

        emit BetAccepted(_betId, msg.sender);
    }

    function resolveBet(uint256 _betId, address _winner) external {
        Bet storage bet = bets[_betId];
        require(!bet.resolved, "Bet already resolved");
        require(_winner == bet.creator || _winner == bet.challenger, "Invalid winner");

        bet.resolved = true;
        bet.winner = _winner;

        payable(_winner).transfer(bet.amount * 2);
        emit BetResolved(_betId, _winner);
    }

    // --------------------------------------
    // Poll Struct & Logic
    // --------------------------------------
    struct Poll {
        string question;
        string[] options;
        uint256[] votes;
        uint256 endTime;
        address creator;
        bool active;
        mapping(address => bool) hasVoted;
    }

    Poll[] public polls;

    event PollCreated(uint256 pollId, string question, string[] options, uint256 endTime);
    event Voted(uint256 pollId, address voter, uint256 optionIndex);
    event PollClosed(uint256 pollId);

    function createPoll(string memory _question, string[] memory _options, uint256 _duration) external {
        require(_options.length >= 2, "Must have at least two options");

        Poll storage newPoll = polls.push();
        newPoll.question = _question;
        newPoll.options = _options;
        newPoll.votes = new uint256[](_options.length);
        newPoll.endTime = block.timestamp + _duration;
        newPoll.creator = msg.sender;
        newPoll.active = true;

        emit PollCreated(polls.length - 1, _question, _options, newPoll.endTime);
    }

    function vote(uint256 _pollId, uint256 _optionIndex) external {
        Poll storage poll = polls[_pollId];
        require(poll.active, "Poll is not active");
        require(block.timestamp < poll.endTime, "Poll has ended");
        require(!poll.hasVoted[msg.sender], "Already voted");
        require(_optionIndex < poll.options.length, "Invalid option");

        poll.votes[_optionIndex]++;
        poll.hasVoted[msg.sender] = true;

        emit Voted(_pollId, msg.sender, _optionIndex);
    }

    function closePoll(uint256 _pollId) external {
        require(msg.sender == polls[_pollId].creator, "Only creator can close");
        require(polls[_pollId].active, "Poll already closed");
        require(block.timestamp >= polls[_pollId].endTime, "Poll is still active");

        polls[_pollId].active = false;

        emit PollClosed(_pollId);
    }

    function getPoll(uint256 _pollId) external view returns (string memory, string[] memory, uint256[] memory, uint256, bool) {
        Poll storage poll = polls[_pollId];
        return (poll.question, poll.options, poll.votes, poll.endTime, poll.active);
    }

    // --------------------------------------
    // Raffle Struct & Logic
    // --------------------------------------
    struct Raffle {
        address creator;
        uint256 ticketPrice;
        address[] participants;
        uint256 endTime;
        bool active;
        address winner;
    }

    mapping(uint256 => Raffle) public raffles;
    uint256 public raffleCount;

    VRFCoordinatorV2Interface COORDINATOR;
    uint64 s_subscriptionId;
    bytes32 keyHash;
    mapping(uint256 => uint256) public requestIdToRaffle;

    event RaffleCreated(uint256 raffleId, uint256 ticketPrice, uint256 endTime);
    event TicketBought(uint256 raffleId, address buyer);
    event WinnerPicked(uint256 raffleId, address winner);

    constructor(
        address _vrfCoordinator, 
        bytes32 _keyHash, 
        uint64 _subscriptionId
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        keyHash = _keyHash;
        s_subscriptionId = _subscriptionId;
    }

    function createRaffle(uint256 _ticketPrice, uint256 _duration) external {
        require(_ticketPrice > 0, "Invalid ticket price");
        require(_duration > 0, "Duration must be positive");

        raffles[raffleCount] = Raffle({
            creator: msg.sender,
            ticketPrice: _ticketPrice,
            participants: new address[](0),
            endTime: block.timestamp + _duration,
            active: true,
            winner: address(0)
        });

        emit RaffleCreated(raffleCount, _ticketPrice, block.timestamp + _duration);
        raffleCount++;
    }

    function buyTicket(uint256 _raffleId) external payable {
        Raffle storage raffle = raffles[_raffleId];
        require(raffle.active, "Raffle is not active");
        require(msg.value == raffle.ticketPrice, "Incorrect ticket price");
        require(block.timestamp < raffle.endTime, "Raffle has ended");

        raffle.participants.push(msg.sender);

        emit TicketBought(_raffleId, msg.sender);
    }

    function requestRandomWinner(uint256 _raffleId) external {
        Raffle storage raffle = raffles[_raffleId];
        require(msg.sender == raffle.creator, "Only creator can pick winner");
        require(raffle.active, "Raffle already ended");
        require(block.timestamp >= raffle.endTime, "Raffle is still active");
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

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 raffleId = requestIdToRaffle[requestId];
        Raffle storage raffle = raffles[raffleId];

        uint256 winnerIndex = randomWords[0] % raffle.participants.length;
        raffle.winner = raffle.participants[winnerIndex];
        raffle.active = false;

        payable(raffle.winner).transfer(address(this).balance);

        emit WinnerPicked(raffleId, raffle.winner);
    }

    function getRaffle(uint256 _raffleId) external view returns (address, uint256, address[] memory, uint256, bool, address) {
        Raffle storage raffle = raffles[_raffleId];
        return (raffle.creator, raffle.ticketPrice, raffle.participants, raffle.endTime, raffle.active, raffle.winner);
    }

    function getRaffleParticipants(uint256 _raffleId) external view returns (address[] memory) {
        return raffles[_raffleId].participants;
    }
}
