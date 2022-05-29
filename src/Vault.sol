// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import {ERC4626, ERC20} from "@omniprotocol/mixins/ERC4626.sol";
import {PublicGood} from "@omniprotocol/mixins/PublicGood.sol";
import {Stewarded} from "@omniprotocol/mixins/Stewarded.sol";

contract Vault is ERC4626, PublicGood, Stewarded {
  function _initialize(bytes memory _params) internal virtual override {
    (
      address _steward,
      address _asset,
      string memory _name,
      string memory _symbol
    ) = abi.decode(_params, (address, address, string, string));

    __initStewarded(_steward);
    __initERC4626(ERC20(_asset), _name, _symbol);
  }

  function totalAssets() public view virtual override returns (uint256) {
    return asset.balanceOf(address(this));
  }

  function withdrawToken(address token, uint256 assets)
    public
    virtual
    override
  {
    require(token != address(asset), "INVALID_ASSET");
    super.withdrawToken(token, assets);
  }
}
