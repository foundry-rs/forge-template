// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
import "ds-test/test.sol";

import "./Hevm.sol";

contract GreeterUser {
    Greeter internal greeter;

    constructor (address greeter) {
        greeter = Greeter(greeter);
    }

    function greet(string memory greeting) {
        greeter.greet(greeting);
    }

    function gm() {
        greeter.gm();
    }
}

contract GreeterTest is DSTest {
    Hevm internal constant hevm =
        Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    // contracts
    Greeter internal greeter;

    // users
    User internal alice;
    User internal bob;

    function setUp() public virtual {
        greeter = new Greeter();
        alice = new User(address(greeter));
        bob = new User(address(greeter));
        greeter.transferOwnership(address(alice));
    }
}
