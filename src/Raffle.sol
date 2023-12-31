// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions



//SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
/**
 * @title A sample Raffel contract
 * @author Package Father
 * @notice This contract is for creating a sample raffle
 * @dev Implements chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2{
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
        //take note that rafflestate is now uint256, that is because
        //its data type is enum and enum states can also be represented as numbers
    );
    //0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c
    //Type declarations
    enum RaffleState {
        OPEN, //0
        CALCULATING //1
    }
    
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;


    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    address payable [] private s_players;
    uint256 private s_lastTimeStamp;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /** Events */
    event  EnteredRaffle(address indexed player);
    event PickedWinner (address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);



    constructor(
        uint64 subscriptionId,
        bytes32 gasLane, //keyhash
        uint256 interval, 
        uint256 entranceFee, 
        uint32 callbackGasLimit,
        address vrfCoordinator

        ) VRFConsumerBaseV2(vrfCoordinator){

        i_entranceFee= entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
    }

    function enterRaffle() external payable {
        //require(msg.value >= i_entranceFee, "Not enough value sent");
        if(msg.value < i_entranceFee){
            revert Raffle__NotEnoughEthSent();
        }
        if(s_raffleState != RaffleState.OPEN){
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

     /**
     * @dev This is the function that the Chainlink Keeper nodes call
     * they look for `upkeepNeeded` to return True.
     * the following should be true for this to return true:
     * 1. The time interval has passed between raffle runs.
     * 2. The raffle is OPEN state.
     * 3. The contract has ETH.
     * 4. Implicity, your subscription is funded with LINK.
     */
    function checkUpkeep(bytes memory /* checkData */)public view returns(bool upkeepNeeded, bytes memory /* performData */){
        //notice that we have given a variable name to the data type in the 
        //return statement, with this we do not have to explicitly write, return
        //this or that. it just returns those things in the bracket on its own

        //this checkupkeep is like asking if the peform upkeep has been done already
        //or it is time enough to do it or if the balance is enough to do it.
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");
        // we are just writing this for writing sake, following the comment above
        //we wouldnt need to write this, it would still return cause we defined it in there

     } 
    

    //1. Get a random number
    //this performUpkeep in our contract is for admin to call on random number 
    //and pick a lucky player 
    //from list of entered players
    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if(!upkeepNeeded){
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, //keyhash
            i_subscriptionId, //the id to fund with link to make request
            REQUEST_CONFIRMATIONS, 
            i_callbackGasLimit, //to make sure we dont over spend on this call
            NUM_WORDS //number of random numbers we want
        );
        emit RequestedRaffleWinner(requestId);
    }
    
    //CEI: Checks, Effects, Interactions
    function fulfillRandomWords(
        uint256 /*_requestId */,
        uint256[] memory randomWords
    ) internal override {
        //Checks : things like require(if -> errors)
        /*
        it is also gas efficient cause at this point 
        if the check aint passed, gas spent so far aint much
        as against having spent so much before the check that even fails
        */

        //Effects (Our own contract)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;

        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(winner);
        
        //Interactions (Other contracts) 
        /**
         * This really helps avoid reentracy attacks
         */
        (bool success,) = s_recentWinner.call{value: address(this).balance}("");
        if(!success){
            revert Raffle__TransferFailed();
        }
        

    }


    function getEntranceFee()  external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState()  external view returns (RaffleState) {
        return s_raffleState;
    }

    function getInterval()  external view returns (uint256) {
        return i_interval;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns(address){
        return s_players[indexOfPlayer];
    }

    function getRaffleBalance() external view returns(uint256){
        return address(this).balance;
    }


    function getRecentWinner() external view returns(address){
        return s_recentWinner;
    }

    function getLengthOfPlayers() external view returns(uint256){
        return s_players.length;
    }

    function getLastTimeStamp() external view returns(uint256){
        return s_lastTimeStamp;
    }
}