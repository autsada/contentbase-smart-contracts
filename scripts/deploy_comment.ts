import { ethers, upgrades } from "hardhat"
import path from "path"
import fs from "fs/promises"

async function main() {
  const CommentContract = await ethers.getContractFactory("ContentBaseComment")
  const commentContract = await upgrades.deployProxy(CommentContract)

  await commentContract.deployed()

  console.log("Comment Contract deployed to:", commentContract.address)
  //Pull the address and ABI out, since that will be key in interacting with the smart contract later
  const data = {
    address: commentContract.address,
    abi: JSON.parse(commentContract.interface.format("json") as string),
  }

  await fs.writeFile(
    path.join(__dirname, "..", "/abi/CommentContract.json"),
    JSON.stringify(data)
  )
}

main().catch((error) => {
  console.error("error: ", error)
  process.exitCode = 1
})
