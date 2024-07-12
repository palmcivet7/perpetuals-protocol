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

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 internal constant PRICE_FEED_PRECISION = 10 ** 8; // 1e8
    uint256 internal constant WAD_PRECISION = 10 ** 18; // 1e18
    uint256 internal constant SCALING_FACTOR = WAD_PRECISION / PRICE_FEED_PRECISION;
    uint256 internal constant USDC_PRECISION = 10 ** 6; // 1e6
    /// @dev The size of a position can be 20x the collateral, but exceeding this results in liquidation
    uint256 internal constant MAX_LEVERAGE = 20;

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

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _priceFeed, address _usdc, address _vault)
        revertIfZeroAddress(_priceFeed)
        revertIfZeroAddress(_usdc)
        revertIfZeroAddress(_vault)
    {
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

    function increaseSize() external {}

    function increaseCollateral() external {}

    function decreaseSize() external {}

    function decreaseCollateral() external {}

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _isMaxLeverageExceeded(uint256 _positionId) internal returns (bool) {
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
        uint256 sizeInUsd = (position.sizeInToken * currentPrice) / PRECISION;
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
    function getLatestPrice() public view returns (uint256) {
        (, int256 price,,,) = i_priceFeed.latestRoundData();
        return uint256(price) * SCALING_FACTOR;
    }

    function getPositionPnl(uint256 _positionId) public view returns (int256) {}

    function getAvailableLiquidity() public view returns (uint256) {}
}
