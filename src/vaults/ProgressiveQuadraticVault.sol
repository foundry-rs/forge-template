// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.13;

import {ERC4626, ERC20} from "@omniprotocol/mixins/ERC4626.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {Arctan} from "@contracts/libraries/Arctan.sol";

// https://forum.effectivealtruism.org/posts/tXavWgk8Xp6Avg8No/new-cooperation-mechanism-quadratic-funding-without-a
contract ProgressiveQuadraticVault is ERC4626, Arctan {
    using FixedPointMathLib for uint256;

    uint256 public velocity = 10_000;
    uint256 internal sumOfRoots = 0;

    constructor(
        address _asset,
        string memory _name,
        string memory _symbol,
        uint256 _velocity
    ) {
        __initERC4626(ERC20(_asset), _name, _symbol);
        velocity = _velocity;
    }

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }
    
    function commit(address to) external requiresAuth {
        uint256 commitment = ((totalSupply() * 100000000000) / 1727108826179) * arctan((sumOfRoots * velocity) / 10_000);
        uint256 dao = goodAmount(commitment);
        uint256 give = commitment - dao;

        require(asset.transfer(address(authority), dao), "TRANSFER_FAILED");
        require(asset.transfer(to, give), "TRANSFER_FAILED");
    }

    function commitmentOf(address account) public view returns (uint256) {
        return
            ((balanceOf[account] * 100000000000) / 1727108826179) *
            arctan((sumOfRoots * velocity) / 10_000);
    }

    function afterDeposit(uint256 assets, uint256 shares) internal override {
        super.afterDeposit(assets, shares);
        uint256 sharesAfter = balanceOf[msg.sender];
        unchecked {
            uint256 sharesBefore = sharesAfter - shares;
            sumOfRoots = sumOfRoots - sharesBefore.sqrt() + sharesAfter.sqrt();
        }
    }

    function beforeWithdraw(uint256 assets, uint256 shares) internal override {
        super.beforeWithdraw(assets, shares);
        uint256 sharesBefore = balanceOf[msg.sender];
        require(shares <= sharesBefore - commitmentOf(msg.sender), "INVARIANT");
        unchecked {
            uint256 sharesAfter = sharesBefore - shares;
            sumOfRoots = sumOfRoots - sharesBefore.sqrt() + sharesAfter.sqrt();
        }
    }
}
