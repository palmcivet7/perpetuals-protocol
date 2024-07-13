// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

interface IVault {
    function totalAssets() external view returns (uint256);

    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);

    function maxWithdraw(address owner) external returns (uint256);

    function approve(uint256 _amount) external;
}
