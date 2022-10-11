import { ethers, upgrades } from 'hardhat'
import path from 'path'
import fs from 'fs/promises'

async function main() {
  const ProfileNFTContract = await ethers.getContractFactory('ProfileNFT')
  const profileNFTContract = await upgrades.deployProxy(ProfileNFTContract)

  await profileNFTContract.deployed()

  console.log('ProfileNFTContract deployed to:', profileNFTContract.address)
  //Pull the address and ABI out, since that will be key in interacting with the smart contract later
  const data = {
    address: profileNFTContract.address,
    abi: JSON.parse(profileNFTContract.interface.format('json') as string),
  }

  await fs.writeFile(
    path.join(__dirname, '..', '/abi/ProfileContract.json'),
    JSON.stringify(data)
  )
}

main().catch((error) => {
  console.error('error: ', error)
  process.exitCode = 1
})
