// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {Vault, CCIPVaultManager} from "../src/Vault.sol";

// These contracts will be deployed to Arbitrum Sepolia
contract DeployVault is Script {
    address constant CCIP_ROUTER_ARB_SEP = 0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165;
    address constant LINK_TOKEN_ARB_SEP = 0xb1D4538B4571d411F07960EF2838Ce337FE1E80E;
    address constant USDC_TOKEN_ARB_SEP = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;
    address constant ETHUSD_CHAINLINK_PRICEFEED_ARB_SEP = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;
    address constant PYTH_PRICEFEED_ARB_SEP = 0x4374e5a8b9C22271E9EB878A2AA31DE97DF15DAF;
    bytes32 constant ETHUSD_PYTH_FEED_ID = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;

    function run() external returns (Vault, CCIPVaultManager) {
        vm.startBroadcast();
        Vault vault = new Vault(
            CCIP_ROUTER_ARB_SEP,
            LINK_TOKEN_ARB_SEP,
            USDC_TOKEN_ARB_SEP,
            ETHUSD_CHAINLINK_PRICEFEED_ARB_SEP,
            PYTH_PRICEFEED_ARB_SEP,
            ETHUSD_PYTH_FEED_ID
        );
        CCIPVaultManager vaultManager = CCIPVaultManager(vault.getCcipVaultManager());

        vm.stopBroadcast();

        return (vault, vaultManager);
    }
}

// forge script script/DeployVault.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --broadcast --private-key $PRIVATE_KEY

// 0: contract Vault 0xAa829eabEC1ec37033c7eFF60C4527Dcf510E28d
// 1: contract CCIPVaultManager 0xC72F72Cecf4D00E4Cb7c999215c6EAF4A8e61A30
