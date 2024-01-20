// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IVault} from "./interfaces/IVault.sol";
import {Vault} from "./Vault.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Perpetual {
    error Perpetual__InvalidAddress();
    error Perpetual__InvalidValue();
    error Perpetual__MaxLeverageExceeded();
    error Perpetual__TokenTransferFailed();
    error Perpetual__PositionDoesNotExist();
    error Perpetual__InsufficientLiquidity();

    event PositionOpened(address, Position);
    event PositionSizeIncreased(address, Position, uint256 sizeIncrease);
    event CollateralIncreased(address, Position, uint256 collateralIncrease);

    using SafeERC20 for IERC20;

    uint256 public constant MAX_LEVERAGE = 20;
    uint256 public constant MAX_UTILISATION_PERCENT = 8000;
    uint256 private constant BASIS_POINT_DIVISOR = 10000;
    uint256 private constant PRECISION = 1e18;

    /////////////////////
    ///// Positions ////
    ///////////////////

    struct Position {
        uint256 size;
        uint256 collateralAmount;
        uint256 openPrice;
        bool isLong;
    }

    mapping(address => Position) public s_positions;
    uint256 public s_totalLockedLiquidity; // total collateral amount

    uint256 public s_openInterestLongUsd;
    uint256 public s_openInterestShortUsd;
    uint256 public s_openInterestLongToken;
    uint256 public s_openInterestShortToken;

    /////////////////////
    //// Immutables ////
    ///////////////////

    AggregatorV3Interface public immutable i_priceFeed;
    IVault public immutable i_vault;
    IERC20 public immutable i_collateralToken;

    constructor(address _priceFeed, address _vault, address _collateralToken)
        noZeroAddress(_priceFeed)
        noZeroAddress(_vault)
        noZeroAddress(_collateralToken)
    {
        i_priceFeed = AggregatorV3Interface(_priceFeed);
        i_vault = IVault(_vault);
        i_collateralToken = IERC20(_collateralToken);
    }

    /////////////////////
    ///// Modifiers ////
    ///////////////////

    modifier noZeroAddress(address _address) {
        if (_address == address(0)) revert Perpetual__InvalidAddress();
        _;
    }

    modifier noZeroValue(uint256 _value) {
        if (_value == 0) revert Perpetual__InvalidValue();
        _;
    }

    modifier validateLiquidity(uint256 _size, bool _isLong) {
        if (!validateLiquidityReserve(_size, _isLong)) revert Perpetual__InsufficientLiquidity();
        _;
    }

    /////////////////////
    ////// User ////////
    ///////////////////

    function openPosition(uint256 _size, uint256 _collateralAmount, bool _isLong)
        external
        noZeroValue(_size)
        noZeroValue(_collateralAmount)
        validateLiquidity(_size, _isLong)
    {
        uint256 leverage = _size / _collateralAmount;
        if (leverage > MAX_LEVERAGE) revert Perpetual__MaxLeverageExceeded();

        uint256 currentPrice = getLatestPrice();

        s_totalLockedLiquidity += _collateralAmount;
        uint256 sizeInUsd = (_size * currentPrice) / PRECISION;
        if (_isLong) {
            s_openInterestLongUsd += sizeInUsd;
            s_openInterestLongToken += _size;
        } else {
            s_openInterestShortUsd += sizeInUsd;
            s_openInterestShortToken += _size;
        }

        s_positions[msg.sender] =
            Position({size: _size, collateralAmount: _collateralAmount, openPrice: currentPrice, isLong: _isLong});

        i_collateralToken.safeTransferFrom(msg.sender, address(i_vault), _collateralAmount);
        emit PositionOpened(msg.sender, s_positions[msg.sender]);
    }

    function increaseSize(uint256 _additionalSize)
        external
        noZeroValue(_additionalSize)
        validateLiquidity(_additionalSize, s_positions[msg.sender].isLong)
    {
        Position storage position = s_positions[msg.sender];
        if (position.size == 0) revert Perpetual__PositionDoesNotExist();

        uint256 newTotalSize = position.size + _additionalSize;
        uint256 leverage = newTotalSize / position.collateralAmount;
        if (leverage > MAX_LEVERAGE) revert Perpetual__MaxLeverageExceeded();

        uint256 additionalSizeInUsd = (_additionalSize * getLatestPrice()) * PRECISION;
        if (position.isLong) {
            s_openInterestLongUsd += additionalSizeInUsd;
            s_openInterestLongToken += _additionalSize;
        } else {
            s_openInterestShortUsd += additionalSizeInUsd;
            s_openInterestShortToken += _additionalSize;
        }

        position.size = newTotalSize;
        emit PositionSizeIncreased(msg.sender, position, _additionalSize);
    }

    function increaseCollateral(uint256 _additionalCollateral) external noZeroValue(_additionalCollateral) {
        Position storage position = s_positions[msg.sender];

        if (position.size == 0) revert Perpetual__PositionDoesNotExist();

        position.collateralAmount += _additionalCollateral;
        s_totalLockedLiquidity += _additionalCollateral;
        i_collateralToken.safeTransferFrom(msg.sender, address(i_vault), _additionalCollateral);

        emit CollateralIncreased(msg.sender, position, _additionalCollateral);
    }

    //////////////////////
    ////// Utility //////
    ////////////////////

    function calculatePnL(uint256 _openPrice, uint256 _size, bool _isLong) public view returns (int256) {
        uint256 currentMarketValue = getLatestPrice();

        uint256 normalizedSize = _size / PRECISION;

        if (_isLong) {
            if (currentMarketValue > _openPrice) {
                return int256(currentMarketValue - _openPrice) * int256(normalizedSize);
            } else {
                return -int256(_openPrice - currentMarketValue) * int256(normalizedSize);
            }
        } else {
            if (_openPrice > currentMarketValue) {
                return int256(_openPrice - currentMarketValue) * int256(normalizedSize);
            } else {
                return -int256(currentMarketValue - _openPrice) * int256(normalizedSize);
            }
        }
    }

    function validateLiquidityReserve(uint256 _size, bool _isLong) private returns (bool) {
        uint256 latestPrice = getLatestPrice();
        uint256 sizeInUsd = _size * latestPrice / PRECISION;
        uint256 totalLiquidity = i_vault.totalAssets();
        uint256 maxLiquidityUsage = (totalLiquidity * MAX_UTILISATION_PERCENT) / BASIS_POINT_DIVISOR;

        if (_isLong) {
            bool isLiquiditySufficient =
                (s_openInterestShortUsd + (s_openInterestLongUsd + sizeInUsd)) < maxLiquidityUsage;
            return isLiquiditySufficient;
        } else {
            bool isLiquiditySufficient =
                (s_openInterestLongUsd + (s_openInterestShortToken + _size) * latestPrice) < maxLiquidityUsage;
            return isLiquiditySufficient;
        }
    }

    /////////////////////
    ////// Getter //////
    ///////////////////

    function getLatestPrice() public view returns (uint256) {
        (, int256 price,,,) = i_priceFeed.latestRoundData();
        return uint256(price) * 10 ** 10;
    }

    function getTotalPnL() public view returns (int256) {
        int256 totalLongPnL = getTotalLongPnL();
        int256 totalShortPnL = getTotalShortPnL();

        return totalLongPnL + totalShortPnL;
    }

    function getTotalLongPnL() public view returns (int256) {
        uint256 longValue = (s_openInterestLongToken * getLatestPrice()) / PRECISION;
        int256 pnl = int256(longValue - s_openInterestLongUsd);

        return pnl;
    }

    function getTotalShortPnL() public view returns (int256) {
        uint256 shortValue = (s_openInterestShortToken * getLatestPrice()) / PRECISION;
        int256 pnl = int256(s_openInterestShortUsd - shortValue);

        return pnl;
    }

    function getAvailableLiquidity() public returns (uint256) {
        uint256 totalLiquidity = i_vault.totalAssets();
        uint256 lockedLiquidity = s_totalLockedLiquidity;
        if (lockedLiquidity > totalLiquidity) {
            return 0;
        }
        return totalLiquidity - lockedLiquidity;
    }
}
