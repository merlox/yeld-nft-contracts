require('@nomiclabs/hardhat-waffle')
require('@openzeppelin/hardhat-upgrades')
require('@nomiclabs/hardhat-etherscan')
const fs = require('fs')
const mnemonic = fs.readFileSync('.secret').toString().trim()

module.exports = {
	solidity: {
		version: '0.6.2',
		settings: {
			optimizer: {
				enabled: true,
				runs: 5,
			},
		},
	},
	networks: {
		hardhat: {
			forking: {
				url: 'https://eth-rinkeby.alchemyapi.io/v2/AMvJwNdOexUXljMgsoindNq2ID9F7Wd0', // Rinkeby
				// url: 'https://eth-mainnet.alchemyapi.io/v2/cmHEQqWnoliAP0lgTieeUtwHi0KxEOlh', // Mainnet
				blockNumber: 8251618, // Rinkeby
				// blockNumber: 12265647, // Mainnet
			},
			accounts: { mnemonic },
		},
		bscTestnet: {
			url: `https://data-seed-prebsc-2-s3.binance.org:8545/`,
			accounts: { mnemonic },
		},
		bsc: {
			url: 'https://bsc-dataseed.binance.org/',
			chainId: 56,
			accounts: { mnemonic },
		},
		rinkeby: {
			url: 'https://rinkeby.infura.io/v3/87ac5f84d691494588f2162b15d1523d',
			chainId: 4,
			accounts: { mnemonic },
		},
		mainnet: {
			url: 'https://mainnet.infura.io/v3/87ac5f84d691494588f2162b15d1523d',
			chainId: 1,
			accounts: { mnemonic },
			gasPrice: 75000000000,
		},
	},
	etherscan: {
		apiKey: 'AYZZZ4DRKVPK1N4D4CE6MUBU1PH9PJUHQ8',
	},
}