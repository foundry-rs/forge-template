// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

interface Passport {
  function mint(address to) external payable returns (uint256 id);
}

interface Note {
  function balanceOf(address owner) external view returns (uint256 amount);

  function decimals() external view returns (uint8);
}

contract FrontierPassport {
  Passport public passport;
  Note public note;

  constructor(address _passport, address _note) {
    passport = Passport(_passport);
    note = Note(_note);
  }

  function canClaim() public view returns (bool) {
    return note.balanceOf(msg.sender) >= 10**(note.decimals() - 2);
  }

  function claim() public returns (uint256) {
    require(canClaim(), "UNAUTHORIZED");
    return passport.mint(msg.sender);
  }
}
