// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {Positions, CCIPPositionsManager} from "../src/Positions.sol";

// These contracts will be deployed to Base Sepolia
contract DeployPositions is Script {
    address constant CCIP_ROUTER_BASE_SEP = 0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93;
    uint64 BASE_SEP_CHAIN_SELECTOR = 10344971235874465080;
    address constant LINK_TOKEN_BASE_SEP = 0xE4aB69C077896252FAFBD49EFD26B5D171A32410;
    address constant USDC_TOKEN_BASE_SEP = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address constant WETH_TOKEN_BASE_SEP = 0x4200000000000000000000000000000000000006;
    address constant ETHUSD_CHAINLINK_PRICEFEED = 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1;
    address constant WORLD_ID_BASE_SEP = 0x42FF98C4E85212a5D31358ACbFe76a621b50fC02;
    string constant WORLD_ID_APP_ID = "app_staging_704615d1d9d9dba9a0b556954779d3ae";
    string constant WORLD_ID_ACTION_ID = "openPosition";

    function run() external returns (Positions, CCIPPositionsManager) {
        vm.startBroadcast();
        Positions positions = new Positions(
            CCIP_ROUTER_BASE_SEP,
            LINK_TOKEN_BASE_SEP,
            USDC_TOKEN_BASE_SEP,
            ETHUSD_CHAINLINK_PRICEFEED,
            WORLD_ID_BASE_SEP,
            WORLD_ID_APP_ID,
            WORLD_ID_ACTION_ID
        );
        CCIPPositionsManager positionsManager = CCIPPositionsManager(positions.getCcipPositionsManager());

        vm.stopBroadcast();

        return (positions, positionsManager);
    }
}

// forge script script/DeployPositions.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --private-key $PRIVATE_KEY

// Positions: 0xAa829eabEC1ec37033c7eFF60C4527Dcf510E28d
// CCIPPositionsManager: 0xC72F72Cecf4D00E4Cb7c999215c6EAF4A8e61A30
