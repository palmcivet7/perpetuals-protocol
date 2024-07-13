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
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
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
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _link, address _registrar, address _automationConsumer, address _positions)
        Ownable(msg.sender)
    {
        i_link = LinkTokenInterface(_link);
        i_registrar = AutomationRegistrarInterface(_registrar);
        i_automationConsumer = IAutomationRegistryConsumer(_automationConsumer);
    }
}
