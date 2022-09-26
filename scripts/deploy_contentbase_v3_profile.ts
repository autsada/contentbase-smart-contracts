import { ethers, upgrades } from 'hardhat'
import path from 'path'
import fs from 'fs/promises'

async function main() {
  const ContentBaseV3 = await ethers.getContractFactory('ContentBaseProfileV3')
  const contentBaseV3 = await upgrades.deployProxy(ContentBaseV3)

  await contentBaseV3.deployed()

  console.log('ContentBaseV3 deployed to:', contentBaseV3.address)
  //Pull the address and ABI out, since that will be key in interacting with the smart contract later
  const data = {
    address: contentBaseV3.address,
    abi: JSON.parse(contentBaseV3.interface.format('json') as string),
  }

  await fs.writeFile(
    path.join(__dirname, '..', '/abi/ContentBaseProfileV3.json'),
    JSON.stringify(data)
  )
}

main().catch((error) => {
  console.error('error: ', error)
  process.exitCode = 1
})
