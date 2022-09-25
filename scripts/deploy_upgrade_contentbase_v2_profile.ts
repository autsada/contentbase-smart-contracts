import { ethers, upgrades } from 'hardhat'
import path from 'path'
import fs from 'fs/promises'

import contentBaseProfileV2 from '../abi/ContentBaseProfileV2.json'

async function main() {
  const ContentBaseV2 = await ethers.getContractFactory('ContentBaseProfileV2')
  const contentBaseV2 = await upgrades.upgradeProxy(
    contentBaseProfileV2.address,
    ContentBaseV2
  )

  await contentBaseV2.deployed()

  console.log('ContentBase deployed to:', contentBaseV2.address)
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
