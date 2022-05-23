// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import"./interface/IApiaryLand.sol";
import"./interface/IBeeItem.sol";
import"./interface/IHoneyBank.sol";
import"./interface/IUserRegistry.sol";

contract HoneypotGame is Ownable {
    IApiaryLand public land;
    IBeeItem public item;
    IHoneyBank public bank;
    IUserRegistry public registry;

    uint public registrationPrice;

    constructor(IApiaryLand _land, IBeeItem _item, IHoneyBank _bank, IUserRegistry _registry) {
        land = _land;
        item = _item;
        bank = _bank;
        registry = _registry;
    }

    /**
     * @dev Register msg.sender in registry, create apiary and subtract registration fee
     *
     * @param referrer account that invite msg.sender
     */
    function register(address referrer) public {
        bank.subtract(msg.sender, registrationPrice);
        registry.register(msg.sender, referrer);
        land.createApiary(msg.sender);
    }

    /**
     * @dev Update registration price value
     *
     * @param _registrationPrice new registration price
     */
    function setRegistrationPrice(uint _registrationPrice) public onlyOwner {
        registrationPrice = _registrationPrice;
    }
}