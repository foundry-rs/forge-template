// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import {console} from "forge-std/console.sol";
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {Steward} from "@omniprotocol/Steward.sol";

import {ElementalVault} from "@contracts/vaults/ElementalVault.sol";
import {EdenVault} from "@contracts/vaults/EdenVault.sol";

import {RockSolidEthPledge} from "@contracts/actors/RockSolidEthPledge.sol";

contract ElementalVaultTest is DSTestPlus {
    Steward public steward = new Steward(address(this), address(this));
    MockERC20 public stETH = new MockERC20("Lido Staked ETH", "stETH", 18);

    ElementalVault public rsETH =
        new ElementalVault(
            address(steward),
            address(stETH),
            "ROCK SOLID ETH",
            "rsETH",
            500
        );

    MockERC20 public ednEARTH =
        new MockERC20("EDEN EARTH DAO NOTE", "ednEARTH", 3);
    EdenVault public edenEARTH =
        new EdenVault(
            address(steward),
            address(ednEARTH),
            "EDEN EARTH DAO VAULT",
            "edenEARTH",
            250
        );

    RockSolidEthPledge public pledge =
        new RockSolidEthPledge(address(rsETH), address(edenEARTH));

    function testPledging(address caller, uint128 amount) public {
        hevm.assume(
            caller != address(this) && caller != address(0) && amount >= 1e3
        );
        stETH.mint(caller, amount);

        hevm.startPrank(caller);
        stETH.approve(address(pledge), amount);
        (uint256 shares, uint256 eden) = pledge.deposit(amount);
        // Redeem exactly what you put in
        assertEq(amount, rsETH.previewRedeem(shares));
        hevm.stopPrank();

        assertEq(shares, rsETH.balanceOf(caller));
        assertEq(eden, edenEARTH.balanceOf(caller));
    }
}
