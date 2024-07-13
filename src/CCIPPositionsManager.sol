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

contract CCIPPositionsManager is ICCIPPositionsManager, Ownable, CCIPReceiver {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error CCIPPositionsManager__OnlyVault();
    error CCIPPositionsManager__WrongSender(address wrongSender);
    error CCIPPositionsManager__WrongSourceChain(uint64 wrongChainSelector);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @dev Chainlink Token for paying for CCIP
    LinkTokenInterface internal immutable i_link;
    /// @dev USDC token for collateral and liquidity
    IERC20 internal immutable i_usdc;
    /// @dev Positions contract native to this protocol
    IPositions internal immutable i_positions;

    /// @dev Only updated by _ccipReceive
    uint256 internal s_totalLiquidity;

    /// @dev CCIPVaultManager native to this protocol we are sending to and receiving from via ccip
    address internal s_vaultManager;
    /// @dev Chain selector we are sending to and receiving from via ccip
    uint64 internal s_vaultManagerChainSelector;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event PositionsMessageReceived(
        uint256 _liquidityAmount, bool _isDeposit, uint256 _profitAmount, address _profitRecipient
    );

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyPositions() {
        if (msg.sender != address(i_positions)) revert CCIPPositionsManager__OnlyVault();
        _;
    }

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
    function ccipSend(
        uint256 _usdcAmount,
        uint256 _openInterestLongInToken,
        uint256 _openInterestShortInUsd,
        bool _increaseLongInToken,
        bool _increaseShortInUsd
    ) external onlyPositions {
        address receiver = s_vaultManager;
        uint64 destinationChainSelector = s_vaultManagerChainSelector;

        Client.EVM2AnyMessage memory evm2AnyMessage;
    }

    function _ccipReceive(Client.Any2EVMMessage memory _message) internal override {
        /// @dev revert if sender or source chain is not what we allowed
        address expectedSender = s_vaultManager;
        address sender = abi.decode(_message.sender, (address));
        if (sender != expectedSender) revert CCIPPositionsManager__WrongSender(sender);
        uint64 expectedSourceChainSelector = s_vaultManagerChainSelector;
        if (_message.sourceChainSelector != expectedSourceChainSelector) {
            revert CCIPPositionsManager__WrongSourceChain(_message.sourceChainSelector);
        }

        (uint256 _liquidityAmount, bool _isDeposit, uint256 _profitAmount, address _profitRecipient) =
            abi.decode(_message.data, (uint256, bool, uint256, address));

        // Effects: Updates s_totalLiquidity
        if (_isDeposit) s_totalLiquidity += _liquidityAmount;
        if (!_isDeposit) s_totalLiquidity -= _liquidityAmount;

        emit PositionsMessageReceived(_liquidityAmount, _isDeposit, _profitAmount, _profitRecipient);

        // Interactions: Sends any profit to profit recipient
        if (_profitAmount > 0) i_usdc.safeTransfer(_profitRecipient, _profitAmount);
    }

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
