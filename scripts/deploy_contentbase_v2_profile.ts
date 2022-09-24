import { ethers, upgrades } from 'hardhat'
import path from 'path'
import fs from 'fs/promises'

async function main() {
  const ContentBaseV2 = await ethers.getContractFactory('ContentBaseProfileV2')
  const contentBaseV2 = await upgrades.deployProxy(ContentBaseV2)

  await contentBaseV2.deployed()

  console.log('ContentBaseV2 deployed to:', contentBaseV2.address)
  //Pull the address and ABI out, since that will be key in interacting with the smart contract later
  const data = {
    address: contentBaseV2.address,
    abi: JSON.parse(contentBaseV2.interface.format('json') as string),
  }

  await fs.writeFile(
    path.join(__dirname, '..', '/abi/ContentBaseProfileV2.json'),
    JSON.stringify(data)
  )
}

main().catch((error) => {
  console.error('error: ', error)
  process.exitCode = 1
})
