// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract InteractionsTest is Test {
    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testHelperLoadsConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 entranceFee,
            uint256 interval,
            address coordinator,
            bytes32 keyHash,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        assert(entranceFee > 0);
        assert(interval > 0);
        assert(coordinator != address(0));
        assert(keyHash != bytes32(0));
        assert(subscriptionId == 0);
        assert(callbackGasLimit == 500000);
        assert(link != address(0));
        assert(deployerKey != 0);
    }
}
