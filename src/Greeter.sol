pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Greeter is Ownable {
    string public greeting;
    address lastGreeter;

    function gm() onlyOwner {
        greeting = "gm";
        lastGreeter = msg.sender;
    }

    function greet(string memory _greeting) {
        greeting = _greeting;
        lastGreeter = msg.sender;
    }
}
