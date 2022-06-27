const fs = require("fs");
const path = require("path");

const { getAddress, solidityKeccak256 } = require("ethers/lib/utils");
const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");

const configPath = path.join(__dirname, `${process.argv[2]}.json`);
if (!fs.existsSync(configPath)) {
  console.error(`Missing config file at ${configPath}`);
  process.exit(1);
}

const config = JSON.parse(fs.readFileSync(configPath).toString());
const ledger = Object.entries(config.ledger ?? {});

config.totalShares = ledger.reduce((sum, [, shares]) => sum + shares, 0);
if (config.totalShares === 0) {
  console.error(`Invalid .ledger in ${configPath}`);
  process.exit(1);
}

config.merkleRoot = new MerkleTree(
  ledger.map(function generateLeaf([address, shares]) {
    const leaf = solidityKeccak256(
      ["address", "uint256"],
      [getAddress(address), shares]
    ).slice(2);
    return Buffer.from(leaf, "hex");
  }),
  keccak256,
  { sortPairs: true }
).getHexRoot();
console.info(`Generated merkle root: ${config.merkleRoot}`);

fs.writeFileSync(configPath, JSON.stringify(config, null, 4));
console.info(`Generated merkle tree and root saved to ${configPath}`);
