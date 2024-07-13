// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {Positions, CCIPPositionsManager} from "../src/Positions.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SetPositionsPermissions is Script {
    function run() external {
        // Positions: 0xAa829eabEC1ec37033c7eFF60C4527Dcf510E28d
        // CCIPPositionsManager: 0xC72F72Cecf4D00E4Cb7c999215c6EAF4A8e61A30
        address positionsAddress = 0xAa829eabEC1ec37033c7eFF60C4527Dcf510E28d;
        address positionsManagerAddress = 0xC72F72Cecf4D00E4Cb7c999215c6EAF4A8e61A30;
        address vaultManagerAddress = 0x88F32280155046f54c24fa0Dd0d176E4e0Ccad7A;

        // Start broadcasting the transaction
        vm.startBroadcast();

        // Create an instance of the vault manager contract
        CCIPPositionsManager positionsManager = CCIPPositionsManager(positionsManagerAddress);

        positionsManager.setVaultManagerChainSelector(3478487238524512106); // arbitrum chain selector
        positionsManager.setVaultManagerAddress(vaultManagerAddress);

        // Stop broadcasting the transaction
        vm.stopBroadcast();
    }
}

// forge script script/SetPositionsPermissions.s.sol --broadcast --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
