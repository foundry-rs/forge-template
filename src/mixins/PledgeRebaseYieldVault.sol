// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {ERC20, GoodVault} from "./GoodVault.sol";

contract PledgeRebaseYieldVault is GoodVault {
    constructor(
        address _steward,
        address _asset,
        string memory _name,
        string memory _symbol,
        uint16 _good
    ) GoodVault(_steward, _asset, _name, _symbol, _good) {}

    // Keep track of total deposits to use instead of total assets for withdrawals
    uint256 public totalDeposits;

    function afterDeposit(uint256 assets, uint256 shares)
        internal
        virtual
        override
    {
        super.afterDeposit(assets, shares);
        // Cannot realistically overflow
        unchecked {
            totalDeposits += assets;
        }
    }

    function beforeWithdraw(uint256 assets, uint256 shares)
        internal
        virtual
        override
    {
        super.beforeWithdraw(assets, shares);
        // Cannot realistically underflow
        unchecked {
            totalDeposits -= assets;
        }
    }

    function pledgeAssets() public view returns (uint256) {
        return totalAssets() - totalDeposits;
    }

    function transferPledge(address to) external requiresAuth returns (bool) {
        address dao = address(authority);
        uint256 goodAssets = pledgeAssets();
        uint256 daoAssets = goodAmount(goodAssets);

        require(asset.transfer(dao, daoAssets), "TRANSFER_FAILED");
        require(asset.transfer(to, goodAssets - daoAssets), "TRANSFER_FAILED");

        return true;
    }

    function convertToShares(uint256 assets)
        public
        pure
        override
        returns (uint256)
    {
        return assets;
    }

    function convertToAssets(uint256 shares)
        public
        pure
        override
        returns (uint256)
    {
        return shares;
    }

    function previewMint(uint256 shares)
        public
        pure
        override
        returns (uint256)
    {
        return shares;
    }

    function previewDeposit(uint256 assets)
        public
        pure
        override
        returns (uint256)
    {
        return assets;
    }

    function previewRedeem(uint256 shares)
        public
        pure
        override
        returns (uint256)
    {
        return shares;
    }

    function previewWithdraw(uint256 assets)
        public
        pure
        override
        returns (uint256)
    {
        return assets;
    }

    function maxWithdraw(address account)
        public
        view
        override
        returns (uint256)
    {
        return balanceOf[account];
    }
}
