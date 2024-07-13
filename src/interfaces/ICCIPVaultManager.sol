// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

interface ICCIPVaultManager {
    function ccipSend(uint256 _liquidityAmount, bool _isDeposit, uint256 _profitAmount, address _profitRecipient)
        external;

    function getAvailableLiquidity() external view returns (uint256);
}
