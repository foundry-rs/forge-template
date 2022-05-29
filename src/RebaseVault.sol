// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import {Vault} from "./Vault.sol";

contract RebaseVault is Vault {
  uint256 public debt;

  function afterDeposit(uint256 assets, uint256) internal override {
    debt += assets;
  }

  function beforeWithdraw(uint256 assets, uint256) internal override {
    debt -= assets;
  }

  function totalAssets() public view override returns (uint256) {
    return debt;
  }

  function committedAssets() public view returns (uint256) {
    return asset.balanceOf(address(this)) - debt;
  }

  function withdrawCommittedAssets()
    public
    requiresAuth
    returns (uint256 amount)
  {
    amount = committedAssets();
    if (amount != 0) {
      asset.transfer(address(authority), amount);
    }
  }
}
