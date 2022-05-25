// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IApiaryLand {
    function createApiary(address account) external;
    function addBees(address owner, uint[] memory beeIds, uint[] memory amounts) external;
    function addSlots(address owner, uint amount) external;
    function setApiaryItems(address owner, uint[7] memory itemIds) external returns(uint[7] memory, uint[7] memory);
}