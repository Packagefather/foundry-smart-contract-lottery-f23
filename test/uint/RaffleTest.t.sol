// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
// import {Vm} from "forge-std/Vm.sol";
// import {StdCheats} from "forge-std/StdCheats.sol";
// import {VRFCoordinatorV2Mock} from "../mocks/VRFCoordinatorV2Mock.sol";
// import {CreateSubscription} from "../../script/Interactions.s.sol";

contract RaffleTest is Test {
        Raffle raffle;
        HelperConfig helperConfig;

        address public PLAYER = makeAddr("player");
        uint256 public constant STARTING_USER_BALANCE = 10 ether;

        uint64 subscriptionId;
        bytes32 gasLane;
        uint256 automationUpdateInterval;
        uint256 raffleEntranceFee;
        uint32 callbackGasLimit;
        address vrfCoordinatorV2;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();

        (
            subscriptionId,
            gasLane,
            automationUpdateInterval,
            raffleEntranceFee,
            callbackGasLimit,
            vrfCoordinatorV2 // link
            // deployerKey
            //,

        ) = helperConfig.activeNetworkConfig();
        //vm.deal(PLAYER, STARTING_USER_BALANCE);

       
    }

     function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }
}