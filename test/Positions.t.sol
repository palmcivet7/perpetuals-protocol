// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Positions, IPositions} from "../src/Positions.sol";
import {Vault, IVault} from "../src/Vault.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";
import {MockUsdc} from "./mocks/MockUsdc.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {CCIPLocalSimulatorFork} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {CCIPPositionsManager} from "../src/CCIPPositionsManager.sol";
import {CCIPVaultManager} from "../src/CCIPVaultManager.sol";
import {BurnMintERC677Helper} from "@chainlink-local/src/ccip/CCIPLocalSimulator.sol";
import {Register} from "@chainlink-local/src/ccip/Register.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PositionsTest is Test {
    using SignedMath for int256;

    Positions positions;
    Vault vault;
    CCIPPositionsManager positionsManager;
    CCIPVaultManager vaultManager;
    MockV3Aggregator arbPriceFeed;
    MockV3Aggregator basePriceFeed;
    BurnMintERC677Helper arbUsdc;
    BurnMintERC677Helper baseUsdc;

    CCIPLocalSimulatorFork ccipLocalSimulatorFork;
    uint256 arbitrumFork;
    uint256 baseFork;

    address trader = makeAddr("trader");
    address liquidityProvider = makeAddr("liquidityProvider");
    address liquidator = makeAddr("liquidator");
    address usdcMinter = makeAddr("usdcMinter");

    uint256 constant FIFTY_USDC = 50_000_000;
    uint256 constant ONE_USDC = 1_000_000;
    uint256 constant WAD = 1e18;
    uint256 constant FIFTY_LINK = 50 * 1e18;

    uint256 constant ARB_SEPOLIA_CHAINID = 421614;
    uint256 constant BASE_SEPOLIA_CHAINID = 84532;

    Register.NetworkDetails arbSepNetworkDetails;
    Register.NetworkDetails baseSepNetworkDetails;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public {
        // Create Arbitrum and Base networks
        string memory ARBITRUM_SEPOLIA_RPC_URL = vm.envString("ARBITRUM_SEPOLIA_RPC_URL");
        string memory BASE_SEPOLIA_RPC_URL = vm.envString("BASE_SEPOLIA_RPC_URL");
        arbitrumFork = vm.createSelectFork(ARBITRUM_SEPOLIA_RPC_URL);
        baseFork = vm.createFork(BASE_SEPOLIA_RPC_URL);

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        arbSepNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(ARB_SEPOLIA_CHAINID);
        baseSepNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(BASE_SEPOLIA_CHAINID);

        // Deploy Vault on Arbitrum
        arbPriceFeed = new MockV3Aggregator(8, 2000_00000000);
        vault = new Vault(
            arbSepNetworkDetails.routerAddress,
            arbSepNetworkDetails.linkAddress,
            arbSepNetworkDetails.ccipBnMAddress,
            address(arbPriceFeed)
        );
        vaultManager = CCIPVaultManager(vault.getCcipVaultManager());

        // Send LINK to VaultManager for ccip fees
        deal(arbSepNetworkDetails.linkAddress, address(vaultManager), FIFTY_LINK);
        assertEq(IERC20(arbSepNetworkDetails.linkAddress).balanceOf(address(vaultManager)), FIFTY_LINK);

        // Send USDC to liquidityProvider
        deal(arbSepNetworkDetails.ccipBnMAddress, liquidityProvider, FIFTY_USDC);
        assertEq(IERC20(arbSepNetworkDetails.ccipBnMAddress).balanceOf(liquidityProvider), FIFTY_USDC);
        arbUsdc = BurnMintERC677Helper(arbSepNetworkDetails.ccipBnMAddress);

        // Switch to Base and deploy Positions
        vm.selectFork(baseFork);
        basePriceFeed = new MockV3Aggregator(8, 2000_00000000);
        positions = new Positions(
            baseSepNetworkDetails.routerAddress,
            baseSepNetworkDetails.linkAddress,
            baseSepNetworkDetails.ccipBnMAddress,
            address(basePriceFeed)
        );
        positionsManager = CCIPPositionsManager(positions.getCcipPositionsManager());

        // Send LINK to PositionsManager for ccip fees
        deal(baseSepNetworkDetails.linkAddress, address(positionsManager), FIFTY_LINK);
        assertEq(IERC20(baseSepNetworkDetails.linkAddress).balanceOf(address(positionsManager)), FIFTY_LINK);

        // Send USDC to trader
        deal(baseSepNetworkDetails.ccipBnMAddress, trader, FIFTY_USDC);
        assertEq(IERC20(baseSepNetworkDetails.ccipBnMAddress).balanceOf(trader), FIFTY_USDC);
        baseUsdc = BurnMintERC677Helper(baseSepNetworkDetails.ccipBnMAddress);

        // Set VaultManager address and chain selector as allowed in PositionsManager on Base
        vm.prank(positionsManager.owner());
        positionsManager.setVaultManagerChainSelector(arbSepNetworkDetails.chainSelector);
        vm.prank(positionsManager.owner());
        positionsManager.setVaultManagerAddress(address(vaultManager));

        // Set PositionsManager address and chain selector as allowed in VaultManager on Arbitrum
        vm.selectFork(arbitrumFork);
        vm.prank(vaultManager.owner());
        vaultManager.setPositionsManagerChainSelector(baseSepNetworkDetails.chainSelector);
        vm.prank(vaultManager.owner());
        vaultManager.setPositionsManagerAddress(address(positionsManager));
    }

    function test_setUp() public liquidityDeposited {}

    modifier liquidityDeposited() {
        vm.selectFork(arbitrumFork);
        vm.startPrank(liquidityProvider);
        arbUsdc.approve(address(vault), FIFTY_USDC);
        vault.deposit(FIFTY_USDC, liquidityProvider);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(baseFork);
        assertEq(positionsManager.getTotalLiquidity(), FIFTY_USDC);
        vm.stopPrank();
        vm.selectFork(baseFork);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             OPEN POSITION
    //////////////////////////////////////////////////////////////*/
    function test_openPosition() public liquidityDeposited {
        uint256 sizeInTokenAmount = 0.5 ether; // half an index token

        vm.startPrank(trader);
        baseUsdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumFork);
        assertEq(vaultManager.getOpenInterestLongInToken(), sizeInTokenAmount);
        vm.stopPrank();
    }

    function test_openPosition_reverts_if_max_leverage_exceeded() public liquidityDeposited {
        uint256 sizeInTokenAmount = 2 ether;

        vm.startPrank(trader);
        baseUsdc.approve(address(positions), FIFTY_USDC);
        vm.expectRevert(Positions.Positions__MaxLeverageExceeded.selector);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                             VAULT WITHDRAW
    //////////////////////////////////////////////////////////////*/
    function test_lp_can_withdraw() public liquidityDeposited {
        vm.selectFork(arbitrumFork);
        uint256 maxWithdraw = vault.maxWithdraw(liquidityProvider);
        vm.prank(liquidityProvider);
        vault.withdraw(maxWithdraw, liquidityProvider, liquidityProvider);
    }

    function test_lp_cant_withdraw_reserved_liquidity() public liquidityDeposited {
        uint256 sizeInTokenAmount = 0.01 ether;
        vm.startPrank(trader);
        baseUsdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumFork);
        vm.stopPrank();

        vm.selectFork(baseFork);
        uint256 availableLiquidityBeforePriceChange = positions.getAvailableLiquidity();
        uint256 initialRecordedLiquidity = positionsManager.getTotalLiquidity();

        basePriceFeed.updateAnswer(3500_00000000);
        vm.selectFork(arbitrumFork);
        arbPriceFeed.updateAnswer(3500_00000000);

        uint256 expectedWithdrawnAmount = vaultManager.getAvailableLiquidity();

        assert(availableLiquidityBeforePriceChange != expectedWithdrawnAmount);
        assertGt(availableLiquidityBeforePriceChange, expectedWithdrawnAmount);
        assertGt(expectedWithdrawnAmount, 0);

        uint256 lpBalanceStart = arbUsdc.balanceOf(liquidityProvider);
        uint256 maxWithdraw = vault.maxWithdraw(liquidityProvider);

        vm.prank(liquidityProvider);
        vault.withdraw(maxWithdraw, liquidityProvider, liquidityProvider);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(baseFork);
        uint256 endingRecordedLiquidity = positionsManager.getTotalLiquidity();

        vm.selectFork(arbitrumFork);
        uint256 lpBalanceEnd = arbUsdc.balanceOf(liquidityProvider);
        uint256 actualWithdrawnAmount = lpBalanceEnd - lpBalanceStart;
        assertEq(expectedWithdrawnAmount, actualWithdrawnAmount);
        assertGt(initialRecordedLiquidity, endingRecordedLiquidity);
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
