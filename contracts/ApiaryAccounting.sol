// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract ApiaryAccounting {
    // Structs
    struct ApiaryInfo {
        address owner;
    }

    // State
    address public admin;
    mapping(address => ApiaryInfo) info;

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
     * @dev Get accounting apiary info
     *
     * @param owner Apiary owner
     */
    function getApiaryInfo(address owner) public view returns(ApiaryInfo memory) {
        return info[owner];
    }
}