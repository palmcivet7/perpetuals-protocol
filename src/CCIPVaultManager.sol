// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVault} from "./interfaces/IVault.sol";
import {ICCIPVaultManager} from "./interfaces/ICCIPVaultManager.sol";

contract CCIPVaultManager is CCIPReceiver, Ownable, ICCIPVaultManager {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error CCIPVaultManager__OnlyVault();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @dev Chainlink Token for paying for CCIP
    LinkTokenInterface internal immutable i_link;
    /// @dev USDC token for collateral and liquidity
    IERC20 internal immutable i_usdc;
    /// @dev Vault contract native to this protocol
    IVault internal immutable i_vault;

    /// @dev CCIPPositionsManager native to this protocol we are sending to and receiving from via ccip
    address internal s_positionsManager;
    /// @dev Chain selector we are sending to and receiving from via ccip
    uint64 internal s_positionsManagerChainSelector;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyVault() {
        if (msg.sender != address(i_vault)) revert CCIPVaultManager__OnlyVault();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _router, address _link, address _usdc, address _vault)
        Ownable(msg.sender)
        CCIPReceiver(_router)
    {
        i_link = LinkTokenInterface(_link);
        i_usdc = IERC20(_usdc);
        i_vault = IVault(_vault);
    }

    /*//////////////////////////////////////////////////////////////
                                  CCIP
    //////////////////////////////////////////////////////////////*/
    function ccipSend() external onlyVault {}

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        /**
         * receives:
         *     uint256 _usdcAmount,
         *     uint256 _openInterestLongInToken,
         *     uint256 _openInterestShortInUsd,
         *     bool _increaseLongInToken,
         *     bool _increaseShortInUsd
         */
    }

    /*//////////////////////////////////////////////////////////////
                                 SETTER
    //////////////////////////////////////////////////////////////*/
    function setVaultManagerChainSelector(uint64 _chainSelector) external onlyOwner {
        s_positionsManagerChainSelector = _chainSelector;
    }

    function setVaultManagerAddress(address _positionsManager) external onlyOwner {
        s_positionsManager = _positionsManager;
    }
}
