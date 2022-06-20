// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.11;

import {MerkleProof} from "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";

import {ERC20, SafeTransferLib} from "@omniprotocol/libraries/SafeTransferLib.sol";
import {ReentrancyGuard} from "@omniprotocol/mixins/ReentrancyGuard.sol";
import {Stewarded} from "@omniprotocol/mixins/Stewarded.sol";

/// @title Shrine
/// @author zefram.eth, cyrusofeden.eth
/// @notice A Shrine maintains a list of Champions with individual weights (shares), and anyone could
/// offer any ERC-20 tokens to the Shrine in order to distribute them to the Champions proportional to their
/// shares. A Champion transfer their right to claim all future tokens offered to
/// the Champion to another address.
contract MerkleShrine is Stewarded, ReentrancyGuard {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error AlreadyInitialized();
    error InputArraysLengthMismatch();
    error NotAuthorized();
    error InvalidMerkleProof();
    error LedgerZeroTotalShares();

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
        uint256 indexed version,
        ERC20 indexed token,
        address indexed champion,
        uint256 claimedTokenAmount
    );
    event ClaimFromMetaShrine(MerkleShrine indexed metaShrine);
    event TransferChampionStatus(address indexed champion, address recipient);
    event UpdateLedger(uint256 indexed newVersion, Ledger newLedger);

    /// -----------------------------------------------------------------------
    /// Structs
    /// -----------------------------------------------------------------------

    /// @param version The Merkle tree version
    /// @param token The ERC-20 token to be claimed
    /// @param champion The Champion address. If the Champion rights
    ///                 have been transferred, the tokens will be sent to its owner.
    /// @param shares The share amount of the Champion
    /// @param merkleProof The Merkle proof showing the Champion is part of this Shrine's Merkle tree
    struct ClaimInfo {
        uint256 version;
        ERC20 token;
        address champion;
        uint256 shares;
        bytes32[] merkleProof;
    }

    /// @param metaShrine The shrine to claim from
    /// @param version The Merkle tree version
    /// @param token The ERC-20 token to be claimed
    /// @param shares The share amount of the Champion
    /// @param merkleProof The Merkle proof showing the Champion is part of this Shrine's Merkle tree
    struct MetaShrineClaimInfo {
        MerkleShrine metaShrine;
        uint256 version;
        ERC20 token;
        uint256 shares;
        bytes32[] merkleProof;
    }

    struct Ledger {
        bytes32 merkleRoot;
        uint256 totalShares;
    }

    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    /// @notice The current version of the ledger, starting from 1
    uint256 public currentLedgerVersion = 1;

    /// @notice version => ledger
    mapping(uint256 => Ledger) public ledgerOfVersion;

    /// @notice version => (token => (champion => claimedTokens))
    mapping(uint256 => mapping(ERC20 => mapping(address => uint256)))
        public claimedTokens;

    /// @notice version => (token => offeredTokens)
    mapping(uint256 => mapping(ERC20 => uint256)) public offeredTokens;

    /// @notice champion => address
    mapping(address => address) public championClaimRightOwner;

    /// -----------------------------------------------------------------------
    /// Initialization
    /// -----------------------------------------------------------------------

    /// @notice Initialize the MerkleShrine contract.
    /// @param steward The Shrine's initial steward, who controls the ledger
    /// @param initialLedger The Shrine's initial ledger with the distribution shares
    constructor(address steward, Ledger memory initialLedger) {
        __initStewarded(steward);

        // 0 total shares makes no sense
        if (initialLedger.totalShares == 0) {
            revert LedgerZeroTotalShares();
        }

        // the version number start at 1
        ledgerOfVersion[1] = initialLedger;

        // emit event to let indexers pick up ledger & metadata IPFS hash
        emit UpdateLedger(1, initialLedger);
    }

    /// -----------------------------------------------------------------------
    /// User actions
    /// -----------------------------------------------------------------------

    /// @notice Offer ERC-20 tokens to the MerkleShrine and distribute them to Champions proportional
    /// to their shares in the Shrine. Callable by anyone.
    /// @param token The ERC-20 token being offered to the Shrine
    /// @param amount The amount of tokens to offer
    function offer(ERC20 token, uint256 amount) external {
        // -------------------------------------------------------------------
        // State updates
        // -------------------------------------------------------------------

        // distribute tokens to Champions
        offeredTokens[currentLedgerVersion][token] += amount;

        // -------------------------------------------------------------------
        // Effects
        // -------------------------------------------------------------------

        // transfer tokens from sender
        token.safeTransferFrom(msg.sender, address(this), amount);

        emit Offer(msg.sender, token, amount);
    }

    /// @notice A Champion or the owner of a Champion may call this to
    ///         claim their share of the tokens offered to this Shrine.
    /// Requires a Merkle proof to prove that the Champion is part of this Shrine's Merkle tree.
    /// Only callable by the champion (if the right was never transferred) or the owner
    /// (that the original champion transferred their rights to)
    /// @param claimInfo The info of the claim
    /// @return claimedTokenAmount The amount of tokens claimed
    function claim(address recipient, ClaimInfo calldata claimInfo)
        external
        returns (uint256 claimedTokenAmount)
    {
        // -------------------------------------------------------------------
        // Validation
        // -------------------------------------------------------------------

        // verify sender auth
        _verifyChampionOwnership(claimInfo.champion);

        // verify Merkle proof that the champion is part of the Merkle tree
        _verifyMerkleProof(
            claimInfo.version,
            claimInfo.champion,
            claimInfo.shares,
            claimInfo.merkleProof
        );

        // compute claimable amount
        uint256 championClaimedTokens = claimedTokens[claimInfo.version][
            claimInfo.token
        ][claimInfo.champion];
        claimedTokenAmount = _computeClaimableTokenAmount(
            claimInfo.version,
            claimInfo.token,
            claimInfo.shares,
            championClaimedTokens
        );

        // -------------------------------------------------------------------
        // State updates
        // -------------------------------------------------------------------

        // record total tokens claimed by the champion
        claimedTokens[claimInfo.version][claimInfo.token][claimInfo.champion] =
            championClaimedTokens +
            claimedTokenAmount;

        // -------------------------------------------------------------------
        // Effects
        // -------------------------------------------------------------------

        // transfer tokens to the recipient
        claimInfo.token.safeTransfer(recipient, claimedTokenAmount);

        emit Claim(
            recipient,
            claimInfo.version,
            claimInfo.token,
            claimInfo.champion,
            claimedTokenAmount
        );
    }

    /// @notice A variant of {claim} that combines multiple claims into a single call.
    function claimMultiple(
        address recipient,
        ClaimInfo[] calldata claimInfoList
    ) external returns (uint256[] memory claimedTokenAmountList) {
        claimedTokenAmountList = new uint256[](claimInfoList.length);
        for (uint256 i = 0; i < claimInfoList.length; i++) {
            // -------------------------------------------------------------------
            // Validation
            // -------------------------------------------------------------------

            // verify sender auth
            _verifyChampionOwnership(claimInfoList[i].champion);

            // verify Merkle proof that the champion is part of the Merkle tree
            _verifyMerkleProof(
                claimInfoList[i].version,
                claimInfoList[i].champion,
                claimInfoList[i].shares,
                claimInfoList[i].merkleProof
            );

            // compute claimable amount
            uint256 championClaimedTokens = claimedTokens[
                claimInfoList[i].version
            ][claimInfoList[i].token][claimInfoList[i].champion];
            claimedTokenAmountList[i] = _computeClaimableTokenAmount(
                claimInfoList[i].version,
                claimInfoList[i].token,
                claimInfoList[i].shares,
                championClaimedTokens
            );

            // -------------------------------------------------------------------
            // State updates
            // -------------------------------------------------------------------

            // record total tokens claimed by the champion
            claimedTokens[claimInfoList[i].version][claimInfoList[i].token][
                claimInfoList[i].champion
            ] = championClaimedTokens + claimedTokenAmountList[i];
        }

        for (uint256 i = 0; i < claimInfoList.length; i++) {
            // -------------------------------------------------------------------
            // Effects
            // -------------------------------------------------------------------

            // transfer tokens to the recipient
            claimInfoList[i].token.safeTransfer(
                recipient,
                claimedTokenAmountList[i]
            );

            emit Claim(
                recipient,
                claimInfoList[i].version,
                claimInfoList[i].token,
                claimInfoList[i].champion,
                claimedTokenAmountList[i]
            );
        }
    }

    /// @notice A variant of {claim} that combines multiple claims for the
    ///         same Champion & version into a single call.
    /// @dev This is more efficient than {claimMultiple} since
    ///      it only checks Champion ownership & verifies Merkle proof once.
    function claimMultipleTokensForChampion(
        address recipient,
        uint256 version,
        ERC20[] calldata tokenList,
        address champion,
        uint256 shares,
        bytes32[] calldata merkleProof
    ) external returns (uint256[] memory claimedTokenAmountList) {
        // -------------------------------------------------------------------
        // Validation
        // -------------------------------------------------------------------

        // verify sender auth
        _verifyChampionOwnership(champion);

        // verify Merkle proof that the champion is part of the Merkle tree
        _verifyMerkleProof(version, champion, shares, merkleProof);

        claimedTokenAmountList = new uint256[](tokenList.length);
        for (uint256 i = 0; i < tokenList.length; i++) {
            // compute claimable amount
            uint256 championClaimedTokens = claimedTokens[version][
                tokenList[i]
            ][champion];
            claimedTokenAmountList[i] = _computeClaimableTokenAmount(
                version,
                tokenList[i],
                shares,
                championClaimedTokens
            );

            // -------------------------------------------------------------------
            // State updates
            // -------------------------------------------------------------------

            // record total tokens claimed by the champion
            claimedTokens[version][tokenList[i]][champion] =
                championClaimedTokens +
                claimedTokenAmountList[i];
        }

        for (uint256 i = 0; i < tokenList.length; i++) {
            // -------------------------------------------------------------------
            // Effects
            // -------------------------------------------------------------------

            // transfer tokens to the recipient
            tokenList[i].safeTransfer(recipient, claimedTokenAmountList[i]);

            emit Claim(
                recipient,
                version,
                tokenList[i],
                champion,
                claimedTokenAmountList[i]
            );
        }
    }

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
        // -------------------------------------------------------------------
        // Validation
        // -------------------------------------------------------------------

        // verify sender auth
        _verifyChampionOwnership(champion);

        // -------------------------------------------------------------------
        // State updates
        // -------------------------------------------------------------------

        championClaimRightOwner[champion] = newOwner;
        emit TransferChampionStatus(champion, newOwner);
    }

    /// -----------------------------------------------------------------------
    /// Getters
    /// -----------------------------------------------------------------------

    /// @notice Computes the amount of a particular ERC-20 token claimable by a Champion from
    /// a particular version of the Merkle tree.
    /// @param version The Merkle tree version
    /// @param token The ERC-20 token to be claimed
    /// @param champion The Champion address
    /// @param shares The share amount of the Champion
    /// @return claimableTokenAmount The amount of tokens claimable
    function computeClaimableTokenAmount(
        uint256 version,
        ERC20 token,
        address champion,
        uint256 shares
    ) public view returns (uint256 claimableTokenAmount) {
        return
            _computeClaimableTokenAmount(
                version,
                token,
                shares,
                claimedTokens[version][token][champion]
            );
    }

    /// @notice The Shrine Guardian's address (same as the contract owner)
    /// @return The Guardian's address
    function guardian() external view returns (address) {
        return owner;
    }

    /// @notice The ledger at a particular version
    /// @param version The version of the ledger to query
    /// @return The ledger at the specified version
    function getLedgerOfVersion(uint256 version)
        external
        view
        returns (Ledger memory)
    {
        return ledgerOfVersion[version];
    }

    /// -----------------------------------------------------------------------
    /// Guardian actions
    /// -----------------------------------------------------------------------

    /// @notice The Guardian may call this function to update the ledger, so that the list of
    /// champions and the associated weights are updated.
    /// @param newLedger The new Merkle tree to use for the list of champions and their shares
    function updateLedger(Ledger calldata newLedger) external requiresAuth {
        // 0 total shares makes no sense
        if (newLedger.totalShares == 0) revert LedgerZeroTotalShares();

        uint256 newVersion = currentLedgerVersion + 1;
        currentLedgerVersion = newVersion;
        ledgerOfVersion[newVersion] = newLedger;

        emit UpdateLedger(newVersion, newLedger);
    }

    /// -----------------------------------------------------------------------
    /// Internal utilities
    /// -----------------------------------------------------------------------

    /// @dev Reverts if the sender isn't the champion or does not own the champion claim right
    /// @param champion The champion whose ownership will be verified
    function _verifyChampionOwnership(address champion) internal view {
        {
            address _championClaimRightOwner = championClaimRightOwner[
                champion
            ];
            if (_championClaimRightOwner == address(0)) {
                // claim right not transferred, sender should be the champion
                if (msg.sender != champion) revert NotAuthorized();
            } else {
                // claim right transferred, sender should be the owner
                if (msg.sender != _championClaimRightOwner)
                    revert NotAuthorized();
            }
        }
    }

    /// @dev Reverts if the champion is not part of the Merkle tree
    /// @param version The Merkle tree version
    /// @param champion The Champion address. If the Champion rights
    ///                 have been transferred, the tokens will be sent to its owner.
    /// @param shares The share amount of the Champion
    /// @param merkleProof The Merkle proof showing the Champion is part of this Shrine's Merkle tree
    function _verifyMerkleProof(
        uint256 version,
        address champion,
        uint256 shares,
        bytes32[] calldata merkleProof
    ) internal view {
        if (
            !MerkleProof.verify(
                merkleProof,
                ledgerOfVersion[version].merkleRoot,
                keccak256(abi.encodePacked(champion, shares))
            )
        ) {
            revert InvalidMerkleProof();
        }
    }

    /// @dev See {computeClaimableTokenAmount}
    function _computeClaimableTokenAmount(
        uint256 version,
        ERC20 token,
        uint256 shares,
        uint256 claimedTokenAmount
    ) internal view returns (uint256 claimableTokenAmount) {
        uint256 totalShares = ledgerOfVersion[version].totalShares;
        uint256 offeredTokenAmount = (offeredTokens[version][token] * shares) /
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
        // -------------------------------------------------------------------
        // Effects
        // -------------------------------------------------------------------

        // claim tokens from the meta shrine
        uint256 beforeBalance = claimInfo.token.balanceOf(address(this));
        claimInfo.metaShrine.claim(
            address(this),
            ClaimInfo({
                version: claimInfo.version,
                token: claimInfo.token,
                champion: address(this),
                shares: claimInfo.shares,
                merkleProof: claimInfo.merkleProof
            })
        );
        claimedTokenAmount =
            claimInfo.token.balanceOf(address(this)) -
            beforeBalance;

        // -------------------------------------------------------------------
        // State updates
        // -------------------------------------------------------------------

        // distribute tokens to Champions
        offeredTokens[currentLedgerVersion][
            claimInfo.token
        ] += claimedTokenAmount;

        emit Offer(
            address(claimInfo.metaShrine),
            claimInfo.token,
            claimedTokenAmount
        );
        emit ClaimFromMetaShrine(claimInfo.metaShrine);
    }
}
