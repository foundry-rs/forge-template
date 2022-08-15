// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

interface LidoStakedETH {
    function getWstETHByStETH(uint256 _stETHAmount)
        external
        view
        returns (uint256);

    function getStETHByWstETH(uint256 _wstETHAmount)
        external
        view
        returns (uint256);
}

contract LidoStakedETHOracle {
    LidoStakedETH internal token;

    constructor(address _token) {
        token = LidoStakedETH(_token);
    }

    function convertToAssets(uint256 shares) external view returns (uint256) {
        return token.getStETHByWstETH(shares);
    }

    function convertToShares(uint256 assets) external view returns (uint256) {
        return token.getWstETHByStETH(assets);
    }
}
