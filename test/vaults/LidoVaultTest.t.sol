// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import {console} from "forge-std/console.sol";
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {Steward} from "@omniprotocol/Steward.sol";

import {RebaseVault} from "@contracts/vaults/RebaseVault.sol";

contract RebaseVaultTest is DSTestPlus {
    Steward public steward = new Steward(address(this));
    MockERC20 public stETH = new MockERC20("stETH", "stETH", 18);
    RebaseVault public edenETH =
        new RebaseVault(
            address(steward),
            address(stETH),
            "ROCK SOLID ETH",
            "edenETH",
            500
        );

    function setUp() public virtual {
        steward.setPublicCapability(0x6e553f65, true);
        steward.setPublicCapability(0xb460af94, true);
    }

    function testPledging(
        address caller,
        uint128 amount,
        uint64 yield
    ) public {
        hevm.assume(
            caller != address(this) &&
                caller != address(0) &&
                amount > 0 &&
                yield > 0 &&
                amount > yield
        );
        stETH.mint(caller, amount);
        hevm.startPrank(caller);

        stETH.approve(address(edenETH), amount);
        uint256 shares = edenETH.deposit(amount, caller);
        // Redeem exactly what you put in
        assertEq(amount, edenETH.previewRedeem(shares));

        stETH.mint(address(edenETH), yield);
        assertEq(amount, edenETH.previewRedeem(shares));

        edenETH.withdraw(amount, caller, caller);

        hevm.stopPrank();

        edenETH.commit(address(this));
        assertEq(
            stETH.balanceOf(address(this)) +
                stETH.balanceOf(address(edenETH.authority())),
            yield
        );
    }
}
