// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
// import "./libraries/IterableOrderedOrderSet.sol";
// import "@openzeppelin/contracts/math/Math.sol";
// import "@openzeppelin/contracts/math/SafeMath.sol";
// import "./libraries/IdToAddressBiMap.sol";
// import "./libraries/SafeCast.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "./interfaces/AllowListVerifier.sol";
import {Owned} from "solmate/auth/Owned.sol";

contract BatchAuction is Owned {
    using IterableOrderedOrderSet for IterableOrderedOrderSet.Data;
    using IterableOrderedOrderSet for bytes32;
    using IdToAddressBiMap for IdToAddressBiMap.Data;

    modifier atStageOrderPlacement(uint256 auctionId) {
        require(
            block.timestamp < auctionData[auctionId].auctionEndDate,
            "no longer in order placement phase"
        );
        _;
    }

    modifier atStageOrderPlacementAndCancelation(uint256 auctionId) {
        require(
            block.timestamp < auctionData[auctionId].orderCancellationEndDate,
            "no longer in order placement and cancelation phase"
        );
        _;
    }

    modifier atStageSolutionSubmission(uint256 auctionId) {
        {
            uint256 auctionEndDate = auctionData[auctionId].auctionEndDate;
            require(
                auctionEndDate != 0 &&
                    block.timestamp >= auctionEndDate &&
                    auctionData[auctionId].clearingPriceOrder == bytes32(0),
                "Auction not in solution submission phase"
            );
        }
        _;
    }

    modifier atStageFinished(uint256 auctionId) {
        require(
            auctionData[auctionId].clearingPriceOrder != bytes32(0),
            "Auction not yet finished"
        );
        _;
    }

    event NewSellOrder(
        uint256 indexed auctionId,
        uint64 indexed userId,
        uint96 buyAmount,
        uint96 sellAmount
    );
    event CancellationSellOrder(
        uint256 indexed auctionId,
        uint64 indexed userId,
        uint96 buyAmount,
        uint96 sellAmount
    );
    event ClaimedFromOrder(
        uint256 indexed auctionId,
        uint64 indexed userId,
        uint96 buyAmount,
        uint96 sellAmount
    );
    event NewUser(uint64 indexed userId, address indexed userAddress);
    event NewAuction(
        uint256 indexed auctionId,
        IERC20 indexed _auctioningToken,
        IERC20 indexed _biddingToken,
        uint256 orderCancellationEndDate,
        uint256 auctionEndDate,
        uint64 userId,
        uint96 _auctionedSellAmount,
        uint96 _minBuyAmount,
        uint256 minimumBiddingAmountPerOrder,
        uint256 minFundingThreshold,
        address allowListContract,
        bytes allowListData
    );
    event AuctionCleared(
        uint256 indexed auctionId,
        uint96 soldAuctioningTokens,
        uint96 soldBiddingTokens,
        bytes32 clearingPriceOrder
    );
    event UserRegistration(address indexed user, uint64 userId);

    struct AuctionData {
        IERC20 auctioningToken;
        IERC20 biddingToken;
        uint256 orderCancellationEndDate;
        uint256 auctionEndDate;
        bytes32 initialAuctionOrder;
        uint256 minimumBiddingAmountPerOrder;
        uint256 interimSumBidAmount;
        bytes32 interimOrder;
        bytes32 clearingPriceOrder;
        uint96 volumeClearingPriceOrder;
        bool minFundingThresholdNotReached;
        bool isAtomicClosureAllowed;
        uint256 feeNumerator;
        uint256 minFundingThreshold;
    }
    mapping(uint256 => IterableOrderedOrderSet.Data) internal sellOrders;
    mapping(uint256 => AuctionData) public auctionData;
    mapping(uint256 => address) public auctionAccessManager;
    mapping(uint256 => bytes) public auctionAccessData;

    IdToAddressBiMap.Data private registeredUsers;
    uint64 public numUsers;
    uint256 public auctionCounter;

    constructor() public Owned() {}

    uint256 public feeNumerator = 0;
    uint256 public constant FEE_DENOMINATOR = 1000;
    uint64 public feeReceiverUserId = 1;

    function setFeeParameters(
        uint256 newFeeNumerator,
        address newfeeReceiverAddress
    ) public onlyOwner {
        require(
            newFeeNumerator <= 15,
            "Fee is not allowed to be set higher than 1.5%"
        );
        // caution: for currently running auctions, the feeReceiverUserId is changing as well.
        feeReceiverUserId = getUserId(newfeeReceiverAddress);
        feeNumerator = newFeeNumerator;
    }

    // @dev: function to intiate a new auction
    // Warning: In case the auction is expected to raise more than
    // 2^96 units of the biddingToken, don't start the auction, as
    // it will not be settlable. This corresponds to about 79
    // billion DAI.
    //
    // Prices between biddingToken and auctioningToken are expressed by a
    // fraction whose components are stored as uint96.
    function initiateAuction(
        IERC20 _auctioningToken,
        IERC20 _biddingToken,
        uint256 orderCancellationEndDate,
        uint256 auctionEndDate,
        uint96 _auctionedSellAmount,
        uint96 _minBuyAmount,
        uint256 minimumBiddingAmountPerOrder,
        uint256 minFundingThreshold,
        bool isAtomicClosureAllowed,
        address accessManagerContract,
        bytes memory accessManagerContractData
    ) public returns (uint256) {
        // withdraws sellAmount + fees
        _auctioningToken.safeTransferFrom(
            msg.sender,
            address(this),
            (_auctionedSellAmount * (FEE_DENOMINATOR + feeNumerator)) /
                FEE_DENOMINATOR
        );
        require(_auctionedSellAmount > 0, "cannot auction zero tokens");
        require(_minBuyAmount > 0, "tokens cannot be auctioned for free");
        require(
            minimumBiddingAmountPerOrder > 0,
            "minimumBiddingAmountPerOrder is not allowed to be zero"
        );
        require(
            orderCancellationEndDate <= auctionEndDate,
            "time periods are not configured correctly"
        );
        require(
            auctionEndDate > block.timestamp,
            "auction end date must be in the future"
        );
        auctionCounter += 1;
        sellOrders[auctionCounter].initializeEmptyList();
        uint64 userId = getUserId(msg.sender);
        auctionData[auctionCounter] = AuctionData(
            _auctioningToken,
            _biddingToken,
            orderCancellationEndDate,
            auctionEndDate,
            IterableOrderedOrderSet.encodeOrder(
                userId,
                _minBuyAmount,
                _auctionedSellAmount
            ),
            minimumBiddingAmountPerOrder,
            0,
            IterableOrderedOrderSet.QUEUE_START,
            bytes32(0),
            0,
            false,
            isAtomicClosureAllowed,
            feeNumerator,
            minFundingThreshold
        );
        auctionAccessManager[auctionCounter] = accessManagerContract;
        auctionAccessData[auctionCounter] = accessManagerContractData;
        emit NewAuction(
            auctionCounter,
            _auctioningToken,
            _biddingToken,
            orderCancellationEndDate,
            auctionEndDate,
            userId,
            _auctionedSellAmount,
            _minBuyAmount,
            minimumBiddingAmountPerOrder,
            minFundingThreshold,
            accessManagerContract,
            accessManagerContractData
        );
        return auctionCounter;
    }

    function placeSellOrders(
        uint256 auctionId,
        uint96[] memory _minBuyAmounts,
        uint96[] memory _sellAmounts,
        bytes32[] memory _prevSellOrders,
        bytes calldata allowListCallData
    ) external atStageOrderPlacement(auctionId) returns (uint64 userId) {
        return
            _placeSellOrders(
                auctionId,
                _minBuyAmounts,
                _sellAmounts,
                _prevSellOrders,
                allowListCallData,
                msg.sender
            );
    }

    function placeSellOrdersOnBehalf(
        uint256 auctionId,
        uint96[] memory _minBuyAmounts,
        uint96[] memory _sellAmounts,
        bytes32[] memory _prevSellOrders,
        bytes calldata allowListCallData,
        address orderSubmitter
    ) external atStageOrderPlacement(auctionId) returns (uint64 userId) {
        return
            _placeSellOrders(
                auctionId,
                _minBuyAmounts,
                _sellAmounts,
                _prevSellOrders,
                allowListCallData,
                orderSubmitter
            );
    }

    function _placeSellOrders(
        uint256 auctionId,
        uint96[] memory _minBuyAmounts,
        uint96[] memory _sellAmounts,
        bytes32[] memory _prevSellOrders,
        bytes calldata allowListCallData,
        address orderSubmitter
    ) internal returns (uint64 userId) {
        {
            address allowListManager = auctionAccessManager[auctionId];
            if (allowListManager != address(0)) {
                require(
                    AllowListVerifier(allowListManager).isAllowed(
                        orderSubmitter,
                        auctionId,
                        allowListCallData
                    ) == AllowListVerifierHelper.MAGICVALUE,
                    "user not allowed to place order"
                );
            }
        }
        {
            (
                ,
                uint96 buyAmountOfInitialAuctionOrder,
                uint96 sellAmountOfInitialAuctionOrder
            ) = auctionData[auctionId].initialAuctionOrder.decodeOrder();
            for (uint256 i = 0; i < _minBuyAmounts.length; i++) {
                require(
                    _minBuyAmounts[i] * buyAmountOfInitialAuctionOrder <
                        sellAmountOfInitialAuctionOrder * _sellAmounts[i],
                    "limit price not better than mimimal offer"
                );
            }
        }
        uint256 sumOfSellAmounts = 0;
        userId = getUserId(orderSubmitter);
        uint256 minimumBiddingAmountPerOrder = auctionData[auctionId]
            .minimumBiddingAmountPerOrder;
        for (uint256 i = 0; i < _minBuyAmounts.length; i++) {
            require(
                _minBuyAmounts[i] > 0,
                "_minBuyAmounts must be greater than 0"
            );
            // orders should have a minimum bid size in order to limit the gas
            // required to compute the final price of the auction.
            require(
                _sellAmounts[i] > minimumBiddingAmountPerOrder,
                "order too small"
            );
            if (
                sellOrders[auctionId].insert(
                    IterableOrderedOrderSet.encodeOrder(
                        userId,
                        _minBuyAmounts[i],
                        _sellAmounts[i]
                    ),
                    _prevSellOrders[i]
                )
            ) {
                sumOfSellAmounts += _sellAmounts[i];
                emit NewSellOrder(
                    auctionId,
                    userId,
                    _minBuyAmounts[i],
                    _sellAmounts[i]
                );
            }
        }
        auctionData[auctionId].biddingToken.safeTransferFrom(
            msg.sender,
            address(this),
            sumOfSellAmounts
        ); //[1]
    }

    function cancelSellOrders(uint256 auctionId, bytes32[] memory _sellOrders)
        public
        atStageOrderPlacementAndCancelation(auctionId)
    {
        uint64 userId = getUserId(msg.sender);
        uint256 claimableAmount = 0;
        for (uint256 i = 0; i < _sellOrders.length; i++) {
            // Note: we keep the back pointer of the deleted element so that
            // it can be used as a reference point to insert a new node.
            bool success = sellOrders[auctionId].removeKeepHistory(
                _sellOrders[i]
            );
            if (success) {
                (
                    uint64 userIdOfIter,
                    uint96 buyAmountOfIter,
                    uint96 sellAmountOfIter
                ) = _sellOrders[i].decodeOrder();
                require(
                    userIdOfIter == userId,
                    "Only the user can cancel his orders"
                );
                claimableAmount += sellAmountOfIter;
                emit CancellationSellOrder(
                    auctionId,
                    userId,
                    buyAmountOfIter,
                    sellAmountOfIter
                );
            }
        }
        auctionData[auctionId].biddingToken.safeTransfer(
            msg.sender,
            claimableAmount
        ); //[2]
    }

    function precalculateSellAmountSum(
        uint256 auctionId,
        uint256 iterationSteps
    ) public atStageSolutionSubmission(auctionId) {
        (, , uint96 auctioneerSellAmount) = auctionData[auctionId]
            .initialAuctionOrder
            .decodeOrder();
        uint256 sumBidAmount = auctionData[auctionId].interimSumBidAmount;
        bytes32 iterOrder = auctionData[auctionId].interimOrder;

        for (uint256 i = 0; i < iterationSteps; i++) {
            iterOrder = sellOrders[auctionId].next(iterOrder);
            (, , uint96 sellAmountOfIter) = iterOrder.decodeOrder();
            sumBidAmount = sumBidAmount + sellAmountOfIter;
        }

        require(
            iterOrder != IterableOrderedOrderSet.QUEUE_END,
            "reached end of order list"
        );

        // it is checked that not too many iteration steps were taken:
        // require that the sum of SellAmounts times the price of the last order
        // is not more than initially sold amount
        (, uint96 buyAmountOfIter, uint96 sellAmountOfIter) = iterOrder
            .decodeOrder();
        require(
            sumBidAmount * buyAmountOfIter <
                auctioneerSellAmount * sellAmountOfIter,
            "too many orders summed up"
        );

        auctionData[auctionId].interimSumBidAmount = sumBidAmount;
        auctionData[auctionId].interimOrder = iterOrder;
    }

    function settleAuctionAtomically(
        uint256 auctionId,
        uint96[] memory _minBuyAmount,
        uint96[] memory _sellAmount,
        bytes32[] memory _prevSellOrder,
        bytes calldata allowListCallData
    ) public atStageSolutionSubmission(auctionId) {
        require(
            auctionData[auctionId].isAtomicClosureAllowed,
            "not allowed to settle auction atomically"
        );
        require(
            _minBuyAmount.length == 1 && _sellAmount.length == 1,
            "Only one order can be placed atomically"
        );
        uint64 userId = getUserId(msg.sender);
        require(
            auctionData[auctionId].interimOrder.smallerThan(
                IterableOrderedOrderSet.encodeOrder(
                    userId,
                    _minBuyAmount[0],
                    _sellAmount[0]
                )
            ),
            "precalculateSellAmountSum is already too advanced"
        );
        _placeSellOrders(
            auctionId,
            _minBuyAmount,
            _sellAmount,
            _prevSellOrder,
            allowListCallData,
            msg.sender
        );
        settleAuction(auctionId);
    }

    // @dev function settling the auction and calculating the price
    function settleAuction(uint256 auctionId)
        public
        atStageSolutionSubmission(auctionId)
        returns (bytes32 clearingOrder)
    {
        (
            uint64 auctioneerId,
            uint96 minAuctionedBuyAmount,
            uint96 fullAuctionedAmount
        ) = auctionData[auctionId].initialAuctionOrder.decodeOrder();

        uint256 currentBidSum = auctionData[auctionId].interimSumBidAmount;
        bytes32 currentOrder = auctionData[auctionId].interimOrder;
        uint256 buyAmountOfIter;
        uint256 sellAmountOfIter;
        uint96 fillVolumeOfAuctioneerOrder = fullAuctionedAmount;
        // Sum order up, until fullAuctionedAmount is fully bought or queue end is reached
        do {
            bytes32 nextOrder = sellOrders[auctionId].next(currentOrder);
            if (nextOrder == IterableOrderedOrderSet.QUEUE_END) {
                break;
            }
            currentOrder = nextOrder;
            (, buyAmountOfIter, sellAmountOfIter) = currentOrder.decodeOrder();
            currentBidSum += sellAmountOfIter;
        } while (
            currentBidSum * buyAmountOfIter <
                fullAuctionedAmount * sellAmountOfIter
        );

        if (
            currentBidSum > 0 &&
            currentBidSum * buyAmountOfIter >=
            fullAuctionedAmount * sellAmountOfIter
        ) {
            // All considered/summed orders are sufficient to close the auction fully
            // at price between current and previous orders.
            uint256 uncoveredBids = currentBidSum -
                ((fullAuctionedAmount * sellAmountOfIter) / buyAmountOfIter);

            if (sellAmountOfIter >= uncoveredBids) {
                //[13]
                // Auction fully filled via partial match of currentOrder
                uint256 sellAmountClearingOrder = sellAmountOfIter -
                    uncoveredBids;
                auctionData[auctionId]
                    .volumeClearingPriceOrder = sellAmountClearingOrder
                    .toUint96();
                currentBidSum -= currentBidSum;
                clearingOrder = currentOrder;
            } else {
                //[14]
                // Auction fully filled via price strictly between currentOrder and the order
                // immediately before. For a proof, see the security-considerations.md
                currentBidSum -= sellAmountOfIter;
                clearingOrder = IterableOrderedOrderSet.encodeOrder(
                    0,
                    fullAuctionedAmount,
                    currentBidSum.toUint96()
                );
            }
        } else {
            // All considered/summed orders are not sufficient to close the auction fully at price of last order //[18]
            // Either a higher price must be used or auction is only partially filled

            if (currentBidSum > minAuctionedBuyAmount) {
                //[15]
                // Price higher than last order would fill the auction
                clearingOrder = IterableOrderedOrderSet.encodeOrder(
                    0,
                    fullAuctionedAmount,
                    currentBidSum.toUint96()
                );
            } else {
                //[16]
                // Even at the initial auction price, the auction is partially filled
                clearingOrder = IterableOrderedOrderSet.encodeOrder(
                    0,
                    fullAuctionedAmount,
                    minAuctionedBuyAmount
                );
                fillVolumeOfAuctioneerOrder =
                    (currentBidSum * fullAuctionedAmount) /
                    minAuctionedBuyAmount;
            }
        }
        auctionData[auctionId].clearingPriceOrder = clearingOrder;

        if (auctionData[auctionId].minFundingThreshold > currentBidSum) {
            auctionData[auctionId].minFundingThresholdNotReached = true;
        }
        processFeesAndAuctioneerFunds(
            auctionId,
            fillVolumeOfAuctioneerOrder,
            auctioneerId,
            fullAuctionedAmount
        );
        emit AuctionCleared(
            auctionId,
            fillVolumeOfAuctioneerOrder,
            uint96(currentBidSum),
            clearingOrder
        );
        // Gas refunds
        auctionAccessManager[auctionId] = address(0);
        delete auctionAccessData[auctionId];
        auctionData[auctionId].initialAuctionOrder = bytes32(0);
        auctionData[auctionId].interimOrder = bytes32(0);
        auctionData[auctionId].interimSumBidAmount = uint256(0);
        auctionData[auctionId].minimumBiddingAmountPerOrder = uint256(0);
    }

    function claimFromParticipantOrder(
        uint256 auctionId,
        bytes32[] memory orders
    )
        public
        atStageFinished(auctionId)
        returns (
            uint256 sumAuctioningTokenAmount,
            uint256 sumBiddingTokenAmount
        )
    {
        for (uint256 i = 0; i < orders.length; i++) {
            // Note: we don't need to keep any information about the node since
            // no new elements need to be inserted.
            require(
                sellOrders[auctionId].remove(orders[i]),
                "order is no longer claimable"
            );
        }
        AuctionData memory auction = auctionData[auctionId];
        (, uint96 priceNumerator, uint96 priceDenominator) = auction
            .clearingPriceOrder
            .decodeOrder();
        (uint64 userId, , ) = orders[0].decodeOrder();
        bool minFundingThresholdNotReached = auctionData[auctionId]
            .minFundingThresholdNotReached;
        for (uint256 i = 0; i < orders.length; i++) {
            (uint64 userIdOrder, uint96 buyAmount, uint96 sellAmount) = orders[
                i
            ].decodeOrder();
            require(
                userIdOrder == userId,
                "only allowed to claim for same user"
            );
            if (minFundingThresholdNotReached) {
                //[10]
                sumBiddingTokenAmount += sellAmount;
            } else {
                //[23]
                if (orders[i] == auction.clearingPriceOrder) {
                    //[25]
                    sumAuctioningTokenAmount +=
                        (auction.volumeClearingPriceOrder * priceNumerator) /
                        priceDenominator;
                    sumBiddingTokenAmount +=
                        sellAmount -
                        auction.volumeClearingPriceOrder;
                } else {
                    if (orders[i].smallerThan(auction.clearingPriceOrder)) {
                        //[17]
                        sumAuctioningTokenAmount +=
                            (sellAmount * priceNumerator) /
                            priceDenominator;
                    } else {
                        //[24]
                        sumBiddingTokenAmount += sellAmount;
                    }
                }
            }
            emit ClaimedFromOrder(auctionId, userId, buyAmount, sellAmount);
        }
        sendOutTokens(
            auctionId,
            sumAuctioningTokenAmount,
            sumBiddingTokenAmount,
            userId
        ); //[3]
    }

    function processFeesAndAuctioneerFunds(
        uint256 auctionId,
        uint256 fillVolumeOfAuctioneerOrder,
        uint64 auctioneerId,
        uint96 fullAuctionedAmount
    ) internal {
        uint256 feeAmount = (fullAuctionedAmount *
            auctionData[auctionId].feeNumerator) / FEE_DENOMINATOR;
        if (auctionData[auctionId].minFundingThresholdNotReached) {
            sendOutTokens(
                auctionId,
                fullAuctionedAmount + feeAmount,
                0,
                auctioneerId
            ); //[4]
        } else {
            //[11]
            (, uint96 priceNumerator, uint96 priceDenominator) = auctionData[
                auctionId
            ].clearingPriceOrder.decodeOrder();
            uint256 unsettledAuctionTokens = fullAuctionedAmount -
                fillVolumeOfAuctioneerOrder;
            uint256 auctioningTokenAmount = unsettledAuctionTokens +
                ((feeAmount * unsettledAuctionTokens) / fullAuctionedAmount);
            uint256 biddingTokenAmount = (fillVolumeOfAuctioneerOrder *
                priceDenominator) / priceNumerator;
            sendOutTokens(
                auctionId,
                auctioningTokenAmount,
                biddingTokenAmount,
                auctioneerId
            ); //[5]
            sendOutTokens(
                auctionId,
                (feeAmount * fillVolumeOfAuctioneerOrder) / fullAuctionedAmount,
                0,
                feeReceiverUserId
            ); //[7]
        }
    }

    function sendOutTokens(
        uint256 auctionId,
        uint256 auctioningTokenAmount,
        uint256 biddingTokenAmount,
        uint64 userId
    ) internal {
        address userAddress = registeredUsers.getAddressAt(userId);
        if (auctioningTokenAmount > 0) {
            auctionData[auctionId].auctioningToken.safeTransfer(
                userAddress,
                auctioningTokenAmount
            );
        }
        if (biddingTokenAmount > 0) {
            auctionData[auctionId].biddingToken.safeTransfer(
                userAddress,
                biddingTokenAmount
            );
        }
    }

    function registerUser(address user) public returns (uint64 userId) {
        numUsers += 1;
        require(
            registeredUsers.insert(numUsers, user),
            "User already registered"
        );
        userId = numUsers;
        emit UserRegistration(user, userId);
    }

    function getUserId(address user) public returns (uint64 userId) {
        if (registeredUsers.hasAddress(user)) {
            userId = registeredUsers.getId(user);
        } else {
            userId = registerUser(user);
            emit NewUser(userId, user);
        }
    }

    function getSecondsRemainingInBatch(uint256 auctionId)
        public
        view
        returns (uint256)
    {
        if (auctionData[auctionId].auctionEndDate < block.timestamp) {
            return 0;
        }
        return auctionData[auctionId].auctionEndDate - block.timestamp;
    }

    function containsOrder(uint256 auctionId, bytes32 order)
        public
        view
        returns (bool)
    {
        return sellOrders[auctionId].contains(order);
    }
}
