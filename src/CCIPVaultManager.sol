// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPyth, PythStructs} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {IVault} from "./interfaces/IVault.sol";
import {ICCIPVaultManager} from "./interfaces/ICCIPVaultManager.sol";
import {Constants} from "./libraries/Constants.sol";
import {Utils} from "./libraries/Utils.sol";

contract CCIPVaultManager is CCIPReceiver, Ownable, ICCIPVaultManager {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/
    using SafeERC20 for IERC20;
    using Utils for uint256;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error CCIPVaultManager__OnlyVaultOrRouter(address wrongCaller);
    error CCIPVaultManager__WrongSender(address wrongSender);
    error CCIPVaultManager__WrongSourceChain(uint64 wrongChainSelector);
    error CCIPVaultManager__InsufficientLinkBalance(uint256 balance, uint256 fees);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @dev Chainlink Token for paying for CCIP
    LinkTokenInterface internal immutable i_link;
    /// @dev USDC token for collateral and liquidity
    IERC20 internal immutable i_usdc;
    /// @dev Vault contract native to this protocol
    IVault internal immutable i_vault;
    /// @dev Chainlink PriceFeed for the token being speculated on
    AggregatorV3Interface internal immutable i_priceFeed;
    /// @dev Pyth pricefeed contract for the token being speculated on
    IPyth internal immutable i_pythFeed;
    /// @dev Pyth pricefeed ID for the token being speculated on
    bytes32 internal immutable i_pythFeedId;

    /// @dev These are updated only by _ccipReceive
    uint256 internal s_totalOpenInterestLongInToken;
    uint256 internal s_totalOpenInterestShortInUsd; // scaled to 1e18, not scaled to usdc

    /// @dev CCIPPositionsManager native to this protocol we are sending to and receiving from via ccip
    address internal s_positionsManager;
    /// @dev Chain selector we are sending to and receiving from via ccip
    uint64 internal s_positionsManagerChainSelector;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event VaultMessageSent(
        bytes32 indexed messageId,
        uint256 indexed liquidityAmount,
        bool indexed isDeposit,
        uint256 profitAmount,
        address profitRecipient,
        uint256 fees
    );
    event VaultMessageReceived(
        uint256 liquidatedCollateralAmount,
        uint256 profitAmountRequest,
        address profitRecipientRequest,
        uint256 openInterestLongInToken,
        uint256 openInterestShortInUsd,
        bool increaseLongInToken,
        bool increaseShortInUsd
    );

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyVaultOrRouter() {
        if (msg.sender != address(i_vault) && msg.sender != address(i_ccipRouter)) {
            revert CCIPVaultManager__OnlyVaultOrRouter(msg.sender);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address _router,
        address _link,
        address _usdc,
        address _priceFeed,
        address _vault,
        address _pythFeed,
        bytes32 _pythFeedId
    ) Ownable(msg.sender) CCIPReceiver(_router) {
        i_link = LinkTokenInterface(_link);
        i_usdc = IERC20(_usdc);
        i_priceFeed = AggregatorV3Interface(_priceFeed);
        i_vault = IVault(_vault);
        i_pythFeed = IPyth(_pythFeed);
        i_pythFeedId = _pythFeedId;
    }

    /*//////////////////////////////////////////////////////////////
                                  CCIP
    //////////////////////////////////////////////////////////////*/
    /// @param _liquidityAmount The amount of liquidity that has been deposited or withdrawn
    /// @param _isDeposit True if liquidity deposited, false if withdrawn
    /// @param _profitAmount The amount of USDC profit being sent to recipient
    /// @param _profitRecipient Recipient of profit being sent (if any)
    /// @notice if _profitAmount is 0, _profitRecipient should be address(0)
    /// @notice if _profitAmount > 0, _isDeposit should be false and _liquidityAmount should be same as _profitAmount
    function ccipSend(uint256 _liquidityAmount, bool _isDeposit, uint256 _profitAmount, address _profitRecipient)
        public
        onlyVaultOrRouter
    {
        address receiver = s_positionsManager;
        uint64 destinationChainSelector = s_positionsManagerChainSelector;

        Client.EVM2AnyMessage memory evm2AnyMessage;

        if (_profitAmount > 0) {
            i_vault.approve(_profitAmount);
            i_usdc.safeTransferFrom(address(i_vault), address(this), _profitAmount);

            Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
            tokenAmounts[0] = Client.EVMTokenAmount({token: address(i_usdc), amount: _profitAmount});

            evm2AnyMessage = Client.EVM2AnyMessage({
                receiver: abi.encode(receiver),
                data: abi.encode(_liquidityAmount, _isDeposit, _profitAmount, _profitRecipient),
                tokenAmounts: tokenAmounts,
                extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: Constants.CCIP_GAS_LIMIT})),
                feeToken: address(i_link)
            });

            i_usdc.approve(i_ccipRouter, _profitAmount);
        } else {
            // dont send tokenAmounts
            evm2AnyMessage = Client.EVM2AnyMessage({
                receiver: abi.encode(receiver),
                data: abi.encode(_liquidityAmount, _isDeposit, _profitAmount, _profitRecipient),
                tokenAmounts: new Client.EVMTokenAmount[](0),
                extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: Constants.CCIP_GAS_LIMIT})),
                feeToken: address(i_link)
            });
        }

        uint256 fees = IRouterClient(i_ccipRouter).getFee(destinationChainSelector, evm2AnyMessage);
        if (fees > i_link.balanceOf(address(this))) {
            revert CCIPVaultManager__InsufficientLinkBalance(i_link.balanceOf(address(this)), fees);
        }

        // approve the Router to transfer LINK tokens on contract's behalf. It will spend the fees in LINK
        i_link.approve(address(i_ccipRouter), fees);

        // Send the message through the router and store the returned message ID
        bytes32 messageId = IRouterClient(i_ccipRouter).ccipSend(destinationChainSelector, evm2AnyMessage);

        // emit messageSent event
        emit VaultMessageSent(messageId, _liquidityAmount, _isDeposit, _profitAmount, _profitRecipient, fees);
    }

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
            uint256 _liquidatedCollateralAmount,
            uint256 _profitAmountRequest,
            address _profitRecipientRequest,
            uint256 _openInterestLongInToken,
            uint256 _openInterestShortInUsd,
            bool _increaseLongInToken,
            bool _increaseShortInUsd
        ) = abi.decode(_message.data, (uint256, uint256, address, uint256, uint256, bool, bool));

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

        if (_profitAmountRequest > 0) {
            ccipSend(_profitAmountRequest, false, _profitAmountRequest, _profitRecipientRequest);
        }

        emit VaultMessageReceived(
            _liquidatedCollateralAmount,
            _profitAmountRequest,
            _profitRecipientRequest,
            _openInterestLongInToken,
            _openInterestShortInUsd,
            _increaseLongInToken,
            _increaseShortInUsd
        );

        if (_liquidatedCollateralAmount > 0) i_usdc.safeTransfer(address(i_vault), _liquidatedCollateralAmount);
    }

    /*//////////////////////////////////////////////////////////////
                                 GETTER
    //////////////////////////////////////////////////////////////*/
    /// @dev Returns the latest price for the speculated asset by combining Chainlink and Pyth pricefeeds
    function getLatestPrice() public view returns (uint256) {
        // Fetch Chainlink price
        (, int256 chainlinkPrice,,,) = i_priceFeed.latestRoundData();

        // Scale Chainlink price from 8 decimals to 18 decimals
        uint256 chainlinkPrice18Decimals = uint256(chainlinkPrice) * Constants.SCALING_FACTOR;

        // Fetch Pyth price
        PythStructs.Price memory priceStruct = i_pythFeed.getPriceUnsafe(i_pythFeedId);

        // Calculate Pyth price in 18 decimals
        uint256 pythPrice18Decimals = (uint256(uint64(priceStruct.price)) * Constants.WAD_PRECISION)
            / (10 ** uint8(uint32(-1 * priceStruct.expo)));

        // Calculate the average price in 18 decimals
        uint256 finalPrice18Decimals = (chainlinkPrice18Decimals + pythPrice18Decimals) / 2;

        // The final price is already in 18 decimals, return it directly
        return finalPrice18Decimals;
    }

    /// @dev Returns the available liquidity of the protocol, excluding any collateral or reserved profits
    function getAvailableLiquidity() public view returns (uint256) {
        // Total assets in the vault
        uint256 totalLiquidity = i_vault.totalAssets();

        // Calculate and scale the total open interest
        uint256 totalOpenInterestLong = (s_totalOpenInterestLongInToken * getLatestPrice()) / Constants.WAD_PRECISION;
        uint256 totalOpenInterest = totalOpenInterestLong + s_totalOpenInterestShortInUsd;
        uint256 totalOpenInterestScaled = totalOpenInterest.scaleToUSDC();

        // Calculate max utilization liquidity
        uint256 maxUtilizationLiquidity =
            (totalLiquidity * Constants.MAX_UTILIZATION_PERCENTAGE) / Constants.BASIS_POINT_DIVISOR;

        // Adjust available liquidity based on total open interest
        uint256 availableLiquidity =
            maxUtilizationLiquidity > totalOpenInterestScaled ? maxUtilizationLiquidity - totalOpenInterestScaled : 0;

        return availableLiquidity;
    }

    function getOpenInterestLongInToken() external view returns (uint256) {
        return s_totalOpenInterestLongInToken;
    }

    function getOpenInterestShortInUsd() external view returns (uint256) {
        return s_totalOpenInterestShortInUsd;
    }

    /*//////////////////////////////////////////////////////////////
                                 SETTER
    //////////////////////////////////////////////////////////////*/
    function setPositionsManagerChainSelector(uint64 _chainSelector) external onlyOwner {
        s_positionsManagerChainSelector = _chainSelector;
    }

    function setPositionsManagerAddress(address _positionsManager) external onlyOwner {
        s_positionsManager = _positionsManager;
    }
}
