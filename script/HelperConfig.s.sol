// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {Vault} from "../src/Vault.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address priceFeed;
        address vault;
        address collateralAsset;
    }

    NetworkConfig public activeNetworkConfig;

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({priceFeed: address(0), vault: address(0), collateralAsset: address(0)});
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        MockUSDC mockUsdc = new MockUSDC();
        Vault vault = new Vault(IERC20(mockUsdc));
        return NetworkConfig({
            priceFeed: address(ethUsdPriceFeed),
            vault: address(vault),
            collateralAsset: address(mockUsdc)
        });
    }
}
