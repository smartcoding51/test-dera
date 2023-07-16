// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  // USDC token address for Goerli testnet
  const USDC = "0x07865c6E87B9F70255377e024ace6630C1Eaa37F";

  const treasury = await hre.ethers.deployContract("Treasury", [USDC]);

  await treasury.waitForDeployment();

  console.log(`Treasury deployed to ${treasury.target}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
