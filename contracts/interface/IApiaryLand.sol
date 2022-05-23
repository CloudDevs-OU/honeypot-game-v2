// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IApiaryLand {
    function createApiary(address account) external;
    function addBees(address owner, uint[] memory beeIds, uint[] memory amounts) external;
}