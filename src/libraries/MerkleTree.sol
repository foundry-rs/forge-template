// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.13;

// solhint-disable no-inline-assembly
library MerkleTree {
    function generate(
        bytes32 leaf,
        uint8 treeHeightMinusOne,
        bytes32 randomness
    ) public pure returns (bytes32 root, bytes32[] memory proof) {
        bytes32 computedHash = leaf;
        proof = new bytes32[](treeHeightMinusOne);
        for (uint256 i = 0; i < treeHeightMinusOne; i++) {
            // use the randomness as the proof element
            proof[i] = randomness;

            // compute hash up the tree
            if (computedHash <= randomness) {
                // Hash(current computed hash + current element of the proof)
                assembly {
                    mstore(0x00, computedHash)
                    mstore(0x20, randomness)
                    computedHash := keccak256(0x00, 0x40)
                }
            } else {
                // Hash(current element of the proof + current computed hash)
                assembly {
                    mstore(0x00, randomness)
                    mstore(0x20, computedHash)
                    computedHash := keccak256(0x00, 0x40)
                }
            }

            // refresh randomness
            randomness = keccak256(abi.encodePacked(randomness));
        }
        root = computedHash;
    }
}
