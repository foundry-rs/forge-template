// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import {Script} from "forge-std/Script.sol";

import {Steward} from "@omniprotocol/Steward.sol";

import {RockSolidEthAuthority} from "@contracts/authorities/RockSolidEthAuthority.sol";
import {RockSolidEthPledge} from "@contracts/actors/RockSolidEthPledge.sol";
import {ElementalVault} from "@contracts/vaults/ElementalVault.sol";

contract DeployRockSolidEth is Script {
    function run() public {
        vm.startBroadcast();
        run(
            vm.envAddress("STEWARD"),
            vm.envAddress("stETH"),
            vm.envAddress("edenEARTH")
        );
        vm.stopBroadcast();
    }

    RockSolidEthAuthority public rsAuthority;
    ElementalVault public rsETH;
    RockSolidEthPledge public pledge;

    function run(
        address steward,
        address stETH,
        address edenEARTH
    ) public {
        rsETH = new ElementalVault(
            steward,
            stETH,
            "ROCK SOLID ETH",
            "rsETH",
            500
        );
        rsAuthority = new RockSolidEthAuthority(steward);

        Steward(payable(steward)).setTargetCustomAuthority(
            address(rsETH),
            rsAuthority
        );

        pledge = new RockSolidEthPledge(address(rsETH), edenEARTH);
    }
}
