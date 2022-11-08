import { ethers, upgrades } from "hardhat"
import path from "path"
import fs from "fs/promises"

async function main() {
  const PublishContract = await ethers.getContractFactory("ContentBasePublish")
  const publishNFTContract = await upgrades.deployProxy(PublishContract)

  await publishNFTContract.deployed()

  console.log("Publish Contract deployed to:", publishNFTContract.address)
  //Pull the address and ABI out, since that will be key in interacting with the smart contract later
  const data = {
    address: publishNFTContract.address,
    abi: JSON.parse(publishNFTContract.interface.format("json") as string),
  }

  await fs.writeFile(
    path.join(__dirname, "..", "/abi/PublishContract.json"),
    JSON.stringify(data)
  )
}

main().catch((error) => {
  console.error("error: ", error)
  process.exitCode = 1
})
