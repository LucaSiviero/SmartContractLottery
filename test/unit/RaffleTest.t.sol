// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test {
    Raffle raffle;
    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 1000 ether;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address coordinator;
    bytes32 keyHash;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address linkAddress;

    // Events must be redefined in other files
    event EnteredRaffle(address indexed playerAddress);

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();

        (
            entranceFee,
            interval,
            coordinator,
            keyHash,
            subscriptionId,
            callbackGasLimit,
            linkAddress
        ) = helperConfig.activeNetworkConfig();

        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    //////////////////////
    // enterRaffle      //
    //////////////////////

    function testRaffleRevertsWhenNotEnoughEthSent() public {
        // Remember this pattern, despite in this case, Act and Assert are inverted due to Foundry cheatcodes
        // Arrange
        vm.prank(PLAYER);
        // Act
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        // Assert
        raffle.enterRaffle{value: 0.005 ether}();
    }

    function testRaffleRecordsPlayerWhenEnters() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: 0.1 ether}();
        // Assert
        address payable[] memory players = raffle.getPlayers();
        assert(players[0] == PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        vm.prank(PLAYER);
        // Events can have up to 3 topic. The event we're going to emit has only one topic. Fourth parameter of expectEmit is to specifiy if there's any data or indexed parameter
        // Last parameter is the emitter address: the address of the contract that emitted the event
        vm.expectEmit(true, false, false, false, address(raffle));
        // After expectEmit we actually emit the event (has to be the same of the contract)
        emit EnteredRaffle(PLAYER);
        // Then we trigger the actual function the will emit the event we want to test
        raffle.enterRaffle{value: 0.1 ether}();
    }

    function testCantEnterWhenRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: 0.1 ether}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__StateNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: 0.1 ether}();
    }

    //////////////////////
    // checkUpKeep      //
    //////////////////////

    function testCheckUpKeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfRaffleNotOpen() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: 0.1 ether}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }
}
