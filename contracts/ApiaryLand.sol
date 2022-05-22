// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract ApiaryLand {
    // Structs
    struct Apiary {
        address owner;
        uint slots;
        uint[7] bees;
    }

    // Constants
    uint constant public DEFAULT_SLOTS = 10;

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
}