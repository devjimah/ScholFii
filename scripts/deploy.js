const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // For local testing, we'll use the deployer as both oracle and VRF coordinator
  const config = {
    oracle: deployer.address,
    vrfCoordinator: deployer.address,
    keyHash: "0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c", // Arbitrum Sepolia VRF keyHash
    subscriptionId: 1
  };

  console.log("Deploying UniGame with config:", config);
  const UniGame = await hre.ethers.getContractFactory("UniGame");
  const uniGame = await UniGame.deploy(
    config.oracle,
    config.vrfCoordinator,
    config.keyHash,
    config.subscriptionId
  );

  await uniGame.waitForDeployment();
  const contractAddress = await uniGame.getAddress();
  console.log("UniGame deployed to:", contractAddress);

  // Initialize some test data
  console.log("Creating initial test data...");
  
  try {
    // Create a test bet
    const betTx = await uniGame.createBet(
      "Test Bet",
      "0x1234567890123456789012345678901234567890123456789012345678901234",
      Math.floor(Date.now() / 1000) + 7 * 24 * 60 * 60, // 7 days from now
      { value: hre.ethers.parseEther("0.1") }
    );
    await betTx.wait();
    console.log("Created test bet");

    // Create a test poll
    const pollTx = await uniGame.createPoll(
      "Test Poll",
      ["Option 1", "Option 2"],
      7 * 24 * 60 * 60 // 7 days duration
    );
    await pollTx.wait();
    console.log("Created test poll");

    // Create a test raffle
    const raffleTx = await uniGame.createRaffle(
      hre.ethers.parseEther("0.01"), // 0.01 ETH ticket price
      7 * 24 * 60 * 60 // 7 days duration
    );
    await raffleTx.wait();
    console.log("Created test raffle");

    // Create a test stake pool
    const stakeTx = await uniGame.createStakePool(
      "Test Stake Pool",
      hre.ethers.parseEther("1"), // 1 ETH max stake
      1000, // 10% APY
      30 * 24 * 60 * 60 // 30 days duration
    );
    await stakeTx.wait();
    console.log("Created test stake pool");

  } catch (error) {
    console.error("Error creating test data:", error);
  }

  // Verify contract on Arbiscan (skip for localhost)
  if (process.env.ARBISCAN_API_KEY && hre.network.name !== "localhost" && hre.network.name !== "hardhat") {
    console.log("Waiting for 6 block confirmations...");
    await uniGame.deploymentTransaction().wait(6);
    
    await hre.run("verify:verify", {
      address: contractAddress,
      constructorArguments: [config.oracle, config.vrfCoordinator, config.keyHash, config.subscriptionId],
    });
    console.log("Contract verified on Arbiscan");
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
