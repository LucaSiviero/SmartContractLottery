// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    Raffle raffle;
    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 1000 ether;
    uint256 public constant ENTRANCE_FEE = 0.001 ether;

    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address coordinator;
    bytes32 keyHash;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address linkAddress;
    uint256 deployerKey;

    // Events must be redefined in other files
    event EnteredRaffle(address indexed playerAddress);

    modifier enterRaffle() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function setUp() public {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();

        (
            entranceFee,
            interval,
            coordinator,
            keyHash,
            subscriptionId,
            callbackGasLimit,
            linkAddress,
            deployerKey
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
        raffle.enterRaffle{value: 0.000001 ether}();
    }

    function testRaffleRecordsPlayerWhenEnters() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: ENTRANCE_FEE}();
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
        raffle.enterRaffle{value: ENTRANCE_FEE}();
    }

    function testCantEnterWhenRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__StateNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
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
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    //////////////////////
    // performUpKeep    //
    //////////////////////

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        vm.warp(block.timestamp + interval + 1);
        //vm.roll(block.number + 1);
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 currentPlayers = 0;
        uint256 raffleState = 0;
        /*  I expect the transaction to revert with the specified error. I also expect the error to be thrown with certain parameters.
            That's why I wrap the error selector with abi.encodeWithSelector, so that I can pass parameters too
        */
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                currentPlayers,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        enterRaffle
    {
        // This line allows foundry to record the logs generated from the next transaction!
        vm.recordLogs();
        // This way we can emit the requestId with an event
        raffle.performUpkeep("");
        // This line uses the recorded logs in foundry vm to populate an array of logs!
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // To retrieve the specific log, we have to know the index of the log in the entries array. We could use the command forge test --debug.
        // In this case, we know that the event we're listening for is the second event emitted by the performUpkeep() transaction.
        // It's importat to know that all logs are stored as bytes32, but to access the data we have to use the topics array selector.
        // topics has always in the starting position (0) the data that identifies the event itself. So, every access to topics is offsetted by 1
        bytes32 requestId = entries[1].topics[1];
        assertEq(
            entries[1].topics[0],
            keccak256("RequestedRaffleWinner(uint256)")
        );
        if (block.chainid == 31337) {
            assertEq(requestId, bytes32(uint256(1)));
        } else {
            assert(requestId > 0);
        }
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(raffleState) == 1);
    }

    ///////////////////////////
    // fulfillRandomWords    //
    ///////////////////////////
    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public enterRaffle skipFork {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(coordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        enterRaffle
        skipFork
    {
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: ENTRANCE_FEE}();
        }
        // Everyone partecipates with ENTRANCE_FEE each (Degenerate gamblers!! :D)
        uint256 prize = ENTRANCE_FEE * (additionalEntrants + 1);

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2Mock(coordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        uint256 previousTimestamp = raffle.getLastTimestamp();

        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        address lastWinner = raffle.getLastWinner();
        assert(lastWinner != address(0));
        assert(raffle.getPlayers().length == 0);

        uint256 lastTimestamp = raffle.getLastTimestamp();
        assert(lastTimestamp >= previousTimestamp);
        assert(
            // Dude won the prize, so he has the prize plus his initial balance (- ENTRANCE_FEE because he gambled it) as a balance!
            lastWinner.balance ==
                (prize + (STARTING_USER_BALANCE - ENTRANCE_FEE))
        );
    }
}
