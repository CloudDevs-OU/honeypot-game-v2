const {ethers, network} = require("hardhat");
const fs = require("fs");
const prizes = { slots: 0, tokens: 1, bee: 2, nft: 3 };

async function main() {
    console.log(`Start migration in '${network.name}' network...`);

    let stableAddress;
    if (network.name === "bscMainnet") {
        stableAddress = "0x55d398326f99059ff775485246999027b3197955"; // USDT
    } if (network.name === "bscTestnet") {
        stableAddress = "0x7136672365a9a09eae2086fc911b948e81132040"; // Mock USDT
    } else {
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
        item = await BeeItem.deploy(`https://${network.name === "bscMainnet" ? "app" : "testnet"}.honeypot.game/items/{id}.json`);
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

    // HoneypotBox
    let box;
    await run("Deploy HoneypotBox", async () => {
        const HoneyBox = await ethers.getContractFactory("HoneyBox");
        box = await HoneyBox.deploy(game.address, bank.address, item.address, land.address);
    })

    await run("Setup 'Welcome' box", async () => {
        // Setup Welcome box
        const welcomeBoxId = await box.welcomeBoxId();
        await box.createOrUpdateBox(welcomeBoxId, 0, [
            // Slots
            {prizeType: prizes.slots, weight: 10000, value: 3}, // 3 Slots
            {prizeType: prizes.slots, weight: 9000, value: 4},  // 4 Slots
            {prizeType: prizes.slots, weight: 8000, value: 5},  // 5 Slots
            {prizeType: prizes.slots, weight: 7000, value: 8},  // 8 Slots

            // Tokens
            {prizeType: prizes.tokens, weight: 6000, value: eth(1000)},  // 1,000 HNY
            {prizeType: prizes.tokens, weight: 5000, value: eth(2000)},  // 2,000 HNY
            {prizeType: prizes.tokens, weight: 4000, value: eth(4000)},  // 4,000 HNY
            {prizeType: prizes.tokens, weight: 3000, value: eth(8000)},  // 8,000 HNY

            // Bees
            {prizeType: prizes.bee, weight: 10, value: 1},  // Bee Level 1
            {prizeType: prizes.bee, weight: 10, value: 2},  // Bee Level 2
            {prizeType: prizes.bee, weight: 10, value: 3},  // Bee Level 3
            {prizeType: prizes.bee, weight: 10, value: 4},  // Bee Level 4
            {prizeType: prizes.bee, weight: 10, value: 5},  // Bee Level 5
            {prizeType: prizes.bee, weight: 10, value: 6},  // Bee Level 6
            {prizeType: prizes.bee, weight: 10, value: 7},  // Bee Level 7

            // NFT
            {prizeType: prizes.nft, weight: 1050, value: 1}, // Common #1
            {prizeType: prizes.nft, weight: 1000, value: 2}, // Common #2
            {prizeType: prizes.nft, weight: 950, value: 3},  // Common #3
            {prizeType: prizes.nft, weight: 900, value: 4},  // Common #4
            {prizeType: prizes.nft, weight: 850, value: 5},  // Common #5
            {prizeType: prizes.nft, weight: 800, value: 6},  // Common #6
            {prizeType: prizes.nft, weight: 750, value: 7},  // Common #7

            {prizeType: prizes.nft, weight: 700, value: 8},  // Uncommon #1
            {prizeType: prizes.nft, weight: 650, value: 9},  // Uncommon #2
            {prizeType: prizes.nft, weight: 600, value: 10}, // Uncommon #3
            {prizeType: prizes.nft, weight: 550, value: 11}, // Uncommon #4
            {prizeType: prizes.nft, weight: 500, value: 12}, // Uncommon #5
            {prizeType: prizes.nft, weight: 450, value: 13}, // Uncommon #6
            {prizeType: prizes.nft, weight: 400, value: 14}, // Uncommon #7

            {prizeType: prizes.nft, weight: 350, value: 15}, // Master #1
            {prizeType: prizes.nft, weight: 300, value: 16}, // Master #2
            {prizeType: prizes.nft, weight: 250, value: 17}, // Master #3
            {prizeType: prizes.nft, weight: 200, value: 18}, // Master #4
            {prizeType: prizes.nft, weight: 150, value: 19}, // Master #5
            {prizeType: prizes.nft, weight: 100, value: 20}, // Master #6
            {prizeType: prizes.nft, weight: 50, value: 21},  // Master #7

            {prizeType: prizes.nft, weight: 10, value: 22},  // Epic #1
            {prizeType: prizes.nft, weight: 10, value: 23},  // Epic #2
            {prizeType: prizes.nft, weight: 10, value: 24},  // Epic #3
            {prizeType: prizes.nft, weight: 10, value: 25},  // Epic #4
            {prizeType: prizes.nft, weight: 10, value: 26},  // Epic #5
            {prizeType: prizes.nft, weight: 10, value: 27},  // Epic #6
            {prizeType: prizes.nft, weight: 10, value: 28},  // Epic #7
        ]);
    })

    await run("Setup 'Everyday' box", async () => {
        const everydayBoxId = await box.everydayBoxId();
        await box.createOrUpdateBox(everydayBoxId, 0, [
            // Slots
            {prizeType: prizes.slots, weight: 100000, value: 1}, // 1 Slot
            {prizeType: prizes.slots, weight: 25000, value: 2},  // 2 Slots
            {prizeType: prizes.slots, weight: 25000, value: 3},  // 3 Slots
            {prizeType: prizes.slots, weight: 15000, value: 4},  // 4 Slots
            {prizeType: prizes.slots, weight: 10000, value: 5},  // 5 Slots
            {prizeType: prizes.slots, weight: 5000, value: 8},   // 8 Slots

            // Tokens
            {prizeType: prizes.tokens, weight: 2000, value: eth(250)},  // 250 HNY
            {prizeType: prizes.tokens, weight: 1000, value: eth(500)},  // 500 HNY
            {prizeType: prizes.tokens, weight: 500, value: eth(1000)},  // 1,000 HNY
            {prizeType: prizes.tokens, weight: 250, value: eth(2000)},  // 2,000 HNY

            // NFT
            {prizeType: prizes.nft, weight: 28, value: 1},  // Common #1
            {prizeType: prizes.nft, weight: 27, value: 2},  // Common #2
            {prizeType: prizes.nft, weight: 26, value: 3},  // Common #3
            {prizeType: prizes.nft, weight: 25, value: 4},  // Common #4
            {prizeType: prizes.nft, weight: 24, value: 5},  // Common #5
            {prizeType: prizes.nft, weight: 23, value: 6},  // Common #6
            {prizeType: prizes.nft, weight: 22, value: 7},  // Common #7

            {prizeType: prizes.nft, weight: 21, value: 8},  // Uncommon #1
            {prizeType: prizes.nft, weight: 20, value: 9},  // Uncommon #2
            {prizeType: prizes.nft, weight: 19, value: 10}, // Uncommon #3
            {prizeType: prizes.nft, weight: 18, value: 11}, // Uncommon #4
            {prizeType: prizes.nft, weight: 17, value: 12}, // Uncommon #5
            {prizeType: prizes.nft, weight: 16, value: 13}, // Uncommon #6
            {prizeType: prizes.nft, weight: 15, value: 14}, // Uncommon #7

            {prizeType: prizes.nft, weight: 14, value: 15}, // Master #1
            {prizeType: prizes.nft, weight: 13, value: 16}, // Master #2
            {prizeType: prizes.nft, weight: 12, value: 17}, // Master #3
            {prizeType: prizes.nft, weight: 11, value: 18}, // Master #4
            {prizeType: prizes.nft, weight: 10, value: 19}, // Master #5
            {prizeType: prizes.nft, weight: 9, value: 20},  // Master #6
            {prizeType: prizes.nft, weight: 8, value: 21},  // Master #7

            {prizeType: prizes.nft, weight: 7, value: 22},  // Epic #1
            {prizeType: prizes.nft, weight: 6, value: 23},  // Epic #2
            {prizeType: prizes.nft, weight: 5, value: 24},  // Epic #3
            {prizeType: prizes.nft, weight: 4, value: 25},  // Epic #4
            {prizeType: prizes.nft, weight: 3, value: 26},  // Epic #5
            {prizeType: prizes.nft, weight: 2, value: 27},  // Epic #6
            {prizeType: prizes.nft, weight: 1, value: 28},  // Epic #7
        ]);
    })

    // Grant roles
    // Bank: BANKER_ROLE
    await run("Grant HoneyBank.BANKER_ROLE to HoneypotGame and HoneyBox", async () => {
        const bankerRole = await bank.BANKER_ROLE();
        await bank.grantRole(bankerRole, game.address);
        await bank.grantRole(bankerRole, box.address);
    })

    // Land: OPERATOR_ROLE
    await run("Grant ApiaryLand.OPERATOR_ROLE to HoneypotGame and HoneyBox", async() => {
        const operatorRole = await land.OPERATOR_ROLE();
        await land.grantRole(operatorRole, game.address);
        await land.grantRole(operatorRole, box.address);
    })

    // Bee Item: OPERATOR_ROLE
    await run("Grant BeeItem.OPERATOR_ROLE to HoneypotGame", async() => {
        const itemOperatorRole = await item.OPERATOR_ROLE();
        await item.grantRole(itemOperatorRole, game.address);
    })

    // Bee Item: MINTER_ROLE
    await run("Grant BeeItem.MINTER_ROLE to HoneyBox", async() => {
        const minterOperatorRole = await item.MINTER_ROLE();
        await item.grantRole(minterOperatorRole, box.address);
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