import { ethers, upgrades } from 'hardhat'
import path from 'path'
import fs from 'fs/promises'

import profileNFTContract from '../abi/ProfileNFTContract.json'

async function main() {
  const ProfileNFTContractV2 = await ethers.getContractFactory('ProfileNFT')
  const profileNFTContractV2 = await upgrades.upgradeProxy(
    profileNFTContract.address,
    ProfileNFTContractV2
  )

  await profileNFTContractV2.deployed()

  console.log('ContentBase deployed to:', profileNFTContractV2.address)
  //Pull the address and ABI out, since that will be key in interacting with the smart contract later
  const data = {
    address: profileNFTContractV2.address,
    abi: JSON.parse(profileNFTContractV2.interface.format('json') as string),
  }

  await fs.writeFile(
    path.join(__dirname, '..', '/abi/ProfileNFTContractV2.json'),
    JSON.stringify(data)
  )
}

main().catch((error) => {
  console.error('error: ', error)
  process.exitCode = 1
})
