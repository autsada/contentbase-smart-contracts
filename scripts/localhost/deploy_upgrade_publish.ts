import { ethers, upgrades } from "hardhat"
import path from "path"
import fs from "fs/promises"

import publishContractV1 from "../../abi/testnet/ContentBasePublishV1.json"

async function main() {
  const ContentBasePublishV1 = await ethers.getContractFactory(
    "ContentBasePublishV1"
  )
  const contentBasePublishV1 = await upgrades.upgradeProxy(
    publishContractV1.address,
    ContentBasePublishV1
  )

  await contentBasePublishV1.deployed()

  console.log("ContentBasePublishV1 deployed to:", contentBasePublishV1.address)
  // Pull the address and ABI out, since that will be key in interacting with the smart contract later.
  const data = {
    address: contentBasePublishV1.address,
    abi: JSON.parse(contentBasePublishV1.interface.format("json") as string),
  }

  await fs.writeFile(
    path.join(__dirname, "../..", "/abi/localhost/ContentBasePublishV1.json"),
    JSON.stringify(data)
  )
}

main().catch((error) => {
  console.error("error: ", error)
  process.exitCode = 1
})
