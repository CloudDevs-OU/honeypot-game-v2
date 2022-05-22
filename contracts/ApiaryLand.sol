// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract ApiaryLand {
    // Structs
    struct Apiary {
        address owner;
        uint slots;
        uint[7] bees;
        uint[7] items;
    }

    // Constants
    uint constant public TOTAL_BEES = 7;
    uint constant public DEFAULT_SLOTS = 10;
    uint[] public beeSlots = [1, 2, 4, 8, 16, 32, 64];

    // State
    address public admin;
    mapping(address => Apiary) apiary;

    // Modifiers
    modifier hasApiary(address account) {
        require(apiary[account].owner == account, "Must be apiary owner");
        _;
    }

    modifier onlyAdmin {
        require(msg.sender == admin, "Only admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    /**
     * @dev Create apiary for account
     * @notice Can be accessed only by contract admin
     *
     * @param account New apiary owner
     */
    function createApiary(address account) public onlyAdmin {
        require(apiary[account].owner == address(0), "Apiary is already created");
        apiary[account].owner = account;
        apiary[account].slots = DEFAULT_SLOTS;
    }

    /**
     * @dev Add bees to owner's apiary
     * @notice Can be accessed only by contract admin
     *
     * @param owner Apiary owner
     * @param beeIds array of bee ids
     * @param amounts array of bee amounts corresponding to beeIds
     */
    function addBees(address owner, uint[] memory beeIds, uint[] memory amounts) public onlyAdmin hasApiary(owner) {
        require(beeIds.length == amounts.length, "'beeIds' length not equal to 'amounts' length");
        for(uint i; i < beeIds.length; i++) {
            apiary[owner].bees[beeIds[i] - 1] += amounts[i];
        }

        require(apiary[owner].slots >= getUsedSlots(owner), "Not enough slots");
    }

    /**
     * @dev Add items to owner's apiary
     * @notice Can be accessed only by contract admin
     *
     * @param owner Apiary owner
     * @param beeIds array of bee ids
     * @param itemIds array of item ids
     */
    function setItems(address owner, uint[] memory beeIds, uint[] memory itemIds) public onlyAdmin hasApiary(owner) {
        require(beeIds.length == itemIds.length, "'beeIds' length not equal to 'itemIds' length");
        for(uint i; i < beeIds.length; i++) {
            apiary[owner].items[beeIds[i] - 1] = itemIds[i];
        }
    }

    /**
     * @dev Add slots to owner's apiary
     * @notice Can be accessed only by contract admin
     *
     * @param owner Apiary owner
     * @param amount slots amount that needs to be added
     */
    function addSlots(address owner, uint amount) public onlyAdmin hasApiary(owner) {
        apiary[owner].slots += amount;
    }

    /**
     * @dev Get apiary by owner
     *
     * @param owner Apiary owner
     */
    function getApiary(address owner) public view returns(Apiary memory) {
        return apiary[owner];
    }


    /**
     * @dev Get owner's apiary used slots
     *
     * @param owner Apiary owner
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
     */
    function getBeeSlots() public view returns(uint[] memory) {
        return beeSlots;
    }
}