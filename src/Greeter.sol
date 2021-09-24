// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

library Errors {
    string internal constant InvalidBlockNumber =
        "invalid block number, please wait";
    string internal constant CannotGm = "cannot greet with gm";
}

contract Greeter is Ownable {
    string public greeting;

    function gm() public onlyOwner {
        require(block.number % 10 == 0, Errors.InvalidBlockNumber);
        greeting = "gm";
    }

    function greet(string memory _greeting) public {
        require(
            keccak256(abi.encodePacked(_greeting)) != keccak256("gm"),
            Errors.CannotGm
        );
        greeting = _greeting;
    }
}
