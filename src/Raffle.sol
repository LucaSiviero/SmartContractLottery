// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title Raffle
 * @author Lca Siviero
 * @notice This contract creates a sample raffle
 * @dev Implements Chainlink VRFv2
 */

contract Raffle {
    error Raffe__NotEnoughEthSent();

    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    //@dev Duration of lottery extraction in seconds
    uint256 immutable i_interval;
    uint256 private s_lastTimeStamp;

    event EnteredRaffle(address playerAddress);

    constructor(uint256 entranceFee, uint256 interval) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffe__NotEnoughEthSent();
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
    }

    // Getters
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
