// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import {ERC20, GoodVault} from "@contracts/mixins/GoodVault.sol";

contract LidoVault is GoodVault {
    constructor(
        address _steward,
        address _asset,
        string memory _name,
        string memory _symbol,
        uint16 _good
    ) GoodVault(_steward, _asset, _name, _symbol, _good) {}

    uint256 public totalDeposits;

    function afterDeposit(uint256 assets, uint256 shares)
        internal
        virtual
        override
    {
        super.afterDeposit(assets, shares);
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
        unchecked {
            totalDeposits -= assets;
        }
    }

    function commit(address to) external requiresAuth {
        uint256 harvest = totalAssets() - totalDeposits;
        uint256 dao = goodAmount(harvest);
        uint256 give = harvest - dao;

        require(asset.transfer(address(authority), dao), "TRANSFER_FAILED");
        require(asset.transfer(to, give), "TRANSFER_FAILED");
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
