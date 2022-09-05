import { ethers, upgrades } from 'hardhat'

const owner = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'

async function main() {
  const ContentBase = await ethers.getContractFactory('ContentBaseProfile')
  const contentBase = await upgrades.deployProxy(ContentBase)

  await contentBase.deployed()

  console.log('ContentBase deployed to:', contentBase.address)
}

main().catch((error) => {
  console.error('error: ', error)
  process.exitCode = 1
})
