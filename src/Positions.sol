// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IPositions} from "./interfaces/IPositions.sol";

contract Positions is IPositions {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    AggregatorV3Interface internal immutable i_priceFeed;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _priceFeed) {
        i_priceFeed = AggregatorV3Interface(_priceFeed);
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
