import { ethers, upgrades } from "hardhat"
import path from "path"
import fs from "fs/promises"

async function main() {
  const LikeContract = await ethers.getContractFactory("ContentBaseLike")
  const likeContract = await upgrades.deployProxy(LikeContract)

  await likeContract.deployed()

  console.log("Like Contract deployed to:", likeContract.address)
  //Pull the address and ABI out, since that will be key in interacting with the smart contract later
  const data = {
    address: likeContract.address,
    abi: JSON.parse(likeContract.interface.format("json") as string),
  }

  await fs.writeFile(
    path.join(__dirname, "..", "/abi/LikeContract.json"),
    JSON.stringify(data)
  )
  // Write abi to json for use in subgraph.
  await fs.writeFile(
    path.join(__dirname, "../..", "/subgraph/abis/ContentBaseLike.json"),
    JSON.stringify(data.abi)
  )
}

main().catch((error) => {
  console.error("error: ", error)
  process.exitCode = 1
})
