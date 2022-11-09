import { ethers, upgrades } from "hardhat"
import path from "path"
import fs from "fs/promises"

import profileFactoryContract from "../abi/ProfileFactory.json"

async function main() {
  const ProfileFactory = await ethers.getContractFactory(
    "ContentBaseProfileFactory"
  )
  const profileFactory = await upgrades.upgradeProxy(
    profileFactoryContract.address,
    ProfileFactory
  )

  await profileFactory.deployed()

  console.log("Profile factory deployed to:", profileFactory.address)
  // Pull the address and ABI out, since that will be key in interacting with the smart contract later.
  const data = {
    address: profileFactory.address,
    abi: JSON.parse(profileFactory.interface.format("json") as string),
  }

  await fs.writeFile(
    path.join(__dirname, "..", "/abi/ProfileFactory.json"),
    JSON.stringify(data)
  )
  // Write abi to json for use in subgraph.
  await fs.writeFile(
    path.join(
      __dirname,
      "../..",
      "/subgraph/abis/ContentBaseProfileFactory.json"
    ),
    JSON.stringify(data.abi)
  )
}

main().catch((error) => {
  console.error("error: ", error)
  process.exitCode = 1
})
