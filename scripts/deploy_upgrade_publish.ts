import { ethers, upgrades } from "hardhat"
import path from "path"
import fs from "fs/promises"

import publishContractV1 from "../abi/ContentBasePublishV1.json"

async function main() {
  const ContentBasePublishV2 = await ethers.getContractFactory(
    "ContentBasePublishV2"
  )
  const contentBasePublishV2 = await upgrades.upgradeProxy(
    publishContractV1.address,
    ContentBasePublishV2
  )

  await contentBasePublishV2.deployed()

  console.log("ContentBasePublishV2 deployed to:", contentBasePublishV2.address)
  // Pull the address and ABI out, since that will be key in interacting with the smart contract later.
  const data = {
    address: contentBasePublishV2.address,
    abi: JSON.parse(contentBasePublishV2.interface.format("json") as string),
  }

  await fs.writeFile(
    path.join(__dirname, "..", "/abi/ContentBasePublishV2.json"),
    JSON.stringify(data)
  )

  // For use in Subgraph project.
  await fs.writeFile(
    path.join(__dirname, "../..", "/subgraph/abis/ContentBasePublishV2.json"),
    JSON.stringify(data.abi)
  )
}

main().catch((error) => {
  console.error("error: ", error)
  process.exitCode = 1
})
