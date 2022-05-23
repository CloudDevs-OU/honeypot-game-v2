// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interface/IApiaryLand.sol";

contract ApiaryLand is IApiaryLand, AccessControl {
    // Structs
    struct Apiary {
        address owner;
        uint slots;
        uint[7] bees;
        uint[7] items;
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
    uint[] public beeSlots = [1, 2, 4, 8, 16, 32, 64];

    // State
    uint public moodRecoveryTime;
    uint[7] beeDailyProfits = [1.5 ether, 3.5 ether, 7.5 ether, 25 ether, 45 ether, 95 ether, 200 ether];
    mapping(uint => uint) itemBonusPercents;
    mapping(uint => uint) setBonusPercents;
    mapping(uint => uint) itemSet;
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
        moodRecoveryTime = 7 days;

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
    function createApiary(address account) public onlyRole(OPERATOR_ROLE) {
        require(apiary[account].owner == address(0), "Apiary is already created");
        apiary[account].owner = account;
        apiary[account].slots = DEFAULT_SLOTS;
        apiary[account].lastClaimTimestamp = block.timestamp;
        apiary[account].lastDeferredPayoutTimestamp = block.timestamp;
    }

    /**
     * @dev Add bees to owner's apiary
     * @notice Can be accessed only by contract admin
     *
     * @param owner Apiary owner
     * @param beeIds array of bee ids
     * @param amounts array of bee amounts corresponding to beeIds
     */
    function addBees(address owner, uint[] memory beeIds, uint[] memory amounts) public operatorOrMinter hasApiary(owner) {
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
    function addSlots(address owner, uint amount) public operatorOrMinter hasApiary(owner) {
        apiary[owner].slots += amount;
    }

    /**
     * @dev Set items to owner's apiary
     * @notice Can be accessed only by contract admin
     *
     * @param owner Apiary owner
     * @param beeIds array of bee ids
     * @param itemIds array of item ids
     * @return item ids that no more in use (corresponding to beeIds)
     */
    function setApiaryItems(address owner, uint[] memory beeIds, uint[] memory itemIds) public onlyRole(OPERATOR_ROLE) hasApiary(owner) returns(uint[] memory) {
        require(beeIds.length == itemIds.length, "'beeIds' length not equal to 'itemIds' length");
        beforeApiaryStateChanged(owner);
        uint[] memory unusedItemIds = new uint[](beeIds.length);
        for(uint i; i < beeIds.length; i++) {
            if(apiary[owner].items[beeIds[i] - 1] > 0 && apiary[owner].items[beeIds[i] - 1] != itemIds[i]) {
                unusedItemIds[i] = apiary[owner].items[beeIds[i] - 1];
            }
            apiary[owner].items[beeIds[i] - 1] = itemIds[i];
        }

        return unusedItemIds;
    }

    /**
     * @dev Set new mood recovery time
     * @notice Can be accessed only by contract admin
     *
     * @param _moodRecoveryTime New mood recovery time
     */
    function setMoodRecoveryTime(uint _moodRecoveryTime) public onlyRole(DEFAULT_ADMIN_ROLE) {
        moodRecoveryTime = _moodRecoveryTime;
    }

    /**
     * @dev Set bee daily profits
     * @notice Can be accessed only by contract admin
     *
     * @param _beeDailyProfits New bee daily profits
     */
    function setBeeDailyProfits(uint[7] memory _beeDailyProfits) public onlyRole(DEFAULT_ADMIN_ROLE) {
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
     * @param itemIds Item identifiers (10000 = 100%)
     * @param itemBonusPercentage Item bonus percents corresponding to itemIds (10000 = 100%)
     */
    function saveSet(
        uint setId,
        uint setBonusPercentage,
        uint[7] memory itemIds,
        uint[7] memory itemBonusPercentage
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        setItems[setId] = itemIds;
        setBonusPercents[setId] = setBonusPercentage;
        for(uint i; i < itemIds.length; i++) {
            itemBonusPercents[itemIds[i]] = itemBonusPercentage[i];
            itemSet[itemIds[i]] = setId;
        }
    }

    /**
     * @dev Get set info
     *
     * @param setId Set identifier
     * @return (setId, setBonusPercents, setItemsIds, setItemBonusPercents);
     */
    function getSet(uint setId) public view returns(uint, uint, uint[7] memory, uint[7] memory) {
        uint[7] memory setItemBonusPercents;
        for(uint i; i < TOTAL_BEES; i++) {
            setItemBonusPercents[i] = itemBonusPercents[setItems[setId][i]];
        }
        return (setId, setBonusPercents[setId], setItems[setId], setItemBonusPercents);
    }

    /**
     * @dev Add profit to owner's totalClaimedProfit and reset deferred payouts
     * @notice Can be accessed only by contract admin
     *
     * @param owner Apiary owner
     * @return claimed profit
     */
    function claimProfit(address owner) public onlyRole(OPERATOR_ROLE) hasApiary(owner) returns(uint) {
        uint profit = calcAvailableProfitForClaiming(owner, apiary[owner].bees, apiary[owner].items);
        apiary[owner].totalClaimedProfit += profit;
        apiary[owner].lastClaimTimestamp = block.timestamp;
        apiary[owner].lastDeferredPayoutTimestamp = block.timestamp;
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
        apiary[owner].deferredProfit += calcPureProfit(apiary[owner].bees, apiary[owner].items, block.timestamp - apiary[owner].lastDeferredPayoutTimestamp);
        apiary[owner].lastDeferredPayoutTimestamp = block.timestamp;
    }

    /**
     * @dev Get setId by itemIds
     *
     * @param itemIds array of item ids
     * @return setId or 0 if items not fro the same set
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
    function getApiary(address owner) public view returns(Apiary memory) {
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
    function getBeeSlots() public view returns(uint[] memory) {
        return beeSlots;
    }

    /**
     * @dev Get bee daily profits
     * @return array of bee daily profits (index = beeId - 1)
     */
    function getBeeDailyProfits() public view returns(uint[7] memory) {
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
        uint timeSpent = block.timestamp - apiary[owner].lastClaimTimestamp;
        if (timeSpent >= moodRecoveryTime) {
            return int(10000);
        }

        return int(20000000 * timeSpent / moodRecoveryTime / 1000) - int(10000);
    }

    /**
     * @dev Get item bonus percents by item ids
     *
     * @param itemIds array of item ids
     * @return array of item bonus percents corresponding to itemIds (10000 = 100%)
     */
    function getItemBonusPercents(uint[] memory itemIds) public view returns(uint[] memory) {
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
    function getSetBonusPercents(uint[] memory setIds) public view returns(uint[] memory) {
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
        uint notDeferredProfit = calcPureProfit(bees, items, block.timestamp - apiary[owner].lastDeferredPayoutTimestamp);
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
        uint profit;

        // Calc bees profit (+ items bonus)
        for(uint i; i < bees.length; i++) {
            // profit = dailyProfit * beesAmount * itemBonusPercent * daysSpent
            profit += beeDailyProfits[i] * bees[i] * (10000 + itemBonusPercents[items[i]]) * period / 1 days / 10000;
        }

        // Apply set bonus
        return profit * (10000 + setBonusPercents[getSetId(items)]) / 10000;
    }
}