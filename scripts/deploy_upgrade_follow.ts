import { ethers, upgrades } from "hardhat"
import path from "path"
import fs from "fs/promises"

import followContractV1 from "../abi/ContentBaseFollowV1.json"

async function main() {
  const ContentBaseFollowV1 = await ethers.getContractFactory(
    "ContentBaseFollowV1"
  )
  const contentBaseFollowV1 = await upgrades.upgradeProxy(
    followContractV1.address,
    ContentBaseFollowV1
  )

  await contentBaseFollowV1.deployed()

  console.log("ContentBaseFollowV1 deployed to:", contentBaseFollowV1.address)
  // Pull the address and ABI out, since that will be key in interacting with the smart contract later.
  const data = {
    address: contentBaseFollowV1.address,
    abi: JSON.parse(contentBaseFollowV1.interface.format("json") as string),
  }

  await fs.writeFile(
    path.join(__dirname, "..", "/abi/ContentBaseFollowV1.json"),
    JSON.stringify(data)
  )
}

main().catch((error) => {
  console.error("error: ", error)
  process.exitCode = 1
})
