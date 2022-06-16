// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import {Script} from "forge-std/Script.sol";

import {Omnitoken} from "@omniprotocol/Omnitoken.sol";
import {Factory} from "@omniprotocol/Factory.sol";
import {Steward} from "@omniprotocol/Steward.sol";

contract BaseDeployment is Script {
  Omnitoken public EDEN;

  function run() public {
    Steward steward = Steward(payable(vm.envAddress("STEWARD")));

    EDEN = Omnitoken(
      Factory(vm.envAddress("FACTORY")).createToken(
        address(steward),
        "Eden Dao",
        "EDEN",
        3
      )
    );
  }
}
