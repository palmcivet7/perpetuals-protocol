// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
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

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/
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

    modifier liquidityDeposited() {
        vm.startPrank(liquidityProvider);
        usdc.approve(address(vault), FIFTY_USDC);
        vault.deposit(FIFTY_USDC, liquidityProvider);
        vm.stopPrank();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             OPEN POSITION
    //////////////////////////////////////////////////////////////*/
    function test_openPosition() public liquidityDeposited {
        uint256 sizeInTokenAmount = 0.5 ether; // half an index token

        vm.startPrank(trader);
        usdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true);
        vm.stopPrank();
    }

    function test_openPosition_reverts_if_max_leverage_exceeded() public liquidityDeposited {
        uint256 sizeInTokenAmount = 2 ether;

        vm.startPrank(trader);
        usdc.approve(address(positions), FIFTY_USDC);
        vm.expectRevert(Positions.Positions__MaxLeverageExceeded.selector);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                             VAULT WITHDRAW
    //////////////////////////////////////////////////////////////*/
    function test_lp_can_withdraw() public liquidityDeposited {
        uint256 maxWithdraw = vault.maxWithdraw(liquidityProvider);
        vm.prank(liquidityProvider);
        vault.withdraw(maxWithdraw, liquidityProvider, liquidityProvider);
    }

    function test_lp_cant_withdraw_reserved_liquidity() public liquidityDeposited {
        uint256 sizeInTokenAmount = 0.01 ether;
        vm.startPrank(trader);
        usdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true);
        vm.stopPrank();

        uint256 availableLiquidityBeforePriceChange = positions.getAvailableLiquidity();
        console.log("availableLiquidityBeforePriceChange:", availableLiquidityBeforePriceChange);

        priceFeed.updateAnswer(5000_00000000);

        uint256 expectedWithdrawnAmount = positions.getAvailableLiquidity();
        console.log("expectedWithdrawnAmount:", expectedWithdrawnAmount);

        assert(availableLiquidityBeforePriceChange != expectedWithdrawnAmount);
        assertGt(availableLiquidityBeforePriceChange, expectedWithdrawnAmount);
        assertGt(expectedWithdrawnAmount, 0);

        uint256 lpBalanceStart = usdc.balanceOf(liquidityProvider);
        uint256 maxWithdraw = vault.maxWithdraw(liquidityProvider);

        vm.prank(liquidityProvider);
        vault.withdraw(maxWithdraw, liquidityProvider, liquidityProvider);

        uint256 lpBalanceEnd = usdc.balanceOf(liquidityProvider);
        uint256 actualWithdrawnAmount = lpBalanceEnd - lpBalanceStart;
        assertEq(expectedWithdrawnAmount, actualWithdrawnAmount);
    }
}
