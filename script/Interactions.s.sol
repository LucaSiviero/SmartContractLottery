// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64, address) {
        HelperConfig helperConfig = new HelperConfig();

        (, , address coordinator, , , , ) = helperConfig.activeNetworkConfig();
        (uint64 subscriptionId, address vrfCoordinator) = createSubscription(
            coordinator
        );
        return (subscriptionId, vrfCoordinator);
    }

    function createSubscription(
        address _vrfCoordinator
    ) public returns (uint64, address) {
        console.log("Creating subscription on ChainId: ", block.chainid);
        vm.startBroadcast();
        uint64 subscriptionId = VRFCoordinatorV2Mock(_vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        return (subscriptionId, _vrfCoordinator);
    }

    function run() external returns (uint64, address) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address coordinator,
            ,
            uint64 subscriptionId,
            ,
            address linkAddress
        ) = helperConfig.activeNetworkConfig();
        if (subscriptionId == 0) {
            CreateSubscription createSub = new CreateSubscription();
            (uint64 updatedSubId, ) = createSub.run();
            subscriptionId = updatedSubId;
        }
        fundSubscription(coordinator, subscriptionId, linkAddress);
    }

    function fundSubscription(
        address _coordinator,
        uint64 _subscriptionId,
        address _linkAddress
    ) public {
        console.log("Funding subscription: ", _subscriptionId);
        console.log("Using VRFCoordinator: ", _coordinator);
        console.log("On ChainID: ", block.chainid);
        if (block.chainid == 31337) {
            vm.startBroadcast();
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
            vm.startBroadcast();
            LinkToken(_linkAddress).transferAndCall(
                _coordinator,
                FUND_AMOUNT,
                abi.encode(_subscriptionId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(
        address _contractAddress,
        address _coordinator,
        uint64 _subscriptionId
    ) public {
        console.log("Adding consumer contract: ", _contractAddress);
        console.log("Using VRFCoordinator: ", _coordinator);
        console.log("SubscriptionID is", _subscriptionId);
        console.log("On ChainID: ", block.chainid);

        vm.startBroadcast();
        VRFCoordinatorV2Mock(_coordinator).addConsumer(
            _subscriptionId,
            _contractAddress
        );
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address _contractAddress) public {
        HelperConfig helperConfig = new HelperConfig();
        (, , address coordinator, , uint64 subscriptionId, , ) = helperConfig
            .activeNetworkConfig();
        addConsumer(_contractAddress, coordinator, subscriptionId);
    }

    function run() external {
        address raffleContractAddress = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(raffleContractAddress);
    }
}
