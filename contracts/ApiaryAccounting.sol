// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract ApiaryAccounting {
    // Structs
    struct ApiaryInfo {
        address owner;
        uint lastClaimTimestamp;
    }

    // Constants
    uint constant public MAX_MOOD = 10000;

    // State
    address public admin;
    mapping(address => ApiaryInfo) info;

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
     * @dev Get bee daily profits
     */
    function getBeeDailyProfits() public view returns(uint[7] memory) {
        return beeDailyProfits;
    }

    /**
     * @dev Get accounting apiary info
     *
     * @param owner Apiary owner
     */
    function getApiaryInfo(address owner) public view returns(ApiaryInfo memory) {
        return info[owner];
    }

    /**
     * @dev Get apiary mood based on last claim timestamp
     *
     * @param owner Apiary owner
     */
    function getApiaryMood(address owner) public view returns(int) {
        uint timeSpent = block.timestamp - info[owner].lastClaimTimestamp;
        if (timeSpent >= moodRecoveryTime) {
            return int(MAX_MOOD);
        }

        return int(2 * MAX_MOOD * 1000 / moodRecoveryTime * timeSpent / 1000) - int(MAX_MOOD);
    }
}