// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockStable is ERC20("MockStableCoin", "DAI") {
    constructor(address[] memory accounts, uint amount) {
        for(uint i; i < accounts.length; i++) {
            _mint(accounts[i], amount);
        }
    }
}