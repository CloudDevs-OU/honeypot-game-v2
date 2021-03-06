// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/*
OFFICIAL WEBSITE: https://honeypot.game

 /$$   /$$                                                     /$$            /$$$$$$
| $$  | $$                                                    | $$           /$$__  $$
| $$  | $$  /$$$$$$  /$$$$$$$  /$$   /$$  /$$$$$$   /$$$$$$  /$$$$$$        | $$  \__/  /$$$$$$  /$$$$$$/$$$$   /$$$$$$
| $$$$$$$$ /$$__  $$| $$__  $$| $$  | $$ /$$__  $$ /$$__  $$|_  $$_/        | $$ /$$$$ |____  $$| $$_  $$_  $$ /$$__  $$
| $$__  $$| $$  \ $$| $$  \ $$| $$  | $$| $$  \ $$| $$  \ $$  | $$          | $$|_  $$  /$$$$$$$| $$ \ $$ \ $$| $$$$$$$$
| $$  | $$| $$  | $$| $$  | $$| $$  | $$| $$  | $$| $$  | $$  | $$ /$$      | $$  \ $$ /$$__  $$| $$ | $$ | $$| $$_____/
| $$  | $$|  $$$$$$/| $$  | $$|  $$$$$$$| $$$$$$$/|  $$$$$$/  |  $$$$/      |  $$$$$$/|  $$$$$$$| $$ | $$ | $$|  $$$$$$$
|__/  |__/ \______/ |__/  |__/ \____  $$| $$____/  \______/    \___/         \______/  \_______/|__/ |__/ |__/ \_______/
                               /$$  | $$| $$
                              |  $$$$$$/| $$
                               \______/ |__/
*/

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "./interface/IBeeItem.sol";

/**
* @title ERC1155 tokens that represents game items
* @author Rustam Mamedov
*/
contract BeeItem is IBeeItem, ERC1155, AccessControl {
    // Constants
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    modifier operatorOrMinter {
        require(hasRole(OPERATOR_ROLE, msg.sender) || hasRole(MINTER_ROLE, msg.sender), "Only operator or minter");
        _;
    }

    constructor(string memory uri_) ERC1155(uri_) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(OPERATOR_ROLE, DEFAULT_ADMIN_ROLE);
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public virtual override(IBeeItem, ERC1155) {
        super.safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev Mint bee item
     *
     * @param to token receiver
     * @param id token identifier
     * @param amount tokens amount that will be added to balance
     */
    function mint(address to, uint id, uint amount) external operatorOrMinter {
        _mint(to, id, amount, "");
    }

    /**
     * @dev Mint batch bee item
     *
     * @param to token receiver
     * @param ids  array of token identifiers
     * @param amounts array of tokens amount that will be added to balance
     */
    function mintBatch(address to, uint[] memory ids, uint[] memory amounts) external operatorOrMinter {
        _mintBatch(to, ids, amounts, "");
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address account, address operator) public view virtual override(IERC1155, ERC1155) returns (bool) {
        return hasRole(OPERATOR_ROLE, operator) || super.isApprovedForAll(account, operator);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}