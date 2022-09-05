import path from 'path'
import dotenv from 'dotenv'
dotenv.config({ path: path.join(__dirname, '.env') })
import { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox'
import '@openzeppelin/hardhat-upgrades'

const config: HardhatUserConfig = {
  solidity: '0.8.9',
  networks: {
    // ropsten: {
    //   url: process.env.ROPSTEN_URL || "",
    //   accounts:
    //     process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    // },
    localhost: {
      allowUnlimitedContractSize: true,
    },
  },
  paths: {
    artifacts: './artifacts',
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  typechain: {
    outDir: './typechain-types',
  },
}

export default config
