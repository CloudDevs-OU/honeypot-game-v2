const { expect } = require("chai");
const { ethers } = require("hardhat");

let bank;
let item;
let land;
let game;
let stable;
let token;
let box;
describe("HoneyBox", async function() {
    before(async function() {
        // Honey Bank
        const signers = await ethers.getSigners();
        const MockStable = await ethers.getContractFactory("MockStable");
        stable = await MockStable.deploy();
        for (let i = 0; i < signers.length; i++) {
            await stable.connect(signers[i]).claim(100000)
        }

        const HoneyBank = await ethers.getContractFactory("HoneyBank");
        bank = await HoneyBank.deploy(stable.address);

        const ERC20 = await ethers.getContractFactory("ERC20");
        token = await ERC20.attach(await bank.token());

        const infinityTokens = ethers.utils.parseEther("99999999999")
        const tenMillionsTokens = ethers.utils.parseEther("10000000")
        for (let i = 0; i < signers.length; i++) {
            await stable.connect(signers[i]).approve(bank.address, infinityTokens);
            await bank.connect(signers[i]).buyTokens(tenMillionsTokens);
        }

        // BeeItem
        const BeeItem = await ethers.getContractFactory("BeeItem");
        item = await BeeItem.deploy("https://honepot.game/item/{id}.json");

        // ApiaryLand
        const ApiaryLand = await ethers.getContractFactory("ApiaryLand");
        land = await ApiaryLand.deploy();

        // HoneypotGame
        const HoneypotGame = await ethers.getContractFactory("HoneypotGame");
        game = await HoneypotGame.deploy(land.address, item.address, bank.address);

        const HoneyBox = await ethers.getContractFactory("HoneyBox");
        box = await HoneyBox.deploy(game.address, bank.address, item.address, land.address);

        // Grant HoneypotGame roles

        // Bank: BANKER_ROLE
        const bankerRole = await bank.BANKER_ROLE();
        await bank.grantRole(bankerRole, game.address);
        await bank.grantRole(bankerRole, box.address);

        // Land: OPERATOR_ROLE
        const operatorRole = await land.OPERATOR_ROLE();
        await land.grantRole(operatorRole, game.address);

        // Land: MINTER_ROLE
        const landMinterRole = await land.MINTER_ROLE();
        await land.grantRole(landMinterRole, box.address);

        // Bee Item: MINTER_ROLE
        const itemOperatorRole = await item.OPERATOR_ROLE();
        await item.grantRole(itemOperatorRole, game.address);

        // Bee Item: MINTER_ROLE
        const beeItemMinterRole = await land.MINTER_ROLE();
        await item.grantRole(beeItemMinterRole, box.address);
    })

    it("should fail to open box with message 'Only registered users'", async () => {
        const [,notRegisteredUser] = await ethers.getSigners();
        await expect(box.connect(notRegisteredUser).open(1)).revertedWith('Only registered users')
    })

    it("should fail to open box with message 'Unknown box id'", async () => {
        await expect(box.open(1)).revertedWith('Unknown box id')
    })

    it("should fail to create or update box with message 'Ownable: caller is not the owner'", async () => {
        const [,hacker] = await ethers.getSigners();
        await expect(box.connect(hacker).createOrUpdateBox(1, 1, [])).revertedWith('Ownable: caller is not the owner')
    })

    it("should successfully create box", async () => {
        const boxBefore = await box.getBox(1);
        expect(boxBefore[0]).eq(0);
        expect(boxBefore[1]).eq(0);
        expect(boxBefore[2].length).eq(0);

        const oneThousandTokens = ethers.utils.parseEther("1000");
        await box.createOrUpdateBox(1, oneThousandTokens, [
            {prizeType: 0, value: 10, weight: 100},
            {prizeType: 1, value: 20, weight: 200},
            {prizeType: 2, value: 30, weight: 300},
        ]);

        const boxIds = await box.getBoxIds();
        expect(boxIds.length).eq(1);
        expect(boxIds[0]).eq(1);

        const boxAfter = await box.getBox(1);
        expect(boxAfter[0]).eq(oneThousandTokens);
        expect(boxAfter[1]).eq(600);
        expect(boxAfter[2].length).eq(3);

        expect(boxAfter[2][0].prizeType).eq(0);
        expect(boxAfter[2][0].value).eq(10);
        expect(boxAfter[2][0].weight).eq(100);

        expect(boxAfter[2][1].prizeType).eq(1);
        expect(boxAfter[2][1].value).eq(20);
        expect(boxAfter[2][1].weight).eq(200);

        expect(boxAfter[2][2].prizeType).eq(2);
        expect(boxAfter[2][2].value).eq(30);
        expect(boxAfter[2][2].weight).eq(300);
    })

    it("should successfully update box", async () => {
        const twoThousandTokens = ethers.utils.parseEther("2000");
        await box.createOrUpdateBox(1, twoThousandTokens, [
            {prizeType: 0, value: 10, weight: 100},
            {prizeType: 1, value: 21, weight: 200},
            {prizeType: 2, value: 30, weight: 400},
        ]);

        const boxIds = await box.getBoxIds();
        expect(boxIds.length).eq(1);
        expect(boxIds[0]).eq(1);

        const boxAfter = await box.getBox(1);
        expect(boxAfter[0]).eq(twoThousandTokens);
        expect(boxAfter[1]).eq(700);
        expect(boxAfter[2].length).eq(3);

        expect(boxAfter[2][0].prizeType).eq(0);
        expect(boxAfter[2][0].value).eq(10);
        expect(boxAfter[2][0].weight).eq(100);

        expect(boxAfter[2][1].prizeType).eq(1);
        expect(boxAfter[2][1].value).eq(21);
        expect(boxAfter[2][1].weight).eq(200);

        expect(boxAfter[2][2].prizeType).eq(2);
        expect(boxAfter[2][2].value).eq(30);
        expect(boxAfter[2][2].weight).eq(400);
    })

    it("should failed to delete box with message 'Ownable: caller is not the owner'", async () => {
        const [,hacker] = await ethers.getSigners();
        await expect(box.connect(hacker).deleteBox(1)).revertedWith('Ownable: caller is not the owner')
    })

    it("should successfully delete box", async () => {
        await box.deleteBox(1);
        const boxAfter = await box.getBox(1);
        expect(boxAfter[0]).eq(0);
        expect(boxAfter[1]).eq(0);
        expect(boxAfter[2].length).eq(0);
    })

    it("should subtract tokens for box", async () => {
        const [admin,user] = await ethers.getSigners();
        // Create box
        const oneThousandTokens = ethers.utils.parseEther("1000");
        await box.createOrUpdateBox(2, oneThousandTokens, [{prizeType: 0, value: 10, weight: 42}]);

        // Register
        await game.connect(user).register(admin.address);

        // Open Box
        const balanceBefore = await token.balanceOf(user.address);
        await box.connect(user).open(2);
        const balanceAfter = await token.balanceOf(user.address);
        expect(balanceAfter).eq(balanceBefore.sub(oneThousandTokens));
    })

    it("should get slots as winner", async () => {
        const [,user] = await ethers.getSigners();
        // Create box
        const slotsPrize = 100;
        await box.createOrUpdateBox(3, ethers.utils.parseEther("1000"), [{prizeType: 0, value: slotsPrize, weight: 42}]);

        // Open Box
        const slotsBefore = (await land.getApiary(user.address)).slots;
        await box.connect(user).open(3);
        const slotsAfter = (await land.getApiary(user.address)).slots;
        expect(slotsAfter).eq(slotsBefore.add(slotsPrize));
    })

    it("should get tokens as winner", async () => {
        const [,user] = await ethers.getSigners();
        // Create box
        const oneThousandTokens = ethers.utils.parseEther("1000");
        const fiveThousandTokens = oneThousandTokens.mul(5);
        await box.createOrUpdateBox(4, oneThousandTokens, [{prizeType: 1, value: fiveThousandTokens, weight: 42}]);

        // Open Box
        const balanceBefore = await token.balanceOf(user.address);
        await box.connect(user).open(4);
        const balanceAfter = await token.balanceOf(user.address);
        expect(balanceAfter).eq(balanceBefore.sub(oneThousandTokens).add(fiveThousandTokens));
    })

    it("should get bee as winner", async () => {
        const [,user] = await ethers.getSigners();
        // Create box
        const beeId = 1;
        await box.createOrUpdateBox(5, ethers.utils.parseEther("1000"), [{prizeType: 2, value: beeId, weight: 42}]);

        // Open Box
        const beesBefore = (await land.getApiary(user.address)).bees;
        await box.connect(user).open(5);
        const beesAfter = (await land.getApiary(user.address)).bees;
        expect(beesAfter[0]).eq(beesBefore[0].add(1));
    })

    it("should get nft as winner", async () => {
        const [,user] = await ethers.getSigners();
        // Create box
        const nftId = 1;
        await box.createOrUpdateBox(6, ethers.utils.parseEther("1000"), [{prizeType: 3, value: nftId, weight: 42}]);

        // Open Box
        const balanceBefore = await item.balanceOf(user.address, 1);
        await box.connect(user).open(6);
        const balanceAfter = await item.balanceOf(user.address, 1);
        expect(balanceAfter).eq(balanceBefore.add(1));
    })
})
