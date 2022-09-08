import { ethers, upgrades } from 'hardhat'
import path from 'path'
import fs from 'fs/promises'

async function main() {
  const ContentBase = await ethers.getContractFactory('ContentBaseProfile')
  const contentBase = await upgrades.deployProxy(ContentBase)

  await contentBase.deployed()

  console.log('ContentBase deployed to:', contentBase.address)
  //Pull the address and ABI out, since that will be key in interacting with the smart contract later
  const data = {
    address: contentBase.address,
    abi: JSON.parse(contentBase.interface.format('json') as string),
  }

  await fs.writeFile(
    path.join(__dirname, '..', '/abi/ContentBaseProfile.json'),
    JSON.stringify(data)
  )
}

main().catch((error) => {
  console.error('error: ', error)
  process.exitCode = 1
})
