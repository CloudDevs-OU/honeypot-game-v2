// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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
        require(msg.sender.code.length == 0, "Only user accounts!");
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

        // Buy box
        bank.subtract(msg.sender, boxes[boxId].price);

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

    /**
     * @dev Create or update existing box if box with such id is already exist
     *
     * @param boxId box identifier
     * @param price box price in tokens
     * @param prizes array of possible prizes
     */
    function createOrUpdateBox(uint boxId, uint price, Prize[] memory prizes) external onlyOwner {
        require(prizes.length > 0);

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
        emit BoxDelete(boxId);
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
}