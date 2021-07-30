// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require('hardhat')
const { ethers, upgrades } = require('hardhat')
const eBigNumber = ethers.BigNumber
const yeldAddress = '0x468ab3b1f63A1C14b361bC367c3cC92277588Da1'

async function main() {
	console.log('Starting')
	let accs = []
	let network = 0
	try {
		network = (await ethers.provider.getNetwork()).chainId
	} catch (e) {}
	const accounts = await ethers.getSigners()
	for (const account of accounts) {
		accs.push(account.address)
	}
	console.log('Deployer acc:', accs[0])
	console.log('Network id:', network)
    if (network !== 1) return console.error('The network must be MAINNET 1')

	console.log('Deploying NFTManager...')
	const NFTManager = await ethers.getContractFactory('NFTManager')
	const manager = await upgrades.deployProxy(NFTManager, [yeldAddress, accs[0], yeldAddress, 'https://yeld.dev/'])
	await manager.deployed()
	console.log('NFTManager:', manager.address)

	console.log('Deploying DistributeNFTRewards...')
	const DistributeNFTRewards = await ethers.getContractFactory('DistributeNFTRewards')
	const rewards = await upgrades.deployProxy(DistributeNFTRewards, [yeldAddress, yeldAddress, manager.address])
	await rewards.deployed()
	console.log('DistributeNFTRewards:', rewards.address)

	console.log('Doing setDistributeNFTRewards...')
	await manager.setDistributeNFTRewards(rewards.address)

	console.log('Creating blueprints 4...')
	const amountFour = eBigNumber.from(10)
	const costFour = eBigNumber.from('400000000000000000000')
	await manager.createBlueprint('magboleite.json', amountFour, costFour)
	await manager.createBlueprint('massaz.json', amountFour, costFour)
	console.log('Creating blueprints 3...')
	const amountThree = eBigNumber.from(100)
	const costThree = eBigNumber.from('100000000000000000000')
	await manager.createBlueprint('nicmond.json', amountThree, costThree)
	await manager.createBlueprint('pasciclase.json', amountThree, costThree)
	console.log('Creating blueprints 2...')
	const amountTwo = eBigNumber.from(300)
	const costTwo = eBigNumber.from('10000000000000000000')
	await manager.createBlueprint('broctanite.json', amountTwo, costTwo)
	await manager.createBlueprint('harmepite.json', amountTwo, costTwo)
	await manager.createBlueprint('paryite.json', amountTwo, costTwo)
	await manager.createBlueprint('zabukite.json', amountTwo, costTwo)
	console.log('Creating blueprints 1...')
	const amountOne = eBigNumber.from(1000)
	const costOne = eBigNumber.from('1000000000000000000')
	await manager.createBlueprint('adembite.json', amountOne, costOne)
	await manager.createBlueprint('archment.json', amountOne, costOne)
	await manager.createBlueprint('borarite.json', amountOne, costOne)
	await manager.createBlueprint('idrosite.json', amountOne, costOne)
	await manager.createBlueprint('rosatorite.json', amountOne, costOne)
	await manager.createBlueprint('zanspore.json', amountOne, costOne)
	
	console.log('DONE')
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
	.then(() => process.exit(0))
	.catch(error => {
		console.error(error)
		process.exit(1)
	})
