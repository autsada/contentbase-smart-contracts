import { ethers, upgrades } from "hardhat"
import path from "path"
import fs from "fs/promises"

const { DEV_PLATFORM_ADDRESS } = process.env

async function main() {
  // Deploy beacon.
  const Implementation = await ethers.getContractFactory("ContentBaseProfile")
  const beacon = await upgrades.deployBeacon(Implementation)
  await beacon.deployed()
  console.log("Profile beacon deployed to:", beacon.address)
  // Pull the address and ABI out, since that will be key in interacting with the smart contract later.
  const beaconData = {
    address: beacon.address,
    abi: JSON.parse(beacon.interface.format("json") as string),
  }
  await fs.writeFile(
    path.join(__dirname, "..", "/abi/ProfileBeacon.json"),
    JSON.stringify(beaconData)
  )

  // Deploy proxy
  // This is just to get an interface of the implementation contract for use on the client.
  const proxy = await upgrades.deployBeaconProxy(beacon, Implementation, [
    DEV_PLATFORM_ADDRESS, // Use this  as a platform owner address
    DEV_PLATFORM_ADDRESS, // Use this  as a factory contract address
    DEV_PLATFORM_ADDRESS, // Use this as an owner of the profile proxy
    { handle: "example", imageURI: "" },
  ])
  console.log("Profile proxy example deployed to:", proxy.address)
  // Pull the address and ABI out, since that will be key in interacting with the smart contract later.
  const proxyData = {
    address: proxy.address,
    abi: JSON.parse(proxy.interface.format("json") as string),
  }
  await fs.writeFile(
    path.join(__dirname, "..", "/abi/ProfileImplementation.json"),
    JSON.stringify(proxyData)
  )
  // Write abi to json for use in subgraph.
  await fs.writeFile(
    path.join(__dirname, "../..", "/subgraph/abis/ContentBaseProfile.json"),
    JSON.stringify(proxyData.abi)
  )

  // Deploy factory.
  const Factory = await ethers.getContractFactory("ContentBaseProfileFactory")
  // Profile factory requires beacon address.
  const factory = await upgrades.deployProxy(Factory, [beacon.address])
  await factory.deployed()
  console.log("Profile factory deployed to:", factory.address)
  // Pull the address and ABI out, since that will be key in interacting with the smart contract later.
  const factoryData = {
    address: factory.address,
    abi: JSON.parse(factory.interface.format("json") as string),
  }
  await fs.writeFile(
    path.join(__dirname, "..", "/abi/ProfileFactory.json"),
    JSON.stringify(factoryData)
  )
  // Write abi to json for use in subgraph.
  await fs.writeFile(
    path.join(
      __dirname,
      "../..",
      "/subgraph/abis/ContentBaseProfileFactory.json"
    ),
    JSON.stringify(factoryData.abi)
  )
}

main().catch((error) => {
  console.error("error: ", error)
  process.exitCode = 1
})
