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

    function createApiary(address account) public onlyAdmin {
        require(apiary[account].owner == address(0), "Apiary is already created");
        apiary[account].owner = account;
    }

    function getApiary(address owner) public view returns(Apiary memory) {
        return apiary[owner];
    }
}