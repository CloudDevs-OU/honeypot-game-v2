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

    it("should fail to steal holder item with message 'ERC1155: caller is not owner nor approved'", async function() {
        const [,,holder,rob] = await ethers.getSigners();
        await expect(item.connect(rob).safeTransferFrom(holder.address, rob.address, 1, 1, [])).revertedWith("ERC1155: caller is not owner nor approved");
    })

    it("should success to transfer item from holder to anotherHolder", async function() {
        const [admin,,holder,,anotherHolder] = await ethers.getSigners();

        const operatorRole = await item.OPERATOR_ROLE();
        await item.grantRole(operatorRole, admin.address);

        await item.safeTransferFrom(holder.address, anotherHolder.address, 1, 1, []);
        expect(await item.balanceOf(holder.address, 1)).eq(0);
        expect(await item.balanceOf(anotherHolder.address, 1)).eq(1);
    })
})