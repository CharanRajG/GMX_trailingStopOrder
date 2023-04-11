// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "../libraries/math/SafeMath.sol";
import "../libraries/token/IERC20.sol";
import "../tokens/interfaces/IWETH.sol";
import "../libraries/token/SafeERC20.sol";
import "../libraries/utils/Address.sol";
import "../libraries/utils/ReentrancyGuard.sol";

import "./interfaces/IRouter.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IOrderBook2.sol";

contract OrderBook2 is ReentrancyGuard, IOrderBook2 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address payable;

    uint256 public constant PRICE_PRECISION = 1e30;
    uint256 public constant USDF_PRECISION = 1e18;

    struct TrailingStopOrder {
        address account;
        address collateralToken;
        uint256 collateralDelta;
        address indexToken;
        uint256 sizeDelta;
        bool isLong;
        uint256 triggerPrice;
        bool triggerAboveThreshold;
        uint256 executionFee;
        uint256 trailingBPS;
    }

    mapping(address => mapping(uint256 => TrailingStopOrder))
        public trailingStopOrders;
    mapping(address => uint256) public trailingStopOrdersIndex;

    address public gov;
    address public weth;
    address public usdf;
    address public router;
    address public vault;
    uint256 public minExecutionFee;
    uint256 public minPurchaseTokenAmountUsd;
    bool public isInitialized = false;

    address public fastPriceFeed;

    event CreateTrailingStopOrder(
        address indexed account,
        uint256 orderIndex,
        address collateralToken,
        uint256 collateralDelta,
        address indexToken,
        uint256 sizeDelta,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee,
        uint256 trailingBPS
    );
    event ExecuteTrailingStopOrder(
        address indexed account,
        uint256 orderIndex,
        address collateralToken,
        uint256 collateralDelta,
        address indexToken,
        uint256 sizeDelta,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee,
        uint256 executionPrice,
        uint256 trailingBPS
    );
    event UpdateTrailingStopOrder(
        address indexed account,
        uint256 orderIndex,
        address collateralToken,
        uint256 collateralDelta,
        address indexToken,
        uint256 sizeDelta,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 trailingBPS
    );
    event CancelTrailingStopOrder(
        address indexed account,
        uint256 orderIndex,
        address collateralToken,
        uint256 collateralDelta,
        address indexToken,
        uint256 sizeDelta,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee,
        uint256 trailingBPS
    );

    event Initialize(
        address router,
        address vault,
        address weth,
        address usdf,
        uint256 minExecutionFee,
        uint256 minPurchaseTokenAmountUsd,
        address fastPriceFeed
    );
    event UpdateMinExecutionFee(uint256 minExecutionFee);
    event UpdateMinPurchaseTokenAmountUsd(uint256 minPurchaseTokenAmountUsd);
    event UpdateGov(address gov);
    event UpdateFastPriceFeed(address fastPriceFeed);

    modifier onlyGov() {
        require(msg.sender == gov, "OrderBook: forbidden");
        _;
    }

    modifier onlyFastPriceFeed() {
        require(msg.sender == fastPriceFeed, "OrderBook: forbidden");
        _;
    }
