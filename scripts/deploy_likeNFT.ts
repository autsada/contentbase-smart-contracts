import { ethers, upgrades } from 'hardhat'
import path from 'path'
import fs from 'fs/promises'

async function main() {
  const LikeNFTContract = await ethers.getContractFactory('LikeNFT')
  const likeNFTContract = await upgrades.deployProxy(LikeNFTContract)

  await likeNFTContract.deployed()

  console.log('LikeNFTContract deployed to:', likeNFTContract.address)
  //Pull the address and ABI out, since that will be key in interacting with the smart contract later
  const data = {
    address: likeNFTContract.address,
    abi: JSON.parse(likeNFTContract.interface.format('json') as string),
  }

  await fs.writeFile(
    path.join(__dirname, '..', '/abi/LikeNFTContract.json'),
    JSON.stringify(data)
  )
}

main().catch((error) => {
  console.error('error: ', error)
  process.exitCode = 1
})
