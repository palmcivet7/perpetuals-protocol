// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

interface IPositions {
    struct Position {
        address trader;
        uint256 sizeInToken;
        uint256 sizeInUsd;
        uint256 collateralAmount;
        uint256 openPrice;
        bool isLong;
    }

    function getAvailableLiquidity() external view returns (uint256);

    function getPositionsCount() external view returns (uint256);

    function getMaxLeverageExceeded(uint256 _positionId) external view returns (bool);

    function liquidate(uint256 _positionId) external;
}
