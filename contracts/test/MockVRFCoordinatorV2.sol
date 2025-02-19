// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

contract MockVRFCoordinatorV2 is VRFCoordinatorV2Interface {
    uint256 private nonce = 0;
    mapping(uint256 => address) public s_consumers;
    mapping(uint256 => uint256) public s_randomWords;

    function requestRandomWords(
        bytes32 keyHash,
        uint64 subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords
    ) external override returns (uint256) {
        uint256 requestId = nonce++;
        s_consumers[requestId] = msg.sender;
        
        // Simulate callback with random number
        uint256[] memory randomWords = new uint256[](numWords);
        for(uint256 i = 0; i < numWords; i++) {
            randomWords[i] = uint256(keccak256(abi.encode(block.timestamp, msg.sender, requestId, i)));
            s_randomWords[i] = randomWords[i];
        }
        
        VRFConsumerBaseV2(msg.sender).rawFulfillRandomWords(requestId, randomWords);
        return requestId;
    }

    function createSubscription() external pure override returns (uint64) {
        return 1;
    }

    function getSubscription(uint64 subId) external pure override returns (
        uint96 balance,
        uint64 reqCount,
        address owner,
        address[] memory consumers
    ) {
        return (0, 0, address(0), new address[](0));
    }

    function requestSubscriptionOwnerTransfer(uint64 subId, address newOwner) external pure override {}
    function acceptSubscriptionOwnerTransfer(uint64 subId) external pure override {}
    function addConsumer(uint64 subId, address consumer) external pure override {}
    function removeConsumer(uint64 subId, address consumer) external pure override {}
    function cancelSubscription(uint64 subId, address to) external pure override {}
    function pendingRequestExists(uint64 subId) external pure override returns (bool) {
        return false;
    }

    function getRequestConfig() external pure override returns (uint16, uint32, bytes32[] memory) {
        bytes32[] memory keysHash = new bytes32[](1);
        keysHash[0] = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
        return (3, 2000000, keysHash);
    }
}
