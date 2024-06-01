// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";
import {console} from "forge-std/Test.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 entranceFee,
            uint256 interval,
            address coordinator,
            bytes32 keyHash,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            address linkAddress
        ) = helperConfig.activeNetworkConfig();

        if (subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (uint64 subId, address vrfCoordinatorAddress) = createSubscription
                .run(helperConfig);
            coordinator = vrfCoordinatorAddress;
            subscriptionId = subId;
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                vrfCoordinatorAddress,
                subId,
                linkAddress
            );
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            entranceFee,
            interval,
            coordinator,
            keyHash,
            subscriptionId,
            callbackGasLimit
        );
        vm.stopBroadcast();
        console.log("coordinator is", coordinator);
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle), coordinator, subscriptionId);
        console.log(
            "Adding coordinator with subId",
            coordinator,
            subscriptionId
        );
        return (raffle, helperConfig);
    }
}
