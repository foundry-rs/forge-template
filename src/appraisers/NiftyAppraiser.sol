// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.13;

import {ERC20, SafeTransferLib} from "@omniprotocol/libraries/SafeTransferLib.sol";
import {Pausable} from "@omniprotocol/mixins/Pausable.sol";
import {Stewarded} from "@omniprotocol/mixins/Stewarded.sol";

import {EIP2612Storage} from "@contracts/mixins/EIP2612Storage.sol";

contract NiftyAppraiser is EIP2612Storage, Pausable, Stewarded {
    using SafeTransferLib for ERC20;

    ERC20 public rewardToken;
    mapping(bytes32 => uint256) public rewardOf;

    constructor(address _steward, address _rewardToken) {
        __initEIP2612("NiftyAppraiser", "1");
        __initStewarded(_steward);
        rewardToken = ERC20(_rewardToken);
    }

    event Appraisal(
        address indexed signer,
        address indexed nifty,
        uint256 id,
        uint256 value
    );

    function claim(
        address signer,
        address nifty,
        uint256 id,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public returns (bytes32 sighash) {
        require(deadline >= block.timestamp, "DEADLINE_EXPIRED");

        sighash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256(
                            "Appraisal(address signer,address nifty,uint256 id,uint256 value,uint256 deadline)"
                        ),
                        signer,
                        nifty,
                        id,
                        value,
                        deadline
                    )
                )
            )
        );
        address recoveredAddress = ecrecover(sighash, v, r, s);

        require(
            recoveredAddress != address(0) &&
                recoveredAddress == signer &&
                isAuthorized(recoveredAddress, msg.sig),
            "INVALID_SIGNER"
        );
        require(rewardOf[sighash] == 0, "INVALID_SIGNATURE");

        rewardOf[sighash] = value;
        emit Appraisal(signer, nifty, id, value);

        rewardToken.safeTransfer(msg.sender, value);
    }
}
