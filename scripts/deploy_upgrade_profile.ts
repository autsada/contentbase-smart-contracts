import { ethers, upgrades } from "hardhat"
import path from "path"
import fs from "fs/promises"

import BeaconContract from "../abi/ProfileBeacon.json"

const { DEV_PLATFORM_ADDRESS } = process.env

async function main() {
  // Deploy beacon.
  const Implementation = await ethers.getContractFactory("ProfileContract")
  const beacon = await upgrades.upgradeBeacon(
    BeaconContract.address,
    Implementation
  )
  await beacon.deployed()
  console.log("Profile beacon deployed to:", beacon.address)
  //Pull the address and ABI out, since that will be key in interacting with the smart contract later
  const beaconData = {
    address: beacon.address,
    abi: JSON.parse(beacon.interface.format("json") as string),
  }
  await fs.writeFile(
    path.join(__dirname, "..", "/abi/ProfileBeacon.json"),
    JSON.stringify(beaconData)
  )

  // Deploy proxy, this is just to get an interface of the implementation contract for use.
  const proxy = await upgrades.deployBeaconProxy(beacon, Implementation, [
    DEV_PLATFORM_ADDRESS,
    DEV_PLATFORM_ADDRESS, // Use this  as a factory contract address
    DEV_PLATFORM_ADDRESS, // Use this as an owner of the profile proxy
    DEV_PLATFORM_ADDRESS, // Use this as a follow proxy
    DEV_PLATFORM_ADDRESS, // Use this as a publish proxy
    DEV_PLATFORM_ADDRESS, // Use this as a comment proxy
    { handle: "example", imageURI: "" },
  ])
  console.log("Profile proxy example deployed to:", proxy.address)
  //Pull the address and ABI out, since that will be key in interacting with the smart contract later
  const proxyData = {
    address: proxy.address,
    abi: JSON.parse(proxy.interface.format("json") as string),
  }
  await fs.writeFile(
    path.join(__dirname, "..", "/abi/ProfileImplementation.json"),
    JSON.stringify(proxyData)
  )
}

main().catch((error) => {
  console.error("error: ", error)
  process.exitCode = 1
})
