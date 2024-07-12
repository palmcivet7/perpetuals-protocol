// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {IPositions} from "./interfaces/IPositions.sol";

contract Positions is IPositions {
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
