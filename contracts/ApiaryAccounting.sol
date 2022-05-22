// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract ApiaryAccounting {
    // Structs
    struct ApiaryInfo {
        address owner;
        uint lastClaimTimestamp;
        uint lastDeferredPayoutTimestamp;
        uint deferredProfit;
    }

    // State
    address public admin;
    mapping(address => ApiaryInfo) info;
    mapping(uint => uint) itemBonusPercents;
    mapping(uint => uint) setBonusPercents;

    // Configs
    uint public moodRecoveryTime;
    uint[7] beeDailyProfits = [1.5 ether, 3.5 ether, 7.5 ether, 25 ether, 45 ether, 95 ether, 200 ether];

    // Modifiers
    modifier hasRegistered(address account) {
        require(info[account].owner == account, "Apiary must be registered");
        _;
    }

    modifier onlyAdmin {
        require(msg.sender == admin, "Only admin");
        _;
    }

    constructor() {
        admin = msg.sender;
        moodRecoveryTime = 7 days;
    }

    /**
     * @dev Register apiary for owner
     * @notice Can be accessed only by contract admin
     *
     * @param owner Apiary owner
     */
    function registerApiary(address owner) public onlyAdmin {
        require(info[owner].owner == address(0), "Apiary is already registered");
        info[owner].owner = owner;
        info[owner].lastClaimTimestamp = block.timestamp;
        info[owner].lastDeferredPayoutTimestamp = block.timestamp;
    }

    /**
     * @dev Set new mood recovery time
     * @notice Can be accessed only by contract admin
     *
     * @param _moodRecoveryTime New mood recovery time
     */
    function setMoodRecoveryTime(uint _moodRecoveryTime) public onlyAdmin {
        moodRecoveryTime = _moodRecoveryTime;
    }

    /**
     * @dev Set bee daily profits
     * @notice Can be accessed only by contract admin
     *
     * @param _beeDailyProfits New bee daily profits
     */
    function setBeeDailyProfits(uint[7] memory _beeDailyProfits) public onlyAdmin {
        beeDailyProfits = _beeDailyProfits;
    }

    /**
     * @dev Set item bonus percents
     * @notice Can be accessed only by contract admin
     *
     * @param itemIds array of item ids
     * @param bonusPercents array of bonus percents that corresponding to itemIds (10000 = 100%)
     */
    function setItemBonusPercents(uint[] memory itemIds, uint[] memory bonusPercents) public onlyAdmin {
        for(uint i; i < itemIds.length; i++) {
            itemBonusPercents[itemIds[i]] = bonusPercents[i];
        }
    }

    /**
     * @dev Set set bonus percents
     * @notice Can be accessed only by contract admin
     *
     * @param setIds array of set ids
     * @param bonusPercents array of bonus percents that corresponding to setIds (10000 = 100%)
     */
    function setSetBonusPercents(uint[] memory setIds, uint[] memory bonusPercents) public onlyAdmin {
        for(uint i; i < setIds.length; i++) {
            setBonusPercents[setIds[i]] = bonusPercents[i];
        }
    }

    /**
     * @dev Get bee daily profits
     * @return array of bee daily profits (index = beeId - 1)
     */
    function getBeeDailyProfits() public view returns(uint[7] memory) {
        return beeDailyProfits;
    }

    /**
     * @dev Get accounting apiary info
     *
     * @param owner Apiary owner
     * @return owner's ApiaryInfo
     */
    function getApiaryInfo(address owner) public view returns(ApiaryInfo memory) {
        return info[owner];
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
        uint timeSpent = block.timestamp - info[owner].lastClaimTimestamp;
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
     * @param setId Set id. Can be 0 when there is no 7 items from the same set.
     * @return profit value
     */
    function calcAvailableProfitForClaiming(
        address owner,
        uint[7] memory bees,
        uint[7] memory items,
        uint setId
    ) public view returns(uint) {
        uint notDeferredProfit = calcPureProfit(bees, items, setId, block.timestamp - info[owner].lastDeferredPayoutTimestamp);
        // Apply mood factor
        int mood = getApiaryMood(owner);
        if (mood > 0) {
            return (notDeferredProfit + info[owner].deferredProfit) * (10000 + uint(mood)) / 10000;
        } else {
            return (notDeferredProfit + info[owner].deferredProfit) * (10000 - uint(mood)) / 10000;
        }
    }

    /**
     * @dev Calculate pure profit (mood factor is not applied)
     *
     * @param bees Owner bees
     * @param items Owner items
     * @param setId Set id. Can be 0 when there is no 7 items from the same set.
     * @param items Owner items
     * @param period period between start time and end time
     * @return profit value
     */
    function calcPureProfit(
        uint[7] memory bees,
        uint[7] memory items,
        uint setId,
        uint period
    ) public view returns(uint){
        uint profit;

        // Calc bees profit (+ items bonus)
        for(uint i; i < bees.length; i++) {
            // profit = dailyProfit * beesAmount * itemBonusPercent * daysSpent
            profit += beeDailyProfits[i] * bees[i] * (10000 + itemBonusPercents[items[i]]) * period / 1 days / 10000;
        }

        // Apply set bonus
        return profit * (10000 + setBonusPercents[setId]) / 10000;
    }
}