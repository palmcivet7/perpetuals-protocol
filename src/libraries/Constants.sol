// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

library Constants {
    uint256 internal constant PRICE_FEED_PRECISION = 10 ** 8; // 1e8
    uint256 internal constant WAD_PRECISION = 10 ** 18; // 1e18
    uint256 internal constant SCALING_FACTOR = WAD_PRECISION / PRICE_FEED_PRECISION;
    uint256 internal constant USDC_PRECISION = 10 ** 6; // 1e6
    /// @dev The size of a position can be 20x the collateral, but exceeding this results in liquidation
    uint256 internal constant MAX_LEVERAGE = 20;
    /// @dev Traders cannot utilize more than a configured percentage of the deposited liquidity
    uint256 internal constant MAX_UTILIZATION_PERCENTAGE = 8000;
    uint256 internal constant BASIS_POINT_DIVISOR = 10000;
    uint256 internal constant LIQUIDATION_BONUS = 2000;
    int256 internal constant INT_PRECISION = 10 ** 18;
    uint256 internal constant CCIP_GAS_LIMIT = 500_000;
}
