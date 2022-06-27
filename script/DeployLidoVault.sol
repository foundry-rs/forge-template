// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import {Script} from "forge-std/Script.sol";

import {Steward} from "@omniprotocol/Steward.sol";

import {LidoVault} from "@contracts/vaults/LidoVault.sol";

contract DeployLidoVault is Script {
    LidoVault public vault;

    function run() public {
        address owner = vm.envAddress("ETH_FROM");
        vm.startBroadcast(owner);

        address steward = vm.envAddress("STEWARD");
        address stTOKEN = vm.envAddress("stTOKEN");
        string memory name = vm.envString("NAME");
        string memory symbol = vm.envString("SYMBOL");

        vault = new LidoVault(steward, stTOKEN, name, symbol, 1_000);

        Steward s = Steward(payable(steward));
        s.setPublicCapability(0x6e553f65, true);
        s.setPublicCapability(0xb460af94, true);

        vm.stopBroadcast();
    }
}
