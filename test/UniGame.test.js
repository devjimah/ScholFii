const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("UniGame on Arbitrum Sepolia", function () {
  let UniGame, uniGame, owner, user1, user2;
  const oracleAddress = ethers.Wallet.createRandom().address; // Mock oracle for bets
  const vrfCoordinator = "0x5ce8d5a2bc84beb22a398cca51996f7930313d61"; // Arbitrum Sepolia VRF
  const keyHash = "0x1770bdc7eec7771f7ba4ffd640f35498d4191358168be8d573cdc9867bc0acbb"; // Fixed length to 32 bytes
  const subscriptionId = 1n; // Using BigInt for uint64

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    // Deploy UniGame
    UniGame = await ethers.getContractFactory("UniGame");
    uniGame = await UniGame.deploy(
      oracleAddress,
      vrfCoordinator,
      ethers.hexlify(keyHash),
      subscriptionId
    );
    await uniGame.waitForDeployment();

    // Fund contract for staking rewards
    await owner.sendTransaction({ to: uniGame.target, value: ethers.parseEther("10") });
  });

  describe("Bets", function () {
    it("Creates and accepts a bet", async function () {
      const betAmount = ethers.parseEther("0.1");
      const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
      const eventId = ethers.keccak256(ethers.toUtf8Bytes("test-event-1"));

      // Create bet
      await uniGame.connect(user1).createBet(
        "Test Bet",
        eventId,
        deadline,
        { value: betAmount }
      );

      const betId = await uniGame.betCounter();
      const bet = await uniGame.bets(betId);
      
      expect(bet.creator).to.equal(user1.address);
      expect(bet.amount).to.equal(betAmount);
      expect(bet.description).to.equal("Test Bet");
      expect(bet.eventId).to.equal(eventId);
      expect(bet.deadline).to.equal(deadline);

      // Accept bet
      await uniGame.connect(user2).acceptBet(betId, { value: betAmount });
      
      const updatedBet = await uniGame.bets(betId);
      expect(updatedBet.challenger).to.equal(user2.address);
      expect(updatedBet.challengerAmount).to.equal(betAmount);
      expect(updatedBet.state).to.equal(1); // BetState.Accepted
    });
  });

  // Polls Tests
  describe("Polls", function () {
    it("Creates and votes in a poll", async function () {
      // Create a poll with 2 options and 1 hour duration
      const duration = 3600;
      const tx = await uniGame.connect(user1).createPoll("Best blockchain?", duration, 2);
      const receipt = await tx.wait();
      
      // Get pollId from event
      const pollCreatedEvent = receipt.logs.find(
        log => log.fragment && log.fragment.name === 'PollCreated'
      );
      expect(pollCreatedEvent).to.not.be.undefined;
      
      // Vote in the poll
      await uniGame.connect(user2).vote(0, 0); // Vote for first option
      await uniGame.connect(user1).vote(0, 1); // Vote for second option
      
      // Check poll status
      const pollEndTime = await uniGame.polls(0).then(poll => poll.endTime);
      const pollCreator = await uniGame.polls(0).then(poll => poll.creator);
      const pollActive = await uniGame.polls(0).then(poll => poll.active);
      
      expect(pollEndTime).to.be.gt(Math.floor(Date.now() / 1000));
      expect(pollCreator).to.equal(user1.address);
      expect(pollActive).to.be.true;
      
      // Verify that users can't vote twice
      await expect(
        uniGame.connect(user2).vote(0, 1)
      ).to.be.revertedWith("Already voted");
    });
  });

  // Raffles Tests
  describe("Raffles", function () {
    it("Creates and buys tickets for a raffle", async function () {
      await uniGame.connect(user1).createRaffle(ethers.parseEther("0.1"), 3600);
      await uniGame.connect(user2).buyTicket(0, 2, { value: ethers.parseEther("0.2") });

      const raffle = await uniGame.raffles(0);
      expect(raffle.totalPool).to.equal(ethers.parseEther("0.2"));
    });
  });

  // Staking Tests
  describe("Staking", function () {
    it("Stakes and unstakes with reward", async function () {
      await uniGame.connect(user1).stake(86400, { value: ethers.parseEther("1") });

      await ethers.provider.send("evm_increaseTime", [86400]);
      await ethers.provider.send("evm_mine");

      const balanceBefore = await ethers.provider.getBalance(user1.address);
      await uniGame.connect(user1).unstake();
      const balanceAfter = await ethers.provider.getBalance(user1.address);

      expect(balanceAfter).to.be.gt(balanceBefore);
    });
  });
});