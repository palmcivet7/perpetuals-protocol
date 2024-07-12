// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Positions, IPositions} from "../src/Positions.sol";
import {Vault, IVault} from "../src/Vault.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";
import {MockUsdc} from "./mocks/MockUsdc.sol";

contract PositionsTest is Test {
    Positions positions;
    Vault vault;
    MockV3Aggregator priceFeed;
    MockUsdc usdc;

    address trader = makeAddr("trader");
    address liquidityProvider = makeAddr("liquidityProvider");

    uint256 constant FIFTY_USDC = 50_000_000;
    uint256 constant ONE_USDC = 1_000_000;
    uint256 constant WAD = 1e18;

    function setUp() public {
        usdc = new MockUsdc();
        priceFeed = new MockV3Aggregator(8, 2000_00000000); // index tokens are initially worth $2k
        (, int256 initialPrice,,,) = priceFeed.latestRoundData();
        assertEq(initialPrice, 2000_00000000);
        usdc.mint(liquidityProvider, FIFTY_USDC);
        usdc.mint(trader, FIFTY_USDC);
        positions = new Positions(address(priceFeed), address(usdc));
        vault = Vault(address(positions.getVault()));
    }

    function test_constructor() public {}
}
