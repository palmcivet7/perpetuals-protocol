// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IPositions} from "./interfaces/IPositions.sol";

contract Positions is IPositions {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error Positions__NoZeroAddress();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @dev Chainlink PriceFeed for the token being speculated on
    AggregatorV3Interface internal immutable i_priceFeed;
    /// @dev USDC is the token used for liquidity and collateral
    IERC20 internal immutable i_usdc;

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

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier revertIfZeroAddress(address _address) {
        if (_address == address(0)) revert Positions__NoZeroAddress();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _priceFeed, address _usdc) revertIfZeroAddress(_priceFeed) revertIfZeroAddress(_usdc) {
        i_priceFeed = AggregatorV3Interface(_priceFeed);
        i_usdc = IERC20(_usdc);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function openPosition() external {}

    function increaseSize() external {}

    function increaseCollateral() external {}

    function decreaseSize() external {}

    function decreaseCollateral() external {}

    /*//////////////////////////////////////////////////////////////
                                 GETTER
    //////////////////////////////////////////////////////////////*/
    function getLatestPrice() external view returns (uint256) {}
}
