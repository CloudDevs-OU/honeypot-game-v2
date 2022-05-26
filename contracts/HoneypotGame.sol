// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import"./interface/IApiaryLand.sol";
import"./interface/IBeeItem.sol";
import"./interface/IHoneyBank.sol";

contract HoneypotGame is ERC1155Holder, Ownable {
    // Structs
    struct User {
        address account;
        address upline;
        uint registrationTimestamp;
        uint partnerLevel;
        uint[10] partnerEarnReward;
        uint[10] partnerMissedReward;
        uint[10] partnerCount;
    }

    // Constants
    uint constant public REWARDABLE_LINES = 10;

    // State
    IApiaryLand public land;
    IBeeItem public item;
    IHoneyBank public bank;

    uint public registrationPrice;
    uint public slotPrice;
    uint[] beePrices;
    uint[] salableItems;
    uint[10] partnerRewardPercents;
    mapping(uint => uint) itemPrices;
    mapping(address => User) users;

    constructor(IApiaryLand _land, IBeeItem _item, IHoneyBank _bank) {
        land = _land;
        item = _item;
        bank = _bank;

        registrationPrice = 100 ether;
        slotPrice = 10 ether;
        beePrices = [250 ether, 500 ether, 1000 ether, 3000 ether, 5000 ether, 10000 ether, 20000 ether];
        partnerRewardPercents = [500, 400, 300, 200, 100, 100, 100, 100, 100, 100]; // 1 % = 100

        // Admin preset
        users[msg.sender].account = msg.sender;
        users[msg.sender].registrationTimestamp = block.timestamp;
        users[msg.sender].partnerLevel = REWARDABLE_LINES;
    }

    /**
     * @dev Register user account, create apiary and subtract registration fee
     *
     * @param upline account that invite msg.sender
     */
    function register(address upline) public {
        require(!isRegistered(msg.sender), "User is already registered");
        require(upline != address(0), 'Upline can not be zero');
        require(isRegistered(upline), "Upline is not registered");

        // Take registration fee
        bank.subtract(msg.sender, registrationPrice);

        // Create apiary
        land.createApiary(msg.sender);

        // Register user
        users[msg.sender].account = msg.sender;
        users[msg.sender].upline = upline;
        users[msg.sender].registrationTimestamp = block.timestamp;

        // Update upline partner counts
        address[] memory uplines = getUplines(msg.sender, REWARDABLE_LINES);
        for(uint line; line < uplines.length && uplines[line] != address(0); line++) {
            users[uplines[line]].partnerCount[line]++;
        }
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
        users[msg.sender].partnerLevel = calcUserPartnerLevel(msg.sender);
        sendPartnerReward(msg.sender, totalCost);
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
        sendPartnerReward(msg.sender, totalCost);
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
        users[msg.sender].partnerLevel = calcUserPartnerLevel(msg.sender);
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
     * @dev Update partner reward percents
     *
     * @notice Can be accessed only by contract admin
     *
     * @param _partnerRewardPercents new partner reward percents
     */
    function setPartnerRewardPercents(uint[10] memory _partnerRewardPercents) public onlyOwner {
        partnerRewardPercents = _partnerRewardPercents;
    }

    /**
     * @dev Send partner reward to uplines
     *
     * @param referral user who made a buy
     * @param spentAmount tokens amount that was spent
     */
    function sendPartnerReward(address referral, uint spentAmount) private {
        address[] memory upline = getUplines(referral, REWARDABLE_LINES);
        for(uint i; i < upline.length && upline[i] != address(0); i++) {
            uint reward = spentAmount * partnerRewardPercents[i] / 10000;
            if(users[upline[i]].partnerLevel > i) {
                users[upline[i]].partnerEarnReward[i] += reward;
                bank.add(users[upline[i]].account, reward);
            } else {
                users[upline[i]].partnerMissedReward[i] += reward;
            }
        }
    }

    /**
     * @dev Get partner reward percents
     */
    function getPartnerRewardPercents() public view returns(uint[10] memory) {
        return partnerRewardPercents;
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
    function getUser(address account) public view returns(User memory) {
        return users[account];
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
     * @dev Get user upline addresses
     *
     * @param account user address
     * @param amount amount of uplines
     * @return array of upline addresses in order of upline value
     */
    function getUplines(address account, uint amount) public view returns(address[] memory) {
        address[] memory result = new address[](amount);

        uint uplineIndex = 0;
        address uplineAddress = users[account].upline;
        while(uplineAddress != address(0) && uplineIndex < amount) {
            result[uplineIndex++] = uplineAddress;
            uplineAddress = users[uplineAddress].upline;
        }

        return result;
    }

    /**
     * @dev Check is user registered
     *
     * @param account user address for check
     * @return true/false
     */
    function isRegistered(address account) public view returns(bool) {
        return account != address(0) && users[account].account == account;
    }

    /**
     * @dev Calc user partner level based on items
     */
    function calcUserPartnerLevel(address account) private view returns(uint) {
        if (account == owner()) {
            return REWARDABLE_LINES;
        }

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