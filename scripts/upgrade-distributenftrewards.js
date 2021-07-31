const { ethers, upgrades } = require('hardhat')

async function main() {
    console.log('Starting')
	const proxyAddress = '0x09358f3fD1d9353eec48f151ebc77d33E76250C3'
	const DistributeNFTRewardsV2 = await ethers.getContractFactory('DistributeNFTRewardsV2')
	const myNew = await upgrades.upgradeProxy(proxyAddress, DistributeNFTRewardsV2)
	console.log('Upgraded', myNew.address)
}

main()
	.then(() => process.exit(0))
	.catch(error => {
		console.error(error)
		process.exit(1)
	})
