const { expect } = require("chai");
const { ethers } = require("hardhat");

let land;
describe("ApiaryLand", async function() {
    before(async function() {
        const ApiaryLand = await ethers.getContractFactory("ApiaryLand");
        land = await ApiaryLand.deploy();

        const [admin] = await ethers.getSigners();

        const operatorRole = await land.OPERATOR_ROLE();
        await land.grantRole(operatorRole, admin.address);

        const minterRole = await land.MINTER_ROLE();
        await land.grantRole(minterRole, admin.address);
    })

    it("should set admin", async function() {
        const [admin] = await ethers.getSigners();
        const adminRole = await land.DEFAULT_ADMIN_ROLE()
        expect(await land.hasRole(adminRole, admin.address)).true;
    })

    it("should successfully create apiary", async function() {
        const [,owner] = await ethers.getSigners();

        const apiaryBefore = await land.getApiary(owner.address);
        expect(apiaryBefore.owner).eq("0x0000000000000000000000000000000000000000");

        await land.createApiary(owner.address);

        const apiaryAfter = await land.getApiary(owner.address);
        expect(apiaryAfter.owner).eq(owner.address);
    })

    it("should fail to create apiary without operator role", async function() {
        const [,,thirdPerson] = await ethers.getSigners();
        await expect(land.connect(thirdPerson).createApiary(thirdPerson.address)).to.be.reverted;
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

    it("should fail to add bees with message 'Only operator or minter'", async function() {
        const [,owner] = await ethers.getSigners();
        await expect(land.connect(owner).addBees(owner.address, [1], [1])).revertedWith("Only operator or minter");
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

    it("should fail to add slots with message 'Only operator or minter'", async function() {
        const [,owner] = await ethers.getSigners();
        await expect(land.connect(owner).addSlots(owner.address, 10)).revertedWith("Only operator or minter");
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

    it("should fail to save set without admin", async function() {
        const [,, thirdPerson] = await ethers.getSigners();
        await expect(land.connect(thirdPerson).saveSet(1, 100, [1,2,3,4,5,6,7], [1,2,3,4,5,6,7])).reverted;
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

    it("should fail to set items without operator role", async function() {
        const [,owner] = await ethers.getSigners();
        await expect(land.connect(owner).setApiaryItems(owner.address, [1,0,0,0,0,0,0])).reverted;
    })

    it("should fail to set items with message 'Must be apiary owner'", async function() {
        const [,,nonRegisteredAccount] = await ethers.getSigners();
        await expect(land.setApiaryItems(nonRegisteredAccount.address, [0,0,0,0,0,0,0])).revertedWith('Must be apiary owner');
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
        const [notUsedItems, newItems] = await land.callStatic.setApiaryItems(owner.address, [0,0,0,0,0,0,0]);
        expect(notUsedItems.length).eq(7);
        expect(newItems.length).eq(7);

        notUsedItems.forEach(id => expect(id).eq(0))
        newItems.forEach(id => expect(id).eq(0))
    })

    it("should successfully return (notUsedItems, newItems) while update", async function() {
        const [,owner] = await ethers.getSigners();
        const [notUsedItems, newItems] = await land.callStatic.setApiaryItems(owner.address, [1, 0, 0, 4, 0, 0, 0]);
        notUsedItems.forEach(id => expect(id).eq(0))
        expect(newItems[0]).eq(1);
        expect(newItems[1]).eq(0);
        expect(newItems[2]).eq(0);
        expect(newItems[3]).eq(4);
        expect(newItems[4]).eq(0);
        expect(newItems[5]).eq(0);
        expect(newItems[6]).eq(0);
    })

    it("should successfully set previously items", async function() {
        const [,owner] = await ethers.getSigners();
        await land.setApiaryItems(owner.address, [1, 0, 0, 4, 0, 0, 0]);
        const apiary = await land.getApiary(owner.address);
        expect(apiary.items[0]).eq(1);
        expect(apiary.items[1]).eq(0);
        expect(apiary.items[2]).eq(0);
        expect(apiary.items[3]).eq(4);
        expect(apiary.items[4]).eq(0);
        expect(apiary.items[5]).eq(0);
        expect(apiary.items[6]).eq(0);
    })


    it("should return correct (notUsed, newItems) while take off item", async function() {
        const [,owner] = await ethers.getSigners();
        const [notUsedItems, newItems] = await land.callStatic.setApiaryItems(owner.address, [0, 0, 0, 4, 0, 0, 0]);
        newItems.forEach(id => expect(id).eq(0))
        expect(notUsedItems[0]).eq(1);
        expect(notUsedItems[1]).eq(0);
        expect(notUsedItems[2]).eq(0);
        expect(notUsedItems[3]).eq(0);
        expect(notUsedItems[4]).eq(0);
        expect(notUsedItems[5]).eq(0);
        expect(notUsedItems[6]).eq(0);
    })

    it("should return correct (notUsed, newItems) while combine update", async function() {
        const [,owner] = await ethers.getSigners();
        const [notUsedItems, newItems] = await land.callStatic.setApiaryItems(owner.address, [1, 2, 0, 0, 0, 6, 0]);

        expect(newItems[0]).eq(0);
        expect(newItems[1]).eq(2);
        expect(newItems[2]).eq(0);
        expect(newItems[3]).eq(0);
        expect(newItems[4]).eq(0);
        expect(newItems[5]).eq(6);
        expect(newItems[6]).eq(0);

        expect(notUsedItems[0]).eq(0);
        expect(notUsedItems[1]).eq(0);
        expect(notUsedItems[2]).eq(0);
        expect(notUsedItems[3]).eq(4);
        expect(notUsedItems[4]).eq(0);
        expect(notUsedItems[5]).eq(0);
        expect(notUsedItems[6]).eq(0);
    })

    it("should fail to set unsupported item with message 'Item does not exists'", async function() {
        const [,owner] = await ethers.getSigners();
        await expect(land.setApiaryItems(owner.address, [1, 2, 99, 0, 0, 6, 0])).revertedWith("Item does not exists");
    })

    it("should fail to set unsupported item with message 'Bee does not support item'", async function() {
        const [,owner] = await ethers.getSigners();
        await expect(land.setApiaryItems(owner.address, [1, 2, 4, 0, 0, 6, 0])).revertedWith("Bee does not support item");
    })

    it("should set default moodRecoveryTime to 6 days", async function() {
        const moodRecoveryTime = await land.moodRecoveryTime();
        expect(moodRecoveryTime).eq(6*24*60*60);
    })

    it("should set moodRecoveryTime to 2 weeks", async function() {
        const twoWeeks = 14*24*60*60;
        await land.setMoodRecoveryTime(twoWeeks);
        const moodRecoveryTime = await land.moodRecoveryTime();
        expect(moodRecoveryTime).eq(twoWeeks);
    })

    it("should fail to update moodRecoveryTime without admin role", async function() {
        const [,, thirdPerson] = await ethers.getSigners();
        await expect(land.connect(thirdPerson).setMoodRecoveryTime(0)).reverted;
    })

    it("should set 10000 apiary mood for empty apiary", async function() {
        const [, owner] = await ethers.getSigners();
        const mood = await land.getApiaryMood(owner.address);
        expect(mood).eq(10000);
    })

    it("should fail to set new beeDailyProfits without admin role", async function() {
        const [,, thirdPerson] = await ethers.getSigners();
        await expect(land.connect(thirdPerson).setBeeDailyProfits([0,0,0,0,0,0,0])).reverted;
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
