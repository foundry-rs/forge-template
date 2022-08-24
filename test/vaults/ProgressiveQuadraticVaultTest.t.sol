// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import {console} from "forge-std/console.sol";
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {Steward} from "@omniprotocol/Steward.sol";

import {ProgressiveQuadraticVault} from "@contracts/vaults/ProgressiveQuadraticVault.sol";

contract ProgressiveQuadraticVaultTest is DSTestPlus {
    Steward public steward = new Steward(address(this));
    MockERC20 public usdc = new MockERC20("usdc", "usdc", 18);
    ProgressiveQuadraticVault public qf =
        new ProgressiveQuadraticVault(
            address(usdc),
            "Net Zero Commitment",
            "ZERO",
            10_000
        );

    function setUp() public virtual {
        steward.setPublicCapability(0x6e553f65, true);
        steward.setPublicCapability(0xb460af94, true);
    }

    function testPledging(address caller, uint128 amount) public {
        hevm.assume(
            caller != address(this) && caller != address(0) && amount > 0
        );
        usdc.mint(caller, amount);
        hevm.startPrank(caller);

        usdc.approve(address(qf), amount);
        uint256 shares = qf.deposit(amount, caller);
        // Redeem exactly what you put in
        assertEq(amount, qf.previewRedeem(shares));
    }
}
