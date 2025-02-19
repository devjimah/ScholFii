const hre = require("hardhat");

async function main() {
  // Contract configuration
  const vrfCoordinator = "0x50d47e4142598E3411aA864e08a44284e471AC6f"; // Arbitrum Sepolia VRF Coordinator
  const keyHash = "0x8212157d7335e4ce0c3ebc56d40c4d3d3d36cf6c0a6d147c5b4b3f8580d5d248"; // Arbitrum Sepolia keyHash
  const subscriptionId = 1; // Replace with your actual Chainlink VRF subscription ID

  // Deploy UniGame
  const UniGame = await hre.ethers.getContractFactory("UniGame");
  const uniGame = await UniGame.deploy(vrfCoordinator, keyHash, subscriptionId);

  await uniGame.waitForDeployment();
  console.log("UniGame deployed to:", await uniGame.getAddress());

  // Verify contract on Arbiscan
  if (process.env.ARBISCAN_API_KEY) {
    console.log("Waiting for 6 block confirmations...");
    await uniGame.deploymentTransaction().wait(6);
    
    await hre.run("verify:verify", {
      address: await uniGame.getAddress(),
      constructorArguments: [vrfCoordinator, keyHash, subscriptionId],
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
