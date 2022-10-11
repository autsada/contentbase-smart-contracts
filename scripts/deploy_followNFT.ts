import { ethers, upgrades } from 'hardhat'
import path from 'path'
import fs from 'fs/promises'

async function main() {
  const FollowNFTContract = await ethers.getContractFactory('FollowNFT')
  const followNFTContract = await upgrades.deployProxy(FollowNFTContract)

  await followNFTContract.deployed()

  console.log('FollowNFTContract deployed to:', followNFTContract.address)
  //Pull the address and ABI out, since that will be key in interacting with the smart contract later
  const data = {
    address: followNFTContract.address,
    abi: JSON.parse(followNFTContract.interface.format('json') as string),
  }

  await fs.writeFile(
    path.join(__dirname, '..', '/abi/FollowContract.json'),
    JSON.stringify(data)
  )
}

main().catch((error) => {
  console.error('error: ', error)
  process.exitCode = 1
})
