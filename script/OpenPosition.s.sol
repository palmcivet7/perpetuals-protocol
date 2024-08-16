// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {Positions, CCIPPositionsManager} from "../src/Positions.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract OpenPosition is Script {
    address positionsAddress = 0xAa829eabEC1ec37033c7eFF60C4527Dcf510E28d;
    address usdcAddress = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;

    function run() external {
        vm.startBroadcast();

        // Create an instance of the token contract
        IERC20 token = IERC20(usdcAddress);

        // Approve the contract to spend tokens
        token.approve(positionsAddress, 20000000);

        // Create an instance of the contract
        Positions positions = Positions(positionsAddress);

        positions.openPosition(0.000005 ether, 20000000, true);

        vm.stopBroadcast();
    }
}

// forge script script/OpenPosition.s.sol --broadcast --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
