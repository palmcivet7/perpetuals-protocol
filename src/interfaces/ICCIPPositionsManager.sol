// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

interface ICCIPPositionsManager {
    function getTotalLiquidity() external view returns (uint256);

    function approve(uint256 _amount) external;
}
