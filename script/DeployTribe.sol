// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import {Script} from "forge-std/Script.sol";

import {Factory} from "@omniprotocol/Factory.sol";
import {Omnitoken} from "@omniprotocol/Omnitoken.sol";

import {ImpactVault} from "@contracts/vaults/ImpactVault.sol";

contract DeployTribe is Script {
    Omnitoken public note;
    ImpactVault public vault;

    function run() public {
        address owner = vm.envAddress("ETH_FROM");
        vm.startBroadcast(owner);

        address steward = vm.envAddress("STEWARD");
        address factory = vm.envAddress("FACTORY");
        string memory tribe = vm.envString("TRIBE");

        // An edn token
        note = Omnitoken(
            Factory(factory).createToken(
                steward,
                string(abi.encodePacked("EDEN ", tribe, " DAO NOTE")),
                string(abi.encodePacked("edn", tribe)),
                3
            )
        );
        // A vault for their edn
        vault = new ImpactVault(
            steward,
            address(note),
            string(abi.encodePacked("EDEN ", tribe, " DAO VAULT")),
            string(abi.encodePacked("eden", tribe)),
            500
        );

        vm.stopBroadcast();
    }
}
