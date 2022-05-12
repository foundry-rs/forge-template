// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import {ERC4626, ERC20} from "@solmate/mixins/ERC4626.sol";

contract PermanentStorage is ERC4626 {
  constructor(address _carbonCoin)
    ERC4626(ERC20(_carbonCoin), "Frontier Carbon", "FRONTIER")
  {
    this;
  }

  function totalAssets() public view override returns (uint256) {
    return asset.balanceOf(address(this));
  }
}
