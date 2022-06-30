const {ethers, network} = require("hardhat");
const fs = require("fs");

if (network.name !== 'testnet') {
    throw Error("This script can be run only in testnet");
}

const ONE_TOKEN = ethers.utils.parseEther("1");
const STABLE_INITIAL_BALANCE = ONE_TOKEN.mul(100000); // 100,000

async function main() {
    console.log("Start migration")
    // Honey Bank
    const signers = await ethers.getSigners();
    const addresses = signers.map(a => a.address);
    const MockStable = await ethers.getContractFactory("MockStable");

    let stable;
    await run("Deploy MockStable", async () => {
        stable = await MockStable.deploy(addresses, STABLE_INITIAL_BALANCE);
    })

    let bank;
    await run("Deploy HoneyBank", async () => {
        const HoneyBank = await ethers.getContractFactory("HoneyBank");
        bank = await HoneyBank.deploy(stable.address);
    })

    const ERC20 = await ethers.getContractFactory("ERC20");
    const token = await ERC20.attach(await bank.token());

    // BeeItem
    let item;
    await run("Deploy BeeItem", async () => {
        const BeeItem = await ethers.getContractFactory("BeeItem");
        item = await BeeItem.deploy("https://honeypot-game-fe.pages.dev/item/{id}.json");
    })

    // ApiaryLand
    let land;
    await run("Deploy ApiaryLand", async () => {
        const ApiaryLand = await ethers.getContractFactory("ApiaryLand");
        land = await ApiaryLand.deploy();
    })

    // HoneypotGame
    let game;
    await run("Deploy HoneypotGame", async () => {
        const HoneypotGame = await ethers.getContractFactory("HoneypotGame");
        game = await HoneypotGame.deploy(land.address, item.address, bank.address);
    })

    // Grant HoneypotGame roles
    // Bank: BANKER_ROLE
    await run("Grant HoneyBank.BANKER_ROLE to HoneypotGame", async () => {
        const bankerRole = await bank.BANKER_ROLE();
        await bank.grantRole(bankerRole, game.address);
    })

    // Land: OPERATOR_ROLE
    await run("Grant ApiaryLand.OPERATOR_ROLE to HoneypotGame", async() => {
        const operatorRole = await land.OPERATOR_ROLE();
        await land.grantRole(operatorRole, game.address);
    })

    // Bee Item: MINTER_ROLE
    await run("Grant BeeItem.OPERATOR_ROLE to HoneypotGame", async() => {
        const itemOperatorRole = await item.OPERATOR_ROLE();
        await item.grantRole(itemOperatorRole, game.address);
    })

    // Save addresses
    let contractAddresses = {
        MockStableCoin: stable.address,
        HoneypotToken: token.address,
        ApiaryLand: land.address,
        HoneypotGame: game.address,
        BeeItem: item.address,
        HoneyBank: bank.address
    };
    await run("Save results to contract-addresses.json", async() => {
        fs.writeFileSync("./contract-addresses.json", JSON.stringify(contractAddresses, null, 4));
    })

    await run("Save 'common' set", async () => {
        await land.saveSet(1, 1000, [1,2,3,4,5,6,7], [1000,1000,1000,1000,1000,1000,1000])
    })

    await run("Save 'uncommon' set", async () => {
        await land.saveSet(2, 2000, [8,9,10,11,12,13,14], [2000,2000,2000,2000,2000,2000,2000])
    })

    await run("Save 'master' set", async () => {
        await land.saveSet(3, 3000, [15,16,17,18,19,20,21], [3000,3000,3000,3000,3000,3000,3000])
    })

    await run("Save 'epic' set", async () => {
        await land.saveSet(4, 4000, [22,23,24,25,26,27,28], [4000,4000,4000,4000,4000,4000,4000])
    })

    await run("Add items for sale", async () => {
        await game.addItemsForSale(
            [
                // Common set
                1,2,3,4,5,6,7,
                // Uncommon set
                8,9,10,11,12,13,14,
                // Master Set
                15,16,17,18,19,20,21,
                // Epic Set
                22,23,24,25,26,27,28
            ],
            [
                // Common set
                eth(5000),  eth(12500), eth(18750), eth(30000), eth(40000),  eth(50000),  eth(62500),
                // Uncommon set
                eth(10000), eth(25000), eth(37500), eth(60000), eth(80000),  eth(100000), eth(125000),
                // Master Set
                eth(15000), eth(37500), eth(56250), eth(90000), eth(120000), eth(150000), eth(187500),
                // Epic Set
                eth(20000), eth(50000), eth(75000), eth(12000), eth(160000), eth(200000), eth(250000)
            ]
        )
    })

    console.log("---------------------------------");
    console.log("Migration successfully completed!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

async function run(name, task) {
    process.stdout.write(`Run '${name}'...`);
    await task();
    console.log("[DONE]");
}

function eth(value) {
    return ethers.utils.parseEther(value.toString());
}