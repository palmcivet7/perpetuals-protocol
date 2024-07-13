// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Vault, CCIPVaultManager} from "../src/Vault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DepositScript is Script {
    function run() external {
        uint256 assets = 10000000;
        address receiver = 0xBd163Be148Fd89424ef67B6D8153d9AeD85C1377;
        address contractAddress = 0x88F32280155046f54c24fa0Dd0d176E4e0Ccad7A;
        address tokenAddress = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;
        address vaultManagerAddress = 0x3EBFE1f7D17c8F6B3fC8Dc5424aE9aaECb227EA3;
        address positionsManagerAddress = 0xC72F72Cecf4D00E4Cb7c999215c6EAF4A8e61A30;

        // Start broadcasting the transaction
        vm.startBroadcast();

        // // Create an instance of the vault manager contract
        // CCIPVaultManager vaultManager = CCIPVaultManager(vaultManagerAddress);

        // vaultManager.setPositionsManagerChainSelector(10344971235874465080); // Base Sepolia Chain Selector
        // vaultManager.setPositionsManagerAddress(positionsManagerAddress);

        // Create an instance of the token contract
        IERC20 token = IERC20(tokenAddress);

        // Approve the contract to spend tokens
        token.approve(contractAddress, assets);

        // Create an instance of the contract
        Vault contractInstance = Vault(contractAddress);

        // Call the deposit function
        contractInstance.deposit(assets, receiver);

        // Stop broadcasting the transaction
        vm.stopBroadcast();
    }
}

// forge script script/DepositScript.s.sol --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
