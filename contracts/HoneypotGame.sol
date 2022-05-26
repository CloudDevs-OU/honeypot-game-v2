// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import"./interface/IApiaryLand.sol";
import"./interface/IBeeItem.sol";
import"./interface/IHoneyBank.sol";
import"./interface/IUserRegistry.sol";

contract HoneypotGame is ERC1155Holder, Ownable {
    // Structs
    struct PartnerAccount {
        address account;
        address upline;
        uint level;
        uint[10] earned;
        uint[10] missed;
        uint[10] count;
    }

    // Constants
    uint constant public REWARDABLE_LINES = 10;

    // State
    IApiaryLand public land;
    IBeeItem public item;
    IHoneyBank public bank;
    IUserRegistry public registry;

    uint public registrationPrice;
    uint public slotPrice;
    uint[] beePrices;
    uint[] salableItems;
    mapping(uint => uint) itemPrices;
    mapping(address => PartnerAccount) partners;

    constructor(IApiaryLand _land, IBeeItem _item, IHoneyBank _bank, IUserRegistry _registry) {
        land = _land;
        item = _item;
        bank = _bank;
        registry = _registry;

        registrationPrice = 100 ether;
        slotPrice = 10 ether;
        beePrices = [250 ether, 500 ether, 1000 ether, 3000 ether, 5000 ether, 10000 ether, 20000 ether];
    }

    /**
     * @dev Register msg.sender in registry, create apiary, subtract registration fee and create partner account
     *
     * @param referrer account that invite msg.sender
     */
    function register(address referrer) public {
        // Take registration fee
        bank.subtract(msg.sender, registrationPrice);

        // Register in global user registry
        registry.register(msg.sender, referrer);

        // Create apiary
        land.createApiary(msg.sender);

        // Register partner account
        partners[msg.sender].account = msg.sender;
        partners[msg.sender].upline = referrer;
    }

    /**
     * @dev Buy bees
     *
     * @notice msg.sender must be registered
     *
     * @param beeIds array of bee ids to buy
     * @param amounts array that correspond to bee amounts from beeIds
     */
    function buyBees(uint[] memory beeIds, uint[] memory amounts) public {
        uint totalCost;
        for(uint i; i < beeIds.length; i++) {
            totalCost += beePrices[beeIds[i] - 1] * amounts[i];
        }

        require(totalCost > 0, "totalCost must be >0");
        bank.subtract(msg.sender, totalCost);
        land.addBees(msg.sender, beeIds, amounts);
        partners[msg.sender].level = calcUserPartnerLevel(msg.sender);
    }

    /**
     * @dev Buy items
     *
     * @param itemIds array of item ids
     * @param amounts array of amount of items corresponding to itemIds
     */
    function buyItems(uint[] memory itemIds, uint[] memory amounts) public {
        require(itemIds.length == amounts.length, "itemIds.length must be equal to amounts.length");
        require(itemIds.length > 0, "packs must be > 0");

        uint totalCost;
        for(uint i; i < itemIds.length; i++) {
            require(itemIds[i] != 0, "item id can not be 0");
            require(amounts[i] != 0, "items amount can not be 0");
            require(itemPrices[itemIds[i]] != 0, "item is not salable");
            totalCost += itemPrices[itemIds[i]] * amounts[i];
        }

        bank.subtract(msg.sender, totalCost);
        item.mintBatch(msg.sender, itemIds, amounts);
    }

    /**
     * @dev Buy slot packs
     *
     * @notice msg.sender must be registered
     *
     * @param packs 1 pack = 10 slots
     */
    function buySlotPacks(uint packs) public {
        require(packs > 0, "packs must be > 0");

        uint totalCost = packs * 10 * slotPrice;
        bank.subtract(msg.sender, totalCost);
        land.addSlots(msg.sender, packs * 10);
    }

    /**
     * @dev Set items to owner apiary. Items that no longer in use will be returned to user
     * and new items will be taken from user.
     *
     * @notice msg.sender must be registered
     *
     * @param itemIds array of item ids that must be set. Each item must be appropriate for beeId (item index + 1)
     */
    function setApiaryItems(uint[7] memory itemIds) public {
        (uint[7] memory notUsedItems, uint[7] memory newItems) = land.setApiaryItems(msg.sender, itemIds);
        for(uint i; i < notUsedItems.length; i++) {
            if (notUsedItems[i] != 0) {
                item.safeTransferFrom(address(this), msg.sender, notUsedItems[i], 1, "");
            }
            if (newItems[i] != 0) {
                item.safeTransferFrom(msg.sender, address(this), newItems[i], 1, "");
            }
        }
        partners[msg.sender].level = calcUserPartnerLevel(msg.sender);
    }

    /**
     * @dev Add items for sale
     *
     * @notice Can be accessed only by contract admin
     *
     * @param itemIds array of item ids to publish for sale
     * @param prices array of itemIds prices
     */
    function addItemsForSale(uint[] memory itemIds, uint[] memory prices) public onlyOwner {
        require(itemIds.length == prices.length, "itemIds.length must be equal to prices.length");
        require(itemIds.length > 0, "itemIds.length must be > 0");
        for(uint i; i < itemIds.length; i++) {
            require(itemPrices[itemIds[i]] == 0, "Item is already presented");
            require(itemIds[i] > 0, "itemIds[i] must be > 0");
            require(prices[i] > 0, "prices[i] must be > 0");

            salableItems.push(itemIds[i]);
            itemPrices[itemIds[i]] = prices[i];
        }
    }

    /**
     * @dev Update registration price value
     *
     * @notice Can be accessed only by contract admin
     *
     * @param _registrationPrice new registration price
     */
    function setRegistrationPrice(uint _registrationPrice) public onlyOwner {
        registrationPrice = _registrationPrice;
    }

    /**
     * @dev Update slot price
     *
     * @notice Can be accessed only by contract admin
     *
     * @param _slotPrice new slot price
     */
    function setSlotPrice(uint _slotPrice) public onlyOwner {
        slotPrice = _slotPrice;
    }

    /**
     * @dev Update bee prices
     *
     * @notice Can be accessed only by contract admin
     *
     * @param _beePrices new bee prices
     */
    function setBeePrices(uint[] memory _beePrices) public onlyOwner {
        beePrices = _beePrices;
    }

    /**
     * @dev Get bee prices
     */
    function getBeePrices() public view returns(uint[] memory) {
        return beePrices;
    }

    /**
     * @dev Get PartnerAccount
     */
    function getPartnerAccount(address account) public view returns(PartnerAccount memory) {
        return partners[account];
    }

    /**
     * @dev Get salable items with prices
     */
    function getSalableItems() public view returns(uint[] memory, uint[] memory) {
        uint[] memory prices = new uint[](salableItems.length);
        for(uint i; i < salableItems.length; i++) {
            prices[i] = itemPrices[salableItems[i]];
        }
        return (salableItems, prices);
    }

    /**
     * @dev Calc user partner level based on items
     */
    function calcUserPartnerLevel(address account) private view returns(uint) {
        (uint[7] memory bees, uint[7] memory items, bool isSet) = land.getBeesAndItems(account);
        uint level;
        for(uint i; i < bees.length; i++) {
            if(bees[i] > 0 && items[i] > 0) {
                level++;
            }
        }

        if(level == 7 && isSet) {
            level = REWARDABLE_LINES;
        }

        return level;
    }
}