// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPositions} from "./interfaces/IPositions.sol";
import {ICCIPPositionsManager} from "./interfaces/ICCIPPositionsManager.sol";

contract CCIPPositionsManager is ICCIPPositionsManager, Ownable {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @dev Chainlink Token for paying for CCIP
    LinkTokenInterface internal immutable i_link;
    /// @dev USDC token for collateral and liquidity
    IERC20 internal immutable i_usdc;
    /// @dev Positions contract native to this protocol
    IPositions internal immutable i_positions;

    /// @dev CCIPVaultManager native to this protocol we are sending to and receiving from via ccip
    address internal s_vaultManager;
    /// @dev Chain selector we are sending to and receiving from via ccip
    uint64 internal s_vaultManagerChainSelector;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _router, address _link, address _usdc, address _positions)
        Ownable(msg.sender)
        CCIPReceiver(_router)
    {
        i_link = LinkTokenInterface(_link);
        i_usdc = IERC20(_usdc);
        i_positions = IPositions(_positions);
    }

    /*//////////////////////////////////////////////////////////////
                                  CCIP
    //////////////////////////////////////////////////////////////*/
    function ccipSend() external {}

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {}

    /*//////////////////////////////////////////////////////////////
                                 SETTER
    //////////////////////////////////////////////////////////////*/
    function setVaultManagerChainSelector(uint64 _chainSelector) external onlyOwner {
        s_vaultManagerChainSelector = _chainSelector;
    }

    function setVaultManagerAddress(address _vaultManager) external onlyOwner {
        s_vaultManager = _vaultManager;
    }
}
