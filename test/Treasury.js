const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");

/// Unit testing on the mainnet fork
describe("Treasury", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployTreasuryFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, user1] = await ethers.getSigners();

    const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";

    const usdc = await ethers.getContractAt("IERC20", USDC);

    const Treasury = await ethers.getContractFactory("Treasury");
    const treasury = await Treasury.deploy(USDC);

    return { treasury, usdc, USDC, owner, user1 };
  }

  describe("Deployment", function () {
    it("Should set the stable coin address", async function () {
      const { treasury, USDC } = await loadFixture(deployTreasuryFixture);

      expect(await treasury.stableCoin()).to.equal(USDC);
    });

    it("Should set the right owner", async function () {
      const { treasury, owner } = await loadFixture(deployTreasuryFixture);

      expect(await treasury.owner()).to.equal(owner.address);
    });
  });
});
