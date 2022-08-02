require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
const {mnemonic, bscscanApiKey} = require('./secrets.json');

task("accounts", "Prints the list of accounts", async () => {
    const accounts = await ethers.getSigners();
    for (const account of accounts) {
        console.log(account.address);
    }
});

module.exports = {
    solidity: "0.8.9",
    networks: {
        localhost: {
            url: "http://127.0.0.1:8545"
        },
        hardhat: {},
        bscTestnet: {
            url: "https://data-seed-prebsc-1-s1.binance.org:8545",
            chainId: 97,
            gasPrice: 20000000000,
            accounts: {mnemonic: mnemonic}
        },
        bscMainnet: {
            url: "https://bsc-dataseed.binance.org/",
            chainId: 56,
            gasPrice: 20000000000,
            accounts: {mnemonic: mnemonic}
        }
    },
    etherscan: {
        apiKey: {
            bscTestnet: bscscanApiKey,
            bsc: bscscanApiKey
        }
    },
    mocha: {
        timeout: 100000000
    }
};
