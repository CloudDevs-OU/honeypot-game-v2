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
        expect(actualAdmin).eq(admin.address);
    })

    it("should successfully create apiary", async function() {
        const [,owner] = await ethers.getSigners();

        const apiaryBefore = await land.getApiary(owner.address);
        expect(apiaryBefore.owner).eq("0x0000000000000000000000000000000000000000");

        await land.createApiary(owner.address);

        const apiaryAfter = await land.getApiary(owner.address);
        expect(apiaryAfter.owner).eq(owner.address);
    })

    it("should fail to create apiary with message 'Only admin'", async function() {
        const [,,thirdPerson] = await ethers.getSigners();
        await expect(land.connect(thirdPerson).createApiary(thirdPerson.address)).revertedWith("Only admin");
    })

    it("should fail to create apiary with message 'Apiary is already created'", async function() {
        const [,owner] = await ethers.getSigners();
        await expect(land.createApiary(owner.address)).revertedWith("Apiary is already created");
    })

    it("should add 2 bees with ID 1 to owner apiary", async function() {
        const [,owner] = await ethers.getSigners();
        await land.addBees(owner.address, [1], [2]);

        const apiary = await land.getApiary(owner.address);
        expect(apiary.bees[0]).eq(2);
    })

    it("should fail to add bees to non existing apiary with message 'Must be apiary owner'", async function() {
        const [,,nonRegisteredAccount] = await ethers.getSigners();
        await expect(land.addBees(nonRegisteredAccount.address, [1], [2])).revertedWith("Must be apiary owner");
    })

    it("should fail to add bees with message 'Only admin'", async function() {
        const [,owner] = await ethers.getSigners();
        await expect(land.connect(owner).addBees(owner.address, [1], [1])).revertedWith("Only admin");
    })

    it("should fail to add bees with none existing id", async function() {
        const [,owner] = await ethers.getSigners();
        await expect(land.addBees(owner.address, [42], [1])).reverted;
    })

    it("should set default slots amount to apiary", async () => {
        const [,owner] = await ethers.getSigners();
        const apiary = await land.getApiary(owner.address);
        const defaultSlots = await land.DEFAULT_SLOTS();
        expect(apiary.slots).eq(defaultSlots);
    })

    it("should fail to add slots with message 'Only admin'", async function() {
        const [,owner] = await ethers.getSigners();
        await expect(land.connect(owner).addSlots(owner.address, 10)).revertedWith("Only admin");
    })

    it("should fail to add slots to none existing apiary with message 'Must be apiary owner'", async function() {
        const [,,nonRegisteredAccount] = await ethers.getSigners();
        await expect(land.addSlots(nonRegisteredAccount.address, 10)).revertedWith("Must be apiary owner");
    })

    it("should increase slots amount", async function() {
        const [,owner] = await ethers.getSigners();
        const apiaryBefore = await land.getApiary(owner.address);
        await land.addSlots(owner.address, 100);
        const apiaryAfter = await land.getApiary(owner.address);
        expect(apiaryAfter.slots).eq(apiaryBefore.slots.add(100));
    })

    it("should increase used slots amount", async function() {
        const [,owner] = await ethers.getSigners();
        const slots = await land.getBeeSlots();

        const usedSlotsBefore = await land.getUsedSlots(owner.address);
        await land.addBees(owner.address, [1], [2]);
        const usedSlotsAfter = await land.getUsedSlots(owner.address);

        expect(usedSlotsAfter).eq(usedSlotsBefore.add(slots[0] * 2));
    })

    it("should fail to add bees with message 'Not enough slots'", async function() {
        const [,owner] = await ethers.getSigners();
        await expect(land.addBees(owner.address, [6], [100])).revertedWith('Not enough slots');
    })

    it("should fail to set items with message 'Only admin'", async function() {
        const [,owner] = await ethers.getSigners();
        await expect(land.connect(owner).setApiaryItems(owner.address, [1], [1])).revertedWith('Only admin');
    })

    it("should fail to set items with message 'Must be apiary owner'", async function() {
        const [,,nonRegisteredAccount] = await ethers.getSigners();
        await expect(land.setApiaryItems(nonRegisteredAccount.address, [1], [1])).revertedWith('Must be apiary owner');
    })

    it("should by default set item ids to 0", async function() {
        const [,owner] = await ethers.getSigners();
        const apiary = await land.getApiary(owner.address);
        expect(apiary.items[0]).eq(0);
        expect(apiary.items[1]).eq(0);
        expect(apiary.items[2]).eq(0);
        expect(apiary.items[3]).eq(0);
        expect(apiary.items[4]).eq(0);
        expect(apiary.items[5]).eq(0);
        expect(apiary.items[6]).eq(0);
    })

    it("should return array of zero values", async function() {
        const [,owner] = await ethers.getSigners();
        const unusedItems = await land.callStatic.setApiaryItems(owner.address, [1, 4, 7], [5, 9, 1]);
        expect(unusedItems.length).eq(3);
        expect(unusedItems[0]).eq(0);
        expect(unusedItems[1]).eq(0);
        expect(unusedItems[2]).eq(0);
    })

    it("should successfully set item ids", async function() {
        const [,owner] = await ethers.getSigners();
        await land.setApiaryItems(owner.address, [1, 4, 7], [5, 9, 1]);

        const apiary = await land.getApiary(owner.address);
        expect(apiary.items[0]).eq(5);
        expect(apiary.items[1]).eq(0);
        expect(apiary.items[2]).eq(0);
        expect(apiary.items[3]).eq(9);
        expect(apiary.items[4]).eq(0);
        expect(apiary.items[5]).eq(0);
        expect(apiary.items[6]).eq(1);
    })

    it("should return array of none zero values", async function() {
        const [,owner] = await ethers.getSigners();
        const unusedItems = await land.callStatic.setApiaryItems(owner.address, [1, 4, 7], [3, 4, 1]);
        expect(unusedItems.length).eq(3);
        expect(unusedItems[0]).eq(5);
        expect(unusedItems[1]).eq(9);
        expect(unusedItems[2]).eq(0);
    })

    it("should successfully update item ids", async function() {
        const [,owner] = await ethers.getSigners();
        await land.setApiaryItems(owner.address, [1, 3, 7], [3, 4, 5]);
        const apiary = await land.getApiary(owner.address);
        expect(apiary.items[0]).eq(3);
        expect(apiary.items[1]).eq(0);
        expect(apiary.items[2]).eq(4);
        expect(apiary.items[3]).eq(9);
        expect(apiary.items[4]).eq(0);
        expect(apiary.items[5]).eq(0);
        expect(apiary.items[6]).eq(5);
    })

    it("should successfully reset item ids", async function() {
        const [,owner] = await ethers.getSigners();
        await land.setApiaryItems(owner.address, [1, 3, 7], [0, 0, 0]);
        const apiary = await land.getApiary(owner.address);
        expect(apiary.items[0]).eq(0);
        expect(apiary.items[1]).eq(0);
        expect(apiary.items[2]).eq(0);
        expect(apiary.items[3]).eq(9);
        expect(apiary.items[4]).eq(0);
        expect(apiary.items[5]).eq(0);
        expect(apiary.items[6]).eq(0);
    })

    it("should set default moodRecoveryTime to 7 days", async function() {
        const moodRecoveryTime = await land.moodRecoveryTime();
        expect(moodRecoveryTime).eq(7*24*60*60);
    })

    it("should set moodRecoveryTime to 2 weeks", async function() {
        const twoWeeks = 14*24*60*60;
        await land.setMoodRecoveryTime(twoWeeks);
        const moodRecoveryTime = await land.moodRecoveryTime();
        expect(moodRecoveryTime).eq(twoWeeks);
    })

    it("should fail to update moodRecoveryTime with message 'Only admin'", async function() {
        const [,, thirdPerson] = await ethers.getSigners();
        await expect(land.connect(thirdPerson).setMoodRecoveryTime(0)).revertedWith("Only admin");
    })

    it("should set -10000 apiary mood for empty apiary", async function() {
        const [, owner] = await ethers.getSigners();
        const mood = await land.getApiaryMood(owner.address);
        expect(mood).eq(-10000);
    })

    it("should fail to set new beeDailyProfits with message 'Only admin'", async function() {
        const [,, thirdPerson] = await ethers.getSigners();
        await expect(land.connect(thirdPerson).setBeeDailyProfits([0,0,0,0,0,0,0]))
            .revertedWith("Only admin");
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
        await land.setBeeDailyProfits(newBeeDailyProfits);
        const beeDailyProfits = await land.getBeeDailyProfits();

        for (let i = 0; i < 7; i++) {
            expect(beeDailyProfits[i]).eq(newBeeDailyProfits[i]);
        }
    })

    it("should fail to save set with message 'Only admin'", async function() {
        const [,, thirdPerson] = await ethers.getSigners();
        await expect(land.connect(thirdPerson).saveSet(1, 100, [1,2,3,4,5,6,7], [1,2,3,4,5,6,7]))
            .revertedWith("Only admin");
    })

    it("should successfully save set", async function() {
        const [admin] = await ethers.getSigners();
        await land.connect(admin).saveSet(1, 10000, [1,2,3,4,5,6,7], [1000,1000,1000,1000,1000,1000,1000]);
        const [setId, setBonus, itemIds, itemBonuses] = await land.getSet(1);
        expect(setId).eq(1);
        expect(setBonus).eq(10000);
        expect(itemIds[0]).eq(1);
        expect(itemIds[1]).eq(2);
        expect(itemIds[2]).eq(3);
        expect(itemIds[3]).eq(4);
        expect(itemIds[4]).eq(5);
        expect(itemIds[5]).eq(6);
        expect(itemIds[6]).eq(7);

        itemBonuses.forEach(b => expect(b).eq(1000));
    })

    it("should successfully update set", async function() {
        const [admin] = await ethers.getSigners();
        await land.connect(admin).saveSet(1, 20000, [1,2,3,4,8,6,7], [700,700,700,700,700,700,700]);
        const [setId, setBonus, itemIds, itemBonuses] = await land.getSet(1);
        expect(setId).eq(1);
        expect(setBonus).eq(20000);
        expect(itemIds[0]).eq(1);
        expect(itemIds[1]).eq(2);
        expect(itemIds[2]).eq(3);
        expect(itemIds[3]).eq(4);
        expect(itemIds[4]).eq(8);
        expect(itemIds[5]).eq(6);
        expect(itemIds[6]).eq(7);

        itemBonuses.forEach(b => expect(b).eq(700));
    })


    it("should correct calculate pure daily profit", async function() {
        const profit = await land.calcPureProfit(
            [1,0,0,0,0,0,0], // bees
            [0,0,0,0,0,0,0], // items
            24*60*60         // 1 day
        )

        const beeDailyProfits = await land.getBeeDailyProfits();
        expect(profit).eq(beeDailyProfits[0]);
    })

    it("should correct calculate pure combined profit", async function() {
        const profit = await land.calcPureProfit(
            [1,1,3,4,0,0,0], // bees
            [0,0,0,0,0,0,0], // items
            12*24*60*60      // 12 days
        )

        const beeDailyProfits = await land.getBeeDailyProfits();
        const firstBeeProfit = beeDailyProfits[0].mul(12)
        const secondBeeProfit = beeDailyProfits[1].mul(12)
        const thirdBeeProfit = beeDailyProfits[2].mul(12).mul(3)
        const forthBeeProfit = beeDailyProfits[3].mul(12).mul(4)
        expect(profit).eq(firstBeeProfit.add(secondBeeProfit).add(thirdBeeProfit).add(forthBeeProfit));
    })
})
