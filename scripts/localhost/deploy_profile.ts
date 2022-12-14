import { ethers, upgrades } from "hardhat"
import path from "path"
import fs from "fs/promises"

async function main() {
  const ContentBaseProfileV1 = await ethers.getContractFactory(
    "ContentBaseProfileV1"
  )
  const contentBaseProfileV1 = await upgrades.deployProxy(ContentBaseProfileV1)

  await contentBaseProfileV1.deployed()

  console.log("ContentBaseProfileV1 deployed to:", contentBaseProfileV1.address)
  // Pull the address and ABI out, since that will be key in interacting with the smart contract later.
  const data = {
    address: contentBaseProfileV1.address,
    abi: JSON.parse(contentBaseProfileV1.interface.format("json") as string),
  }

  await fs.writeFile(
    path.join(__dirname, "../..", "/abi/localhost/ContentBaseProfileV1.json"),
    JSON.stringify(data)
  )
}

main().catch((error) => {
  console.error("error: ", error)
  process.exitCode = 1
})
