const { expect } = require("chai");
const { ethers } = require("hardhat");

let token;
describe("HoneyToken", async function() {
    before(async function() {
        const HoneyToken = await ethers.getContractFactory("HoneyToken");
        token = await HoneyToken.deploy();
    })

    it("total supply should be equals to 0", async function() {
        const totalSupply = await token.totalSupply();
        expect(totalSupply).eq(0);
    })

    it("should successfully mint tokens", async function() {
        const [,user] = await ethers.getSigners();
        const oneThousandTokens = ethers.utils.parseEther("1000");
        await token.mintTokens(user.address, oneThousandTokens);
        const balance = await token.balanceOf(user.address);
        expect(balance).eq(oneThousandTokens);
    })

    it("total supply should be increased to 1000", async function() {
        const totalSupply = await token.totalSupply();
        expect(totalSupply).eq(ethers.utils.parseEther("1000"));
    })

    it("should fail to mint tokens with message 'Ownable: caller is not the owner'", async function() {
        const [,user] = await ethers.getSigners();
        await expect(token.connect(user).mintTokens(user.address, ethers.utils.parseEther("1000")))
            .revertedWith("Ownable: caller is not the owner")
    })

    it("should successfully burn tokens", async function() {
        const [,user] = await ethers.getSigners();
        const oneThousandTokens = ethers.utils.parseEther("1000");
        await token.burnTokens(user.address, oneThousandTokens);
        const balance = await token.balanceOf(user.address);
        expect(balance).eq(0);
    })

    it("total supply should be decreased to 0", async function() {
        const totalSupply = await token.totalSupply();
        expect(totalSupply).eq(0);
    })

    it("should fail to burn tokens with message 'Ownable: caller is not the owner'", async function() {
        const [,user] = await ethers.getSigners();
        await expect(token.connect(user).burnTokens(user.address, ethers.utils.parseEther("1000")))
            .revertedWith("Ownable: caller is not the owner")
    })
})