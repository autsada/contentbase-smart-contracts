import { ethers, upgrades } from "hardhat"
import path from "path"
import fs from "fs/promises"

async function main() {
  const ContentBaseV1 = await ethers.getContractFactory("ContentBaseV1")
  const contentBaseV1 = await upgrades.deployProxy(ContentBaseV1)

  await contentBaseV1.deployed()

  console.log("ContentBaseV1 deployed to:", contentBaseV1.address)
  // Pull the address and ABI out, since that will be key in interacting with the smart contract later.
  const data = {
    address: contentBaseV1.address,
    abi: JSON.parse(contentBaseV1.interface.format("json") as string),
  }

  await fs.writeFile(
    path.join(__dirname, "..", "/abi/ContentBaseV1.json"),
    JSON.stringify(data)
  )

  // For use in Subgraph project.
  await fs.writeFile(
    path.join(__dirname, "../..", "/subgraph/abis/ContentBaseV1.json"),
    JSON.stringify(data.abi)
  )
}

main().catch((error) => {
  console.error("error: ", error)
  process.exitCode = 1
})
