// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Positions, IPositions} from "../src/Positions.sol";
import {Vault, IVault} from "../src/Vault.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";
import {MockUsdc} from "./mocks/MockUsdc.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";

contract PositionsTest is Test {
    using SignedMath for int256;

    Positions positions;
    Vault vault;
    MockV3Aggregator priceFeed;
    MockUsdc usdc;

    address trader = makeAddr("trader");
    address liquidityProvider = makeAddr("liquidityProvider");
    address liquidator = makeAddr("liquidator");

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

    /*//////////////////////////////////////////////////////////////
                             INCREASE SIZE
    //////////////////////////////////////////////////////////////*/
    function test_increaseSize() public liquidityDeposited {
        uint256 sizeInTokenAmount = 0.25 ether;

        vm.startPrank(trader);
        usdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true);

        uint256 sizeToIncrease = 0.25 ether;
        positions.increaseSize(1, sizeToIncrease);

        vm.stopPrank();
    }

    function test_increaseSize_reverts_if_max_leverage_exceeded() public liquidityDeposited {
        uint256 sizeInTokenAmount = 0.25 ether;
        vm.startPrank(trader);
        usdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true);

        uint256 sizeToIncrease = 10e18;
        vm.expectRevert(Positions.Positions__MaxLeverageExceeded.selector);
        positions.increaseSize(1, sizeToIncrease);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                          INCREASE COLLATERAL
    //////////////////////////////////////////////////////////////*/
    function test_increaseCollateral() public {
        uint256 sizeInTokenAmount = 0.5 ether;
        usdc.mint(trader, FIFTY_USDC);

        vm.startPrank(trader);
        usdc.approve(address(positions), FIFTY_USDC * 2);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true);

        (,,, uint256 collateralAmount,,) = positions.getPositionData(1);

        assertEq(collateralAmount, FIFTY_USDC);

        positions.increaseCollateral(1, FIFTY_USDC);
        vm.stopPrank();

        (,,, uint256 collateralAmountAfter,,) = positions.getPositionData(1);
        assertEq(collateralAmountAfter, FIFTY_USDC * 2);
    }

    /*//////////////////////////////////////////////////////////////
                          DECREASE COLLATERAL
    //////////////////////////////////////////////////////////////*/
    function test_decreaseCollateral() public {
        uint256 sizeInTokenAmount = 0.01 ether;

        vm.startPrank(trader);
        usdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true);

        (,,, uint256 collateralAmount,,) = positions.getPositionData(1);

        assertEq(collateralAmount, FIFTY_USDC);

        positions.decreaseCollateral(1, FIFTY_USDC / 4);
        vm.stopPrank();

        (,,, uint256 collateralAmountAfter,,) = positions.getPositionData(1);
        assertEq(collateralAmountAfter, collateralAmount - (FIFTY_USDC / 4));
    }

    function test_decreaseCollateral_reverts_if_max_leverage_exceeded() public {
        uint256 sizeInTokenAmount = 0.01 ether;

        vm.startPrank(trader);
        usdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true);

        (,,, uint256 collateralAmount,,) = positions.getPositionData(1);

        assertEq(collateralAmount, FIFTY_USDC);

        priceFeed.updateAnswer(1000_00000000);

        vm.expectRevert(Positions.Positions__MaxLeverageExceeded.selector);
        positions.decreaseCollateral(1, FIFTY_USDC);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                      DECREASE SIZE/CLOSE POSITION
    //////////////////////////////////////////////////////////////*/
    function test_decreaseSize_no_pnl() public liquidityDeposited {
        uint256 sizeInTokenAmount = 0.5 ether;

        vm.startPrank(trader);
        usdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true);

        (, uint256 sizeInTokenStart,,,,) = positions.getPositionData(1);
        assertEq(sizeInTokenStart, sizeInTokenAmount);
        uint256 startingBalance = usdc.balanceOf(trader);

        uint256 sizeToDecrease = 0.5 ether;
        positions.decreaseSize(1, sizeToDecrease);

        vm.stopPrank();

        (, uint256 sizeInTokenEnd,,,,) = positions.getPositionData(1);

        assertEq(sizeInTokenEnd, 0);
        uint256 endingBalance = usdc.balanceOf(trader);
        assertEq(endingBalance, startingBalance + FIFTY_USDC);
    }

    function test_close_position_in_profit() public liquidityDeposited {
        uint256 sizeInTokenAmount = 0.01 ether;

        vm.startPrank(trader);
        usdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true);

        (, uint256 sizeInTokenStart,,,,) = positions.getPositionData(1);
        assertEq(sizeInTokenStart, sizeInTokenAmount);
        uint256 startingBalance = usdc.balanceOf(trader);
        uint256 startingTotalCollateral = positions.getTotalCollateral();

        priceFeed.updateAnswer(7000_00000000);

        uint256 sizeToDecrease = 0.01 ether;
        positions.decreaseSize(1, sizeToDecrease);

        vm.stopPrank();

        (, uint256 sizeInTokenEnd,,,,) = positions.getPositionData(1);
        uint256 endingBalance = usdc.balanceOf(trader);
        uint256 endingTotalCollateral = positions.getTotalCollateral();
        assertEq(sizeInTokenEnd, 0);
        assertEq(endingBalance, startingBalance + (FIFTY_USDC * 2));
        assertLt(endingTotalCollateral, startingTotalCollateral);
    }

    function test_decreaseSize_in_profit() public liquidityDeposited {
        uint256 sizeInTokenAmount = 0.02 ether;

        vm.startPrank(trader);
        usdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true);

        (, uint256 sizeInTokenStart,,,,) = positions.getPositionData(1);
        assertEq(sizeInTokenStart, sizeInTokenAmount);
        uint256 startingBalance = usdc.balanceOf(trader);

        priceFeed.updateAnswer(3000_00000000);

        uint256 sizeToDecrease = 0.01 ether;
        positions.decreaseSize(1, sizeToDecrease);
        vm.stopPrank();

        (, uint256 sizeInTokenEnd,,,,) = positions.getPositionData(1);
        uint256 endingBalance = usdc.balanceOf(trader);

        assertEq(sizeInTokenEnd, sizeInTokenStart - sizeToDecrease);
        assertEq(endingBalance, startingBalance + (FIFTY_USDC / 5));
    }

    function test_close_position_in_loss() public liquidityDeposited {
        uint256 sizeInTokenAmount = 0.5 ether;

        vm.startPrank(trader);
        usdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true);

        uint256 startingBalance = usdc.balanceOf(trader);

        priceFeed.updateAnswer(1000_00000000);

        positions.decreaseSize(1, sizeInTokenAmount);
        vm.stopPrank();

        (, uint256 sizeInTokenEnd,,,,) = positions.getPositionData(1);
        uint256 endingBalance = usdc.balanceOf(trader);
        assertEq(sizeInTokenEnd, 0);
        assertEq(endingBalance, startingBalance);
    }

    function test_decreaseSize_in_loss() public liquidityDeposited {
        uint256 sizeInTokenAmount = 0.5 ether;

        vm.startPrank(trader);
        usdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true);

        uint256 startingBalance = usdc.balanceOf(trader);

        priceFeed.updateAnswer(1700_00000000);

        (, uint256 sizeInToken,, uint256 collateralStart,,) = positions.getPositionData(1);

        uint256 sizeToDecrease = 0.01 ether;

        int256 pnl = positions.getPositionPnl(1);
        int256 realisedPnl = (pnl * int256(sizeToDecrease)) / int256(sizeInToken);
        uint256 negativeRealisedPnl = uint256(realisedPnl.abs());
        uint256 negativeRealisedPnlScaledToUsdc = negativeRealisedPnl / (1e18 / 1e6);

        positions.decreaseSize(1, sizeToDecrease);
        vm.stopPrank();

        (, uint256 sizeInTokenEnd,, uint256 collateralEnd,,) = positions.getPositionData(1);
        uint256 endingBalance = usdc.balanceOf(trader);

        assertGt(sizeInTokenEnd, 0);
        assertEq(collateralEnd, collateralStart - negativeRealisedPnlScaledToUsdc);
        assertEq(endingBalance, startingBalance);
    }

    /*//////////////////////////////////////////////////////////////
                               LIQUIDATE
    //////////////////////////////////////////////////////////////*/
    function test_liquidate_reverts_if_max_leverage_not_exceeded() public liquidityDeposited {
        uint256 sizeInTokenAmount = 0.25 ether;

        vm.startPrank(trader);
        usdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true);
        vm.stopPrank();

        vm.prank(liquidator);
        vm.expectRevert(Positions.Positions__MaxLeverageNotExceeded.selector);
        positions.liquidate(1);
    }

    function test_liquidate_works() public liquidityDeposited {
        uint256 sizeInTokenAmount = 0.5 ether;

        vm.startPrank(trader);
        usdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true);
        vm.stopPrank();

        priceFeed.updateAnswer(1950_00000000);

        int256 pnl = positions.getPositionPnl(1);
        (,,, uint256 collateral,,) = positions.getPositionData(1);
        uint256 negativePnl = uint256(pnl.abs());
        uint256 negativePnlScaledToUsdc = negativePnl / (1e18 / 1e6);
        assertGt(collateral, negativePnlScaledToUsdc);
        uint256 remainingCollateral = collateral - negativePnlScaledToUsdc;
        uint256 expectedReward = (remainingCollateral * 2000) / 10000;

        uint256 liquidatorStartingBalance = usdc.balanceOf(liquidator);

        vm.prank(liquidator);
        positions.liquidate(1);

        uint256 liquidatorEndingBalance = usdc.balanceOf(liquidator);

        assertGt(liquidatorEndingBalance, liquidatorStartingBalance);
        assertEq(liquidatorEndingBalance, expectedReward);
    }
}
