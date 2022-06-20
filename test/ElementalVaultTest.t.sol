// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import {console} from "forge-std/console.sol";
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {Steward} from "@omniprotocol/Steward.sol";

import {ElementalVault} from "@contracts/vaults/ElementalVault.sol";

contract ElementalVaultTest is DSTestPlus {
    Steward public steward = new Steward(address(this), address(this));
    MockERC20 public stETH = new MockERC20("stETH", "stETH", 18);
    ElementalVault public rsETH =
        new ElementalVault(
            address(steward),
            address(stETH),
            "ROCK SOLID ETH",
            "rsETH",
            500
        );

    function testPledging(
        address caller,
        uint128 amount,
        uint64 yield
    ) public {
        hevm.assume(
            caller != address(this) && amount > 0 && yield > 0 && amount > yield
        );
        stETH.mint(caller, amount);
        hevm.startPrank(caller);

        stETH.approve(address(rsETH), amount);
        uint256 shares = rsETH.deposit(amount, caller);
        // Redeem exactly what you put in
        assertEq(amount, rsETH.previewRedeem(shares));

        stETH.mint(address(rsETH), yield);
        assertEq(amount, rsETH.previewRedeem(shares));
        assertEq(yield, rsETH.pledgeAssets());

        hevm.stopPrank();

        rsETH.transferPledge(address(this));
        assertEq(
            stETH.balanceOf(address(this)) +
                stETH.balanceOf(address(rsETH.authority())),
            yield
        );
    }
}
