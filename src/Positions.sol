// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IPositions} from "./interfaces/IPositions.sol";
import {IVault} from "./interfaces/IVault.sol";

contract Positions is IPositions, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/
    using SafeERC20 for IERC20;

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

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event PositionOpened();

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
        i_vault = IVault(_vault);
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

        // update collateral
        // increase open interest

        /// @dev revert if max leverage exceeded
        if (_isMaxLeverageExceeded(positionId)) revert Positions__MaxLeverageExceeded();

        emit PositionOpened();

        // transfer usdc from trader to vault
    }

    function increaseSize() external {}

    function increaseCollateral() external {}

    function decreaseSize() external {}

    function decreaseCollateral() external {}

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _isMaxLeverageExceeded(uint256 _positionId) internal returns (bool) {}

    /*//////////////////////////////////////////////////////////////
                                 GETTER
    //////////////////////////////////////////////////////////////*/
    function getLatestPrice() public view returns (uint256) {
        (, int256 price,,,) = i_priceFeed.latestRoundData();
        return uint256(price) * SCALING_FACTOR;
    }
}
