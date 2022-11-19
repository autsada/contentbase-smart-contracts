import { ethers, upgrades } from "hardhat"
import path from "path"
import fs from "fs/promises"

import profileContractV1 from "../abi/ContentBaseProfileV1.json"

async function main() {
  const ContentBaseProfileV1 = await ethers.getContractFactory(
    "ContentBaseProfileV1"
  )
  const contentBaseProfileV1 = await upgrades.upgradeProxy(
    profileContractV1.address,
    ContentBaseProfileV1
  )

  await contentBaseProfileV1.deployed()

  console.log("ContentBaseProfileV1 deployed to:", contentBaseProfileV1.address)
  // Pull the address and ABI out, since that will be key in interacting with the smart contract later.
  const data = {
    address: contentBaseProfileV1.address,
    abi: JSON.parse(contentBaseProfileV1.interface.format("json") as string),
  }

  await fs.writeFile(
    path.join(__dirname, "..", "/abi/ContentBaseProfileV1.json"),
    JSON.stringify(data)
  )

  // For use in Subgraph project.
  // Write abi.
  await fs.writeFile(
    path.join(__dirname, "../..", "/subgraph/abis/ContentBaseProfileV1.json"),
    JSON.stringify(data.abi)
  )
  // Write address.
  const networksFile = await fs.readFile(
    path.join(__dirname, "../..", "/subgraph/networks.json"),
    "utf8"
  )
  const networks = JSON.parse(networksFile)
  await fs.writeFile(
    path.join(__dirname, "../..", "/subgraph/networks.json"),
    JSON.stringify({
      localhost: {
        ...networks.localhost,
        ContentBaseProfileV1: { address: data.address },
      },
    })
  )
}

main().catch((error) => {
  console.error("error: ", error)
  process.exitCode = 1
})
