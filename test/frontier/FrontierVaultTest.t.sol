// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import {console} from "forge-std/console.sol";
import {DSTestPlus} from "@solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";

import {Steward} from "@omniprotocol/Steward.sol";

import {FrontierVault} from "@contracts/frontier/FrontierVault.sol";

contract FrontierVaultTest is DSTestPlus {
  Steward public steward = new Steward(address(this), address(this));
  MockERC20 public stETH = new MockERC20("stETH", "stETH", 18);
  FrontierVault public vault =
    new FrontierVault(address(steward), address(stETH), 0);

  function testCommittingAssetsFromYield(uint128 amount, uint64 yield) public {
    hevm.assume(amount > 0 && yield > 0);
    stETH.mint(address(this), amount);

    stETH.approve(address(vault), amount);
    uint256 shares = vault.deposit(amount, address(this));
    // Redeem exactly what you put in
    assertEq(amount, vault.previewRedeem(shares));

    stETH.mint(address(vault), yield);
    assertEq(amount, vault.previewRedeem(shares));
    // Redeem exactly what you put in
    assertEq(yield, vault.committedAssets());

    address beneficiary = hevm.addr(42);
    vault.withdrawToken(address(stETH), beneficiary, yield);
    assertEq(stETH.balanceOf(beneficiary), yield);
  }
}
