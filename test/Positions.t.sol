// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Positions, IPositions} from "../src/Positions.sol";
import {Vault, IVault} from "../src/Vault.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {CCIPLocalSimulatorFork} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {CCIPPositionsManager} from "../src/CCIPPositionsManager.sol";
import {CCIPVaultManager} from "../src/CCIPVaultManager.sol";
import {BurnMintERC677Helper} from "@chainlink-local/src/ccip/CCIPLocalSimulator.sol";
import {Register} from "@chainlink-local/src/ccip/Register.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MockWorldID} from "./mocks/MockWorldID.sol";

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
    MockWorldID mockWorldId;

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

    string constant WORLDID_APP_ID = "app_staging_704615d1d9d9dba9a0b556954779d3ae";
    string constant WORLDID_ACTION_ID = "openPosition";

    uint256 constant WORLDID_ROOT = 0x231c157755ced1799aeb4e74149eaf576b0838c40c70cbb3aa803cb4ee860760;
    uint256 constant WORLDID_NULLIFIER_HASH = 1;
    uint256[8] WORLDID_PROOF = [
        0x29cddd130f81c1a0abd4b1077c82e556fe9e6a7d8915baac867dd6392e03fc10,
        0x1fabf9e4a1b45abcb1580565c9d615c8616ad588b1a01ade07a00ff7d965442b,
        0x23ccc263123e8cd76ea7773c6d4eddc2d4f7b4feba213f85dfb56070e42a87b7,
        0x226b40abc0db1a9fa7c8a440e30ca321639df97c844d1a1d385d3e3073e805a0,
        0x13779875425d9baa6f71597fe9ac21e3c0ef35b27802068c5528ed28231c050c,
        0x68e7081aa8912a70d404f5ac668709898e496e79af27a41228f94ee501f2f84,
        0x249471298db747c1e1e7388bb41e58ec2d541bdd6eee00be3b6ce9f02977df90,
        0x19ce330c2870c52b0855be468f9bc91e8bb6b6c0e26545363b1be467f92eb40e
    ];

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
        mockWorldId = new MockWorldID();
        positions = new Positions(
            baseSepNetworkDetails.routerAddress,
            baseSepNetworkDetails.linkAddress,
            baseSepNetworkDetails.ccipBnMAddress,
            address(basePriceFeed),
            address(mockWorldId),
            WORLDID_APP_ID,
            WORLDID_ACTION_ID
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
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true, WORLDID_ROOT, WORLDID_NULLIFIER_HASH, WORLDID_PROOF);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumFork);
        assertEq(vaultManager.getOpenInterestLongInToken(), sizeInTokenAmount);
        vm.stopPrank();
    }

    function test_openPosition_reverts_if_max_leverage_exceeded() public liquidityDeposited {
        uint256 sizeInTokenAmount = 2 ether;

        vm.startPrank(trader);
        baseUsdc.approve(address(positions), FIFTY_USDC);
        vm.expectRevert(Positions.Positions__MaxLeverageExceeded.selector);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true, WORLDID_ROOT, WORLDID_NULLIFIER_HASH, WORLDID_PROOF);
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
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true, WORLDID_ROOT, WORLDID_NULLIFIER_HASH, WORLDID_PROOF);
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
        baseUsdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true, WORLDID_ROOT, WORLDID_NULLIFIER_HASH, WORLDID_PROOF);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumFork);
        vm.stopPrank();

        vm.selectFork(baseFork);
        uint256 sizeToIncrease = 0.25 ether;
        vm.prank(trader);
        positions.increaseSize(1, sizeToIncrease);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumFork);
        assertEq(vaultManager.getOpenInterestLongInToken(), sizeInTokenAmount + sizeToIncrease);
    }

    function test_increaseSize_reverts_if_max_leverage_exceeded() public liquidityDeposited {
        uint256 sizeInTokenAmount = 0.25 ether;
        vm.startPrank(trader);
        baseUsdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true, WORLDID_ROOT, WORLDID_NULLIFIER_HASH, WORLDID_PROOF);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumFork);
        vm.stopPrank();

        vm.selectFork(baseFork);
        uint256 sizeToIncrease = 10e18;
        vm.prank(trader);
        vm.expectRevert(Positions.Positions__MaxLeverageExceeded.selector);
        positions.increaseSize(1, sizeToIncrease);
    }

    /*//////////////////////////////////////////////////////////////
                          INCREASE COLLATERAL
    //////////////////////////////////////////////////////////////*/
    function test_increaseCollateral() public liquidityDeposited {
        uint256 sizeInTokenAmount = 0.25 ether;

        vm.startPrank(trader);
        baseUsdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(
            sizeInTokenAmount, FIFTY_USDC / 2, true, WORLDID_ROOT, WORLDID_NULLIFIER_HASH, WORLDID_PROOF
        );
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumFork);
        vm.stopPrank();

        vm.selectFork(baseFork);
        (,,, uint256 collateralAmount,,) = positions.getPositionData(1);

        assertEq(collateralAmount, FIFTY_USDC / 2);

        vm.prank(trader);
        positions.increaseCollateral(1, FIFTY_USDC / 2);

        (,,, uint256 collateralAmountAfter,,) = positions.getPositionData(1);
        assertEq(collateralAmountAfter, FIFTY_USDC);
    }

    /*//////////////////////////////////////////////////////////////
                          DECREASE COLLATERAL
    //////////////////////////////////////////////////////////////*/
    function test_decreaseCollateral() public liquidityDeposited {
        uint256 sizeInTokenAmount = 0.01 ether;

        vm.startPrank(trader);
        baseUsdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true, WORLDID_ROOT, WORLDID_NULLIFIER_HASH, WORLDID_PROOF);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumFork);
        vm.stopPrank();

        vm.selectFork(baseFork);
        (,,, uint256 collateralAmount,,) = positions.getPositionData(1);

        assertEq(collateralAmount, FIFTY_USDC);

        vm.prank(trader);
        positions.decreaseCollateral(1, FIFTY_USDC / 4);

        (,,, uint256 collateralAmountAfter,,) = positions.getPositionData(1);
        assertEq(collateralAmountAfter, collateralAmount - (FIFTY_USDC / 4));
    }

    function test_decreaseCollateral_reverts_if_max_leverage_exceeded() public liquidityDeposited {
        uint256 sizeInTokenAmount = 0.01 ether;

        vm.startPrank(trader);
        baseUsdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true, WORLDID_ROOT, WORLDID_NULLIFIER_HASH, WORLDID_PROOF);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumFork);
        vm.stopPrank();

        vm.selectFork(baseFork);
        (,,, uint256 collateralAmount,,) = positions.getPositionData(1);

        assertEq(collateralAmount, FIFTY_USDC);

        basePriceFeed.updateAnswer(1000_00000000);
        vm.selectFork(arbitrumFork);
        arbPriceFeed.updateAnswer(1000_00000000);

        vm.selectFork(baseFork);
        vm.prank(trader);
        vm.expectRevert(Positions.Positions__MaxLeverageExceeded.selector);
        positions.decreaseCollateral(1, FIFTY_USDC);
    }

    /*//////////////////////////////////////////////////////////////
                      DECREASE SIZE/CLOSE POSITION
    //////////////////////////////////////////////////////////////*/
    function test_decreaseSize_no_pnl() public liquidityDeposited {
        uint256 sizeInTokenAmount = 0.5 ether;

        vm.startPrank(trader);
        baseUsdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true, WORLDID_ROOT, WORLDID_NULLIFIER_HASH, WORLDID_PROOF);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumFork);
        vm.stopPrank();

        vm.selectFork(baseFork);
        (, uint256 sizeInTokenStart,,,,) = positions.getPositionData(1);
        assertEq(sizeInTokenStart, sizeInTokenAmount);
        uint256 startingBalance = baseUsdc.balanceOf(trader);

        uint256 sizeToDecrease = 0.5 ether;
        vm.prank(trader);
        positions.decreaseSize(1, sizeToDecrease);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumFork);

        vm.selectFork(baseFork);
        (, uint256 sizeInTokenEnd,,,,) = positions.getPositionData(1);

        assertEq(sizeInTokenEnd, 0);
        uint256 endingBalance = baseUsdc.balanceOf(trader);
        assertEq(endingBalance, startingBalance + FIFTY_USDC);
    }

    function test_close_position_in_profit() public liquidityDeposited {
        uint256 sizeInTokenAmount = 0.05 ether;

        vm.startPrank(trader);
        baseUsdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true, WORLDID_ROOT, WORLDID_NULLIFIER_HASH, WORLDID_PROOF);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumFork);
        vm.stopPrank();

        vm.selectFork(baseFork);
        (, uint256 sizeInTokenStart,,,,) = positions.getPositionData(1);
        assertEq(sizeInTokenStart, sizeInTokenAmount);
        uint256 startingBalance = baseUsdc.balanceOf(trader);
        uint256 startingTotalCollateral = positions.getTotalCollateral();

        basePriceFeed.updateAnswer(2500_00000000);
        vm.selectFork(arbitrumFork);
        arbPriceFeed.updateAnswer(2500_00000000);

        uint256 arbUsdcTransferStart = arbUsdc.balanceOf(address(vault));

        vm.selectFork(baseFork);
        uint256 sizeToDecrease = 0.05 ether;
        vm.prank(trader);
        positions.decreaseSize(1, sizeToDecrease);
        /// @dev send instructions for profit to Arbitrum
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumFork);
        /// @dev assert that tokens have left Arbitrum
        uint256 arbUsdcTransferEnd = arbUsdc.balanceOf(address(vault));
        assertGt(arbUsdcTransferStart, arbUsdcTransferEnd);
        /// @dev send tokens from Arbitrum to Base
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumFork);

        vm.selectFork(baseFork);
        (, uint256 sizeInTokenEnd,,,,) = positions.getPositionData(1);
        uint256 endingBalance = baseUsdc.balanceOf(trader);
        uint256 endingTotalCollateral = positions.getTotalCollateral();
        assertEq(sizeInTokenEnd, 0);
        assertEq(endingBalance, startingBalance + (FIFTY_USDC));
        assertLt(endingTotalCollateral, startingTotalCollateral);
    }

    function test_decreaseSize_in_profit() public liquidityDeposited {
        uint256 sizeInTokenAmount = 0.02 ether;

        vm.startPrank(trader);
        baseUsdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true, WORLDID_ROOT, WORLDID_NULLIFIER_HASH, WORLDID_PROOF);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumFork);
        vm.stopPrank();

        vm.selectFork(baseFork);
        (, uint256 sizeInTokenStart,,,,) = positions.getPositionData(1);
        assertEq(sizeInTokenStart, sizeInTokenAmount);
        uint256 startingBalance = baseUsdc.balanceOf(trader);

        basePriceFeed.updateAnswer(2500_00000000);
        vm.selectFork(arbitrumFork);
        arbPriceFeed.updateAnswer(2500_00000000);

        vm.selectFork(baseFork);
        uint256 sizeToDecrease = 0.01 ether;
        vm.prank(trader);
        positions.decreaseSize(1, sizeToDecrease);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumFork);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(baseFork);

        (, uint256 sizeInTokenEnd,,,,) = positions.getPositionData(1);
        uint256 endingBalance = baseUsdc.balanceOf(trader);

        assertEq(sizeInTokenEnd, sizeInTokenStart - sizeToDecrease);
        assertGt(endingBalance, startingBalance);
    }

    function test_close_position_in_loss() public liquidityDeposited {
        uint256 sizeInTokenAmount = 0.5 ether;

        vm.startPrank(trader);
        baseUsdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true, WORLDID_ROOT, WORLDID_NULLIFIER_HASH, WORLDID_PROOF);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumFork);
        vm.stopPrank();

        vm.selectFork(baseFork);
        uint256 startingBalance = baseUsdc.balanceOf(trader);

        basePriceFeed.updateAnswer(1000_00000000);
        vm.selectFork(arbitrumFork);
        arbPriceFeed.updateAnswer(1000_00000000);

        vm.selectFork(baseFork);
        vm.prank(trader);
        positions.decreaseSize(1, sizeInTokenAmount);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumFork);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(baseFork);

        (, uint256 sizeInTokenEnd,,,,) = positions.getPositionData(1);
        uint256 endingBalance = baseUsdc.balanceOf(trader);
        assertEq(sizeInTokenEnd, 0);
        assertEq(endingBalance, startingBalance);
    }

    function test_decreaseSize_in_loss() public liquidityDeposited {
        uint256 sizeInTokenAmount = 0.5 ether;

        vm.startPrank(trader);
        baseUsdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true, WORLDID_ROOT, WORLDID_NULLIFIER_HASH, WORLDID_PROOF);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumFork);
        vm.stopPrank();

        vm.selectFork(baseFork);
        uint256 startingBalance = baseUsdc.balanceOf(trader);

        basePriceFeed.updateAnswer(1700_00000000);
        vm.selectFork(arbitrumFork);
        arbPriceFeed.updateAnswer(1700_00000000);

        vm.selectFork(baseFork);
        (, uint256 sizeInToken,, uint256 collateralStart,,) = positions.getPositionData(1);

        uint256 sizeToDecrease = 0.01 ether;

        int256 pnl = positions.getPositionPnl(1);
        int256 realisedPnl = (pnl * int256(sizeToDecrease)) / int256(sizeInToken);
        uint256 negativeRealisedPnl = uint256(realisedPnl.abs());
        uint256 negativeRealisedPnlScaledToUsdc = negativeRealisedPnl / (1e18 / 1e6);

        vm.prank(trader);
        positions.decreaseSize(1, sizeToDecrease);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumFork);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(baseFork);

        (, uint256 sizeInTokenEnd,, uint256 collateralEnd,,) = positions.getPositionData(1);
        uint256 endingBalance = baseUsdc.balanceOf(trader);

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
        baseUsdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true, WORLDID_ROOT, WORLDID_NULLIFIER_HASH, WORLDID_PROOF);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumFork);
        vm.stopPrank();

        vm.selectFork(baseFork);
        vm.prank(liquidator);
        vm.expectRevert(Positions.Positions__MaxLeverageNotExceeded.selector);
        positions.liquidate(1);
    }

    function test_liquidate_works() public liquidityDeposited {
        uint256 sizeInTokenAmount = 0.5 ether;

        vm.startPrank(trader);
        baseUsdc.approve(address(positions), FIFTY_USDC);
        positions.openPosition(sizeInTokenAmount, FIFTY_USDC, true, WORLDID_ROOT, WORLDID_NULLIFIER_HASH, WORLDID_PROOF);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumFork);
        vm.stopPrank();

        arbPriceFeed.updateAnswer(1950_00000000);
        vm.selectFork(baseFork);
        basePriceFeed.updateAnswer(1950_00000000);

        int256 pnl = positions.getPositionPnl(1);
        (,,, uint256 collateral,,) = positions.getPositionData(1);
        uint256 negativePnl = uint256(pnl.abs());
        uint256 negativePnlScaledToUsdc = negativePnl / (1e18 / 1e6);
        assertGt(collateral, negativePnlScaledToUsdc);
        uint256 remainingCollateral = collateral - negativePnlScaledToUsdc;
        uint256 expectedReward = (remainingCollateral * 2000) / 10000;

        uint256 liquidatorStartingBalance = baseUsdc.balanceOf(liquidator);

        vm.prank(liquidator);
        positions.liquidate(1);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumFork);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(baseFork);

        uint256 liquidatorEndingBalance = baseUsdc.balanceOf(liquidator);

        assertGt(liquidatorEndingBalance, liquidatorStartingBalance);
        assertEq(liquidatorEndingBalance, expectedReward);
    }
}
