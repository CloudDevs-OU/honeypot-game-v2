const { expect } = require("chai");
const { ethers } = require("hardhat");

let item;
describe("BeeItem", async function() {
    before(async function() {
        const BeeItem = await ethers.getContractFactory("BeeItem");
        item = await BeeItem.deploy("https://honepot.game/item/{id}.json");
    })

    it("should fail to mint token without role", async function() {
        const [admin] = await ethers.getSigners();
        await expect(item.mint(admin.address, 1, 1)).reverted;
    })

    it("should successfully mint token", async function() {
        const [,minter,holder] = await ethers.getSigners();
        const minterRole = await item.MINTER_ROLE();
        await item.grantRole(minterRole, minter.address);
        await item.connect(minter).mint(holder.address, 1, 1);
        expect(await item.balanceOf(holder.address, 1)).eq(1);
    })
})