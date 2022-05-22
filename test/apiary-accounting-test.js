const { expect } = require("chai");
const { ethers } = require("hardhat");

let accounting;
describe("ApiaryAccounting", async function() {
    before(async function () {
        const ApiaryAccounting = await ethers.getContractFactory("ApiaryAccounting");
        accounting = await ApiaryAccounting.deploy();
    })

    it("should set admin", async function() {
        const [admin] = await ethers.getSigners();
        const actualAdmin = await accounting.admin();
        expect(actualAdmin).to.eq(admin.address);
    })

    it("should successfully register apiary", async function() {
        const [, owner] = await ethers.getSigners();
        await accounting.registerApiary(owner.address);
        const apiary = await accounting.getApiaryInfo(owner.address);
        expect(apiary.owner).to.eq(owner.address);
    })

    it("should failed to register apiary with message 'Apiary is already registered'", async function() {
        const [, owner] = await ethers.getSigners();
        await expect(accounting.registerApiary(owner.address)).to.revertedWith("Apiary is already registered");
    })

    it("should failed to register apiary with message 'Only admin'", async function() {
        const [,, thirdPerson] = await ethers.getSigners();
        await expect(accounting.connect(thirdPerson).registerApiary(thirdPerson.address)).to.revertedWith("Only admin");
    })
})