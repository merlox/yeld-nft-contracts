const hre = require('hardhat')
const { ethers, upgrades } = require('hardhat')

async function main() {
    console.log('Starting')
	const proxyAddress = '0x306220604A87Bc090fF7Dd8656c6Bd446A1c083d'
	const NFTManagerV4 = await ethers.getContractFactory('NFTManagerV4')
	const newManager = await upgrades.upgradeProxy(proxyAddress, NFTManagerV4)
	console.log('newManager upgraded', newManager.address)
}

main()
	.then(() => process.exit(0))
	.catch(error => {
		console.error(error)
		process.exit(1)
	})
