// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/*
OFFICIAL WEBSITE: https://honeypot.game

 /$$   /$$                                                     /$$            /$$$$$$
| $$  | $$                                                    | $$           /$$__  $$
| $$  | $$  /$$$$$$  /$$$$$$$  /$$   /$$  /$$$$$$   /$$$$$$  /$$$$$$        | $$  \__/  /$$$$$$  /$$$$$$/$$$$   /$$$$$$
| $$$$$$$$ /$$__  $$| $$__  $$| $$  | $$ /$$__  $$ /$$__  $$|_  $$_/        | $$ /$$$$ |____  $$| $$_  $$_  $$ /$$__  $$
| $$__  $$| $$  \ $$| $$  \ $$| $$  | $$| $$  \ $$| $$  \ $$  | $$          | $$|_  $$  /$$$$$$$| $$ \ $$ \ $$| $$$$$$$$
| $$  | $$| $$  | $$| $$  | $$| $$  | $$| $$  | $$| $$  | $$  | $$ /$$      | $$  \ $$ /$$__  $$| $$ | $$ | $$| $$_____/
| $$  | $$|  $$$$$$/| $$  | $$|  $$$$$$$| $$$$$$$/|  $$$$$$/  |  $$$$/      |  $$$$$$/|  $$$$$$$| $$ | $$ | $$|  $$$$$$$
|__/  |__/ \______/ |__/  |__/ \____  $$| $$____/  \______/    \___/         \______/  \_______/|__/ |__/ |__/ \_______/
                               /$$  | $$| $$
                              |  $$$$$$/| $$
                               \______/ |__/
*/

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/IHoneypotGame.sol";
import "./interface/IHoneyBank.sol";
import "./interface/IBeeItem.sol";
import "./interface/IApiaryLand.sol";
import "hardhat/console.sol";

