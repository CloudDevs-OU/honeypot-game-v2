// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IHoneyBank {
    function balanceOf(uint account) external returns(uint);
    function subtract(uint from, uint amount) external;
    function add(uint to, uint amount) external;
}