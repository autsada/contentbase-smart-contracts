import { ethers, upgrades } from "hardhat"
import path from "path"
import fs from "fs/promises"

import profileContractV1 from "../abi/ContentBaseProfileV1.json"

async function main() {
  const ContentBaseProfileV2 = await ethers.getContractFactory(
    "ContentBaseProfileV2"
  )
  const contentBaseProfileV2 = await upgrades.upgradeProxy(
    profileContractV1.address,
    ContentBaseProfileV2
  )

  await contentBaseProfileV2.deployed()

  console.log("ContentBaseProfileV2 deployed to:", contentBaseProfileV2.address)
  // Pull the address and ABI out, since that will be key in interacting with the smart contract later.
  const data = {
    address: contentBaseProfileV2.address,
    abi: JSON.parse(contentBaseProfileV2.interface.format("json") as string),
  }

  await fs.writeFile(
    path.join(__dirname, "..", "/abi/ContentBaseProfileV2.json"),
    JSON.stringify(data)
  )

  // For use in Subgraph project.
  await fs.writeFile(
    path.join(__dirname, "../..", "/subgraph/abis/ContentBaseProfileV2.json"),
    JSON.stringify(data.abi)
  )
}

main().catch((error) => {
  console.error("error: ", error)
  process.exitCode = 1
})
