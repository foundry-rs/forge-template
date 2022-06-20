// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import {GoodVault} from "@contracts/mixins/GoodVault.sol";

contract EdenVault is GoodVault {
    constructor(
        address _steward,
        address _asset,
        string memory _name,
        string memory _symbol,
        uint16 _good
    ) GoodVault(_steward, _asset, _name, _symbol, _good) {}

    function afterDeposit(uint256 assets, uint256 shares) internal override {
        super.afterDeposit(assets, shares);
        _mint(address(authority), goodAmount(shares));
    }
}
