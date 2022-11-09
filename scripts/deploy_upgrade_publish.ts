import { ethers, upgrades } from "hardhat"
import path from "path"
import fs from "fs/promises"

import publishContractV1 from "../abi/PublishContract.json"

async function main() {
  const PublishContract = await ethers.getContractFactory("ContentBasePublish")
  const publishContract = await upgrades.upgradeProxy(
    publishContractV1.address,
    PublishContract
  )

  await publishContract.deployed()

  console.log(
    "Publish contract (updated) deployed to:",
    publishContract.address
  )
  //Pull the address and ABI out, since that will be key in interacting with the smart contract later
  const data = {
    address: publishContract.address,
    abi: JSON.parse(publishContract.interface.format("json") as string),
  }

  await fs.writeFile(
    path.join(__dirname, "..", "/abi/PublishContract.json"),
    JSON.stringify(data)
  )
  // Write abi to json for use in subgraph.
  await fs.writeFile(
    path.join(__dirname, "../..", "/subgraph/abis/ContentBasePublish.json"),
    JSON.stringify(data.abi)
  )
}

main().catch((error) => {
  console.error("error: ", error)
  process.exitCode = 1
})
