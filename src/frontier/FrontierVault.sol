// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import {Stewarded} from "@omniprotocol/mixins/Stewarded.sol";
import {ERC4626, ERC20, FixedPointMathLib} from "@omniprotocol/mixins/ERC4626.sol";

contract FrontierVault is ERC4626, Stewarded {
  using FixedPointMathLib for uint256;

  uint64 public immutable timelock;
  uint256 public deposits;

  constructor(
    address _steward,
    address _stETH,
    uint64 _timelock
  ) {
    __initStewarded(_steward);
    __initERC4626(ERC20(_stETH), "Frontier Climate Vault", "FRONTIER");

    // First day of the year 2030 (Spring Equinox, March 20th, 2030, 6:51 UTC)
    timelock = _timelock != 0 ? _timelock : 1900219860;
  }

  function totalAssets() public view override returns (uint256) {
    return asset.balanceOf(address(this));
  }

  function committedAssets() public view returns (uint256) {
    return totalAssets() - deposits;
  }

  function withdrawToken(
    address token,
    address to,
    uint256 assets
  ) public virtual override {
    require(
      token != address(asset) || assets <= committedAssets(),
      "UNAUTHORIZED"
    );
    super.withdrawToken(token, to, assets);
  }

  function afterDeposit(uint256 assets, uint256) internal override {
    unchecked {
      deposits += assets;
    }
  }

  function beforeWithdraw(uint256 assets, uint256) internal override {
    require(timelock <= block.timestamp, "UNAUTHORIZED");
    unchecked {
      deposits -= assets;
    }
  }

  function previewWithdraw(uint256 assets)
    public
    view
    override
    returns (uint256)
  {
    uint256 supply = totalSupply;
    return supply == 0 ? assets : assets.mulDivUp(supply, deposits);
  }

  function previewRedeem(uint256 shares)
    public
    view
    override
    returns (uint256)
  {
    uint256 supply = totalSupply;
    return supply == 0 ? shares : shares.mulDivDown(deposits, supply);
  }

  function maxDeposit(address owner) public view override returns (uint256) {
    return asset.balanceOf(owner);
  }

  function maxMint(address owner) public view override returns (uint256) {
    return previewDeposit(maxDeposit(owner));
  }

  function maxWithdraw(address owner) public view override returns (uint256) {
    return previewRedeem(maxRedeem(owner));
  }
}
