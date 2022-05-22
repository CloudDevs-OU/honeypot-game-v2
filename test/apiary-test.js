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

    it("should set default slots amount to apiary", async () => {
        const [,owner] = await ethers.getSigners();
        const apiary = await land.getApiary(owner.address);
        const defaultSlots = await land.DEFAULT_SLOTS();
        expect(apiary.slots).to.eq(defaultSlots);
    })

    it("should fail to add slots with message 'Only admin'", async function() {
        const [,owner] = await ethers.getSigners();
        await expect(land.connect(owner).addSlots(owner.address, 10)).to.revertedWith("Only admin");
    })

    it("should fail to add slots to none existing apiary with message 'Must be apiary owner'", async function() {
        const [,,nonRegisteredAccount] = await ethers.getSigners();
        await expect(land.addSlots(nonRegisteredAccount.address, 10)).to.revertedWith("Must be apiary owner");
    })

    it("should increase slots amount", async function() {
        const [,owner] = await ethers.getSigners();
        const apiaryBefore = await land.getApiary(owner.address);
        await land.addSlots(owner.address, 100);
        const apiaryAfter = await land.getApiary(owner.address);
        expect(apiaryAfter.slots).to.eq(apiaryBefore.slots.add(100));
    })

    it("should increase used slots amount", async function() {
        const [,owner] = await ethers.getSigners();
        const slots = await land.getBeeSlots();

        const usedSlotsBefore = await land.getUsedSlots(owner.address);
        await land.addBees(owner.address, [1], [2]);
        const usedSlotsAfter = await land.getUsedSlots(owner.address);

        expect(usedSlotsAfter).to.eq(usedSlotsBefore.add(slots[0] * 2));
    })

    it("should fail to add bees with message 'Not enough slots'", async function() {
        const [,owner] = await ethers.getSigners();
        await expect(land.addBees(owner.address, [6], [100])).to.revertedWith('Not enough slots');
    })

    it("should fail to set items with message 'Only admin'", async function() {
        const [,owner] = await ethers.getSigners();
        await expect(land.connect(owner).setItems(owner.address, [1], [1])).to.revertedWith('Only admin');
    })

    it("should fail to set items with message 'Must be apiary owner'", async function() {
        const [,,nonRegisteredAccount] = await ethers.getSigners();
        await expect(land.setItems(nonRegisteredAccount.address, [1], [1])).to.revertedWith('Must be apiary owner');
    })

    it("should by default set item ids to 0", async function() {
        const [,owner] = await ethers.getSigners();
        const apiary = await land.getApiary(owner.address);
        expect(apiary.items[0]).to.eq(0);
        expect(apiary.items[1]).to.eq(0);
        expect(apiary.items[2]).to.eq(0);
        expect(apiary.items[3]).to.eq(0);
        expect(apiary.items[4]).to.eq(0);
        expect(apiary.items[5]).to.eq(0);
        expect(apiary.items[6]).to.eq(0);
    })

    it("should successfully set item ids", async function() {
        const [,owner] = await ethers.getSigners();
        await land.setItems(owner.address, [1, 4, 7], [5, 9, 1]);
        const apiary = await land.getApiary(owner.address);
        expect(apiary.items[0]).to.eq(5);
        expect(apiary.items[1]).to.eq(0);
        expect(apiary.items[2]).to.eq(0);
        expect(apiary.items[3]).to.eq(9);
        expect(apiary.items[4]).to.eq(0);
        expect(apiary.items[5]).to.eq(0);
        expect(apiary.items[6]).to.eq(1);
    })

    it("should successfully update item ids", async function() {
        const [,owner] = await ethers.getSigners();
        await land.setItems(owner.address, [1, 3, 7], [3, 4, 5]);
        const apiary = await land.getApiary(owner.address);
        expect(apiary.items[0]).to.eq(3);
        expect(apiary.items[1]).to.eq(0);
        expect(apiary.items[2]).to.eq(4);
        expect(apiary.items[3]).to.eq(9);
        expect(apiary.items[4]).to.eq(0);
        expect(apiary.items[5]).to.eq(0);
        expect(apiary.items[6]).to.eq(5);
    })

    it("should successfully reset item ids", async function() {
        const [,owner] = await ethers.getSigners();
        await land.setItems(owner.address, [1, 3, 7], [0, 0, 0]);
        const apiary = await land.getApiary(owner.address);
        expect(apiary.items[0]).to.eq(0);
        expect(apiary.items[1]).to.eq(0);
        expect(apiary.items[2]).to.eq(0);
        expect(apiary.items[3]).to.eq(9);
        expect(apiary.items[4]).to.eq(0);
        expect(apiary.items[5]).to.eq(0);
        expect(apiary.items[6]).to.eq(0);
    })
})
