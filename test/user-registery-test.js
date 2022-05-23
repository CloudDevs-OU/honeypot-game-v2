const { expect } = require("chai");
const { ethers } = require("hardhat");

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
let registry;
describe("UserRegistry", async function() {
    before(async function() {
        const UserRegistry = await ethers.getContractFactory("UserRegistry");
        registry = await UserRegistry.deploy();

        const [admin] = await ethers.getSigners();
        const registerRole = await registry.REGISTER_ROLE();
        await registry.grantRole(registerRole, admin.address);
    })

    it("should successfully register user", async function() {
        const [admin,user] = await ethers.getSigners();
        expect(await registry.isRegistered(user.address)).false;
        await registry.register(user.address, admin.address);
        expect(await registry.isRegistered(user.address)).true;
    })

    it("should return correct referrer", async function() {
        const [admin,user] = await ethers.getSigners();
        const userData = await registry.getUser(user.address);
        expect(userData.account).eq(user.address);
        expect(userData.referrer).eq(admin.address);
        expect(userData.registrationTimestamp).not.eq(0);
    })

    it("should return correct user upline", async function() {
        const [admin,user] = await ethers.getSigners();
        const uplines = await registry.getUplines(user.address, 1);
        expect(uplines.length).eq(1);
        expect(uplines[0]).eq(admin.address);
    })

    it("should return correct admin upline", async function() {
        const [admin] = await ethers.getSigners();
        const uplines = await registry.getUplines(admin.address, 10);
        expect(uplines.length).eq(10);
        uplines.forEach(u => expect(u).eq(ZERO_ADDRESS))
    })

    it("should fail to register already registered user", async function() {
        const [admin,user] = await ethers.getSigners();
        expect(await registry.isRegistered(user.address)).true;
        await expect(registry.register(user.address, admin.address)).revertedWith("User is already registered");
    })

    it("should fail to register with not registered referrer", async function() {
        const [,,notRegisteredUser, notRegisteredReferrer] = await ethers.getSigners();
        expect(await registry.isRegistered(notRegisteredUser.address)).false;
        await expect(registry.register(notRegisteredUser.address, notRegisteredReferrer.address))
            .revertedWith("Referrer is not registered");
    })

    it("should fail to register with zero address referrer", async function() {
        const [,,notRegisteredUser] = await ethers.getSigners();
        expect(await registry.isRegistered(notRegisteredUser.address)).false;
        await expect(registry.register(notRegisteredUser.address, ZERO_ADDRESS))
            .revertedWith("Referrer is not registered");
    })

    it("should fail to register zero address", async function() {
        const [,user] = await ethers.getSigners();
        await expect(registry.register(ZERO_ADDRESS, user.address))
            .revertedWith("Account can not be zero");
    })
})