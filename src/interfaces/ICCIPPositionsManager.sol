// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

interface ICCIPPositionsManager {
    function getTotalLiquidity() external view returns (uint256);

    function approve(uint256 _amount) external;

    function ccipSend(
        uint256 _liquidatedCollateralAmount,
        uint256 _profitAmountRequest,
        address _profitRecipientRequest,
        uint256 _openInterestLongInToken,
        uint256 _openInterestShortInUsd,
        bool _increaseLongInToken,
        bool _increaseShortInUsd
    ) external;
}
