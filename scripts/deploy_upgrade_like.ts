import { ethers, upgrades } from "hardhat"
import path from "path"
import fs from "fs/promises"

import likeContractV1 from "../abi/ContentBaseLikeV1.json"

async function main() {
  const ContentBaseLikeV1 = await ethers.getContractFactory("ContentBaseLikeV1")
  const contentBaseLikeV1 = await upgrades.upgradeProxy(
    likeContractV1.address,
    ContentBaseLikeV1
  )

  await contentBaseLikeV1.deployed()

  console.log("ContentBaseLikeV1 deployed to:", contentBaseLikeV1.address)
  // Pull the address and ABI out, since that will be key in interacting with the smart contract later.
  const data = {
    address: contentBaseLikeV1.address,
    abi: JSON.parse(contentBaseLikeV1.interface.format("json") as string),
  }

  await fs.writeFile(
    path.join(__dirname, "..", "/abi/ContentBaseLikeV1.json"),
    JSON.stringify(data)
  )
}

main().catch((error) => {
  console.error("error: ", error)
  process.exitCode = 1
})
