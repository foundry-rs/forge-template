// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import {PledgeRebaseYieldVault} from "@contracts/mixins/PledgeRebaseYieldVault.sol";

contract ElementalVault is PledgeRebaseYieldVault {
    constructor(
        address _steward,
        address _asset,
        string memory _name,
        string memory _symbol,
        uint16 _good
    ) PledgeRebaseYieldVault(_steward, _asset, _name, _symbol, _good) {}

    function beforeWithdraw(uint256 assets, uint256 shares)
        internal
        override
        requiresAuth // steward authorizes withdrawals
    {
        super.beforeWithdraw(assets, shares);
    }
}
