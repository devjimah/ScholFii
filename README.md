# ScholFii (UniGame Protocol): Decentralized GameFi & Staking

![Solidity](https://img.shields.io/badge/Solidity-e6e6e6?style=for-the-badge&logo=solidity&logoColor=black)
![Chainlink](https://img.shields.io/badge/Chainlink-375BD2?style=for-the-badge&logo=chainlink&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-Cloud_Infrastructure-232F3E?style=for-the-badge&logo=amazon-aws)

## Abstract
The UniGame Protocol is a multi-primitive decentralized application (dApp) built on the Ethereum Virtual Machine (EVM). It explores secure state execution across four distinct Web3 mechanisms: Peer-to-Peer Wagering, Provably Fair Raffles, Decentralized Polling, and Yield-Bearing Staking Pools.

The primary architectural objective is mitigating common DeFi attack vectors (such as reentrancy and oracle manipulation) while maintaining efficient gas consumption during complex state transitions.

## Core Protocol Features
1. **P2P Wagering (Oracle Integrated):** Users can deploy collateralized bets resolved strictly by authorized off-chain Oracles, preventing on-chain state derailment.
2. **Provably Fair Raffles (Chainlink VRF):** Integrates Chainlink's Verifiable Random Function (VRF v2) to ensure ticket selection is cryptographically secure and immune to miner/validator manipulation.
3. **Liquidity Staking:** Time-locked staking pools with dynamic APY reward calculations based on block timestamps.
4. **Platform Fee Routing:** Automated treasury management that securely routes protocol fees without risking user collateral.

## Security Architecture
* **Reentrancy Protection:** Strict adherence to the Checks-Effects-Interactions pattern, bolstered by OpenZeppelin's `nonReentrant` modifiers on all state-altering, payable functions.
* **Access Control:** `Ownable` role-based access for Oracle designation and emergency fee extraction.
* **Deterministic Randomness:** Off-chain randomness resolution to prevent block-timestamp manipulation exploits.

## Developer Profile
**Abraham Jimah Zorwi**
* Software Engineer & AWS Certified Cloud Practitioner
* Focusing on secure Web3 smart contract architecture and cloud-native frontend deployments.
