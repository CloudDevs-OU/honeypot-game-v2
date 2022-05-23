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
    uint[] public beePrices;

    constructor(IApiaryLand _land, IBeeItem _item, IHoneyBank _bank, IUserRegistry _registry) {
        land = _land;
        item = _item;
        bank = _bank;
        registry = _registry;

        registrationPrice = 100 ether;
        beePrices = [250 ether, 500 ether, 1000 ether, 3000 ether, 5000 ether, 10000 ether, 20000 ether];
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
     * @dev Buy bees
     *
     * @notice msg.sender must be registered
     *
     * @param beeIds array of bee ids to buy
     * @param amounts array that correspond to bee amounts from beeIds
     */
    function buyBees(uint[] memory beeIds, uint[] memory amounts) public {
        require(beeIds.length == amounts.length, "beeIds.length must be equal to amounts.length");
        require(beeIds.length > 0, "beeIds can not be empty");

        uint totalCost;
        for(uint i; i < beeIds.length; i++) {
            totalCost += beePrices[beeIds[i] - 1] * amounts[i];
        }

        bank.subtract(msg.sender, totalCost);
        land.addBees(msg.sender, beeIds, amounts);
    }

    /**
     * @dev Update registration price value
     *
     * @param _registrationPrice new registration price
     */
    function setRegistrationPrice(uint _registrationPrice) public onlyOwner {
        registrationPrice = _registrationPrice;
    }

    /**
     * @dev Update bee prices
     *
     * @param _beePrices new bee prices
     */
    function setBeePrices(uint[] memory _beePrices) public onlyOwner {
        beePrices = _beePrices;
    }

    /**
     * @dev Get bee prices
     */
    function getBeePrices() public view returns(uint[] memory) {
        return beePrices;
    }
}