/**
* @title Box with prizes (slots, tokens, bees, NFTs)
* @author Rustam Mamedov
*/
contract HoneyBox is Ownable {
    // Structs and enums
    enum PrizeType {SLOTS, TOKENS, BEE, NFT}

    struct Prize {
        PrizeType prizeType;
        uint value;
        uint weight;
    }

    struct Box {
        uint price;
        uint totalPrizes;
        uint totalWeight;
        mapping(uint => Prize) prizes;
    }

    // Events
    event Win(address account, uint boxId, uint boxPrice, PrizeType prizeType, uint value);
    event BoxUpdate(uint boxId, uint price, Prize[] prizes);
    event BoxDelete(uint boxId);

    // Modifiers
    /**
     * @dev Check that msg.sender is not smart contract and registered user.
     * Also check that registration timestamp is not equal to current block timestamp in order to avoid hacks
     * with smart contracts zero code size
     */
    modifier notContractAndRegistered() {
        require(msg.sender.code.length == 0 && msg.sender == tx.origin, "Only user accounts!");
        uint registrationTimestamp = game.getRegistrationTimestamp(msg.sender);
        require(registrationTimestamp > 0 && registrationTimestamp < block.timestamp, "Only registered users");
        _;
    }

    // State
    uint public nonce;
    uint[] boxIds;
    mapping(uint => Box) boxes;
    IHoneypotGame public game;
    IHoneyBank public bank;
    IBeeItem public item;
    IApiaryLand public land;

    // Welcome Boxes
    uint public constant welcomeBoxId = 42;
    uint public availableWelcomeBoxes = 1000;
    mapping(address => bool) welcomeBoxOpened;

    // Everyday Boxes
    uint public constant everydayBoxId = 4242;
    mapping(address => uint) lastEverydayBoxOpen;

    constructor(IHoneypotGame _game, IHoneyBank _bank, IBeeItem _item, IApiaryLand _land) {
        game = _game;
        bank = _bank;
        item = _item;
        land = _land;
    }

    /**
     * @dev Buy and open box
     *
     * @param boxId box identifier
     */
    function open(uint boxId) external notContractAndRegistered {
        require(boxes[boxId].totalWeight > 0, "Unknown box id");
        require(boxId != welcomeBoxId, "You can't open welcome box");
        require(boxId != everydayBoxId, "You can't open everyday box");
        require(boxes[boxId].price > 0, "Invalid box price");
        bank.subtract(msg.sender, boxes[boxId].price);
        play(boxId);
    }

    /**
     * @dev Open welcome box
     */
    function openWelcomeBox() public notContractAndRegistered {
        require(availableWelcomeBoxes > 0, "No more welcome boxes available");
        require(!welcomeBoxOpened[msg.sender], "You already received welcome box");
        require(boxes[welcomeBoxId].totalWeight > 0, "Box not configured");

        welcomeBoxOpened[msg.sender] = true;
        availableWelcomeBoxes--;
        play(welcomeBoxId);
    }

    /**
     * @dev Open everyday box
     */
    function openEverydayBox() public notContractAndRegistered {
        require(boxes[everydayBoxId].totalWeight > 0, "Box not configured");
        if (lastEverydayBoxOpen[msg.sender] > 0) {
            require(block.timestamp - lastEverydayBoxOpen[msg.sender] > 1 days, "Box already opened today");
        }
        lastEverydayBoxOpen[msg.sender] = block.timestamp;
        play(everydayBoxId);
    }

    /**
     * @dev Create or update existing box if box with such id is already exist
     *
     * @param boxId box identifier
     * @param price box price in tokens
     * @param prizes array of possible prizes
     */
    function createOrUpdateBox(uint boxId, uint price, Prize[] memory prizes) external onlyOwner {
        require(prizes.length > 0, "Prizes array is empty");
        require(boxId != welcomeBoxId || price == 0, "Welcome box must have zero price");
        require(boxId != everydayBoxId || price == 0, "Everyday box must have zero price");

        if (boxes[boxId].totalWeight == 0) {
            boxIds.push(boxId);
        }

        boxes[boxId].price = price;
        boxes[boxId].totalPrizes = prizes.length;
        boxes[boxId].totalWeight = 0;
        for (uint i; i < prizes.length; i++) {
            require(prizes[i].weight > 0, "Prize weight can't be zero");
            boxes[boxId].prizes[i] = prizes[i];
            boxes[boxId].totalWeight += prizes[i].weight;
        }
        emit BoxUpdate(boxId, price, prizes);
    }

    /**
     * @dev Delete box
     *
     * @param boxId box identifier
     */
    function deleteBox(uint boxId) external onlyOwner {
        delete boxes[boxId];
        for(uint i; i < boxIds.length; i++) {
            if (boxIds[i] == boxId) {
                boxIds[i] = boxIds[boxIds.length - 1];
                boxIds.pop();
            }
        }

        boxes[boxId].price = 0;
        boxes[boxId].totalWeight = 0;
        boxes[boxId].totalPrizes = 0;
        emit BoxDelete(boxId);
    }

    /**
     * @dev Open box and send prize
     *
     * @param boxId box identifier
     */
    function play(uint boxId) private {
        uint number = uint256(keccak256(abi.encodePacked(block.number, block.timestamp, block.difficulty, nonce))) % boxes[boxId].totalWeight;
        uint range;
        for (uint i; i < boxes[boxId].totalPrizes; i++) {
            range += boxes[boxId].prizes[i].weight;
            if (number < range) {
                nonce++;
                Prize storage prize = boxes[boxId].prizes[i];
                if (prize.prizeType == PrizeType.SLOTS) {
                    land.addSlots(msg.sender, prize.value);
                } else if (prize.prizeType == PrizeType.TOKENS) {
                    bank.add(msg.sender, prize.value);
                } else if (prize.prizeType == PrizeType.NFT) {
                    item.mint(msg.sender, prize.value, 1);
                } else if (prize.prizeType == PrizeType.BEE) {
                    uint[] memory bee = new uint[](1);
                    bee[0] = prize.value;

                    uint[] memory amount = new uint[](1);
                    amount[0] = 1;

                    land.addBees(msg.sender, bee, amount);
                }
                emit Win(
                    msg.sender,
                    boxId,
                    boxes[boxId].price,
                    boxes[boxId].prizes[i].prizeType,
                    boxes[boxId].prizes[i].value
                );
                return;
            }
        }
    }

    /*
     * @dev Get active box ids
     *
     * @return array of active box ids
     */
    function getBoxIds() external view returns(uint[] memory) {
        return boxIds;
    }

    /**
     * @dev Get box info
     *
     * @param boxId box identifier
     */
    function getBox(uint boxId) external view returns(uint price, uint totalWeight, Prize[] memory prizes) {
        price = boxes[boxId].price;
        totalWeight = boxes[boxId].totalWeight;
        prizes = new Prize[](boxes[boxId].totalPrizes);
        for(uint i; i < boxes[boxId].totalPrizes; i++) {
            prizes[i] = boxes[boxId].prizes[i];
        }
    }

    /**
     * @dev Check is welcome box available for user
     *
     * @param account user address
     */
    function isWelcomeBoxAvailable(address account) external view returns(bool) {
        uint registrationTimestamp = game.getRegistrationTimestamp(msg.sender);
        return registrationTimestamp > 0 && availableWelcomeBoxes > 0 && !welcomeBoxOpened[account];
    }

    /**
     * @dev Get last everyday box open time
     *
     * @param account user address
     *
     * @return time in seconds
     */
    function getLastEverydayBoxOpenTime(address account) external view returns(uint) {
        return lastEverydayBoxOpen[account];
    }
}