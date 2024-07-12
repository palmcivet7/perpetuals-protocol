// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IPositions} from "./interfaces/IPositions.sol";
import {IVault, Vault} from "./Vault.sol";

contract Positions is IPositions, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/
    using SafeERC20 for IERC20;
    using SignedMath for int256;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error Positions__NoZeroAddress();
    error Positions__NoZeroAmount();
    error Positions__MaxLeverageExceeded();
    error Positions__OnlyTrader();
    error Positions__InvalidPosition();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 internal constant PRICE_FEED_PRECISION = 10 ** 8; // 1e8
    uint256 internal constant WAD_PRECISION = 10 ** 18; // 1e18
    uint256 internal constant SCALING_FACTOR = WAD_PRECISION / PRICE_FEED_PRECISION;
    uint256 internal constant USDC_PRECISION = 10 ** 6; // 1e6
    /// @dev The size of a position can be 20x the collateral, but exceeding this results in liquidation
    uint256 internal constant MAX_LEVERAGE = 20;
    /// @dev Traders cannot utilize more than a configured percentage of the deposited liquidity
    uint256 internal constant MAX_UTILIZATION_PERCENTAGE = 8000;
    uint256 internal constant BASIS_POINT_DIVISOR = 10000;
    int256 internal constant INT_PRECISION = 10 ** 18;

    /// @dev Chainlink PriceFeed for the token being speculated on
    AggregatorV3Interface internal immutable i_priceFeed;
    /// @dev USDC is the token used for liquidity and collateral
    IERC20 internal immutable i_usdc;
    /// @dev The system's native Vault
    IVault internal immutable i_vault;

    struct Position {
        address trader;
        uint256 sizeInToken;
        uint256 sizeInUsd;
        uint256 collateralAmount;
        uint256 openPrice;
        bool isLong;
    }

    /// @dev Maps position ID to a position
    mapping(uint256 positionId => Position position) internal s_position;
    /// @dev Increments everytime a position is opened
    uint256 internal s_positionsCount;
    /// @dev Total deposited collateral
    uint256 internal s_totalCollateral;
    uint256 internal s_totalOpenInterestLongInToken;
    uint256 internal s_totalOpenInterestLongInUsd; // scaled to 1e18, not scaled to usdc
    uint256 internal s_totalOpenInterestShortInToken;
    uint256 internal s_totalOpenInterestShortInUsd; // scaled to 1e18, not scaled to usdc

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event PositionOpened(
        uint256 indexed positionId,
        address trader,
        uint256 indexed sizeInToken,
        uint256 sizeInUsd,
        uint256 collateralAmount,
        uint256 indexed openPrice,
        bool isLong
    );
    event PositionSizeIncreased(
        uint256 indexed positionId, uint256 indexed newSizeInToken, uint256 indexed newSizeInUsd
    );
    event PositionCollateralIncreased(uint256 indexed positionId, uint256 indexed newCollateralAmount);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier revertIfZeroAddress(address _address) {
        if (_address == address(0)) revert Positions__NoZeroAddress();
        _;
    }

    modifier revertIfZeroAmount(uint256 _amount) {
        if (_amount == 0) revert Positions__NoZeroAmount();
        _;
    }

    /// @dev If the sizeInToken of a position is 0, it isn't an open position and therefore invalid
    modifier revertIfPositionInvalid(uint256 _positionId) {
        Position memory position = s_position[_positionId];
        if (position.sizeInToken == 0) revert Positions__InvalidPosition();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _priceFeed, address _usdc) revertIfZeroAddress(_priceFeed) revertIfZeroAddress(_usdc) {
        i_priceFeed = AggregatorV3Interface(_priceFeed);
        i_usdc = IERC20(_usdc);
        i_vault = IVault(new Vault(address(this), _usdc));
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @dev Allows a trader to open a position
    function openPosition(uint256 _sizeInTokenAmount, uint256 _collateralAmount, bool _isLong)
        external
        revertIfZeroAmount(_sizeInTokenAmount)
        revertIfZeroAmount(_collateralAmount)
        nonReentrant
    {
        uint256 currentPrice = getLatestPrice();
        uint256 sizeInUsd = (_sizeInTokenAmount * currentPrice) / WAD_PRECISION;

        s_positionsCount++;
        uint256 positionId = s_positionsCount;
        s_position[positionId] =
            Position(msg.sender, _sizeInTokenAmount, sizeInUsd, _collateralAmount, currentPrice, _isLong);

        s_totalCollateral += _collateralAmount;

        /// @dev increase open interest
        _increaseTotalOpenInterest(_sizeInTokenAmount, sizeInUsd, _isLong);

        /// @dev revert if max leverage exceeded
        if (_isMaxLeverageExceeded(positionId)) revert Positions__MaxLeverageExceeded();

        emit PositionOpened(
            positionId, msg.sender, _sizeInTokenAmount, sizeInUsd, _collateralAmount, currentPrice, _isLong
        );

        /// @dev transfer usdc from trader to vault
        i_usdc.safeTransferFrom(msg.sender, address(i_vault), _collateralAmount);
    }

    /// @dev The position trader can call this to increase the size of their position
    function increaseSize(uint256 _positionId, uint256 _sizeInTokenAmountToIncrease)
        external
        revertIfPositionInvalid(_positionId)
        revertIfZeroAmount(_sizeInTokenAmountToIncrease)
        nonReentrant
    {
        Position memory position = s_position[_positionId];
        if (msg.sender != position.trader) revert Positions__OnlyTrader();

        uint256 sizeInUsd = (_sizeInTokenAmountToIncrease * getLatestPrice()) / WAD_PRECISION;

        s_position[_positionId].sizeInToken += _sizeInTokenAmountToIncrease;
        _increaseTotalOpenInterest(_sizeInTokenAmountToIncrease, sizeInUsd, position.isLong);

        /// @dev revert if max leverage exceeded
        if (_isMaxLeverageExceeded(_positionId)) revert Positions__MaxLeverageExceeded();

        emit PositionSizeIncreased(
            _positionId, position.sizeInToken + _sizeInTokenAmountToIncrease, position.sizeInUsd + sizeInUsd
        );
    }

    /// @dev Anyone can currently call this function on behalf of other users' positions to increase the collateral
    function increaseCollateral(uint256 _positionId, uint256 _collateralAmountToIncrease)
        external
        revertIfPositionInvalid(_positionId)
        revertIfZeroAmount(_collateralAmountToIncrease)
        nonReentrant
    {
        Position memory position = s_position[_positionId];

        s_position[_positionId].collateralAmount += _collateralAmountToIncrease;
        s_totalCollateral += _collateralAmountToIncrease;

        /// @dev Increasing collateral is almost certainly not going to exceed the max leverage
        /// but we check for added security
        /// @dev revert if max leverage exceeded
        if (_isMaxLeverageExceeded(_positionId)) revert Positions__MaxLeverageExceeded();

        emit PositionCollateralIncreased(_positionId, position.collateralAmount + _collateralAmountToIncrease);

        i_usdc.safeTransferFrom(msg.sender, address(i_vault), _collateralAmountToIncrease);
    }

    function decreaseSize() external {}

    function decreaseCollateral() external {}

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _isMaxLeverageExceeded(uint256 _positionId) internal view returns (bool) {
        Position memory position = s_position[_positionId];

        int256 pnl = getPositionPnl(_positionId);

        uint256 effectiveCollateral = position.collateralAmount;
        if (pnl >= 0) {
            effectiveCollateral += uint256(pnl);
        } else {
            if (pnl.abs() > effectiveCollateral) {
                effectiveCollateral = 0;
            } else {
                effectiveCollateral -= pnl.abs();
            }
        }
        if (effectiveCollateral == 0) return true;

        uint256 currentPrice = getLatestPrice();
        uint256 sizeInUsd = (position.sizeInToken * currentPrice) / WAD_PRECISION;
        uint256 sizeInUsdScaled = _scaleToUSDC(sizeInUsd);
        uint256 effectiveCollateralByLeverage = effectiveCollateral * MAX_LEVERAGE;

        return (effectiveCollateralByLeverage < sizeInUsdScaled);
    }

    function _increaseTotalOpenInterest(uint256 _sizeInToken, uint256 _sizeInUsd, bool _isLong) internal {
        if (_isLong) {
            s_totalOpenInterestLongInToken += _sizeInToken;
            s_totalOpenInterestLongInUsd += _sizeInUsd;
        } else {
            s_totalOpenInterestShortInToken += _sizeInToken;
            s_totalOpenInterestShortInUsd += _sizeInUsd;
        }
    }

    function _scaleToUSDC(uint256 _amount) internal pure returns (uint256) {
        return _amount / (WAD_PRECISION / USDC_PRECISION);
    }

    /*//////////////////////////////////////////////////////////////
                                 GETTER
    //////////////////////////////////////////////////////////////*/
    /// @dev Returns the latest price for the speculated asset
    function getLatestPrice() public view returns (uint256) {
        (, int256 price,,,) = i_priceFeed.latestRoundData();
        return uint256(price) * SCALING_FACTOR;
    }

    /// @dev Returns the PnL for a position
    function getPositionPnl(uint256 _positionId) public view returns (int256) {
        Position memory position = s_position[_positionId];
        if (position.sizeInToken == 0) return 0;

        uint256 currentPrice = getLatestPrice();

        int256 pnl;
        if (position.isLong) {
            /// Formula for Long PnL:
            /// (Current Market Value - Average Position Price) * Size In Tokens
            pnl = ((int256(currentPrice) - int256(position.openPrice)) * int256(position.sizeInToken)) / INT_PRECISION;
        } else {
            /// Formula for Short PnL:
            /// (Average Position Price - Current Market Value) * Size In Tokens
            pnl = ((int256(position.openPrice) - int256(currentPrice)) * int256(position.sizeInToken)) / INT_PRECISION;
        }
        return pnl;
    }

    /// @dev Returns the available liquidity of the protocol, excluding any collateral or reserved profits
    function getAvailableLiquidity() public view returns (uint256) {
        // Total assets in the vault
        uint256 totalLiquidity = i_vault.totalAssets();

        // Calculate and scale the total open interest
        uint256 currentPrice = getLatestPrice();
        uint256 totalOpenInterestLong = (s_totalOpenInterestLongInToken * currentPrice) / WAD_PRECISION;
        uint256 totalOpenInterest = totalOpenInterestLong + s_totalOpenInterestShortInUsd;
        uint256 totalOpenInterestScaled = _scaleToUSDC(totalOpenInterest);

        // Calculate max utilization liquidity
        uint256 maxUtilizationLiquidity = (totalLiquidity * MAX_UTILIZATION_PERCENTAGE) / BASIS_POINT_DIVISOR;

        // Adjust available liquidity based on total open interest
        uint256 availableLiquidity =
            maxUtilizationLiquidity > totalOpenInterestScaled ? maxUtilizationLiquidity - totalOpenInterestScaled : 0;

        return availableLiquidity;
    }

    function getVault() external view returns (IVault) {
        return i_vault;
    }

    function getPositionData(uint256 _positionId)
        external
        view
        returns (address, uint256, uint256, uint256, uint256, bool)
    {
        Position memory position = s_position[_positionId];
        return (
            position.trader,
            position.sizeInToken,
            position.sizeInUsd,
            position.collateralAmount,
            position.openPrice,
            position.isLong
        );
    }
}
