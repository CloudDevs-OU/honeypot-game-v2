const { expect } = require("chai");
const { ethers } = require("hardhat");
const STABLE_INITIAL_BALANCE = ethers.utils.parseEther("10000");
const ONE_TOKEN = ethers.utils.parseEther("1");

let registry;
let bank;
let item;
let land;
let game;
let stable;
let token;
describe("HoneypotGame", async function() {
    before(async function() {
        // UserRegistry
        const UserRegistry = await ethers.getContractFactory("UserRegistry");
        registry = await UserRegistry.deploy();

        // Honey Bank
        const signers = await ethers.getSigners();
        const addresses = signers.map(a => a.address);
        const MockStable = await ethers.getContractFactory("MockStable");
        stable = await MockStable.deploy(addresses, STABLE_INITIAL_BALANCE);

        const HoneyBank = await ethers.getContractFactory("HoneyBank");
        bank = await HoneyBank.deploy(stable.address);

        const ERC20 = await ethers.getContractFactory("ERC20");
        token = await ERC20.attach(await bank.token());

        const infinityTokens = ethers.utils.parseEther("99999999999")
        const oneHundredThousandTokens = ethers.utils.parseEther("100000")
        for (let i = 0; i < signers.length; i++) {
            await stable.connect(signers[i]).approve(bank.address, infinityTokens);
            await bank.connect(signers[i]).buyTokens(oneHundredThousandTokens);
        }

        // BeeItem
        const BeeItem = await ethers.getContractFactory("BeeItem");
        item = await BeeItem.deploy("https://honepot.game/item/{id}.json");

        // ApiaryLand
        const ApiaryLand = await ethers.getContractFactory("ApiaryLand");
        land = await ApiaryLand.deploy();

        // HoneypotGame
        const HoneypotGame = await ethers.getContractFactory("HoneypotGame");
        game = await HoneypotGame.deploy(land.address, item.address, bank.address, registry.address);

        // Grant HoneypotGame roles

        // Bank: BANKER_ROLE
        const bankerRole = await bank.BANKER_ROLE();
        await bank.grantRole(bankerRole, game.address);

        // Land: OPERATOR_ROLE
        const operatorRole = await land.OPERATOR_ROLE();
        await land.grantRole(operatorRole, game.address);

        // Registry: REGISTER_ROLE
        const registerRole = await registry.REGISTER_ROLE();
        await registry.grantRole(registerRole, game.address);

        // Bee Item: MINTER_ROLE
        const minterRole = await item.MINTER_ROLE();
        await item.grantRole(minterRole, game.address);

        const itemOperatorRole = await item.OPERATOR_ROLE();
        await item.grantRole(itemOperatorRole, game.address);
    })

    it("should successfully register user", async function() {
        const [admin,user] = await ethers.getSigners();

        const tokenBalanceBefore = await token.balanceOf(user.address);
        await game.connect(user).register(admin.address);

        // Check tokens balance diff
        const tokenBalanceAfter = await token.balanceOf(user.address);
        const registrationPrice = await game.registrationPrice();
        expect(tokenBalanceBefore.sub(tokenBalanceAfter)).eq(registrationPrice);

        // Check user in registry
        expect(await registry.isRegistered(user.address)).true;

        // Check user's apiary
        const apiary = await land.getApiary(user.address)
        expect(apiary.owner).eq(user.address);

        // Check partner account
        const partnerAccount = await game.getPartnerAccount(user.address);
        expect(partnerAccount.account).eq(user.address);
        expect(partnerAccount.upline).eq(admin.address);
        expect(partnerAccount.level).eq(0);
    })

    it("should successfully buy bees", async function() {
        const [,user] = await ethers.getSigners();

        const tokenBalanceBefore = await token.balanceOf(user.address);
        await game.connect(user).buyBees([1, 2], [5, 1]);

        // Check tokens balance diff
        const beePrices = await game.getBeePrices();
        const totalCost = beePrices[0].mul(5).add(beePrices[1]);
        const tokenBalanceAfter = await token.balanceOf(user.address);
        expect(tokenBalanceBefore.sub(tokenBalanceAfter)).eq(totalCost);

        // Check apiary bees
        const apiary = await land.getApiary(user.address)
        expect(apiary.bees[0]).eq(5);
        expect(apiary.bees[1]).eq(1);
        expect(apiary.bees[2]).eq(0);
        expect(apiary.bees[3]).eq(0);
        expect(apiary.bees[4]).eq(0);
        expect(apiary.bees[5]).eq(0);
        expect(apiary.bees[6]).eq(0);
    })

    it("should successfully buy slots", async function() {
        const [,user] = await ethers.getSigners();

        const tokenBalanceBefore = await token.balanceOf(user.address);
        await game.connect(user).buySlotPacks(5);

        // Check tokens balance diff
        const slotPrice = await game.slotPrice();
        const totalCost = slotPrice.mul(50);
        const tokenBalanceAfter = await token.balanceOf(user.address);
        expect(tokenBalanceBefore.sub(tokenBalanceAfter)).eq(totalCost);

        // Check apiary slots
        const apiary = await land.getApiary(user.address)
        const defaultSlots = await land.DEFAULT_SLOTS();
        expect(apiary.slots).eq(defaultSlots.add(50));
    })

    it("should successfully add items for sale", async function() {
        const itemsBefore = await game.getSalableItems();
        expect(itemsBefore.length).eq(2);
        expect(itemsBefore[0].length).eq(0);
        expect(itemsBefore[1].length).eq(0);

        const itemPrice = ONE_TOKEN.mul(100);
        await game.addItemsForSale([21], [itemPrice])

        const itemsAfter = await game.getSalableItems();
        expect(itemsAfter.length).eq(2);
        expect(itemsAfter[0].length).eq(1);
        expect(itemsAfter[1].length).eq(1);

        expect(itemsAfter[0][0]).eq(21);
        expect(itemsAfter[1][0]).eq(itemPrice);
    })

    it("should successfully buy items", async function() {
        const [,user] = await ethers.getSigners();

        expect(await item.balanceOf(user.address, 21)).eq(0);
        const tokenBalanceBefore = await token.balanceOf(user.address);
        await game.connect(user).buyItems([21], [1]);

        expect(await item.balanceOf(user.address, 21)).eq(1);
        const tokenBalanceAfter = await token.balanceOf(user.address);
        expect(tokenBalanceBefore.sub(tokenBalanceAfter)).eq(ONE_TOKEN.mul(100));
    })

    it("should successfully set apiary items", async function() {
        const [,user] = await ethers.getSigners();

        const apiaryBefore = await land.getApiary(user.address);
        apiaryBefore.items.forEach(itemId => expect(itemId).eq(0));

        await land.saveSet(5, 100, [21,22,23,24,25,26,27], [100, 100, 100, 100, 100, 100, 100]);
        await game.connect(user).setApiaryItems([21,0,0,0,0,0,0]);

        // Check that item is presented on apiary
        const apiaryAfter = await land.getApiary(user.address);
        expect(apiaryAfter.items[0]).eq(21);
        expect(apiaryAfter.items[1]).eq(0);
        expect(apiaryAfter.items[2]).eq(0);
        expect(apiaryAfter.items[3]).eq(0);
        expect(apiaryAfter.items[4]).eq(0);
        expect(apiaryAfter.items[5]).eq(0);
        expect(apiaryAfter.items[6]).eq(0);

        // Check that item is transferred from user to game
        expect(await item.balanceOf(user.address, 21)).eq(0);
        expect(await item.balanceOf(game.address, 21)).eq(1);
    })

    it("should successfully take off apiary items", async function() {
        const [,user] = await ethers.getSigners();
        await game.connect(user).setApiaryItems([0,0,0,0,0,0,0]);

        // Check that item is returned to user
        expect(await item.balanceOf(user.address, 21)).eq(1);
        expect(await item.balanceOf(game.address, 21)).eq(0);
    })

    it("should fail to set apiary items to unsupported bee with message 'Bee does not support item'", async function() {
        const [,user] = await ethers.getSigners();
        await expect(game.connect(user).setApiaryItems([0,21,0,0,0,0,0])).revertedWith("Bee does not support item");
    })

    it("should fail to set not owned item with message 'ERC1155: insufficient balance for transfer'", async function() {
        const [,user] = await ethers.getSigners();
        await expect(game.connect(user).setApiaryItems([0,22,0,0,0,0,0])).revertedWith("ERC1155: insufficient balance for transfer");
    })

    it("should successfully do nothing while set apiary items that already set", async function() {
        const [,user] = await ethers.getSigners();

        await game.connect(user).setApiaryItems([21,0,0,0,0,0,0]);
        expect(await item.balanceOf(user.address, 21)).eq(0);
        expect(await item.balanceOf(game.address, 21)).eq(1);

        await game.connect(user).setApiaryItems([21,0,0,0,0,0,0]);
        expect(await item.balanceOf(user.address, 21)).eq(0);
        expect(await item.balanceOf(game.address, 21)).eq(1);
    })

    it("should decrease partner level to 0", async function() {
        const [,user] = await ethers.getSigners();

        const before = await game.getPartnerAccount(user.address);
        expect(before.level).eq(1);

        await game.connect(user).setApiaryItems([0,0,0,0,0,0,0]);

        const after = await game.getPartnerAccount(user.address);
        expect(after.level).eq(0);
    })

    it("should increase partner level to 1", async function() {
        const [,user] = await ethers.getSigners();

        const before = await game.getPartnerAccount(user.address);
        expect(before.level).eq(0);

        await game.connect(user).setApiaryItems([21,0,0,0,0,0,0]);

        const after = await game.getPartnerAccount(user.address);
        expect(after.level).eq(1);
    })

    it("should set partner level to max", async function() {
        const [,user] = await ethers.getSigners();

        await game.connect(user).buySlotPacks(100);
        await game.connect(user).buyBees([3,4,5,6,7], [1,1,1,1,1]);
        await game.addItemsForSale([22,23,24,25,26,27], [ONE_TOKEN,ONE_TOKEN,ONE_TOKEN,ONE_TOKEN,ONE_TOKEN,ONE_TOKEN]);
        await game.connect(user).buyItems([22,23,24,25,26,27], [1,1,1,1,1,1]);
        await game.connect(user).setApiaryItems([21,22,23,24,25,26,27]);

        const partner = await game.getPartnerAccount(user.address);
        const maxLevel = await game.REWARDABLE_LINES();
        expect(partner.level).eq(maxLevel);
    })
})