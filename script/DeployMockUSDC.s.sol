// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

contract DeployMockUSDC is Script {
    function run() external returns (MockUSDC) {
        vm.startBroadcast();
        MockUSDC mockUsdc = new MockUSDC();
        vm.stopBroadcast();
        return (mockUsdc);
    }
}
