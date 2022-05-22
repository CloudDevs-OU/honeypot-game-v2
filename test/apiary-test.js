const { expect } = require("chai");
const { ethers } = require("hardhat");

let land;
describe("ApiaryLand", async function() {
    before(async function() {
        const ApiaryLand = await ethers.getContractFactory("ApiaryLand");
        land = await ApiaryLand.deploy();

    })

    it("should set admin", async function() {
        const [admin] = await ethers.getSigners();
        const actualAdmin = await land.admin();
        expect(actualAdmin).to.eq(admin.address);
    })

    it("should successfully create apiary", async function() {
        const [,owner] = await ethers.getSigners();

        const apiaryBefore = await land.getApiary(owner.address);
        expect(apiaryBefore.owner).to.eq("0x0000000000000000000000000000000000000000");

        await land.createApiary(owner.address);

        const apiaryAfter = await land.getApiary(owner.address);
        expect(apiaryAfter.owner).to.eq(owner.address);
    })

    it("should fail to create apiary with message 'Only admin'", async function() {
        const [,,thirdPerson] = await ethers.getSigners();
        await expect(land.connect(thirdPerson).createApiary(thirdPerson.address)).to.revertedWith("Only admin");
    })

    it("should fail to create apiary with message 'Apiary is already created'", async function() {
        const [,owner] = await ethers.getSigners();
        await expect(land.createApiary(owner.address)).to.revertedWith("Apiary is already created");
    })

})
