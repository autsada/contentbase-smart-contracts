import { ethers, upgrades } from 'hardhat'
import path from 'path'
import fs from 'fs/promises'

async function main() {
  const PublishNFTContract = await ethers.getContractFactory('PublishNFT')
  const publishNFTContract = await upgrades.deployProxy(PublishNFTContract)

  await publishNFTContract.deployed()

  console.log('PublishNFTContract deployed to:', publishNFTContract.address)
  //Pull the address and ABI out, since that will be key in interacting with the smart contract later
  const data = {
    address: publishNFTContract.address,
    abi: JSON.parse(publishNFTContract.interface.format('json') as string),
  }

  await fs.writeFile(
    path.join(__dirname, '..', '/abi/PublishNFTContract.json'),
    JSON.stringify(data)
  )
}

main().catch((error) => {
  console.error('error: ', error)
  process.exitCode = 1
})
