// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig(
        HelperConfig helperConfig
    ) public returns (uint64, address) {
        (, , address coordinator, , , , , uint256 deployerKey) = helperConfig
            .activeNetworkConfig();
        (uint64 subscriptionId, address vrfCoordinator) = createSubscription(
            coordinator,
            deployerKey
        );
        console.log("Created subscription with coordinator", coordinator);
        return (subscriptionId, vrfCoordinator);
    }

    function createSubscription(
        address _vrfCoordinator,
        uint256 _deployerKey
    ) public returns (uint64, address) {
        vm.startBroadcast(_deployerKey);
        uint64 subscriptionId = VRFCoordinatorV2Mock(_vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        return (subscriptionId, _vrfCoordinator);
    }

    function run(HelperConfig helperConfig) external returns (uint64, address) {
        return createSubscriptionUsingConfig(helperConfig);
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig(HelperConfig helperConfig) public {
        (
            ,
            ,
            address coordinator,
            ,
            uint64 subscriptionId,
            ,
            address linkAddress,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        if (subscriptionId == 0) {
            CreateSubscription createSub = new CreateSubscription();
            (uint64 updatedSubId, ) = createSub.run(helperConfig);
            subscriptionId = updatedSubId;
        }
        fundSubscription(coordinator, subscriptionId, linkAddress, deployerKey);
    }

    function fundSubscription(
        address _coordinator,
        uint64 _subscriptionId,
        address _linkAddress,
        uint256 _deployerKey
    ) public {
        console.log("Funding subscription: ", _subscriptionId);
        console.log("Using VRFCoordinator: ", _coordinator);
        console.log("On ChainID: ", block.chainid);
        if (block.chainid == 31337) {
            vm.startBroadcast(_deployerKey);
            VRFCoordinatorV2Mock(_coordinator).fundSubscription(
                _subscriptionId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            console.log(LinkToken(_linkAddress).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(_linkAddress).balanceOf(address(this)));
            console.log(address(this));
            vm.startBroadcast(_deployerKey);
            LinkToken(_linkAddress).transferAndCall(
                _coordinator,
                FUND_AMOUNT,
                abi.encode(_subscriptionId)
            );
            vm.stopBroadcast();
        }
    }

    function run(HelperConfig helperConfig) external {
        fundSubscriptionUsingConfig(helperConfig);
    }
}

contract AddConsumer is Script {
    function addConsumer(
        address _contractAddress,
        address _coordinator,
        uint64 _subscriptionId,
        uint256 _deployerKey
    ) public {
        console.log("Adding consumer contract: ", _contractAddress);
        console.log("Using VRFCoordinator: ", _coordinator);
        console.log("SubscriptionID is", _subscriptionId);
        console.log("On ChainID: ", block.chainid);

        vm.startBroadcast(_deployerKey);
        VRFCoordinatorV2Mock(_coordinator).addConsumer(
            _subscriptionId,
            _contractAddress
        );
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(
        address _contractAddress,
        HelperConfig helperConfig
    ) public {
        (
            ,
            ,
            address coordinator,
            ,
            uint64 subscriptionId,
            ,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        addConsumer(_contractAddress, coordinator, subscriptionId, deployerKey);
    }

    function run(HelperConfig helperConfig) external {
        address raffleContractAddress = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(raffleContractAddress, helperConfig);
    }
}
