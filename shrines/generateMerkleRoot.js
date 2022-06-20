const fs = require("fs");
const path = require("path");

const { getAddress, solidityKeccak256 } = require("ethers/lib/utils");
const keccak256 = require("keccak256");
const { MerkleTree } = require("merkletreejs");
const sumBy = require("lodash/sumBy");

const configPath = path.join(__dirname, `${process.argv[2]}.json`);
if (!fs.existsSync(configPath)) {
  console.error(`Missing config at ${configPath}.`);
  process.exit(1);
}

const { ledger = {} } = JSON.parse(fs.readFileSync(configPath).toString());
const recipients = Object.entries(ledger);
if (recipients.length === 0) {
  console.error(`Missing .ledger in ${configPath}`);
  process.exit(1);
}

const merkleRoot = new MerkleTree(
  recipients.map(([address, shares]) =>
    Buffer.from(
      solidityKeccak256(
        ["address", "uint256"],
        [getAddress(address), shares]
      ).slice(2),
      "hex"
    )
  ),
  keccak256,
  { sortPairs: true }
).getHexRoot();
console.info(`Generated Merkle root: ${merkleRoot}`);

const totalShares = sumBy(recipients, "1");

fs.writeFileSync(
  configPath,
  JSON.stringify({ ledger, totalShares, merkleRoot }, null, 4)
);
console.info(`Generated merkle tree and root saved to ${configPath}`);
