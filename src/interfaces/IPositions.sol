// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

interface IPositions {
    function getAvailableLiquidity() external view returns (uint256);

    function getPositionsCount() external view returns (uint256);

    function getMaxLeverageExceeded(uint256 _positionId) external view returns (bool);
}
