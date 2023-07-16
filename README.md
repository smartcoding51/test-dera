# Test Task for DERA Fundation

This repo contains smart contracts for test task assigned by DERA.

## Testing

This repo uses Hardhat framework for compilation, testing and deployment.

- Create an enviroment file named `.env` (copy .env.example) and fill the next enviroment variables

```
# Private key of a wallet address that will be used for deployment into the testnet or mainnet
PRIVATE_KEY=

# Env variable for gas report
REPORT_GAS=

# Alchemy api key for Ethereum goerli testnet
ALCHEMY_KEY_GOERLI=

# Alchemy api key for Ethereum mainnet
ALCHEMY_KEY_MAINNET=

# Etherscan api key for contract verification
ETHERSCAN_API_KEY=

```

- Hardhat Setup

```ml
npm i
npm run compile
npm run test
```

## Contract

### Goerli
| Name               | Address                                                                                                                           |
| :----------------- | :---------------------------------------------------------------------------------------------------------------------------------|
| Treasury           | [0x51983562bE6BFB09F77344956a938B385FBF1B17](https://goerli.etherscan.io/address/0x51983562bE6BFB09F77344956a938B385FBF1B17#code) |
