import { ethers, upgrades } from "hardhat"
import path from "path"
import fs from "fs/promises"

async function main() {
  const CommentNFTContract = await ethers.getContractFactory("CommentNFT")
  const commentNFTContract = await upgrades.deployProxy(CommentNFTContract)

  await commentNFTContract.deployed()

  console.log("CommentNFTContract deployed to:", commentNFTContract.address)
  //Pull the address and ABI out, since that will be key in interacting with the smart contract later
  const data = {
    address: commentNFTContract.address,
    abi: JSON.parse(commentNFTContract.interface.format("json") as string),
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
