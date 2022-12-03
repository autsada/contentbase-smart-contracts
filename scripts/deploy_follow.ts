import { ethers, upgrades } from "hardhat"
import path from "path"
import fs from "fs/promises"

import profileContractV1 from "../abi/ContentBaseProfileV1.json"

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
    path.join(__dirname, "..", "/abi/ContentBaseFollowV1.json"),
    JSON.stringify(data)
  )

  //   // For use in Subgraph project.
  //   // Write abi.
  //   await fs.writeFile(
  //     path.join(__dirname, "../..", "/subgraph/abis/ContentBaseFollowV1.json"),
  //     JSON.stringify(data.abi)
  //   )
  //   // Write address.
  //   const networksFile = await fs.readFile(
  //     path.join(__dirname, "../..", "/subgraph/networks.json"),
  //     "utf8"
  //   )
  //   const networks = JSON.parse(networksFile)
  //   await fs.writeFile(
  //     path.join(__dirname, "../..", "/subgraph/networks.json"),
  //     JSON.stringify({
  //       localhost: {
  //         ...networks.localhost,
  //         ContentBaseFollowV1: { address: data.address },
  //       },
  //     })
  //   )
}

main().catch((error) => {
  console.error("error: ", error)
  process.exitCode = 1
})
