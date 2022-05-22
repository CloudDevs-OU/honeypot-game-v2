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

    it("should add 2 bees with ID 1 to owner apiary", async function() {
        const [,owner] = await ethers.getSigners();
        await land.addBees(owner.address, [1], [2]);

        const apiary = await land.getApiary(owner.address);
        expect(apiary.bees[0]).to.eq(2);
    })

    it("should fail to add bees to non existing apiary with message 'Must be apiary owner'", async function() {
        const [,,nonRegisteredAccount] = await ethers.getSigners();
        await expect(land.addBees(nonRegisteredAccount.address, [1], [2])).to.revertedWith("Must be apiary owner");
    })

    it("should fail to add bees with message 'Only admin'", async function() {
        const [,owner] = await ethers.getSigners();
        await expect(land.connect(owner).addBees(owner.address, [1], [1])).to.revertedWith("Only admin");
    })

    it("should fail to add bees with none existing id", async function() {
        const [,owner] = await ethers.getSigners();
        await expect(land.addBees(owner.address, [42], [1])).to.reverted;
    })

})
