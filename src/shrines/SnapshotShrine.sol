// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.11;

import {ERC20, SafeTransferLib} from "@omniprotocol/libraries/SafeTransferLib.sol";
import {ReentrancyGuard} from "@omniprotocol/mixins/ReentrancyGuard.sol";
import {Stewarded} from "@omniprotocol/mixins/Stewarded.sol";

import {ERC20Snapshot} from "../mixins/ERC20Snapshot.sol";

/// @title SnapshotShrine
/// @author zefram.eth, cyrusofeden.eth
/// A Champion can transfer their right to claim all future tokens offered to
/// the Champion to another address.
contract SnapshotShrine is Stewarded, ReentrancyGuard {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error NotAuthorized();

    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------

    using SafeTransferLib for ERC20;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Offer(address indexed sender, ERC20 indexed token, uint256 amount);
    event Claim(
        address recipient,
        uint256 indexed snapshotId,
        ERC20 indexed token,
        address indexed champion,
        uint256 claimedTokenAmount
    );
    event ClaimFromMetaShrine(SnapshotShrine indexed metaShrine);
    event TransferChampionStatus(address indexed champion, address recipient);
    event UpdateSnapshot(uint256 indexed snapshotId);

    /// -----------------------------------------------------------------------
    /// Structs
    /// -----------------------------------------------------------------------

    /// @param snapshotId The snapshotId
    /// @param token The ERC-20 token to be claimed
    /// @param champion The Champion address. If the Champion rights
    ///                 have been transferred, the tokens will be sent to its owner.

    struct ClaimInfo {
        uint256 snapshotId;
        ERC20 token;
        address champion;
    }

    /// @param metaShrine The shrine to claim from
    /// @param snapshotId The snapshotId
    /// @param token The ERC-20 token to be claimed
    struct MetaShrineClaimInfo {
        SnapshotShrine metaShrine;
        uint256 snapshotId;
        ERC20 token;
    }

    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    /// @notice Source
    ERC20Snapshot public source;

    /// @notice The current snapshotId
    uint256 public snapshotId;

    /// @notice snapshotId => (token => (champion => claimedTokens))
    mapping(uint256 => mapping(ERC20 => mapping(address => uint256)))
        public claimedTokens;

    /// @notice snapshotId => (token => offeredTokens)
    mapping(uint256 => mapping(ERC20 => uint256)) public offeredTokens;

    /// @notice champion => address
    mapping(address => address) public championClaimRightOwner;

    /// -----------------------------------------------------------------------
    /// Initialization
    /// -----------------------------------------------------------------------

    constructor(address _steward, address _source) {
        __initStewarded(_steward);

        source = ERC20Snapshot(_source);
        snapshotId = source.currentSnapshot();

        emit UpdateSnapshot(snapshotId);
    }

    // -----------------------------------------------------------------------
    /// User actions
    /// -----------------------------------------------------------------------

    // TODO: Update below notice to reflect structure
    /// @notice Offer ERC-20 tokens to the MerkleShrine and distribute them to Champions proportional
    /// to their shares in the Shrine. Callable by anyone.
    /// @param token The ERC-20 token being offered to the Shrine
    /// @param amount The amount of tokens to offer
    function offer(ERC20 token, uint256 amount) external {
        // distribute tokens to Champions
        offeredTokens[snapshotId][token] += amount;
        // transfer tokens from sender
        token.safeTransferFrom(msg.sender, address(this), amount);

        emit Offer(msg.sender, token, amount);
    }

    // TODO: Update below notice to reflect structure
    /// @notice A Champion or the owner of a Champion may call this to
    ///         claim their share of the tokens offered to this Shrine.
    /// Requires a Merkle proof to prove that the Champion is part of this Shrine's Merkle tree.
    // TODO: what kind of proof does it need now?
    /// Only callable by the champion (if the right was never transferred) or the owner
    /// (that the original champion transferred their rights to)
    /// @param claimInfo The info of the claim
    /// @return claimedTokenAmount The amount of tokens claimed
    function claim(address recipient, ClaimInfo calldata claimInfo)
        external
        returns (uint256 claimedTokenAmount)
    {
        // verify sender auth
        _verifyChampionOwnership(claimInfo.champion);

        // compute claimable amount
        uint256 championClaimedTokens = claimedTokens[claimInfo.snapshotId][
            claimInfo.token
        ][claimInfo.champion];
        claimedTokenAmount = _computeClaimableTokenAmount(
            claimInfo.snapshotId,
            claimInfo.token,
            source.totalSupplyAt(claimInfo.snapshotId),
            championClaimedTokens
        );

        // record total tokens claimed by the champion
        claimedTokens[claimInfo.snapshotId][claimInfo.token][
            claimInfo.champion
        ] = championClaimedTokens + claimedTokenAmount;

        // transfer tokens to the recipient
        claimInfo.token.safeTransfer(recipient, claimedTokenAmount);

        emit Claim(
            recipient,
            claimInfo.snapshotId,
            claimInfo.token,
            claimInfo.champion,
            claimedTokenAmount
        );
    }

    /// @notice A variant of {claim} that combines multiple claims for the
    ///         same Champion & snapshotId into a single call.
    /// @dev This is more efficient than {claimMultiple} since
    ///      it only checks Champion ownership & verifies Merkle proof once.
    function claimMultipleTokensForChampion(
        address recipient,
        uint256 snapshot,
        ERC20[] calldata tokenList,
        address champion,
        uint256 shares
    ) external returns (uint256[] memory claimedTokenAmountList) {
        // verify sender auth
        _verifyChampionOwnership(champion);

        claimedTokenAmountList = new uint256[](tokenList.length);
        for (uint256 i = 0; i < tokenList.length; i++) {
            // compute claimable amount
            uint256 championClaimedTokens = claimedTokens[snapshot][
                tokenList[i]
            ][champion];
            claimedTokenAmountList[i] = _computeClaimableTokenAmount(
                snapshot,
                tokenList[i],
                shares,
                championClaimedTokens
            );

            // record total tokens claimed by the champion
            claimedTokens[snapshot][tokenList[i]][champion] =
                championClaimedTokens +
                claimedTokenAmountList[i];
        }

        for (uint256 i = 0; i < tokenList.length; i++) {
            // transfer tokens to the recipient
            tokenList[i].safeTransfer(recipient, claimedTokenAmountList[i]);

            emit Claim(
                recipient,
                snapshot,
                tokenList[i],
                champion,
                claimedTokenAmountList[i]
            );
        }
    }

    // TODO: Update below notice to reflect structure
    /// @notice If this MerkleShrine is a Champion of another MerkleShrine (MetaShrine),
    ///         calling this can claim the tokens
    /// from the MetaShrine and distribute them to this Shrine's Champions. Callable by anyone.
    /// @param claimInfo The info of the claim
    /// @return claimedTokenAmount The amount of tokens claimed
    function claimFromMetaShrine(MetaShrineClaimInfo calldata claimInfo)
        external
        nonReentrant
        returns (uint256 claimedTokenAmount)
    {
        return _claimFromMetaShrine(claimInfo);
    }

    /// @notice A variant of {claimFromMetaShrine} that combines multiple claims into a single call.
    function claimMultipleFromMetaShrine(
        MetaShrineClaimInfo[] calldata claimInfoList
    ) external nonReentrant returns (uint256[] memory claimedTokenAmountList) {
        // claim and distribute tokens
        claimedTokenAmountList = new uint256[](claimInfoList.length);
        for (uint256 i = 0; i < claimInfoList.length; i++) {
            claimedTokenAmountList[i] = _claimFromMetaShrine(claimInfoList[i]);
        }
    }

    /// @notice Allows a champion to transfer their right to claim from this shrine to
    /// another address. The champion will effectively lose their shrine membership, so
    /// make sure the new owner is a trusted party.
    /// Only callable by the champion (if the right was never transferred) or the owner
    /// (that the original champion transferred their rights to)
    /// @param champion The champion whose claim rights will be transferred away
    /// @param newOwner The address that will receive all rights of the champion
    function transferChampionClaimRight(address champion, address newOwner)
        external
    {
        // verify sender auth
        _verifyChampionOwnership(champion);

        championClaimRightOwner[champion] = newOwner;
        emit TransferChampionStatus(champion, newOwner);
    }

    /// -----------------------------------------------------------------------
    /// Getters
    /// -----------------------------------------------------------------------

    /// @notice Computes the amount of a particular ERC-20 token claimable by a Champion from
    /// @param snapshot The snapshotId
    /// @param token The ERC-20 token to be claimed
    /// @param champion The Champion address
    /// @param shares The share amount of the Champion
    /// @return claimableTokenAmount The amount of tokens claimable
    function computeClaimableTokenAmount(
        uint256 snapshot,
        ERC20 token,
        address champion,
        uint256 shares
    ) public view returns (uint256 claimableTokenAmount) {
        claimableTokenAmount = _computeClaimableTokenAmount(
            snapshot,
            token,
            shares,
            claimedTokens[snapshot][token][champion]
        );
    }

    /// @notice The Shrine Guardian's address (same as the contract owner)
    /// @return The Guardian's address
    function guardian() external view returns (address) {
        return owner;
    }

    /// -----------------------------------------------------------------------
    /// Guardian actions
    /// -----------------------------------------------------------------------

    function updateSnapshot() external {
        snapshotId = source.incrementSnapshot();
        emit UpdateSnapshot(snapshotId);
    }

    /// -----------------------------------------------------------------------
    /// Internal utilities
    /// -----------------------------------------------------------------------

    /// @dev Reverts if the sender isn't the champion or does not own the champion claim right
    /// @param champion The champion whose ownership will be verified
    function _verifyChampionOwnership(address champion) internal view {
        {
            address rightsOwner = championClaimRightOwner[champion];
            if (
                // claim right not transferred, sender should be the champion
                (rightsOwner == address(0) && msg.sender != champion) ||
                // claim right transferred, sender should be the owner
                msg.sender != rightsOwner
            ) {
                revert NotAuthorized();
            }
        }
    }

    /// @dev See {computeClaimableTokenAmount}
    function _computeClaimableTokenAmount(
        uint256 snapshot,
        ERC20 token,
        uint256 shares,
        uint256 claimedTokenAmount
    ) internal view returns (uint256 claimableTokenAmount) {
        uint256 totalShares = source.totalSupplyAt(snapshot);
        uint256 offeredTokenAmount = (offeredTokens[snapshot][token] * shares) /
            totalShares;

        // rounding may cause (offeredTokenAmount < claimedTokenAmount)
        // don't want to revert because of it
        claimableTokenAmount = offeredTokenAmount >= claimedTokenAmount
            ? offeredTokenAmount - claimedTokenAmount
            : 0;
    }

    /// @dev See {claimFromMetaShrine}
    function _claimFromMetaShrine(MetaShrineClaimInfo calldata claimInfo)
        internal
        returns (uint256 claimedTokenAmount)
    {
        // claim tokens from the meta shrine
        uint256 beforeBalance = claimInfo.token.balanceOf(address(this));
        claimInfo.metaShrine.claim(
            address(this),
            ClaimInfo({
                snapshotId: claimInfo.snapshotId,
                token: claimInfo.token,
                champion: address(this)
            })
        );
        claimedTokenAmount =
            claimInfo.token.balanceOf(address(this)) -
            beforeBalance;

        // distribute tokens to Champions
        offeredTokens[snapshotId][claimInfo.token] += claimedTokenAmount;

        emit Offer(
            address(claimInfo.metaShrine),
            claimInfo.token,
            claimedTokenAmount
        );
        emit ClaimFromMetaShrine(claimInfo.metaShrine);
    }
}
