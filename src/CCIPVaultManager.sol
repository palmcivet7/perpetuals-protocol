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
import {Constants} from "./libraries/Constants.sol";

contract CCIPVaultManager is CCIPReceiver, Ownable, ICCIPVaultManager {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error CCIPVaultManager__OnlyVault();
    error CCIPVaultManager__WrongSender(address wrongSender);
    error CCIPVaultManager__WrongSourceChain(uint64 wrongChainSelector);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @dev Chainlink Token for paying for CCIP
    LinkTokenInterface internal immutable i_link;
    /// @dev USDC token for collateral and liquidity
    IERC20 internal immutable i_usdc;
    /// @dev Vault contract native to this protocol
    IVault internal immutable i_vault;

    /// @dev These are updated only by _ccipReceive
    uint256 internal s_totalOpenInterestLongInToken;
    uint256 internal s_totalOpenInterestShortInUsd; // scaled to 1e18, not scaled to usdc

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

    function _ccipReceive(Client.Any2EVMMessage memory _message) internal override {
        /// @dev revert if sender or source chain is not what we allowed
        address expectedSender = s_positionsManager;
        address sender = abi.decode(_message.sender, (address));
        if (sender != expectedSender) revert CCIPVaultManager__WrongSender(sender);
        uint64 expectedSourceChainSelector = s_positionsManagerChainSelector;
        if (_message.sourceChainSelector != expectedSourceChainSelector) {
            revert CCIPVaultManager__WrongSourceChain(_message.sourceChainSelector);
        }

        (
            uint256 _usdcAmount,
            uint256 _openInterestLongInToken,
            uint256 _openInterestShortInUsd,
            bool _increaseLongInToken,
            bool _increaseShortInUsd
        ) = abi.decode(_message.data, (uint256, uint256, uint256, bool, bool));

        if (_increaseLongInToken) {
            s_totalOpenInterestLongInToken += _openInterestLongInToken;
        } else if (_openInterestLongInToken > 0) {
            s_totalOpenInterestLongInToken -= _openInterestLongInToken;
        }

        if (_increaseShortInUsd) {
            s_totalOpenInterestShortInUsd += _openInterestShortInUsd;
        } else if (_openInterestShortInUsd > 0) {
            s_totalOpenInterestShortInUsd -= _openInterestShortInUsd;
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 GETTER
    //////////////////////////////////////////////////////////////*/
    /// @dev Returns the latest price for the speculated asset
    function getLatestPrice() public view returns (uint256) {
        (, int256 price,,,) = i_priceFeed.latestRoundData();
        return uint256(price) * Constants.SCALING_FACTOR;
    }

    /// @dev Returns the available liquidity of the protocol, excluding any collateral or reserved profits
    function getAvailableLiquidity() public view returns (uint256) {
        // Total assets in the vault
        uint256 totalLiquidity = i_vault.totalAssets();

        // Calculate and scale the total open interest
        uint256 totalOpenInterestLong = (s_totalOpenInterestLongInToken * getLatestPrice()) / Constants.WAD_PRECISION;
        uint256 totalOpenInterest = totalOpenInterestLong + s_totalOpenInterestShortInUsd;
        uint256 totalOpenInterestScaled = _scaleToUSDC(totalOpenInterest);

        // Calculate max utilization liquidity
        uint256 maxUtilizationLiquidity =
            (totalLiquidity * Constants.MAX_UTILIZATION_PERCENTAGE) / Constants.BASIS_POINT_DIVISOR;

        // Adjust available liquidity based on total open interest
        uint256 availableLiquidity =
            maxUtilizationLiquidity > totalOpenInterestScaled ? maxUtilizationLiquidity - totalOpenInterestScaled : 0;

        return availableLiquidity;
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
