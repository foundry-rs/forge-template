// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import {console} from "forge-std/console.sol";
import {DSTestPlus} from "@solmate/test/utils/DSTestPlus.sol";

import {Steward} from "@omniprotocol/Steward.sol";
import {MockERC20} from "@omniprotocol/../test/mocks/MockERC20.sol";

import {RebaseVault} from "@carbon-coin/RebaseVault.sol";

contract RebaseVaultTest is DSTestPlus {
  Steward public steward = new Steward(address(this), address(this));
  MockERC20 public stETH = new MockERC20("stETH", "stETH", 18);
  RebaseVault public edenETH = new RebaseVault();

  function setUp() public {
    edenETH.initialize(
      address(steward),
      abi.encode(address(steward), address(stETH), "EDEN stETH", "eden-stETH")
    );
  }

  function testNameAndSymbol() public {
    assertEq(edenETH.name(), "EDEN stETH");
    assertEq(edenETH.symbol(), "eden-stETH");
  }

  function testCommittingAssetsFromYield(uint128 amount, uint64 yield) public {
    hevm.assume(amount > 0 && yield > 0);
    stETH.mint(address(this), amount);

    stETH.approve(address(edenETH), amount);
    uint256 shares = edenETH.deposit(amount, address(this));
    // Redeem exactly what you put in
    assertEq(amount, edenETH.previewRedeem(shares));

    stETH.mint(address(edenETH), yield);
    assertEq(amount, edenETH.previewRedeem(shares));
    // Redeem exactly what you put in
    assertEq(yield, edenETH.committedAssets());

    assertEq(yield, edenETH.withdrawCommittedAssets());
    assertEq(stETH.balanceOf(edenETH.beneficiary()), yield);
  }
}
