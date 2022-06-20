// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import {Script} from "forge-std/Script.sol";

import {Factory} from "@omniprotocol/Factory.sol";
import {Omnitoken} from "@omniprotocol/Omnitoken.sol";

import {EdenVault} from "@contracts/vaults/EdenVault.sol";

contract DeployTribe is Script {
    function run() public {
        vm.startBroadcast();
        run(
            vm.envAddress("STEWARD"),
            vm.envAddress("FACTORY"),
            vm.envString("TRIBE")
        );
        vm.stopBroadcast();
    }

    Omnitoken public note;
    EdenVault public vault;

    function run(
        address steward,
        address factory,
        string memory tribe
    ) public {
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
        vault = new EdenVault(
            steward,
            note,
            string(abi.encodePacked("EDEN ", tribe, " DAO VAULT")),
            string(abi.encodePacked("eden", tribe))
        );
    }
}
