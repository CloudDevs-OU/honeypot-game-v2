// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
* @title Game utility token
* @author Rustam Mamedov
*/
contract HoneyToken is Ownable, ERC20("HoneyToken", "HNY"), ERC20Burnable {
    function mintTokens(address to, uint amount) external onlyOwner {
        _mint(to, amount);
    }

    function burnTokens(address from, uint amount) external onlyOwner {
        _burn(from, amount);
    }
}