// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import {Stewarded} from "@omniprotocol/mixins/Stewarded.sol";
import {ERC4626, ERC20} from "@omniprotocol/mixins/ERC4626.sol";

import {ERC20Snapshot} from "./ERC20Snapshot.sol";

contract GoodVault is ERC4626, ERC20Snapshot, Stewarded {
    uint16 public good;
    event GoodUpdated(uint16 good);

    constructor(
        address _steward,
        address _asset,
        string memory _name,
        string memory _symbol,
        uint16 _good
    ) {
        __initStewarded(_steward);
        __initERC4626(ERC20(_asset), _name, _symbol);

        require(_good <= 1_000, "TOO_GOOD");
        good = _good;
        emit GoodUpdated(_good);
    }

    function setGood(uint16 _good) external requiresAuth {
        require(_good <= 1_000, "TOO_GOOD");
        good = _good;
        emit GoodUpdated(_good);
    }

    function goodAmount(uint256 amount) public view returns (uint256) {
        return (amount * good) / 10_000;
    }

    // For accidentally sent tokens, only callable by authorized users
    function withdrawToken(
        address token,
        address to,
        uint256 assets
    ) public virtual override {
        require(token != address(asset), "UNAUTHORIZED");
        super.withdrawToken(token, to, assets);
    }

    function totalAssets() public view virtual override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function _mint(address to, uint256 amount)
        internal
        virtual
        override(ERC20, ERC20Snapshot)
    {
        super._mint(to, amount);
    }

    function _burn(address from, uint256 amount)
        internal
        virtual
        override(ERC20, ERC20Snapshot)
    {
        super._burn(from, amount);
    }

    function transfer(address to, uint256 amount)
        public
        virtual
        override(ERC20, ERC20Snapshot)
        returns (bool)
    {
        return super.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override(ERC20, ERC20Snapshot) returns (bool) {
        return super.transferFrom(from, to, amount);
    }

    function maxDeposit(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return asset.balanceOf(account);
    }

    function maxMint(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return previewDeposit(maxDeposit(account));
    }
}
