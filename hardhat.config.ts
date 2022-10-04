import path from 'path'
import dotenv from 'dotenv'
dotenv.config({ path: path.join(__dirname, '.env') })
import { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox'
import '@openzeppelin/hardhat-upgrades'

const { GOERLI_URL, PRIVATE_KEY, ETHERSCAN_API_KEY } = process.env

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.9',
    settings: {
      optimizer: {
        enabled: true,
        runs: 10,
      },
    },
  },
  networks: {
    goerli: {
      url: GOERLI_URL || '',
      accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
    },
    localhost: {
      allowUnlimitedContractSize: true,
    },
  },
  paths: {
    artifacts: './artifacts',
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },
  typechain: {
    outDir: './typechain-types',
  },
}

export default config
