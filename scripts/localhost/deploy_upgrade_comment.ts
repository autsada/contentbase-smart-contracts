import { ethers, upgrades } from "hardhat"
import path from "path"
import fs from "fs/promises"

import commentContractV1 from "../../abi/localhost/ContentBaseCommentV1.json"

async function main() {
  const ContentBaseCommentV1 = await ethers.getContractFactory(
    "ContentBaseCommentV1"
  )
  const contentBaseCommentV1 = await upgrades.upgradeProxy(
    commentContractV1.address,
    ContentBaseCommentV1
  )

  await contentBaseCommentV1.deployed()

  console.log("ContentBaseCommentV1 deployed to:", contentBaseCommentV1.address)
  // Pull the address and ABI out, since that will be key in interacting with the smart contract later.
  const data = {
    address: contentBaseCommentV1.address,
    abi: JSON.parse(contentBaseCommentV1.interface.format("json") as string),
  }

  await fs.writeFile(
    path.join(__dirname, "../..", "/abi/localhost/ContentBaseCommentV1.json"),
    JSON.stringify(data)
  )
}

main().catch((error) => {
  console.error("error: ", error)
  process.exitCode = 1
})
