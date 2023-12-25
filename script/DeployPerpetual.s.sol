// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Perpetual} from "../src/Perpetual.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract DeployPerpetual is Script {
    function run() external returns (Perpetual, HelperConfig) {
        HelperConfig config = new HelperConfig();
        (address priceFeed, address vault, address asset) = config.activeNetworkConfig();

        vm.startBroadcast();
        Perpetual perpetual = new Perpetual(priceFeed, vault, asset);
        vm.stopBroadcast();
        return (perpetual, config);
    }
}
