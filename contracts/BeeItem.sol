// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "./interface/IBeeItem.sol";

contract BeeItem is IBeeItem, ERC1155, AccessControl {
    // Constants
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(string memory uri_) ERC1155(uri_) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);
    }

    /**
     * @dev Mint bee item
     *
     * @param to token receiver
     * @param id token identifier
     * @param amount tokens amount that will be added to balance
     */
    function mint(address to, uint id, uint amount) public onlyRole(MINTER_ROLE) {
        _mint(to, id, amount, "");
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}