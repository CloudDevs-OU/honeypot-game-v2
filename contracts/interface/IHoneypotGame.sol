// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IHoneypotGame {
    function getRegistrationTimestamp(address account) external view returns(uint);
}