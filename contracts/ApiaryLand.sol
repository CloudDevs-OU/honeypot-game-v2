// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract ApiaryLand {
    // Structs
    struct Apiary {
        address owner;
    }

    // State
    address public admin;
    mapping(address => Apiary) apiary;

    // Modifiers
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
     * @param account Owner of new apiary
     */
    function createApiary(address account) public onlyAdmin {
        require(apiary[account].owner == address(0), "Apiary is already created");
        apiary[account].owner = account;
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