// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {AutomationCompatible} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {AutomationRegistrarInterface, RegistrationParams} from "./interfaces/AutomationRegistrarInterface.sol";
import {IAutomationRegistryConsumer} from
    "@chainlink/contracts-ccip/src/v0.8/automation/interfaces/IAutomationRegistryConsumer.sol";
import {IPositions} from "./interfaces/IPositions.sol";

contract AutomatedLiquidator is Ownable, AutomationCompatible {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error AutomatedLiquidator__AutomationRegistrationFailed();
    error AutomatedLiquidator__OnlyForwarder();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
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

    /// @dev Automation forwarder address
    address internal s_forwarder;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event UpkeepRegistered(uint256 upkeepId);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _link, address _registrar, address _automationConsumer, address _positions)
        Ownable(msg.sender)
    {
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
        i_perpetual.liquidate(positionId);
    }

    /*//////////////////////////////////////////////////////////////
                                 SETTER
    //////////////////////////////////////////////////////////////*/
    function setForwarder(address _forwarder) external onlyOwner {
        s_forwarder = _forwarder;
    }
}
