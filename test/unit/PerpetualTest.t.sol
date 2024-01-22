// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployPerpetual} from "../../script/DeployPerpetual.s.sol";
import {Perpetual} from "../../src/Perpetual.sol";
import {Vault} from "../../src/Vault.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {MockUSDC} from "../../src/mocks/MockUSDC.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract PerpetualTest is Test {
    Perpetual perpetual;
    Vault vault;
    HelperConfig helperConfig;
    MockUSDC mockUsdc;
    MockV3Aggregator priceFeed;

    address public LIQUIDITY_PROVIDER = makeAddr("LIQUIDITY_PROVIDER");
    address public TRADER = makeAddr("TRADER");
    uint256 public constant STARTING_USER_BALANCE = 1000 ether;
    uint256 public constant ONE_THOUSAND_USDC = 1000_000000;
    uint256 public constant TEN_THOUSAND_USDC = 10000_000000;

    function setUp() external {
        DeployPerpetual deployer = new DeployPerpetual();
        (perpetual, helperConfig) = deployer.run();
        (address priceFeedAddress, address vaultAddress, address assetAddress) = helperConfig.activeNetworkConfig();
        priceFeed = MockV3Aggregator(priceFeedAddress);
        vault = Vault(vaultAddress);
        mockUsdc = MockUSDC(assetAddress);

        vm.prank(address(helperConfig));
        vault.setPerpetual(address(perpetual));

        vm.deal(LIQUIDITY_PROVIDER, STARTING_USER_BALANCE);
        vm.deal(TRADER, STARTING_USER_BALANCE);
        vm.prank(LIQUIDITY_PROVIDER);
        mockUsdc.mintTokens(TEN_THOUSAND_USDC);
        vm.prank(TRADER);
        mockUsdc.mintTokens(ONE_THOUSAND_USDC);
    }

    function test_constructor_sets_values() public {
        assertEq(address(priceFeed), address(perpetual.i_priceFeed()));
        assertEq(address(vault), address(perpetual.i_vault()));
        assertEq(address(mockUsdc), address(perpetual.i_collateralToken()));
    }

    /*//////////////////////////////////////////////////////////////
                             OPEN POSITION
    //////////////////////////////////////////////////////////////*/

    function test_openPosition_reverts_if_size_is_zero() public {
        vm.startPrank(TRADER);
        vm.expectRevert(Perpetual.Perpetual__InvalidValue.selector);
        perpetual.openPosition(0, 1, true);
        vm.stopPrank();
    }

    function test_openPosition_reverts_if_collateralAmount_is_zero() public {
        vm.startPrank(TRADER);
        vm.expectRevert(Perpetual.Perpetual__InvalidValue.selector);
        perpetual.openPosition(1, 0, true);
        vm.stopPrank();
    }

    function test_openPosition_reverts_if_liquidity_is_insufficient() public {
        vm.startPrank(TRADER);
        vm.expectRevert(Perpetual.Perpetual__InsufficientLiquidity.selector);
        perpetual.openPosition(1, 1, true);
        vm.stopPrank();
    }

    modifier liquidityDeposited() {
        vm.startPrank(LIQUIDITY_PROVIDER);
        mockUsdc.approve(address(vault), TEN_THOUSAND_USDC);
        vault.deposit(TEN_THOUSAND_USDC, LIQUIDITY_PROVIDER);
        vm.stopPrank();
        _;
    }

    modifier traderApproveCollateralTokenForPerpetualContract() {
        vm.startPrank(TRADER);
        mockUsdc.approve(address(perpetual), type(uint256).max);
        mockUsdc.approve(address(vault), type(uint256).max);
        vm.stopPrank();
        _;
    }

    function test_openPosition_works() public liquidityDeposited traderApproveCollateralTokenForPerpetualContract {
        vm.startPrank(TRADER);
        perpetual.openPosition(1, ONE_THOUSAND_USDC, true);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                             INCREASE SIZE
    //////////////////////////////////////////////////////////////*/

    function test_increaseSize_reverts_if_size_is_zero()
        public
        liquidityDeposited
        traderApproveCollateralTokenForPerpetualContract
    {
        vm.startPrank(TRADER);
        perpetual.openPosition(1, ONE_THOUSAND_USDC, true);
        vm.expectRevert(Perpetual.Perpetual__InvalidValue.selector);
        perpetual.increaseSize(0);
        vm.stopPrank();
    }

    function test_increaseSize_reverts_if_liquidity_is_insufficient()
        public
        liquidityDeposited
        traderApproveCollateralTokenForPerpetualContract
    {
        vm.startPrank(TRADER);
        perpetual.openPosition(1, ONE_THOUSAND_USDC, true);
        vm.expectRevert(Perpetual.Perpetual__InsufficientLiquidity.selector);
        perpetual.increaseSize(ONE_THOUSAND_USDC);
        vm.stopPrank();
    }

    function test_increaseSize_reverts_if_position_doesnt_exist()
        public
        liquidityDeposited
        traderApproveCollateralTokenForPerpetualContract
    {
        vm.startPrank(TRADER);
        vm.expectRevert(Perpetual.Perpetual__PositionDoesNotExist.selector);
        perpetual.increaseSize(1);
        vm.stopPrank();
    }

    function test_increaseSize_works() public liquidityDeposited traderApproveCollateralTokenForPerpetualContract {
        vm.startPrank(TRADER);
        perpetual.openPosition(1, ONE_THOUSAND_USDC, true);
        perpetual.increaseSize(1);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                          INCREASE COLLATERAL
    //////////////////////////////////////////////////////////////*/

    function test_increaseCollateral_reverts_if_additional_is_zero()
        public
        liquidityDeposited
        traderApproveCollateralTokenForPerpetualContract
    {
        vm.startPrank(TRADER);
        perpetual.openPosition(1, ONE_THOUSAND_USDC, true);
        vm.expectRevert(Perpetual.Perpetual__InvalidValue.selector);
        perpetual.increaseCollateral(0);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                             VAULT CONTRACT
    //////////////////////////////////////////////////////////////*/

    function test_vault_withdraw_reverts_if_assets_are_zero() public {
        vm.startPrank(LIQUIDITY_PROVIDER);
        vm.expectRevert(Vault.Vault__InvalidValue.selector);
        vault.withdraw(0, address(0), address(0));
        vm.stopPrank();
    }

    function test_vault_withdraw_reverts_if_receiver_is_zero_address() public {
        vm.startPrank(LIQUIDITY_PROVIDER);
        vm.expectRevert(Vault.Vault__InvalidAddress.selector);
        vault.withdraw(1, address(0), address(0));
        vm.stopPrank();
    }

    function test_vault_withdraw_reverts_if_owner_is_zero_address() public {
        vm.startPrank(LIQUIDITY_PROVIDER);
        vm.expectRevert(Vault.Vault__InvalidAddress.selector);
        vault.withdraw(1, address(1), address(0));
        vm.stopPrank();
    }

    function test_vault_withdraw_reverts_if_not_enough_available_liquidity() public liquidityDeposited {
        vm.startPrank(LIQUIDITY_PROVIDER);
        vm.expectRevert(Vault.Vault__NotEnoughLiquidity.selector);
        vault.withdraw(TEN_THOUSAND_USDC * 2, LIQUIDITY_PROVIDER, LIQUIDITY_PROVIDER);
        vm.stopPrank();
    }

    function test_vault_withdraw_works() public liquidityDeposited {
        vm.startPrank(LIQUIDITY_PROVIDER);
        uint256 userBalanceStart = mockUsdc.balanceOf(LIQUIDITY_PROVIDER);
        uint256 vaultBalanceStart = mockUsdc.balanceOf(address(vault));
        vault.withdraw(TEN_THOUSAND_USDC, LIQUIDITY_PROVIDER, LIQUIDITY_PROVIDER);
        uint256 userBalanceEnd = mockUsdc.balanceOf(LIQUIDITY_PROVIDER);
        uint256 vaultBalanceEnd = mockUsdc.balanceOf(address(vault));
        vm.stopPrank();

        assertEq(userBalanceStart, vaultBalanceEnd);
        assertEq(vaultBalanceStart, userBalanceEnd);
    }
}
