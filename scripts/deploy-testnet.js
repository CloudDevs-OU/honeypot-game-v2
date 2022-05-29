const {ethers, network} = require("hardhat");
const fs = require("fs");

if (network.name !== 'testnet') {
    throw Error("This script can be run only in testnet");
}

const ONE_TOKEN = ethers.utils.parseEther("1");
const STABLE_INITIAL_BALANCE = ONE_TOKEN.mul(100000); // 100,000

async function main() {
    // Honey Bank
    const signers = await ethers.getSigners();
    const addresses = signers.map(a => a.address);
    const MockStable = await ethers.getContractFactory("MockStable");
    console.log("Deploying MockStable...");
    const stable = await MockStable.deploy(addresses, STABLE_INITIAL_BALANCE);
    console.log(`MockStable deployed: ${link(stable.address)}`);

    const HoneyBank = await ethers.getContractFactory("HoneyBank");
    console.log("Deploying HoneyBank...");
    const bank = await HoneyBank.deploy(stable.address);
    console.log(`HoneyBank deployed: ${link(bank.address)}`);

    const ERC20 = await ethers.getContractFactory("ERC20");
    const token = await ERC20.attach(await bank.token());
    console.log(`HoneyToken:  ${link(token.address)}`);

    // BeeItem
    const BeeItem = await ethers.getContractFactory("BeeItem");
    console.log("Deploying BeeItem...");
    const item = await BeeItem.deploy("https://honeypot-game-fe.pages.dev/item/{id}.json");
    console.log(`BeeItem deployed: ${link(item.address)}`);

    // ApiaryLand
    const ApiaryLand = await ethers.getContractFactory("ApiaryLand");
    console.log("Deploying ApiaryLand...");
    const land = await ApiaryLand.deploy();
    console.log(`ApiaryLand deployed: ${link(land.address)}`);

    // HoneypotGame
    const HoneypotGame = await ethers.getContractFactory("HoneypotGame");
    console.log("Deploying HoneypotGame...");
    const game = await HoneypotGame.deploy(land.address, item.address, bank.address);
    console.log(`HoneypotGame deployed: ${link(game.address)}`);

    // Grant HoneypotGame roles
    // Bank: BANKER_ROLE
    const bankerRole = await bank.BANKER_ROLE();
    process.stdout.write("Granting HoneyBank.BANKER_ROLE to HoneypotGame...");
    await bank.grantRole(bankerRole, game.address);
    console.log("[DONE]");

    // Land: OPERATOR_ROLE
    const operatorRole = await land.OPERATOR_ROLE();
    process.stdout.write("Granting ApiaryLand,OPERATOR_ROLE to HoneypotGame...");
    await land.grantRole(operatorRole, game.address);
    console.log("[DONE]");

    // Bee Item: MINTER_ROLE
    const itemOperatorRole = await item.OPERATOR_ROLE();
    process.stdout.write("Granting BeeItem.OPERATOR_ROLE to HoneypotGame...");
    await item.grantRole(itemOperatorRole, game.address);
    console.log("[DONE]");

    // Save addresses
    let contractAddresses = {
        MockStableCoin: stable.address,
        HoneypotToken: token.address,
        ApiaryLand: land.address,
        HoneypotGame: game.address
    };
    process.stdout.write("Saving results to contract-addresses.json...");
    fs.writeFileSync("./contract-addresses.json", JSON.stringify(contractAddresses, null, 4));
    console.log("[DONE]");

    console.log("---------------------------------");
    console.log("Migration successfully completed!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

function link(contractAddress) {
    return `https://testnet.bscscan.com/address/${contractAddress}`;
}