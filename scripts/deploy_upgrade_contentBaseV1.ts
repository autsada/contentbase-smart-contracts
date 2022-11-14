import { ethers, upgrades } from "hardhat"
import path from "path"
import fs from "fs/promises"

// import contentBaseV1Contract from "../abi/ContentBaseV1.json"

// async function main() {
//   const ContentBaseV2 = await ethers.getContractFactory("ContentBaseV2")
//   const contentBaseV2 = await upgrades.upgradeProxy(
//     contentBaseV1Contract.address,
//     ContentBaseV2
//   )

//   await contentBaseV2.deployed()

//   console.log("ContentBaseV2 deployed to:", contentBaseV2.address)
//   // Pull the address and ABI out, since that will be key in interacting with the smart contract later.
//   const data = {
//     address: contentBaseV2.address,
//     abi: JSON.parse(contentBaseV2.interface.format("json") as string),
//   }

//   await fs.writeFile(
//     path.join(__dirname, "..", "/abi/ContentBaseV2.json"),
//     JSON.stringify(data)
//   )

//   // For use in Subgraph project.
//   await fs.writeFile(
//     path.join(__dirname, "../..", "/subgraph/abis/ContentBaseV2.json"),
//     JSON.stringify(data.abi)
//   )
// }

// main().catch((error) => {
//   console.error("error: ", error)
//   process.exitCode = 1
// })
