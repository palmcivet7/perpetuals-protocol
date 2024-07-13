// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {AutomationCompatible} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {AutomationRegistrarInterface, RegistrationParams} from "./interfaces/AutomationRegistrarInterface.sol";
import {IAutomationRegistryConsumer} from
    "@chainlink/contracts-ccip/src/v0.8/automation/interfaces/IAutomationRegistryConsumer.sol";
import {IPoolManager} from "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@uniswap/v4-core/contracts/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@uniswap/v4-core/contracts/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/contracts/types/BalanceDelta.sol";
import {IPositions} from "./interfaces/IPositions.sol";

contract AutomatedLiquidator is Ownable, AutomationCompatible, IUnlockCallback {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error AutomatedLiquidator__AutomationRegistrationFailed();
    error AutomatedLiquidator__OnlyForwarder();
    error AutomatedLiquidator__OnlyPoolManager();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @dev When our USDC balance reaches this threshold we swap it for LINK
    uint256 internal constant SWAP_THRESHOLD = 100_000_000;
    /// @dev 3 LINK - deployer must have this in their wallet
    uint96 internal constant STARTING_LINK_FOR_REGISTRATION = 3 * 1e18;

    /// @dev Chainlink Token for paying for Automation
    LinkTokenInterface internal immutable i_link;
    /// @dev Chainlink Automation registrar, so we can register directly through this contract
    AutomationRegistrarInterface internal immutable i_registrar;
    /// @dev Automation Consumer for managing automation subscription, ie adding funds
    IAutomationRegistryConsumer internal immutable i_automationConsumer;
    /// @dev Automation subscription ID
    uint256 internal immutable i_subId;
    /// @dev Positions contract native to our system
    IPositions internal immutable i_positions;
    /// @dev USDC token
    IERC20 internal immutable i_usdc;
    /// @dev WETH token
    IERC20 internal immutable i_weth;
    /// @dev Uniswap V4 PoolManager
    IPoolManager internal immutable i_poolManager;

    /// @dev Automation forwarder address
    address internal s_forwarder;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event UpkeepRegistered(uint256 upkeepId);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address _link,
        address _registrar,
        address _automationConsumer,
        address _positions,
        address _usdc,
        address _weth,
        address _poolManager
    ) Ownable(msg.sender) {
        i_link = LinkTokenInterface(_link);
        i_registrar = AutomationRegistrarInterface(_registrar);
        i_automationConsumer = IAutomationRegistryConsumer(_automationConsumer);

        RegistrationParams memory params = RegistrationParams({
            name: "",
            encryptedEmail: hex"",
            upkeepContract: address(this),
            gasLimit: 2000000,
            adminAddress: msg.sender,
            triggerType: 0, // 0 is Conditional upkeep, 1 is Log trigger upkeep
            checkData: hex"",
            triggerConfig: hex"",
            offchainConfig: hex"",
            amount: STARTING_LINK_FOR_REGISTRATION
        });

        i_link.approve(address(i_registrar), params.amount);
        i_subId = i_registrar.registerUpkeep(params);
        if (i_subId != 0) emit UpkeepRegistered(i_subId);
        else revert AutomatedLiquidator__AutomationRegistrationFailed();

        i_usdc = IERC20(_usdc);
        i_weth = IERC20(_weth);
        i_poolManager = IPoolManager(_poolManager);
    }

    /*//////////////////////////////////////////////////////////////
                               AUTOMATION
    //////////////////////////////////////////////////////////////*/
    /// @dev Called continuously offchain by Chainlink Automation nodes
    /// @dev Cycles through all positions, checking if they can be liquidated
    function checkUpkeep(bytes calldata) external cannotExecute returns (bool upkeepNeeded, bytes memory performData) {
        uint256 positionsCount = i_positions.getPositionsCount();
        for (uint256 i = 1; i <= positionsCount; ++i) {
            if (i_positions.getMaxLeverageExceeded(i)) {
                upkeepNeeded = true;
                performData = abi.encode(i);
                return (upkeepNeeded, performData);
            }
        }
        // If no position needs upkeep, default return values will be false and empty bytes
        return (false, bytes(""));
    }

    /// @dev Called by the Automation forwarder address
    /// @dev Liquidates undercollateralized positions to keep our Perpetuals Protocol solvent
    function performUpkeep(bytes calldata performData) external {
        if (msg.sender != s_forwarder) revert AutomatedLiquidator__OnlyForwarder();
        uint256 positionId = abi.decode(performData, (uint256));
        i_positions.liquidate(positionId);

        // if we have more than 100 USDC in the contract, swap it for LINK and fund automation
        if (i_usdc.balanceOf(address(this)) > SWAP_THRESHOLD) _swapLiquidationRewardsAndFundAutomation();
    }

    /*//////////////////////////////////////////////////////////////
                                UNISWAP
    //////////////////////////////////////////////////////////////*/
    function _swapLiquidationRewardsAndFundAutomation() internal {
        uint256 balance = i_usdc.balanceOf(address(this));

        // Approve pool manager to spend USDC
        i_usdc.approve(address(i_poolManager), balance);

        // Encode the data for unlocking
        bytes memory data = abi.encode(balance);

        // Call unlock on the pool manager, which will call unlockCallback
        i_poolManager.unlock(data);
    }

    function unlockCallback(bytes calldata data) external override returns (bytes memory) {
        if (msg.sender != address(i_poolManager)) revert AutomatedLiquidator__OnlyPoolManager();

        (uint256 amountUSDC) = abi.decode(data, (uint256));

        // Swap USDC to WETH
        PoolKey memory usdcWethKey = PoolKey({
            currency0: address(i_usdc),
            currency1: address(i_weth),
            fee: 3000, // Assuming a 0.3% fee tier
            tickSpacing: , ///  int24 tickSpacing; @notice Ticks that involve positions must be a multiple of tick spacing
            hooks: // IHooks hooks;/// @notice The hooks of the pool
        });

        IPoolManager.SwapParams memory usdcWethParams = IPoolManager.SwapParams({
            zeroForOne: true, // Swapping USDC (currency0) for WETH (currency1)
            amountSpecified: int256(amountUSDC),
            sqrtPriceLimitX96: 0 // Setting to zero to allow any price, bad practice but just for simplicity
        });

        bytes memory hookDataForUSDCtoWETH = "";

        BalanceDelta balanceDeltaWETH = i_poolManager.swap(usdcWethKey, usdcWethParams, hookDataForUSDCtoWETH);

        // Extract WETH amount received from balanceDeltaWETH
        uint256 amountWETHReceived = uint256(balanceDeltaWETH.delta1);

        // Approve pool manager to spend WETH
        i_weth.approve(address(i_poolManager), amountWETHReceived);

        // Swap WETH to LINK
        PoolKey memory wethLinkKey = PoolKey({
            currency0: address(i_weth),
            currency1: address(i_link),
            fee: 3000, // Assuming a 0.3% fee tier
            tickSpacing: , ///  int24 tickSpacing; @notice Ticks that involve positions must be a multiple of tick spacing
            hooks: // IHooks hooks;/// @notice The hooks of the pool
        });             

        IPoolManager.SwapParams memory wethLinkParams = IPoolManager.SwapParams({
            zeroForOne: true, // Swapping WETH (currency0) for LINK (currency1)
            amountSpecified: int256(amountWETHReceived),
            sqrtPriceLimitX96: 0 // Setting to zero to allow any price, bad practice but just for simplicity
        });

        bytes memory hookDataForWETHtoLINK = "";

        BalanceDelta balanceDeltaLINK = i_poolManager.swap(wethLinkKey, wethLinkParams, hookDataForWETHtoLINK);

        // Extract LINK amount received from balanceDeltaLINK
        uint256 amountLINKReceived = uint256(balanceDeltaLINK.delta1);

        // Send the swapped LINK to Chainlink automation subscription
        i_automationConsumer.addFunds(i_subId, uint96(amountLINKReceived));

        return "";
    }

    /*//////////////////////////////////////////////////////////////
                                 SETTER
    //////////////////////////////////////////////////////////////*/
    function setForwarder(address _forwarder) external onlyOwner {
        s_forwarder = _forwarder;
    }
}
