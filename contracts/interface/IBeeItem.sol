// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IBeeItem is IERC1155 {
    function mintBatch(address to, uint[] memory ids, uint[] memory amounts) external;
}