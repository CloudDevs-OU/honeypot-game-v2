const {ethers, network} = require("hardhat");
const fs = require("fs");

async function main() {
    console.log(`Start migration in '${network.name}' network...`);

    let stableAddress;
    if (network.name === "bscMainnet") {
        stableAddress = "0x55d398326f99059ff775485246999027b3197955"; // USDT
    } else {
        // Mock Stable
        const MockStable = await ethers.getContractFactory("MockStable");
        await run("Deploy MockStable", async () => {
            const stable = await MockStable.deploy();
            stableAddress = stable.address;
        })
    }

    // Honey Bank
    let bank;
    await run("Deploy HoneyBank", async () => {
        const HoneyBank = await ethers.getContractFactory("HoneyBank");
        bank = await HoneyBank.deploy(stableAddress, { gasLimit: 4000000 });
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
        StableCoin: stableAddress,
        HoneypotToken: token.address,
        ApiaryLand: land.address,
        HoneypotGame: game.address,
        BeeItem: item.address,
        HoneyBank: bank.address
    };

    const fileName = network.name === "bscMainnet" ? "contract-addresses.json" : `contract-addresses-${network.name}.json`;
    await run(`Save results to ${fileName}`, async() => {
        fs.writeFileSync(`./${fileName}`, JSON.stringify(contractAddresses, null, 4));
    })

    await run("Save 'Honey Hunter' set", async () => {
        await land.saveSet(1, 1000, [1,2,3,4,5,6,7], [1000,1000,1000,1000,1000,1000,1000])
    })

    await run("Save 'Sweet Bee' set", async () => {
        await land.saveSet(2, 2000, [8,9,10,11,12,13,14], [2000,2000,2000,2000,2000,2000,2000])
    })

    await run("Save 'Holly Pot' set", async () => {
        await land.saveSet(3, 3000, [15,16,17,18,19,20,21], [3000,3000,3000,3000,3000,3000,3000])
    })

    await run("Save 'Golden Wings' set", async () => {
        await land.saveSet(4, 4000, [22,23,24,25,26,27,28], [4000,4000,4000,4000,4000,4000,4000])
    })

    await run("Add items for sale", async () => {
        await game.addItemsForSale(
            [
                // Honey Hunter set items
                1,2,3,4,5,6,7,
                // Sweet Bee set items
                8,9,10,11,12,13,14,
                // Holly Pot set items
                15,16,17,18,19,20,21,
                // Golden Wings set items
                22,23,24,25,26,27,28
            ],
            [
                // Honey Hunter set items prices
                eth(5000),  eth(12500), eth(18750), eth(30000), eth(40000),  eth(50000),  eth(62500),
                //  Sweet Bee set items prices
                eth(10000), eth(25000), eth(37500), eth(60000), eth(80000),  eth(100000), eth(125000),
                //  Holly Pot set items prices
                eth(15000), eth(37500), eth(56250), eth(90000), eth(120000), eth(150000), eth(187500),
                //  Golden Wings set items prices
                eth(20000), eth(50000), eth(75000), eth(12000), eth(160000), eth(200000), eth(250000)
            ]
        )
    })

    console.log("---------------------------------");
    console.log(`Migration to '${network.name}' network successfully completed!`);
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