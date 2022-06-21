// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interface/IApiaryLand.sol";

/**
* @title Holds info and manipulation methods for all apiaries
* @author Rustam Mamedov
*/
contract ApiaryLand is IApiaryLand, AccessControl {
    // Structs
    struct Apiary {
        address owner;
        uint slots;
        uint[7] bees;
        uint[7] items;
        uint workStartTime;
        uint lastClaimTimestamp;
        uint lastDeferredPayoutTimestamp;
        uint deferredProfit;
        uint totalClaimedProfit;
    }

    // Constants
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint constant public TOTAL_BEES = 7;
    uint constant public DEFAULT_SLOTS = 10;
    uint[] public beeSlots = [3, 7, 11, 18, 24, 29, 37];

    // State
    uint public moodRecoveryTime;
    uint public noneProfitTimeout;
    uint[7] beeDailyProfits = [53.33 ether, 150 ether, 250 ether, 440 ether, 640 ether, 866.67 ether, 1166.67 ether];
    mapping(uint => uint) itemBonusPercents;
    mapping(uint => uint) setBonusPercents;
    mapping(uint => uint) itemSet;
    mapping(uint => uint) itemBee;
    mapping(uint => uint[7]) setItems;
    mapping(address => Apiary) apiary;

    // Modifiers
    modifier hasApiary(address account) {
        require(apiary[account].owner == account, "Must be apiary owner");
        _;
    }

    modifier operatorOrMinter {
        require(hasRole(OPERATOR_ROLE, msg.sender) || hasRole(MINTER_ROLE, msg.sender), "Only operator or minter");
        _;
    }

    constructor() {
        moodRecoveryTime = 6 days;
        noneProfitTimeout = 1 days;

        // Create admin apiary
        apiary[msg.sender].owner = msg.sender;
        apiary[msg.sender].slots = DEFAULT_SLOTS;
        apiary[msg.sender].workStartTime = block.timestamp;

        // Setup roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(OPERATOR_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);
    }

    /**
     * @dev Create apiary for account
     * @notice Can be accessed only by contract admin
     *
     * @param account New apiary owner
     */
    function createApiary(address account) external onlyRole(OPERATOR_ROLE) {
        require(apiary[account].owner == address(0), "Apiary is already created");
        apiary[account].owner = account;
        apiary[account].slots = DEFAULT_SLOTS;
        apiary[account].workStartTime = block.timestamp;
    }

    /**
     * @dev Add bees to owner's apiary
     * @notice Can be accessed only by contract admin
     *
     * @param owner Apiary owner
     * @param beeIds array of bee ids
     * @param amounts array of bee amounts corresponding to beeIds
     */
    function addBees(address owner, uint[] memory beeIds, uint[] memory amounts) external operatorOrMinter hasApiary(owner) {
        require(beeIds.length == amounts.length, "'beeIds' length not equal to 'amounts' length");
        require(beeIds.length > 0, "'beeIds' length must be > 0");
        beforeApiaryStateChanged(owner);
        for(uint i; i < beeIds.length; i++) {
            apiary[owner].bees[beeIds[i] - 1] += amounts[i];
        }

        require(apiary[owner].slots >= getUsedSlots(owner), "Not enough slots");
    }

    /**
     * @dev Add slots to owner's apiary
     * @notice Can be accessed only by contract admin
     *
     * @param owner Apiary owner
     * @param amount slots amount that needs to be added
     */
    function addSlots(address owner, uint amount) external operatorOrMinter hasApiary(owner) {
        apiary[owner].slots += amount;
    }

    /**
     * @dev Set items to owner's apiary
     * @notice Can be accessed only by contract operator
     *
     * @param owner Apiary owner
     * @param itemIds array of item ids
     * @return (notUsedItems, newItems) notUsedItems - items that no longer in use, newItems - items that will be used (corresponding to beeIds)
     */
    function setApiaryItems(address owner, uint[7] memory itemIds) external onlyRole(OPERATOR_ROLE) hasApiary(owner) returns(uint[7] memory, uint[7] memory) {
        beforeApiaryStateChanged(owner);
        uint[7] memory newItems;
        uint[7] memory notUsedItems;
        for(uint i; i < itemIds.length; i++) {
            require(itemIds[i] == 0 || itemSet[itemIds[i]] != 0, "Item does not exists");
            require(itemIds[i] == 0 || itemBee[itemIds[i]] == i + 1, "Bee does not support item");
            require(itemIds[i] == 0 || apiary[owner].bees[i] > 0, "Can't use item without bee");

            if (apiary[owner].items[i] == 0 && itemIds[i] != 0) {
                newItems[i] = itemIds[i];
            } else if (apiary[owner].items[i] != 0 && itemIds[i] == 0) {
                notUsedItems[i] = apiary[owner].items[i];
            }
        }
        apiary[owner].items = itemIds;
        return (notUsedItems, newItems);
    }

    /**
     * @dev Set new mood recovery time
     * @notice Can be accessed only by contract admin
     *
     * @param _moodRecoveryTime New mood recovery time
     */
    function setMoodRecoveryTime(uint _moodRecoveryTime) external onlyRole(DEFAULT_ADMIN_ROLE) {
        moodRecoveryTime = _moodRecoveryTime;
    }

    /**
     * @dev Set none profit timeout after claiming
     * @notice Can be accessed only by contract admin
     *
     * @param _noneProfitTimeout New none profit timeout
     */
    function setNoneProfitTimeout(uint _noneProfitTimeout) external onlyRole(DEFAULT_ADMIN_ROLE) {
        noneProfitTimeout = _noneProfitTimeout;
    }

    /**
     * @dev Set bee daily profits
     * @notice Can be accessed only by contract admin
     *
     * @param _beeDailyProfits New bee daily profits
     */
    function setBeeDailyProfits(uint[7] memory _beeDailyProfits) external onlyRole(DEFAULT_ADMIN_ROLE) {
        beeDailyProfits = _beeDailyProfits;
    }

    /**
     * @dev Save set with bonus percents and set items with bonus percents.
     * If set was already saved then it will be updated.
     *
     * @notice Can be accessed only by contract admin
     *
     * @param setId Set identifier
     * @param setBonusPercentage Bonus reward for collection all items from set (10000 = 100%)
     * @param itemIds Item identifiers, beeId = index + 1 (10000 = 100%)
     * @param itemBonusPercentage Item bonus percents corresponding to itemIds (10000 = 100%)
     */
    function saveSet(
        uint setId,
        uint setBonusPercentage,
        uint[7] memory itemIds,
        uint[7] memory itemBonusPercentage
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        setItems[setId] = itemIds;
        setBonusPercents[setId] = setBonusPercentage;
        for(uint i; i < itemIds.length; i++) {
            itemBonusPercents[itemIds[i]] = itemBonusPercentage[i];
            itemSet[itemIds[i]] = setId;
            itemBee[itemIds[i]] = i + 1;
        }
    }

    /**
     * @dev Add profit to owner's totalClaimedProfit and reset deferred payouts
     * @notice Can be accessed only by contract admin
     *
     * @param owner Apiary owner
     * @return claimed profit
     */
    function claimProfit(address owner) external onlyRole(OPERATOR_ROLE) hasApiary(owner) returns(uint) {
        uint profit = calcAvailableProfitForClaiming(owner, apiary[owner].bees, apiary[owner].items);
        apiary[owner].totalClaimedProfit += profit;
        apiary[owner].workStartTime = block.timestamp + noneProfitTimeout;
        apiary[owner].lastClaimTimestamp = block.timestamp;
        apiary[owner].lastDeferredPayoutTimestamp = 0;
        apiary[owner].deferredProfit = 0;

        return profit;
    }

    /**
     * @dev Function should be triggered before owner's apiary state changed
     * in order to save deferred profit. It needs for correct calculation of profit that available for claiming.
     *
     * @notice Can be accessed only by contract admin
     *
     * @param owner Apiary owner
     */
    function beforeApiaryStateChanged(address owner) private {
        // If bees are not working right now
        if (block.timestamp < apiary[owner].workStartTime) {
            return;
        }

        if (apiary[owner].lastDeferredPayoutTimestamp == 0) {
            apiary[owner].deferredProfit += calcPureProfit(apiary[owner].bees, apiary[owner].items, block.timestamp - apiary[owner].workStartTime);
        } else {
            apiary[owner].deferredProfit += calcPureProfit(apiary[owner].bees, apiary[owner].items, block.timestamp - apiary[owner].lastDeferredPayoutTimestamp);
        }
        apiary[owner].lastDeferredPayoutTimestamp = block.timestamp;
    }

    /**
     * @dev Get set info
     *
     * @param setId Set identifier
     * @return (setId, setBonusPercents, setItemsIds, setItemBonusPercents);
     */
    function getSet(uint setId) external view returns(uint, uint, uint[7] memory, uint[7] memory) {
        uint[7] memory setItemBonusPercents;
        for(uint i; i < TOTAL_BEES; i++) {
            setItemBonusPercents[i] = itemBonusPercents[setItems[setId][i]];
        }
        return (setId, setBonusPercents[setId], setItems[setId], setItemBonusPercents);
    }

    /**
     * @dev Get owner's bees and items
     *
     * @param owner Apiary owner
     * @return (bees, items, isSet)
     */
    function getBeesAndItems(address owner) external view returns(uint[7] memory, uint[7] memory, bool) {
        return (apiary[owner].bees, apiary[owner].items, getSetId(apiary[owner].items) > 0);
    }

    /**
     * @dev Get setId by itemIds
     *
     * @param itemIds array of item ids
     * @return setId or 0 if items not from the same set
     */
    function getSetId(uint[7] memory itemIds) public view returns(uint) {
        for(uint i = 1; i < itemIds.length; i++) {
            if (itemSet[itemIds[i - 1]] != itemSet[itemIds[i]]) {
                return 0;
            }
        }

        return itemSet[itemIds[0]];
    }

    /**
     * @dev Get apiary by owner
     *
     * @param owner Apiary owner
     * @return owner's Apiary
     */
    function getApiary(address owner) external view returns(Apiary memory) {
        return apiary[owner];
    }

    /**
     * @dev Get owner's apiary used slots
     *
     * @param owner Apiary owner
     * @return owner's Apiary used slots
     */
    function getUsedSlots(address owner) public view returns(uint) {
        uint result;
        for(uint i; i < TOTAL_BEES; i++) {
            result += apiary[owner].bees[i] * beeSlots[i];
        }

        return result;
    }

    /**
     * @dev Get slots needed for each bee
     *
     * @return array of slot amounts (index = beeId - 1, value = needed slots)
     */
    function getBeeSlots() external view returns(uint[] memory) {
        return beeSlots;
    }

    /**
     * @dev Get bee daily profits
     * @return array of bee daily profits (index = beeId - 1)
     */
    function getBeeDailyProfits() external view returns(uint[7] memory) {
        return beeDailyProfits;
    }

    /**
     * @dev Get apiary mood based on last claim timestamp.
     * Mood factor affects to available for claiming profit and indicates
     * how much percentage owner can get from pure profit.
     *
     * @param owner Apiary owner
     * @return owner's apiary mood from -10000 up to +10000
     */
    function getApiaryMood(address owner) public view returns(int) {
        if (apiary[owner].totalClaimedProfit == 0) {
            return 10000;
        }

        if (block.timestamp < apiary[owner].workStartTime) {
            return -10000;
        }

        uint timeSpent = block.timestamp - apiary[owner].workStartTime;
        if (timeSpent >= moodRecoveryTime) {
            return 10000;
        }

        return int(20000000 * timeSpent / moodRecoveryTime / 1000) - int(10000);
    }

    /**
     * @dev Get item bonus percents by item ids
     *
     * @param itemIds array of item ids
     * @return array of item bonus percents corresponding to itemIds (10000 = 100%)
     */
    function getItemBonusPercents(uint[] memory itemIds) external view returns(uint[] memory) {
        uint[] memory result = new uint[](itemIds.length);
        for(uint i; i < itemIds.length; i++) {
            result[i] = itemBonusPercents[itemIds[i]];
        }

        return result;
    }

    /**
     * @dev Get set bonus percents by set ids
     *
     * @param setIds array of set ids
     * @return array of item bonus percents corresponding to setIds (10000 = 100%)
     */
    function getSetBonusPercents(uint[] memory setIds) external view returns(uint[] memory) {
        uint[] memory result = new uint[](setIds.length);
        for(uint i; i < setIds.length; i++) {
            result[i] = setBonusPercents[setIds[i]];
        }

        return result;
    }

    /**
     * @dev Calculate available profit for claiming (mood factor is applied)
     *
     * @param owner Apiary owner
     * @param bees Owner bees
     * @param items Owner items
     * @return profit value
     */
    function calcAvailableProfitForClaiming(
        address owner,
        uint[7] memory bees,
        uint[7] memory items
    ) public view returns(uint) {
        if(block.timestamp < apiary[owner].workStartTime) {
            return 0;
        }

        uint notDeferredProfit;
        if (apiary[owner].lastDeferredPayoutTimestamp == 0) {
            calcPureProfit(bees, items, block.timestamp - apiary[owner].workStartTime);
        } else {
            calcPureProfit(bees, items, block.timestamp - apiary[owner].lastDeferredPayoutTimestamp);
        }
        // Apply mood factor
        return (notDeferredProfit + apiary[owner].deferredProfit) * uint(int(10000) + getApiaryMood(owner)) / 10000;
    }

    /**
     * @dev Calculate pure profit (mood factor is not applied)
     *
     * @param bees Owner bees
     * @param items Owner items
     * @param period period between start time and end time
     * @return profit value
     */
    function calcPureProfit(
        uint[7] memory bees,
        uint[7] memory items,
        uint period
    ) public view returns(uint){
        uint beesProfit;
        uint itemsProfit;

        // Calc bees profit (+ items bonus)
        for(uint i; i < bees.length; i++) {
            beesProfit += beeDailyProfits[i] * bees[i] * period / 1 days;
            itemsProfit += beeDailyProfits[i] * bees[i] * itemBonusPercents[items[i]] * period / 1 days / 10000;
        }

        // Apply set bonus
        return beesProfit + itemsProfit + (beesProfit * setBonusPercents[getSetId(items)] / 10000);
    }
}