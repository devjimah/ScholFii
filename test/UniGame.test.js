const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("UniGame", function () {
  let UniGame, uniGame, owner, user1, user2;
  let vrfCoordinator, keyHash, subscriptionId;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();
    
    // Deploy mock VRF Coordinator
    const MockVRFCoordinator = await ethers.getContractFactory("MockVRFCoordinatorV2");
    vrfCoordinator = await MockVRFCoordinator.deploy();
    await vrfCoordinator.waitForDeployment();

    keyHash = "0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c"; // Goerli keyHash
    subscriptionId = 1;

    // Deploy UniGame
    UniGame = await ethers.getContractFactory("UniGame");
    uniGame = await UniGame.deploy(
      await vrfCoordinator.getAddress(),
      keyHash,
      subscriptionId
    );
    await uniGame.waitForDeployment();
  });

  describe("Betting", function () {
    it("Should create a bet", async function () {
      const betAmount = ethers.parseEther("0.1");
      await uniGame.connect(user1).createBet("Who wins?", { value: betAmount });

      const betId = await uniGame.betCounter();
      const bet = await uniGame.bets(betId);
      expect(bet.creator).to.equal(user1.address);
      expect(bet.amount).to.equal(betAmount);
      expect(bet.description).to.equal("Who wins?");
    });

    it("Should allow a challenger to accept a bet", async function () {
      const betAmount = ethers.parseEther("0.1");
      await uniGame.connect(user1).createBet("Who wins?", { value: betAmount });
      
      const betId = await uniGame.betCounter();
      await uniGame.connect(user2).acceptBet(betId, { value: betAmount });

      const bet = await uniGame.bets(betId);
      expect(bet.challenger).to.equal(user2.address);
    });

    it("Should not allow accepting a bet with wrong amount", async function () {
      const betAmount = ethers.parseEther("0.1");
      await uniGame.connect(user1).createBet("Who wins?", { value: betAmount });
      
      const betId = await uniGame.betCounter();
      await expect(
        uniGame.connect(user2).acceptBet(betId, { value: ethers.parseEther("0.05") })
      ).to.be.revertedWith("Must match bet amount");
    });
  });

  describe("Raffle", function () {
    it("Should create a raffle", async function () {
      const ticketPrice = ethers.parseEther("0.01");
      const duration = 3600; // 1 hour
      await uniGame.connect(user1).createRaffle(ticketPrice, duration);

      const raffleId = 0; // First raffle has ID 0
      const raffle = await uniGame.raffles(raffleId);
      expect(raffle.creator).to.equal(user1.address);
      expect(raffle.ticketPrice).to.equal(ticketPrice);
      expect(raffle.active).to.equal(true);
    });

    it("Should allow buying tickets", async function () {
      const ticketPrice = ethers.parseEther("0.01");
      const duration = 3600;
      await uniGame.connect(user1).createRaffle(ticketPrice, duration);

      const raffleId = 0; // First raffle has ID 0
      await uniGame.connect(user2).buyTicket(raffleId, { value: ticketPrice });
      
      const participants = await uniGame.getRaffleParticipants(raffleId);
      expect(participants[0]).to.equal(user2.address);
    });

    it("Should not allow buying tickets with wrong price", async function () {
      const ticketPrice = ethers.parseEther("0.01");
      const duration = 3600;
      await uniGame.connect(user1).createRaffle(ticketPrice, duration);

      const raffleId = 0; // First raffle has ID 0
      await expect(
        uniGame.connect(user2).buyTicket(raffleId, { value: ethers.parseEther("0.005") })
      ).to.be.revertedWith("Incorrect ticket price");
    });
  });
});
