// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

interface Mintable {
    function mint(address to, uint256 amount) external;
}

interface IERC20 {
    function decimals() external view returns (uint8);

    function transferFrom(
        address sender,
        address receiver,
        uint256 amount
    ) external returns (bool);
}

interface Vault is IERC20 {
    function asset() external view returns (IERC20 underlying);

    function approve(address spender, uint256 amount) external;

    function deposit(uint256 assets, address receiver)
        external
        view
        returns (uint256 shares);
}

contract RockSolidEthPledge {
    Vault public immutable rsETH;
    Vault public immutable edenEARTH;

    constructor(address _rsETH, address _edenEARTH) {
        rsETH = Vault(_rsETH);
        edenEARTH = Vault(_edenEARTH);

        rsETH.approve(address(rsETH.asset()), type(uint256).max);
        edenEARTH.approve(address(edenEARTH.asset()), type(uint256).max);
    }

    function deposit(uint256 stETH)
        public
        returns (uint256 shares, uint256 eden)
    {
        require(
            rsETH.asset().transferFrom(msg.sender, address(this), stETH),
            "TRANSFER_FROM_FAILED"
        );
        shares = rsETH.deposit(stETH, msg.sender);

        uint256 edn = (stETH * 10**edenEARTH.decimals()) /
            (10 * 10**rsETH.decimals());
        Mintable(address(edenEARTH.asset())).mint(address(this), edn);

        eden = edenEARTH.deposit(edn, msg.sender);

        return (shares, eden);
    }
}
