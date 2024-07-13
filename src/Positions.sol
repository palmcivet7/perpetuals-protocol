// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IPositions} from "./interfaces/IPositions.sol";
import {ICCIPPositionsManager, CCIPPositionsManager} from "./CCIPPositionsManager.sol";
import {Constants} from "./libraries/Constants.sol";
import {Utils} from "./libraries/Utils.sol";

contract Positions is IPositions, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/
    using SafeERC20 for IERC20;
    using SignedMath for int256;
    using Utils for uint256;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error Positions__NoZeroAddress();
    error Positions__NoZeroAmount();
    error Positions__MaxLeverageExceeded();
    error Positions__OnlyTrader();
    error Positions__InvalidPosition();
    error Positions__InvalidPositionSize();
    error Positions__InsufficientLiquidity();
    error Positions__MaxLeverageNotExceeded();
    error Positions__PositionInProfit();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @dev Chainlink PriceFeed for the token being speculated on
    AggregatorV3Interface internal immutable i_priceFeed;
    /// @dev USDC is the token used for liquidity and collateral
    IERC20 internal immutable i_usdc;
    /// @dev Contract that handles crosschain messaging
    ICCIPPositionsManager internal immutable i_ccipPositionsManager;

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
    event PositionSizeDecreased(
        uint256 indexed positionId, uint256 indexed newSizeInToken, uint256 indexed newSizeInUsd
    );
    event PositionCollateralIncreased(uint256 indexed positionId, uint256 indexed newCollateralAmount);
    event PositionCollateralDecreased(uint256 indexed positionId, uint256 indexed newCollateralAmount);
    event PositionClosed(uint256 indexed positionId, address indexed trader, int256 indexed pnl);
    event PositionLiquidated(uint256 indexed positionId, address indexed trader, int256 indexed pnl);

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
    constructor(address _router, address _link, address _usdc, address _priceFeed)
        revertIfZeroAddress(_priceFeed)
        revertIfZeroAddress(_usdc)
    {
        i_priceFeed = AggregatorV3Interface(_priceFeed);
        i_usdc = IERC20(_usdc);
        i_ccipPositionsManager =
            ICCIPPositionsManager(new CCIPPositionsManager(_router, _link, _usdc, address(this), msg.sender));
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
        uint256 sizeInUsd = (_sizeInTokenAmount * currentPrice) / Constants.WAD_PRECISION;

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

        /// @dev transfer usdc from trader to ccipPositionsManager
        i_usdc.safeTransferFrom(msg.sender, address(i_ccipPositionsManager), _collateralAmount);
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

        uint256 sizeInUsd = (_sizeInTokenAmountToIncrease * getLatestPrice()) / Constants.WAD_PRECISION;

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

        i_usdc.safeTransferFrom(msg.sender, address(i_ccipPositionsManager), _collateralAmountToIncrease);
    }

    /// @notice Only the position trader can call this to decrease the size of their position
    /// @notice If a position size is decreased to 0, the position will be closed
    function decreaseSize(uint256 _positionId, uint256 _sizeInTokenAmountToDecrease)
        external
        revertIfPositionInvalid(_positionId)
        revertIfZeroAmount(_sizeInTokenAmountToDecrease)
        nonReentrant
    {
        Position memory position = s_position[_positionId];
        if (msg.sender != position.trader) revert Positions__OnlyTrader();
        if (_sizeInTokenAmountToDecrease > position.sizeInToken) revert Positions__InvalidPositionSize();

        uint256 sizeInUsd = (position.sizeInUsd * _sizeInTokenAmountToDecrease) / position.sizeInToken;

        // Get the current PnL of the position
        int256 pnl = getPositionPnl(_positionId);
        // Calculate the realized PnL based on the decrease in size
        int256 realisedPnl = (pnl * int256(_sizeInTokenAmountToDecrease)) / int256(position.sizeInToken);

        uint256 collateral = position.collateralAmount;

        if (realisedPnl > 0) {
            // If the realized PnL is positive, convert to unsigned int
            uint256 positiveRealisedPnlScaledToUsdc = uint256(realisedPnl).scaleToUSDC();

            // Check if there is enough liquidity in the vault to pay the PnL
            uint256 availableLiquidity = getAvailableLiquidity();
            if (positiveRealisedPnlScaledToUsdc > availableLiquidity) revert Positions__InsufficientLiquidity();

            // Decrease the size of the position
            s_position[_positionId].sizeInToken -= _sizeInTokenAmountToDecrease;
            s_position[_positionId].sizeInUsd -= sizeInUsd;

            /// @dev we send the message to the vault via ccip, saying "we need this much profit sent back to this trader"
            i_ccipPositionsManager.ccipSend(
                0, positiveRealisedPnlScaledToUsdc, msg.sender, _sizeInTokenAmountToDecrease, 0, false, false
            );
        } else if (realisedPnl < 0) {
            // If the realized PnL is negative, convert to unsigned int and scale to USDC precision
            uint256 negativeRealisedPnl = uint256(realisedPnl.abs());
            uint256 negativeRealisedPnlScaledToUsdc = negativeRealisedPnl.scaleToUSDC();

            if (collateral > negativeRealisedPnlScaledToUsdc) {
                // Deduct the realized loss from the collateral if there is enough
                s_position[_positionId].collateralAmount -= negativeRealisedPnlScaledToUsdc;
                s_totalCollateral -= negativeRealisedPnlScaledToUsdc;

                // Decrease the size of the position
                s_position[_positionId].sizeInToken -= _sizeInTokenAmountToDecrease;
                s_position[_positionId].sizeInUsd -= sizeInUsd;
                _decreaseTotalOpenInterest(_sizeInTokenAmountToDecrease, sizeInUsd, position.isLong);
            } else {
                // Set the collateral to zero if the realized loss exceeds it
                s_totalCollateral -= collateral;
                s_position[_positionId].collateralAmount = 0;

                // Decrease the size of the position
                s_position[_positionId].sizeInToken = 0;
                s_position[_positionId].sizeInUsd = 0;
                _decreaseTotalOpenInterestAndSendCollateral(
                    collateral, _sizeInTokenAmountToDecrease, sizeInUsd, position.isLong
                );
            }
        } else if (realisedPnl == 0) {
            s_position[_positionId].sizeInToken -= _sizeInTokenAmountToDecrease;
            s_position[_positionId].sizeInUsd -= sizeInUsd;
            _decreaseTotalOpenInterest(_sizeInTokenAmountToDecrease, sizeInUsd, position.isLong);
        }

        if (position.sizeInToken == _sizeInTokenAmountToDecrease && realisedPnl >= 0) {
            // If the position size is zero, mark the position as closed and emit the PositionClosed event
            s_totalCollateral -= collateral;
            s_position[_positionId].collateralAmount = 0;
            emit PositionClosed(_positionId, msg.sender, realisedPnl);

            // Transfer remaining collateral back to the trader
            i_ccipPositionsManager.approve(collateral);
            i_usdc.safeTransferFrom(address(i_ccipPositionsManager), msg.sender, collateral);
        } else if (s_position[_positionId].sizeInToken == 0) {
            emit PositionClosed(_positionId, msg.sender, realisedPnl);
        } else {
            emit PositionSizeDecreased(
                _positionId, position.sizeInToken - _sizeInTokenAmountToDecrease, position.sizeInUsd - sizeInUsd
            );
        }
    }

    /// @dev Only the position trader can call this to decrease the collateral of their position
    function decreaseCollateral(uint256 _positionId, uint256 _collateralAmountToDecrease)
        external
        revertIfPositionInvalid(_positionId)
        revertIfZeroAmount(_collateralAmountToDecrease)
        nonReentrant
    {
        Position memory position = s_position[_positionId];
        if (msg.sender != position.trader) revert Positions__OnlyTrader();

        s_position[_positionId].collateralAmount -= _collateralAmountToDecrease;
        s_totalCollateral -= _collateralAmountToDecrease;

        /// @dev revert if max leverage exceeded
        if (_isMaxLeverageExceeded(_positionId)) revert Positions__MaxLeverageExceeded();
        emit PositionCollateralDecreased(_positionId, position.collateralAmount - _collateralAmountToDecrease);

        i_ccipPositionsManager.approve(_collateralAmountToDecrease);
        i_usdc.safeTransferFrom(address(i_ccipPositionsManager), msg.sender, _collateralAmountToDecrease);
    }

    /// @notice Anyone can call this to liquidate and close an over leveraged position
    /// @notice Liquidators are incentivized to call this as early as possible as they will receive
    /// a liquidation reward of 20% of any remaining collateral
    /// @dev This function is called by Chainlink Automation nodes via our AutomatedLiquidator contract
    /// when a position becomes liquidatable to keep our system solvent
    function liquidate(uint256 _positionId) external revertIfPositionInvalid(_positionId) nonReentrant {
        Position memory position = s_position[_positionId];
        if (!_isMaxLeverageExceeded(_positionId)) revert Positions__MaxLeverageNotExceeded();

        // use the pnl to get any remaining collateral
        int256 pnl = getPositionPnl(_positionId);
        if (pnl >= 0) revert Positions__PositionInProfit(); // does this line even need to be here??
        uint256 remainingCollateral = position.collateralAmount;
        uint256 negativePnl = uint256(pnl.abs());
        uint256 negativePnlScaledToUsdc = negativePnl.scaleToUSDC();
        if (remainingCollateral > negativePnlScaledToUsdc) remainingCollateral -= negativePnlScaledToUsdc;
        else remainingCollateral = 0;

        // Effects: Close the position
        s_totalCollateral -= position.collateralAmount;
        s_position[_positionId].collateralAmount = 0;
        s_position[_positionId].sizeInToken = 0;
        s_position[_positionId].sizeInUsd = 0;

        emit PositionLiquidated(_positionId, position.trader, pnl);

        // transfer 20% of any remaining collateral to the liquidator
        if (remainingCollateral > 0) {
            // calculate 20% of position.collateralAmount
            uint256 liquidationReward =
                (remainingCollateral * Constants.LIQUIDATION_BONUS) / Constants.BASIS_POINT_DIVISOR;
            i_ccipPositionsManager.approve(liquidationReward);
            i_usdc.safeTransferFrom(address(i_ccipPositionsManager), msg.sender, liquidationReward);
        }
    }

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
        uint256 sizeInUsd = (position.sizeInToken * currentPrice) / Constants.WAD_PRECISION;
        uint256 sizeInUsdScaled = sizeInUsd.scaleToUSDC();
        uint256 effectiveCollateralByLeverage = effectiveCollateral * Constants.MAX_LEVERAGE;

        return (effectiveCollateralByLeverage < sizeInUsdScaled);
    }

    function _increaseTotalOpenInterest(uint256 _sizeInToken, uint256 _sizeInUsd, bool _isLong) internal {
        if (_isLong) {
            i_ccipPositionsManager.ccipSend(0, 0, address(0), _sizeInToken, 0, true, false);
        } else {
            i_ccipPositionsManager.ccipSend(0, 0, address(0), 0, _sizeInUsd, false, true);
        }
    }

    function _decreaseTotalOpenInterest(uint256 _sizeInToken, uint256 _sizeInUsd, bool _isLong) internal {
        if (_isLong) {
            i_ccipPositionsManager.ccipSend(0, 0, address(0), _sizeInToken, 0, false, false);
        } else {
            i_ccipPositionsManager.ccipSend(0, 0, address(0), 0, _sizeInUsd, false, false);
        }
    }

    function _decreaseTotalOpenInterestAndSendCollateral(
        uint256 _liquidatedCollateralToSend,
        uint256 _sizeInToken,
        uint256 _sizeInUsd,
        bool _isLong
    ) internal {
        if (_isLong) {
            i_ccipPositionsManager.ccipSend(_liquidatedCollateralToSend, 0, address(0), _sizeInToken, 0, false, false);
        } else {
            i_ccipPositionsManager.ccipSend(_liquidatedCollateralToSend, 0, address(0), 0, _sizeInUsd, false, false);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 GETTER
    //////////////////////////////////////////////////////////////*/
    /// @dev Returns the latest price for the speculated asset
    function getLatestPrice() public view returns (uint256) {
        (, int256 price,,,) = i_priceFeed.latestRoundData();
        return uint256(price) * Constants.SCALING_FACTOR;
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
            pnl = ((int256(currentPrice) - int256(position.openPrice)) * int256(position.sizeInToken))
                / Constants.INT_PRECISION;
        } else {
            /// Formula for Short PnL:
            /// (Average Position Price - Current Market Value) * Size In Tokens
            pnl = ((int256(position.openPrice) - int256(currentPrice)) * int256(position.sizeInToken))
                / Constants.INT_PRECISION;
        }
        return pnl;
    }

    /// @dev Returns the available liquidity of the protocol, excluding any collateral or reserved profits
    function getAvailableLiquidity() public view returns (uint256) {
        // Total assets in the vault
        uint256 totalLiquidity = i_ccipPositionsManager.getTotalLiquidity();

        // Calculate and scale the total open interest
        uint256 totalOpenInterestLong = (s_totalOpenInterestLongInToken * getLatestPrice()) / Constants.WAD_PRECISION;
        uint256 totalOpenInterest = totalOpenInterestLong + s_totalOpenInterestShortInUsd;
        uint256 totalOpenInterestScaled = totalOpenInterest.scaleToUSDC();

        // Calculate max utilization liquidity
        uint256 maxUtilizationLiquidity =
            (totalLiquidity * Constants.MAX_UTILIZATION_PERCENTAGE) / Constants.BASIS_POINT_DIVISOR;

        // Adjust available liquidity based on total open interest
        uint256 availableLiquidity =
            maxUtilizationLiquidity > totalOpenInterestScaled ? maxUtilizationLiquidity - totalOpenInterestScaled : 0;

        return availableLiquidity;
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

    function getTotalCollateral() external view returns (uint256) {
        return s_totalCollateral;
    }

    function getPositionsCount() external view returns (uint256) {
        return s_positionsCount;
    }

    function getMaxLeverageExceeded(uint256 _positionId) external view returns (bool) {
        return _isMaxLeverageExceeded(_positionId);
    }

    function getCcipPositionsManager() external view returns (address) {
        return address(i_ccipPositionsManager);
    }
}
