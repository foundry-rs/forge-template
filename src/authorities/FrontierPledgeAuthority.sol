// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.13;

import {Authority} from "@omniprotocol/mixins/auth/Auth.sol";
import {Stewarded} from "@omniprotocol/mixins/Stewarded.sol";

interface Vault {
    function totalAssets() external view returns (uint256);
}

contract FrontierPledgeAuthority is Stewarded, Authority {
    // First day of the year 2030 (Spring Equinox, March 20th, 2030, 6:51 UTC)
    uint64 public unlockedAt = 1900219860;

    constructor(address _steward) {
        __initStewarded(_steward);
    }

    function unlock() external requiresAuth {
        unlockedAt = 0;
    }

    function canCall(
        address user,
        address target,
        bytes4 functionSig
    ) external view returns (bool) {
        // beforeWithdraw(uint256, uint256)
        if (functionSig != 0x6f7e9bd5) {
            return authority.canCall(user, target, functionSig);
        }
        if (Vault(target).totalAssets() < 10_000 ether) {
            return true;
        }
        return unlockedAt <= block.timestamp;
    }
}
