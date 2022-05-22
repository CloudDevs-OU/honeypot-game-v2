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
        expect(apiary.lastClaimTimestamp).to.not.eq(0);
        expect(apiary.lastDeferredPayoutTimestamp).to.eq(apiary.lastClaimTimestamp);
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

    it("should set -10000 apiary mood for empty apiary", async function() {
        const [, owner] = await ethers.getSigners();
        const mood = await accounting.getApiaryMood(owner.address);
        expect(mood).to.eq(-10000);
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

    it("should successfully set item bonus percents", async function() {
        await accounting.setItemBonusPercents([1,2,3], [10,20,30]);
        const percents = await accounting.getItemBonusPercents([1,2,3]);
        expect(percents[0]).to.eq(10);
        expect(percents[1]).to.eq(20);
        expect(percents[2]).to.eq(30);
    })

    it("should fail set item bonus percents with message 'Only admin'", async function() {
        const [,, thirdPerson] = await ethers.getSigners();
        await expect(accounting.connect(thirdPerson).setItemBonusPercents([1], [1]))
            .to.revertedWith("Only admin");
    })

    it("should successfully set set bonus percents", async function() {
        await accounting.setSetBonusPercents([1,2,3], [100,200,300]);
        const percents = await accounting.getSetBonusPercents([1,2,3]);
        expect(percents[0]).to.eq(100);
        expect(percents[1]).to.eq(200);
        expect(percents[2]).to.eq(300);
    })

    it("should fail set set bonus percents with message 'Only admin'", async function() {
        const [,, thirdPerson] = await ethers.getSigners();
        await expect(accounting.connect(thirdPerson).setSetBonusPercents([1], [1]))
            .to.revertedWith("Only admin");
    })

    it("should correct calculate pure daily profit", async function() {
        const profit = await accounting.calcPureProfit(
            [1,0,0,0,0,0,0], // bees
            [0,0,0,0,0,0,0], // items
            0,               // set
            24*60*60         // 1 day
        )

        const beeDailyProfits = await accounting.getBeeDailyProfits();
        expect(profit).to.eq(beeDailyProfits[0]);
    })

    it("should correct calculate pure combined profit", async function() {
        const profit = await accounting.calcPureProfit(
            [1,1,3,4,0,0,0], // bees
            [0,0,0,0,0,0,0], // items
            0,               // set
            12*24*60*60      // 12 days
        )

        const beeDailyProfits = await accounting.getBeeDailyProfits();
        const firstBeeProfit = beeDailyProfits[0].mul(12)
        const secondBeeProfit = beeDailyProfits[1].mul(12)
        const thirdBeeProfit = beeDailyProfits[2].mul(12).mul(3)
        const forthBeeProfit = beeDailyProfits[3].mul(12).mul(4)
        expect(profit).to.eq(firstBeeProfit.add(secondBeeProfit).add(thirdBeeProfit).add(forthBeeProfit));
    })
})