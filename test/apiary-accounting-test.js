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

    it("should set default moodRecoveryTime to 7 days", async function() {
        const moodRecoveryTime = await accounting.moodRecoveryTime();
        expect(moodRecoveryTime).to.eq(7*24*60*60);
    })

    it("should set moodRecoveryTime to 2 weeks", async function() {
        const twoWeeks = 14*24*60*60;
        await accounting.setMoodRecoveryTime(twoWeeks);
        const moodRecoveryTime = await accounting.moodRecoveryTime();
        expect(moodRecoveryTime).to.eq(twoWeeks);
    })

    it("should fail to update moodRecoveryTime with message 'Only admin'", async function() {
        const [,, thirdPerson] = await ethers.getSigners();
        await expect(accounting.connect(thirdPerson).setMoodRecoveryTime(0)).to.revertedWith("Only admin");
    })

    it("should set max apiary mood for empty apiary", async function() {
        const [, owner] = await ethers.getSigners();
        const mood = await accounting.getApiaryMood(owner.address);
        const maxMood = await accounting.MAX_MOOD();
        expect(mood).to.eq(maxMood);
    })

    it("should fail to set new beeDailyProfits with message 'Only admin'", async function() {
        const [,, thirdPerson] = await ethers.getSigners();
        await expect(accounting.connect(thirdPerson).setBeeDailyProfits([0,0,0,0,0,0,0]))
            .to.revertedWith("Only admin");
    })

    it("should set new beeDailyProfits", async function() {
        const newBeeDailyProfits = [
            ethers.utils.parseEther("1"),
            ethers.utils.parseEther("2"),
            ethers.utils.parseEther("3"),
            ethers.utils.parseEther("4"),
            ethers.utils.parseEther("5"),
            ethers.utils.parseEther("6"),
            ethers.utils.parseEther("7")
        ];
        await accounting.setBeeDailyProfits(newBeeDailyProfits);
        const beeDailyProfits = await accounting.getBeeDailyProfits();

        for (let i = 0; i < 7; i++) {
            expect(beeDailyProfits[i]).to.eq(newBeeDailyProfits[i]);
        }
    })
})