const { expect } = require("chai");
const { ethers } = require("hardhat");

const STABLE_INITIAL_BALANCE = ethers.utils.parseEther("10000");
let bank;
let stable;
let token;
describe("HoneyBank", async function() {
    before(async function() {
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
    })

    it("should correctly set admin role", async function() {
        const [admin] = await ethers.getSigners();
        const adminRole = await bank.DEFAULT_ADMIN_ROLE();
        expect(await bank.hasRole(adminRole, admin.address)).true;
    })

    it("should fail to add tokens", async function() {
        const [admin] = await ethers.getSigners();
        await expect(bank.add(admin.address, 10000000)).reverted;
    })

    it("should fail to grant BANKER role", async function() {
        const [,banker] = await ethers.getSigners();

        const bankerRole = await bank.BANKER_ROLE();
        await expect(bank.connect(banker).grantRole(bankerRole, banker.address)).reverted;
    })

    it("should correctly grant BANKER role", async function() {
        const [,banker] = await ethers.getSigners();

        const bankerRole = await bank.BANKER_ROLE();
        expect(await bank.hasRole(bankerRole, banker.address)).false;

        await bank.grantRole(bankerRole, banker.address);
        expect(await bank.hasRole(bankerRole, banker.address)).true;
    })

    it("should add 1000 tokens to account balance", async function() {
        const [,banker, thirdPartyUser] = await ethers.getSigners();
        expect(await bank.balanceOf(thirdPartyUser.address)).eq(0);

        const oneThousandTokens = ethers.utils.parseEther("1000");
        await bank.connect(banker).add(thirdPartyUser.address, oneThousandTokens);

        expect(await bank.balanceOf(thirdPartyUser.address)).eq(oneThousandTokens);
    })

    it("should burn 1000 tokens from account balance", async function() {
        const [,banker, thirdPartyUser] = await ethers.getSigners();
        const oneThousandTokens = ethers.utils.parseEther("1000");
        expect(await bank.balanceOf(thirdPartyUser.address)).eq(oneThousandTokens);

        await bank.connect(banker).subtract(thirdPartyUser.address, oneThousandTokens);

        expect(await bank.balanceOf(thirdPartyUser.address)).eq(0);
    })

    it("should fail to revoke BANKER role", async function() {
        const [,banker] = await ethers.getSigners();

        const bankerRole = await bank.BANKER_ROLE();
        await expect(bank.connect(banker).revokeRole(bankerRole, banker.address)).reverted;
    })

    it("should correctly revoke BANKER role", async function() {
        const [,banker] = await ethers.getSigners();

        const bankerRole = await bank.BANKER_ROLE();
        expect(await bank.hasRole(bankerRole, banker.address)).true;

        await bank.revokeRole(bankerRole, banker.address);
        expect(await bank.hasRole(bankerRole, banker.address)).false;
    })

    it("should successfully buy tokens", async function() {
        const [,user] = await ethers.getSigners();
        const oneThousandTokens = ethers.utils.parseEther("1000");

        expect(await token.balanceOf(user.address)).eq(0);
        await bank.connect(user).buyTokens(oneThousandTokens);
        expect(await token.balanceOf(user.address)).eq(oneThousandTokens);

        const pureStableAmount = oneThousandTokens.div(await bank.rate());
        const swapFee = await bank.swapFee();
        const expectedSpentStableAmount = pureStableAmount.add(pureStableAmount.mul(swapFee).div(10000));
        const actualStableSpentAmount = STABLE_INITIAL_BALANCE.sub(await stable.balanceOf(user.address));
        expect(actualStableSpentAmount).eq(expectedSpentStableAmount);
    })

    it("should successfully sell tokens", async function() {
        const [,user] = await ethers.getSigners();
        const oneThousandTokens = ethers.utils.parseEther("1000");
        const stableBalanceBefore = await stable.balanceOf(user.address);

        expect(await token.balanceOf(user.address)).eq(oneThousandTokens);
        await bank.connect(user).sellTokens(oneThousandTokens);
        expect(await token.balanceOf(user.address)).eq(0);

        const swapFee = await bank.swapFee();
        const pureTokensAmount = oneThousandTokens.sub(oneThousandTokens.mul(swapFee).div(10000));

        const rate = await bank.rate();
        const stableAmount = pureTokensAmount.div(rate);

        expect(await stable.balanceOf(user.address)).eq(stableBalanceBefore.add(stableAmount));
    })
})