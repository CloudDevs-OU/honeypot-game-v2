const { expect } = require("chai");
const { ethers } = require("hardhat");
const STABLE_INITIAL_BALANCE = ethers.utils.parseEther("10000");

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
        for (let i = 0; i < signers.length; i++) {
            await stable.connect(signers[i]).approve(bank.address, infinityTokens)
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
    })
})