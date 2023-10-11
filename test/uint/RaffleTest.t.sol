// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
// import {StdCheats} from "forge-std/StdCheats.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
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
        address link;
        uint256 deployerKey;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();

        (
            subscriptionId,
            gasLane,
            automationUpdateInterval,
            raffleEntranceFee,
            callbackGasLimit,
            vrfCoordinatorV2, // link
            link,
            deployerKey
            

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
        //warp for time-travelling
        vm.warp(block.timestamp + automationUpdateInterval + 1); //sets the blocktimestamp
        //so here we are fast forwad=rding the time to the interval required to pass
        //then adding extra 1 second to it
        vm.roll(block.number + 1); //roll for mining blocks.

        raffle.performUpkeep(""); //since time is passed, we should be able to call this
        //this performUpkeep in our contract is for admin to call on random number and pick a lucky player 
        //from list of entered players

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector); //remember this revert is for next rxn
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        
    }

    /////////////////////////
    // checkUpkeep         //
    /////////////////////////
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        //this no balance means if no one has entered the raffle, based on 
        //sending value into it
        // Arrange
        uint256 raffleInterval = raffle.getInterval();

        //1. //the condition of time being enough for performupkeep is true
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        //uint256 currentTime = block.timestamp + automationUpdateInterval + 1;

        //2. //condition of sending balance is false, we didnt initiate sending value
        
        
        //3. //condition of it being OPEN should be true currently
        Raffle.RaffleState raffleState = raffle.getRaffleState();


        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep(""); 
        //upkeep aint needed, so this is false

        // Assert
        assert(!upkeepNeeded);
        assert(raffleState == Raffle.RaffleState.OPEN);
        //assert(currentTime >= raffleInterval);
    }


    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(raffleState == Raffle.RaffleState.CALCULATING);
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        //first condition met, there is balance by player entering the raffle

        uint256 raffleInterval = raffle.getInterval();
        uint256 currentTime = block.timestamp;
        //second condition is time before we can perform upkeep, 
        //it is not yet time. so this is false.

        //lets go further by checking the third condition of it being open
        //so we will be sure  it is the time that if making it to fail
        Raffle.RaffleState raffleState = raffle.getRaffleState();


        //lets check balance of raffle to be sure it has balance
        uint256 raffleBal = raffle.getRaffleBalance();
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded == false);
        assert(raffleInterval >= currentTime);
        assert(raffleState == Raffle.RaffleState.OPEN);
        assert(raffleBal >= raffleEntranceFee);

    }

    function testCheckUpKeepReturnsTrueWhenParametersAreGood() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();

        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);


        Raffle.RaffleState raffleState = raffle.getRaffleState();

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
       
       //so by progression, we can say that once we manually meet 
       //the other conditions like we have now, we do not need
       //to assert them again. we assert the one that we have not set
        assert(raffleState == Raffle.RaffleState.OPEN);
        assert(upkeepNeeded == true);

    }


    
    /////////////////////////
    // performUpkeep       //
    /////////////////////////

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);

        // Act / Assert
        // It doesnt revert
        raffle.performUpkeep("");
        //there is not notExpectRevert function, so when the performUpKeep
        //on its own passes, it will pass
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();


        // Act / Assert
        //remember the expect revert is for the next trxn
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                rState
            )
        );//this is how it is done when there are params in custom errors
        raffle.performUpkeep("");
    }

    modifier raffleEnteredAndTimePassed {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEnteredAndTimePassed{
    
        // Act
        vm.recordLogs(); //saves all the logs including events
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // requestId = raffle.getLastRequestId();
        assert(uint256(requestId) > 0);
        assert(uint(raffleState) == 1); // 0 = open, 1 = calculating
    }


    /////////////////////////
    // fulfillRandomWords //
    ////////////////////////

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId)
        public
        raffleEnteredAndTimePassed
        
    {
        // Arrange
        // Act / Assert
        vm.expectRevert("nonexistent request");
        // vm.mockCall could be used here...
        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );

        
    }


    
    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEnteredAndTimePassed
        
    {
        //address expectedWinner = address(1);

        // Arrange
        uint256 additionalEntrances = 5;
        uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0)

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrances;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE); // deal 1 eth to the player
            raffle.enterRaffle{value: raffleEntranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        //uint256 startingBalance = expectedWinner.balance;

         uint256 prize = raffleEntranceFee * (additionalEntrances + 1);

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = raffle.getRecentWinner().balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
       

        assert(raffle.getRecentWinner() != address(0));
        //assert(uint256(raffleState) == 0);
        //assert(raffle.getLengthOfPlayers() == 0);
        //assert(endingTimeStamp > startingTimeStamp);
        assert(winnerBalance == STARTING_USER_BALANCE + prize - raffleEntranceFee);
        
    }

}