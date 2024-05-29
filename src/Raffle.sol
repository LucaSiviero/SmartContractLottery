// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title Raffle
 * @author Lca Siviero
 * @notice This contract creates a sample raffle
 * @dev Implements Chainlink VRFv2
 */

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Raffle is VRFConsumerBaseV2 {
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFail();

    // @dev The number of confirmations (number of blocks after the one that contains the random number) by the network to actually start to use the random number.
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    // @dev How many random words do you want to be generated
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;

    // @dev Duration of lottery extraction in seconds
    uint256 immutable i_interval;

    // @dev Address for VRF Coordinator (The Chainlink contract to call)
    VRFCoordinatorV2Interface immutable i_coordinator;

    // @dev The gas lane key hash value, which is the maximum gas price we pay for a request in wei.
    // @dev It is an ID for the offchain VRF job that is triggered by the request
    bytes32 immutable i_keyHash;

    uint64 immutable i_subscriptionId;

    // @dev How much gas we're going to allow the contract to spend when the response of the offchain VRF comes back to the contract
    uint32 immutable i_callbackGasLimit;

    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address s_lastWinner;

    event EnteredRaffle(address playerAddress);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address coordinator,
        bytes32 keyHash,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(coordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_coordinator = VRFCoordinatorV2Interface(coordinator);
        i_keyHash = keyHash;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    //1. Get a random number
    //2. Use the random number to pick a player
    //3. Automatically call pickWinner
    function pickWinner() external {
        if (block.timestamp - s_lastTimeStamp < i_interval) {
            revert();
        }
        // @dev Implements the VRFv2Consumer method to perform the random words request
        uint256 requestId = i_coordinator.requestRandomWords(
            i_keyHash,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
    }

    // @dev Overrides the function from VRFConsumerBaseV2 to actually get the random number back
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory _randomWords
    ) internal override {
        uint256 indexOfWinner = _randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_lastWinner = winner;
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFail();
        }
    }

    // Getters
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
