const { expect } = require("chai");
const { ethers } = require("hardhat");

let bank;
let stable;
describe("HoneyBank", async function() {
    before(async function() {
        const ERC20 = await ethers.getContractFactory("ERC20");
        stable = await ERC20.deploy("SomeStableCoin", "DAI");

        const HoneyBank = await ethers.getContractFactory("HoneyBank");
        bank = await HoneyBank.deploy(stable.address);
    })

    it("should correctly set admin role", async function() {
        const [admin] = await ethers.getSigners();
        const adminRole = await bank.DEFAULT_ADMIN_ROLE();
        expect(await bank.hasRole(adminRole, admin.address)).to.true;
    })

    it("should fail to add tokens", async function() {
        const [admin] = await ethers.getSigners();
        await expect(bank.add(admin.address, 10000000)).to.reverted;
    })

    it("should fail to grant BANKER role", async function() {
        const [,banker] = await ethers.getSigners();

        const bankerRole = await bank.BANKER_ROLE();
        await expect(bank.connect(banker).grantRole(bankerRole, banker.address)).to.reverted;
    })

    it("should correctly grant BANKER role", async function() {
        const [,banker] = await ethers.getSigners();

        const bankerRole = await bank.BANKER_ROLE();
        expect(await bank.hasRole(bankerRole, banker.address)).to.false;

        await bank.grantRole(bankerRole, banker.address);
        expect(await bank.hasRole(bankerRole, banker.address)).to.true;
    })

    it("should add 1000 tokens to account balance", async function() {
        const [,banker, thirdPartyUser] = await ethers.getSigners();
        expect(await bank.balanceOf(thirdPartyUser.address)).to.eq(0);

        const oneThousandTokens = ethers.utils.parseEther("1000");
        await bank.connect(banker).add(thirdPartyUser.address, oneThousandTokens);

        expect(await bank.balanceOf(thirdPartyUser.address)).to.eq(oneThousandTokens);
    })

    it("should burn 1000 tokens from account balance", async function() {
        const [,banker, thirdPartyUser] = await ethers.getSigners();
        const oneThousandTokens = ethers.utils.parseEther("1000");
        expect(await bank.balanceOf(thirdPartyUser.address)).to.eq(oneThousandTokens);

        await bank.connect(banker).subtract(thirdPartyUser.address, oneThousandTokens);

        expect(await bank.balanceOf(thirdPartyUser.address)).to.eq(0);
    })

    it("should fail to revoke BANKER role", async function() {
        const [,banker] = await ethers.getSigners();

        const bankerRole = await bank.BANKER_ROLE();
        await expect(bank.connect(banker).revokeRole(bankerRole, banker.address)).to.reverted;
    })

    it("should correctly revoke BANKER role", async function() {
        const [,banker] = await ethers.getSigners();

        const bankerRole = await bank.BANKER_ROLE();
        expect(await bank.hasRole(bankerRole, banker.address)).to.true;

        await bank.revokeRole(bankerRole, banker.address);
        expect(await bank.hasRole(bankerRole, banker.address)).to.false;
    })
})