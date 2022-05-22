// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IHoneyBank {
    function balanceOf(address account) external returns(uint);
    function subtract(address from, uint amount) external;
    function add(address to, uint amount) external;
}