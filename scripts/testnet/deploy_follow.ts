import { ethers, upgrades } from "hardhat"
import path from "path"
import fs from "fs/promises"

import profileContractV1 from "../../abi/testnet/ContentBaseProfileV1.json"

async function main() {
  const ContentBaseFollowV1 = await ethers.getContractFactory(
    "ContentBaseFollowV1"
  )
  const contentBaseFollowV1 = await upgrades.deployProxy(ContentBaseFollowV1, [
    profileContractV1.address,
  ])

  await contentBaseFollowV1.deployed()

  console.log("ContentBaseFollowV1 deployed to:", contentBaseFollowV1.address)
  // Pull the address and ABI out, since that will be key in interacting with the smart contract later.
  const data = {
    address: contentBaseFollowV1.address,
    abi: JSON.parse(contentBaseFollowV1.interface.format("json") as string),
  }

  await fs.writeFile(
    path.join(__dirname, "../..", "/abi/testnet/ContentBaseFollowV1.json"),
    JSON.stringify(data)
  )
}

main().catch((error) => {
  console.error("error: ", error)
  process.exitCode = 1
})
