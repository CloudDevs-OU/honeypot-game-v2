// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./interface/IApiaryLand.sol";
import "./interface/IBeeItem.sol";
import "./interface/IHoneyBank.sol";
import "./interface/IHoneypotGame.sol";

contract HoneypotGame is IHoneypotGame, ERC1155Holder, Ownable {
    // Structs
    struct User {
        address account;
        string[] accountAliases;
        address upline;
        uint registrationTimestamp;
        uint partnerLevel;
        uint[10] partnerEarnReward;
        uint[10] partnerMissedReward;
        uint[10] partnerCount;
    }

    // Constants
    uint constant public REWARDABLE_LINES = 10;

    // Events
    event UserRegistration(address account, address upline);
    event BuyBees(address account, uint[] beeIds, uint[] amounts);
    event BuyItems(address account, uint[] itemIds, uint[] amounts);
    event BuySlotPacks(address account, uint packs);
    event BuyAlias(address account, string ref);
    event PartnerLevelUpdate(address account, uint oldLevel, uint newLevel);
    event ClaimProfit(address account, uint profit);
    event PartnerReward(address account, address referral, uint line, uint reward);
    event MissedPartnerReward(address account, address referral, uint line, uint reward);

    // State
    IApiaryLand public land;
    IBeeItem public item;
    IHoneyBank public bank;

    uint public registrationPrice;
    uint public aliasPrice;
    uint public slotPrice;
    uint[7] beePrices;
    uint[] salableItems;
    uint[10] partnerRewardPercents;
    mapping(uint => uint) itemPrices;
    mapping(address => User) users;
    mapping(string => address) aliasAddress;
    uint public totalUsers;

    constructor(IApiaryLand _land, IBeeItem _item, IHoneyBank _bank) {
        land = _land;
        item = _item;
        bank = _bank;

        registrationPrice = 5000 ether;
        slotPrice = 250 ether;
        aliasPrice = 10000 ether;
        beePrices = [20000 ether, 50000 ether, 75000 ether, 120000 ether, 160000 ether, 200000 ether, 250000 ether];
        partnerRewardPercents = [500, 400, 300, 200, 100, 100, 100, 100, 100, 100]; // 1 % = 100

        // Admin preset
        users[msg.sender].account = msg.sender;
        users[msg.sender].registrationTimestamp = block.timestamp;
        users[msg.sender].partnerLevel = REWARDABLE_LINES;
        totalUsers++;
    }

    /**
     * @dev Register user account, create apiary and subtract registration fee
     *
     * @param upline account that invite msg.sender
     */
    function register(address upline) external {
        require(!isRegistered(msg.sender), "User is already registered");
        require(upline != address(0), 'Upline can not be zero');
        require(isRegistered(upline), "Upline is not registered");

        // Register user
        users[msg.sender].account = msg.sender;
        users[msg.sender].upline = upline;
        users[msg.sender].registrationTimestamp = block.timestamp;

        // Update upline partner counts
        address[] memory uplines = getUplines(msg.sender, REWARDABLE_LINES);
        for(uint line; line < uplines.length && uplines[line] != address(0); line++) {
            users[uplines[line]].partnerCount[line]++;
        }

        // Take registration fee
        bank.subtract(msg.sender, registrationPrice);

        // Create apiary
        land.createApiary(msg.sender);

        totalUsers++;
        emit UserRegistration(msg.sender, upline);
    }

    /**
     * @dev Buy bees
     *
     * @notice msg.sender must be registered
     *
     * @param beeIds array of bee ids to buy
     * @param amounts array that correspond to bee amounts from beeIds
     */
    function buyBees(uint[] memory beeIds, uint[] memory amounts) external {
        uint totalCost;
        for(uint i; i < beeIds.length; i++) {
            totalCost += beePrices[beeIds[i] - 1] * amounts[i];
        }

        require(totalCost > 0, "totalCost must be >0");
        bank.subtract(msg.sender, totalCost);
        land.addBees(msg.sender, beeIds, amounts);
        sendPartnerReward(msg.sender, totalCost);

        emit BuyBees(msg.sender, beeIds, amounts);
    }

    /**
     * @dev Buy items
     *
     * @param itemIds array of item ids
     * @param amounts array of amount of items corresponding to itemIds
     */
    function buyItems(uint[] memory itemIds, uint[] memory amounts) external {
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

        emit BuyItems(msg.sender, itemIds, amounts);
    }

    /**
     * @dev Buy slot packs
     *
     * @notice msg.sender must be registered
     *
     * @param packs 1 pack = 10 slots
     */
    function buySlotPacks(uint packs) external {
        require(packs > 0, "packs must be > 0");

        uint totalCost = packs * 10 * slotPrice;
        bank.subtract(msg.sender, totalCost);
        land.addSlots(msg.sender, packs * 10);

        emit BuySlotPacks(msg.sender, packs);
    }

    /**
     * @dev Set items to owner apiary. Items that no longer in use will be returned to user
     * and new items will be taken from user.
     *
     * @notice msg.sender must be registered
     *
     * @param itemIds array of item ids that must be set. Each item must be appropriate for beeId (item index + 1)
     */
    function setApiaryItems(uint[7] memory itemIds) external {
        (uint[7] memory notUsedItems, uint[7] memory newItems) = land.setApiaryItems(msg.sender, itemIds);
        for(uint i; i < notUsedItems.length; i++) {
            if (notUsedItems[i] != 0) {
                item.safeTransferFrom(address(this), msg.sender, notUsedItems[i], 1, "");
            }
            if (newItems[i] != 0) {
                item.safeTransferFrom(msg.sender, address(this), newItems[i], 1, "");
            }
        }
        recalcUserPartnerLevel(msg.sender);
    }

    /**
     * @dev Claim available profit
     *
     * @notice msg.sender must be registered
     *
     */
    function claimProfit() external {
        uint profit = land.claimProfit(msg.sender);
        require(profit > 0, "Can't claim 0 profit");
        bank.add(msg.sender, profit);

        emit ClaimProfit(msg.sender, profit);
    }

    /**
     * @dev Buy alias for custom invite links
     *
     * @param ref alias
     *
     * @notice msg.sender must be registered
     *
     */
    function buyAlias(string memory ref) external {
        require(users[msg.sender].account == msg.sender, "Only registered user");
        require(users[msg.sender].accountAliases.length < 10, "Max 10 aliases");
        bytes memory refBytes = bytes(ref);
        require(refBytes.length >= 3 && refBytes.length <= 20, "ref size must be >= 3 and <= 20");
        require(aliasAddress[ref] == address(0), "Alias is already taken");
        for(uint i; i < refBytes.length; i++) {
            require(
                uint8(refBytes[i]) >= 48 && uint8(refBytes[i]) <= 57 ||  // 0-9
                uint8(refBytes[i]) >= 65 && uint8(refBytes[i]) <= 90 ||  // a-z
                uint8(refBytes[i]) >= 97 && uint8(refBytes[i]) <= 122    // A-Z
            , "Only alphanumeric symbols");
        }

        aliasAddress[ref] = msg.sender;
        users[msg.sender].accountAliases.push(ref);
        bank.subtract(msg.sender, aliasPrice);

        emit BuyAlias(msg.sender, ref);
    }

    /**
     * @dev Add items for sale
     *
     * @notice Can be accessed only by contract admin
     *
     * @param itemIds array of item ids to publish for sale
     * @param prices array of itemIds prices
     */
    function addItemsForSale(uint[] memory itemIds, uint[] memory prices) external onlyOwner {
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
    function setRegistrationPrice(uint _registrationPrice) external onlyOwner {
        registrationPrice = _registrationPrice;
    }

    /**
     * @dev Update slot price
     *
     * @notice Can be accessed only by contract admin
     *
     * @param _slotPrice new slot price
     */
    function setSlotPrice(uint _slotPrice) external onlyOwner {
        slotPrice = _slotPrice;
    }

    /**
     * @dev Update bee prices
     *
     * @notice Can be accessed only by contract admin
     *
     * @param _beePrices new bee prices
     */
    function setBeePrices(uint[7] memory _beePrices) external onlyOwner {
        beePrices = _beePrices;
    }

    /**
     * @dev Update partner reward percents
     *
     * @notice Can be accessed only by contract admin
     *
     * @param _partnerRewardPercents new partner reward percents
     */
    function setPartnerRewardPercents(uint[10] memory _partnerRewardPercents) external onlyOwner {
        partnerRewardPercents = _partnerRewardPercents;
    }

    /**
     * @dev Update alias price
     *
     * @notice Can be accessed only by contract admin
     *
     * @param _aliasPrice new alias price
     */
    function setAliasPrice(uint _aliasPrice) external onlyOwner {
        aliasPrice = _aliasPrice;
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
                emit PartnerReward(users[upline[i]].account, referral, i + 1, reward);
            } else {
                users[upline[i]].partnerMissedReward[i] += reward;
                emit MissedPartnerReward(users[upline[i]].account, referral, i + 1, reward);
            }
        }
    }

    /**
     * @dev Recalculate user partner level based on bees with items
     */
    function recalcUserPartnerLevel(address account) private {
        if (account == owner()) {
            return;
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

        if (users[msg.sender].partnerLevel != level) {
            emit PartnerLevelUpdate(msg.sender, users[msg.sender].partnerLevel, level);
            users[msg.sender].partnerLevel = level;
        }
    }

    /**
     * @dev Get partner reward percents
     */
    function getPartnerRewardPercents() external view returns(uint[10] memory) {
        return partnerRewardPercents;
    }

    /**
     * @dev Get user address by alias
     *
     * @param ref alias
     *
     * @return resolved address
     */
    function getAddressByAlias(string memory ref) external view returns(address) {
        return aliasAddress[ref];
    }

    /**
     * @dev Get bee prices
     */
    function getBeePrices() external view returns(uint[7] memory) {
        return beePrices;
    }

    /**
     * @dev Get PartnerAccount
     */
    function getUser(address account) external view returns(User memory) {
        return users[account];
    }

    /**
     * @dev Get salable items with prices
     */
    function getSalableItems() external view returns(uint[] memory, uint[] memory) {
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
     * @dev Get registration timestamp
     *
     * @param account user address
     * @return 0 - if not registered, any other value is registration timestamp
     */
    function getRegistrationTimestamp(address account) external view returns(uint) {
        return users[account].registrationTimestamp;
    }
}