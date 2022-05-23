// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interface/IUserRegistry.sol";

contract UserRegistry is IUserRegistry, AccessControl {
    // Structs
    struct User {
        address account;
        address referrer;
        uint registrationTimestamp;
    }

    // Constants
    bytes32 public constant REGISTER_ROLE = keccak256("REGISTER_ROLE");

    // State
    mapping(address => User) users;

    constructor() {
        users[msg.sender].account = msg.sender;
        users[msg.sender].registrationTimestamp = block.timestamp;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(REGISTER_ROLE, DEFAULT_ADMIN_ROLE);
    }

    /**
     * @dev Register new user with referrer
     * @notice Can be accessed only by REGISTER_ROLE
     *
     * @param account user address
     * @param referrer user's upline address
     */
    function register(address account, address referrer) public onlyRole(REGISTER_ROLE) {
        require(account != address(0), 'Account can not be zero');
        require(!isRegistered(account), 'User is already registered');
        require(isRegistered(referrer), 'Referrer is not registered');

        users[account].account = account;
        users[account].referrer = referrer;
        users[account].registrationTimestamp = block.timestamp;
    }

    /**
     * @dev Check is user registered
     *
     * @param account user address for check
     * @return true/false
     */
    function isRegistered(address account) public view returns(bool) {
        return account != address(0) && users[account].account == account;
    }

    /**
     * @dev Get user by address
     *
     * @param account user address
     * @return User
     */
    function getUser(address account) public view returns(User memory) {
        return users[account];
    }

    /**
     * @dev Get user upline addresses
     *
     * @param account user address
     * @param amount amount of uplines
     * @return array of upline addresses in order of upline value
     */
    function getUplines(address account, uint amount) public view returns(address[] memory) {
        address[] memory result = new address[](amount);

        uint uplineIndex = 0;
        address uplineAddress = users[account].referrer;
        while(uplineAddress != address(0) && uplineIndex < amount) {
            result[uplineIndex++] = uplineAddress;
            uplineAddress = users[uplineAddress].referrer;
        }

        return result;
    }
}