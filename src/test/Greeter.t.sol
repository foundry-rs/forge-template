// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./utils/GreeterTest.sol";
import {Errors} from "../Greeter.sol";

contract Greet is GreeterTest {
    function testCannotGm() public {
        try alice.greet("gm") {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.CannotGm);
        }
    }

    function testCanSetGreeting() public {
        alice.greet("hi");
        assertEq(greeter.greeting(), "hi");
    }

    function testWorksForAllGreetings(string memory greeting) public {
        alice.greet(greeting);
        assertEq(greeter.greeting(), greeting);
    }
}

contract Gm is GreeterTest {
    function testOwnerCanGmOnGoodBlocks() public {
        hevm.roll(10);
        alice.gm();
        assertEq(greeter.greeting(), "gm");
    }

    function testOwnerCannotGmOnBadBlocks() public {
        hevm.roll(11);
        try alice.gm() {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.InvalidBlockNumber);
        }
    }

    function testNonOwnerCannotGm() public {
        try bob.gm() {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "Ownable: caller is not the owner");
        }
    }
}
