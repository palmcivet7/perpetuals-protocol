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

    event PositionOpened(address, Position);
    event PositionSizeIncreased(address, Position, uint256 sizeIncrease);
    event CollateralIncreased(address, Position, uint256 collateralIncrease);

    using SafeERC20 for IERC20;

    uint256 public constant MAX_LEVERAGE = 20;

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

    /////////////////////
    ////// User ////////
    ///////////////////

    function openPosition(uint256 _size, uint256 _collateralAmount, bool _isLong)
        external
        noZeroValue(_size)
        noZeroValue(_collateralAmount)
    {
        uint256 leverage = _size / _collateralAmount;
        if (leverage > MAX_LEVERAGE) revert Perpetual__MaxLeverageExceeded();

        uint256 currentPrice = getLatestPrice();

        s_positions[msg.sender] =
            Position({size: _size, collateralAmount: _collateralAmount, openPrice: currentPrice, isLong: _isLong});

        i_collateralToken.safeTransferFrom(msg.sender, address(i_vault), _collateralAmount);
        emit PositionOpened(msg.sender, s_positions[msg.sender]);
    }

    function increaseSize(uint256 _additionalSize) external noZeroValue(_additionalSize) {
        Position storage position = s_positions[msg.sender];

        if (position.size == 0) revert Perpetual__PositionDoesNotExist();
        uint256 newTotalSize = position.size + _additionalSize;

        uint256 leverage = newTotalSize / position.collateralAmount;
        if (leverage > MAX_LEVERAGE) revert Perpetual__MaxLeverageExceeded();

        position.size = newTotalSize;

        emit PositionSizeIncreased(msg.sender, position, _additionalSize);
    }

    function increaseCollateral(uint256 _additionalCollateral) external noZeroValue(_additionalCollateral) {
        Position storage position = s_positions[msg.sender];

        if (position.size == 0) revert Perpetual__PositionDoesNotExist();

        position.collateralAmount += _additionalCollateral;

        i_collateralToken.safeTransferFrom(msg.sender, address(i_vault), _additionalCollateral);

        emit CollateralIncreased(msg.sender, position, _additionalCollateral);
    }

    /////////////////////
    ////// Getter //////
    ///////////////////

    function getLatestPrice() public view returns (uint256) {
        (, int256 price,,,) = i_priceFeed.latestRoundData();
        return uint256(price);
    }

    function getTotalPnL() public view returns (int256) {}

    function getAvailableLiquidity() public view returns (uint256) {}
}
