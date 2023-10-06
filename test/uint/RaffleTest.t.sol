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
        /*Events */
        event EnteredRaffle(address indexed player);

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
        vm.deal(PLAYER, STARTING_USER_BALANCE);

       
    }

     function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

     /////////////////////////
    // enterRaffle         //
    /////////////////////////

    function testRaffleRevertsWHenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        //here we are saying, expect this error stated in the raffle code
        raffle.enterRaffle();
        //we call enterRaffle without seinding any value. 
        //it should pass by failing with the error stated
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: raffleEntranceFee}();
        // Assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    /**
         * EVENTS
         * Event Signature by foundry
         * function expectEmit(
         * bool checkTopic1,
         * bool checkTopic2,
         * bool checkTopic3,
         * bool checkData
         * ) external;
         * 
         *  function expectEmit(
         * bool checkTopic1,
         * bool checkTopic2,
         * bool checkTopic3,
         * bool checkData,
         * address emitter
         * ) external;
         * 
         */
    function testEmitsEventOnEntrance() public {
        // Arrange
        vm.prank(PLAYER);

        // Act / Assert
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
    }

    function testCantEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1); //sets the blocktimestamp
        //so here we are fast forwad=rding the time to the interval required to pass
        //then adding extra 1 second to it
        vm.roll(block.number + 1);
        raffle.performUpkeep(""); //since time is passed, we should be able to call this
        //this performUpkeep in our contract is for admin to call on random number and pick a lucky player 
        //from list of entered players

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
    }
}