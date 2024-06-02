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
import {console} from "forge-std/Test.sol";

contract Raffle is VRFConsumerBaseV2 {
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFail();
    error Raffle__StateNotOpen();
    // You can use both uint256 or RaffleState for the last object passed as a partameter for the error
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        RaffleState stateValue
    );

    // @dev Type declarations (Enum).
    // In solidity, enum declaration matches the ENUM value with an integer value. So, OPEN would be 0, CALCULATING would be 1.
    enum RaffleState {
        OPEN,
        CALCULATING
    }

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
    address private s_lastWinner;
    RaffleState private s_raffleState;

    event EnteredRaffle(address indexed playerAddress);
    event WinnerPicked(address indexed winnerAddress);
    event RequestedRaffleWinner(uint256 indexed requestId);

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
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__StateNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    // Function to return if the upkeep is needed
    /**
     * @dev This is a function that the chainlink automation nodes call to see if it's time to perform an upkeep.
     * The following should be true for the function to return true:
     * 1. The time interval has passed between raffle runs
     * 2. The raffle is in the OPEN state
     * 3. The contract has ETH (aka, players)
     * 4. (Implicit) The subscription is funded with LINK
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeIntervalPassed = block.timestamp - s_lastTimeStamp >=
            i_interval;
        bool isOpenState = RaffleState.OPEN == s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;

        // If we needed to just return upkeepNeeded, at this point, this would be enough to return it
        // Because in Solidity, a return statemet can be omitted if the variable has been declared in the returns part of the function signature
        upkeepNeeded = (timeIntervalPassed &&
            isOpenState &&
            hasBalance &&
            hasPlayers);

        // In this case, we also have to return performData though
        return (upkeepNeeded, "0x0");
    }

    //1. Get a random number
    //2. Use the random number to pick a player
    //3. Automatically call pickWinner
    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                s_raffleState
            );
        }
        s_raffleState = RaffleState.CALCULATING;
        // @dev Implements the VRFv2Consumer method to perform the random words request
        uint256 requestId = i_coordinator.requestRandomWords(
            i_keyHash,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedRaffleWinner(requestId);
    }

    // The contract code follows the CEI design pattern: Checks, Effects, Interactions.
    // Check first, so you know that if some requirement failed, at least you didn't spend gas doing useless computation that has to be done after the checks.
    // Effects is the actual implementation of what the function has to do. The gas consuming activities that bring changes to the blockchain
    // Interactions is the part where we interact with other contracts. It's important to keep interactions last, so we protect against re-entrancy attacks!!!

    // @dev Overrides the function from VRFConsumerBaseV2 to actually get the random number back
    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory _randomWords
    ) internal override {
        uint256 indexOfWinner = _randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_lastWinner = winner;
        s_raffleState = RaffleState.OPEN;
        (bool success, ) = winner.call{value: address(this).balance}("");
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(winner);

        if (!success) {
            revert Raffle__TransferFail();
        }
    }

    // Getters
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayers() external view returns (address payable[] memory) {
        return s_players;
    }

    function getLastWinner() external view returns (address) {
        return s_lastWinner;
    }

    function getLastTimestamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}
