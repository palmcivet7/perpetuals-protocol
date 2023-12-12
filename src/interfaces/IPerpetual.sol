// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IPerpetual {
    function getTotalPnL() external view returns (int256);

    function getAvailableLiquidity() external view returns (uint256);
}
