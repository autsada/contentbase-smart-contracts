import path from "path"
import dotenv from "dotenv"
dotenv.config({ path: path.join(__dirname, ".env") })
import { HardhatUserConfig } from "hardhat/config"
import "@nomicfoundation/hardhat-toolbox"
import "@openzeppelin/hardhat-upgrades"
import "hardhat-contract-sizer"

const { GOERLI_URL, DEV_PRIVATE_KEY, PRIVATE_KEY, ETHERSCAN_API_KEY } =
  process.env

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.9",
        settings: {
          optimizer: {
            enabled: true,
            runs: 20,
          },
        },
      },
    ],
  },
  networks: {
    goerli: {
      url: GOERLI_URL || "",
      accounts: DEV_PRIVATE_KEY !== undefined ? [DEV_PRIVATE_KEY] : [],
    },
    localhost: {
      allowUnlimitedContractSize: true,
    },
  },
  paths: {
    artifacts: "./artifacts",
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },
  typechain: {
    outDir: "./typechain-types",
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
  },
}

export default config
