// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import {GoodVault} from "@contracts/mixins/GoodVault.sol";

interface StakingOracle {
    function convertToShares(uint256 assets) external view returns (uint256);

    function convertToAssets(uint256 shares) external view returns (uint256);
}

contract StakeVault is GoodVault {
    StakingOracle internal oracle;

    constructor(
        address _steward,
        address _asset,
        string memory _name,
        string memory _symbol,
        uint16 _good,
        address _oracle
    ) GoodVault(_steward, _asset, _name, _symbol, _good) {
        oracle = StakingOracle(_oracle);
    }

    function convertToShares(uint256 assets)
        public
        view
        override
        returns (uint256)
    {
        return oracle.convertToShares(assets / totalAssets());
    }

    function convertToAssets(uint256 shares)
        public
        view
        override
        returns (uint256)
    {
        return oracle.convertToAssets(shares / totalSupply);
    }
}
