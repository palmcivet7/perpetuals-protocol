// SPDX-License-Identifier: MIT
pragma solidity =0.8.24 ^0.8.0 ^0.8.10 ^0.8.20 ^0.8.21;

// lib/ccip/contracts/src/v0.8/ccip/libraries/Client.sol

// End consumer library.
library Client {
  /// @dev RMN depends on this struct, if changing, please notify the RMN maintainers.
  struct EVMTokenAmount {
    address token; // token address on the local chain.
    uint256 amount; // Amount of tokens.
  }

  struct Any2EVMMessage {
    bytes32 messageId; // MessageId corresponding to ccipSend on source.
    uint64 sourceChainSelector; // Source chain selector.
    bytes sender; // abi.decode(sender) if coming from an EVM chain.
    bytes data; // payload sent in original message.
    EVMTokenAmount[] destTokenAmounts; // Tokens and their amounts in their destination chain representation.
  }

  // If extraArgs is empty bytes, the default is 200k gas limit.
  struct EVM2AnyMessage {
    bytes receiver; // abi.encode(receiver address) for dest EVM chains
    bytes data; // Data payload
    EVMTokenAmount[] tokenAmounts; // Token transfers
    address feeToken; // Address of feeToken. address(0) means you will send msg.value.
    bytes extraArgs; // Populate this with _argsToBytes(EVMExtraArgsV1)
  }

  // bytes4(keccak256("CCIP EVMExtraArgsV1"));
  bytes4 public constant EVM_EXTRA_ARGS_V1_TAG = 0x97a657c9;

  struct EVMExtraArgsV1 {
    uint256 gasLimit;
  }

  function _argsToBytes(EVMExtraArgsV1 memory extraArgs) internal pure returns (bytes memory bts) {
    return abi.encodeWithSelector(EVM_EXTRA_ARGS_V1_TAG, extraArgs);
  }
}

// lib/ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/utils/introspection/IERC165.sol

// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// lib/chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol

// solhint-disable-next-line interface-starts-with-i
interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  function getRoundData(
    uint80 _roundId
  ) external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

// lib/chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol

// solhint-disable-next-line interface-starts-with-i
interface LinkTokenInterface {
  function allowance(address owner, address spender) external view returns (uint256 remaining);

  function approve(address spender, uint256 value) external returns (bool success);

  function balanceOf(address owner) external view returns (uint256 balance);

  function decimals() external view returns (uint8 decimalPlaces);

  function decreaseApproval(address spender, uint256 addedValue) external returns (bool success);

  function increaseApproval(address spender, uint256 subtractedValue) external;

  function name() external view returns (string memory tokenName);

  function symbol() external view returns (string memory tokenSymbol);

  function totalSupply() external view returns (uint256 totalTokensIssued);

  function transfer(address to, uint256 value) external returns (bool success);

  function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool success);

  function transferFrom(address from, address to, uint256 value) external returns (bool success);
}

// lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Permit.sol)

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * ==== Security Considerations
 *
 * There are two important considerations concerning the use of `permit`. The first is that a valid permit signature
 * expresses an allowance, and it should not be assumed to convey additional meaning. In particular, it should not be
 * considered as an intention to spend the allowance in any specific way. The second is that because permits have
 * built-in replay protection and can be submitted by anyone, they can be frontrun. A protocol that uses permits should
 * take this into consideration and allow a `permit` call to fail. Combining these two aspects, a pattern that may be
 * generally recommended is:
 *
 * ```solidity
 * function doThingWithPermit(..., uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
 *     try token.permit(msg.sender, address(this), value, deadline, v, r, s) {} catch {}
 *     doThing(..., value);
 * }
 *
 * function doThing(..., uint256 value) public {
 *     token.safeTransferFrom(msg.sender, address(this), value);
 *     ...
 * }
 * ```
 *
 * Observe that: 1) `msg.sender` is used as the owner, leaving no ambiguity as to the signer intent, and 2) the use of
 * `try/catch` allows the permit to fail and makes the code tolerant to frontrunning. (See also
 * {SafeERC20-safeTransferFrom}).
 *
 * Additionally, note that smart contract wallets (such as Argent or Safe) are not able to produce permit signatures, so
 * contracts should have entry points that don't rely on permit.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     *
     * CAUTION: See Security Considerations above.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// lib/openzeppelin-contracts/contracts/utils/Address.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/Address.sol)

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error AddressInsufficientBalance(address account);

    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedInnerCall();

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert AddressInsufficientBalance(address(this));
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert FailedInnerCall();
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {FailedInnerCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {FailedInnerCall}) in case of an
     * unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {FailedInnerCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {FailedInnerCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert FailedInnerCall();
        }
    }
}

// lib/openzeppelin-contracts/contracts/utils/Context.sol

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/ReentrancyGuard.sol)

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

// lib/openzeppelin-contracts/contracts/utils/math/SignedMath.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/SignedMath.sol)

/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMath {
    /**
     * @dev Returns the largest of two signed numbers.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two signed numbers.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two signed numbers without overflow.
     * The result is rounded towards zero.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        // Formula from the book "Hacker's Delight"
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }

    /**
     * @dev Returns the absolute unsigned value of a signed value.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // must be unchecked in order to support `n = type(int256).min`
            return uint256(n >= 0 ? n : -n);
        }
    }
}

// lib/pyth-sdk-solidity/IPythEvents.sol

/// @title IPythEvents contains the events that Pyth contract emits.
/// @dev This interface can be used for listening to the updates for off-chain and testing purposes.
interface IPythEvents {
    /// @dev Emitted when the price feed with `id` has received a fresh update.
    /// @param id The Pyth Price Feed ID.
    /// @param publishTime Publish time of the given price update.
    /// @param price Price of the given price update.
    /// @param conf Confidence interval of the given price update.
    event PriceFeedUpdate(
        bytes32 indexed id,
        uint64 publishTime,
        int64 price,
        uint64 conf
    );

    /// @dev Emitted when a batch price update is processed successfully.
    /// @param chainId ID of the source chain that the batch price update comes from.
    /// @param sequenceNumber Sequence number of the batch price update.
    event BatchPriceFeedUpdate(uint16 chainId, uint64 sequenceNumber);
}

// lib/pyth-sdk-solidity/PythStructs.sol

contract PythStructs {
    // A price with a degree of uncertainty, represented as a price +- a confidence interval.
    //
    // The confidence interval roughly corresponds to the standard error of a normal distribution.
    // Both the price and confidence are stored in a fixed-point numeric representation,
    // `x * (10^expo)`, where `expo` is the exponent.
    //
    // Please refer to the documentation at https://docs.pyth.network/consumers/best-practices for how
    // to how this price safely.
    struct Price {
        // Price
        int64 price;
        // Confidence interval around the price
        uint64 conf;
        // Price exponent
        int32 expo;
        // Unix timestamp describing when the price was published
        uint publishTime;
    }

    // PriceFeed represents a current aggregate price from pyth publisher feeds.
    struct PriceFeed {
        // The price ID.
        bytes32 id;
        // Latest available price
        Price price;
        // Latest available exponentially-weighted moving average price
        Price emaPrice;
    }
}

// lib/world-id-contracts/src/interfaces/IBaseWorldID.sol

/// @title Base WorldID interface
/// @author Worldcoin
/// @notice The interface providing basic types across various WorldID contracts.
interface IBaseWorldID {
    ///////////////////////////////////////////////////////////////////////////////
    ///                                  ERRORS                                 ///
    ///////////////////////////////////////////////////////////////////////////////

    /// @notice Thrown when attempting to validate a root that has expired.
    error ExpiredRoot();

    /// @notice Thrown when attempting to validate a root that has yet to be added to the root
    ///         history.
    error NonExistentRoot();
}

// src/interfaces/ICCIPPositionsManager.sol

interface ICCIPPositionsManager {
    function getTotalLiquidity() external view returns (uint256);

    function approve(uint256 _amount) external;

    function ccipSend(
        uint256 _liquidatedCollateralAmount,
        uint256 _profitAmountRequest,
        address _profitRecipientRequest,
        uint256 _openInterestLongInToken,
        uint256 _openInterestShortInUsd,
        bool _increaseLongInToken,
        bool _increaseShortInUsd
    ) external;
}

// src/interfaces/IPositions.sol

interface IPositions {
    struct Position {
        address trader;
        uint256 sizeInToken;
        uint256 sizeInUsd;
        uint256 collateralAmount;
        uint256 openPrice;
        bool isLong;
    }

    function getAvailableLiquidity() external view returns (uint256);

    function getPositionsCount() external view returns (uint256);

    function getMaxLeverageExceeded(uint256 _positionId) external view returns (bool);

    function liquidate(uint256 _positionId) external;
}

// src/libraries/ByteHasher.sol

library ByteHasher {
    /// @dev Creates a keccak256 hash of a bytestring.
    /// @param value The bytestring to hash
    /// @return The hash of the specified value
    /// @dev `>> 8` makes sure that the result is included in our field
    function hashToField(bytes memory value) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(value))) >> 8;
    }
}

// src/libraries/Constants.sol

library Constants {
    uint256 internal constant PRICE_FEED_PRECISION = 10 ** 8; // 1e8
    uint256 internal constant WAD_PRECISION = 10 ** 18; // 1e18
    uint256 internal constant SCALING_FACTOR = WAD_PRECISION / PRICE_FEED_PRECISION;
    uint256 internal constant USDC_PRECISION = 10 ** 6; // 1e6
    /// @dev The size of a position can be 20x the collateral, but exceeding this results in liquidation
    uint256 internal constant MAX_LEVERAGE = 20;
    /// @dev Traders cannot utilize more than a configured percentage of the deposited liquidity
    uint256 internal constant MAX_UTILIZATION_PERCENTAGE = 8000;
    uint256 internal constant BASIS_POINT_DIVISOR = 10000;
    uint256 internal constant LIQUIDATION_BONUS = 2000;
    int256 internal constant INT_PRECISION = 10 ** 18;
    uint256 internal constant CCIP_GAS_LIMIT = 3_000_000;
}

// lib/ccip/contracts/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol

/// @notice Application contracts that intend to receive messages from
/// the router should implement this interface.
interface IAny2EVMMessageReceiver {
  /// @notice Called by the Router to deliver a message.
  /// If this reverts, any token transfers also revert. The message
  /// will move to a FAILED state and become available for manual execution.
  /// @param message CCIP Message
  /// @dev Note ensure you check the msg.sender is the OffRampRouter
  function ccipReceive(Client.Any2EVMMessage calldata message) external;
}

// lib/ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol

interface IRouterClient {
  error UnsupportedDestinationChain(uint64 destChainSelector);
  error InsufficientFeeTokenAmount();
  error InvalidMsgValue();

  /// @notice Checks if the given chain ID is supported for sending/receiving.
  /// @param chainSelector The chain to check.
  /// @return supported is true if it is supported, false if not.
  function isChainSupported(uint64 chainSelector) external view returns (bool supported);

  /// @notice Gets a list of all supported tokens which can be sent or received
  /// to/from a given chain id.
  /// @param chainSelector The chainSelector.
  /// @return tokens The addresses of all tokens that are supported.
  function getSupportedTokens(uint64 chainSelector) external view returns (address[] memory tokens);

  /// @param destinationChainSelector The destination chainSelector
  /// @param message The cross-chain CCIP message including data and/or tokens
  /// @return fee returns execution fee for the message
  /// delivery to destination chain, denominated in the feeToken specified in the message.
  /// @dev Reverts with appropriate reason upon invalid message.
  function getFee(
    uint64 destinationChainSelector,
    Client.EVM2AnyMessage memory message
  ) external view returns (uint256 fee);

  /// @notice Request a message to be sent to the destination chain
  /// @param destinationChainSelector The destination chain ID
  /// @param message The cross-chain CCIP message including data and/or tokens
  /// @return messageId The message ID
  /// @dev Note if msg.value is larger than the required fee (from getFee) we accept
  /// the overpayment with no refund.
  /// @dev Reverts with appropriate reason upon invalid message.
  function ccipSend(
    uint64 destinationChainSelector,
    Client.EVM2AnyMessage calldata message
  ) external payable returns (bytes32);
}

// lib/openzeppelin-contracts/contracts/access/Ownable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// lib/world-id-contracts/src/interfaces/IWorldID.sol

/// @title WorldID Interface
/// @author Worldcoin
/// @notice The interface to the proof verification for WorldID.
interface IWorldID is IBaseWorldID {
    /// @notice Verifies a WorldID zero knowledge proof.
    /// @dev Note that a double-signaling check is not included here, and should be carried by the
    ///      caller.
    /// @dev It is highly recommended that the implementation is restricted to `view` if possible.
    ///
    /// @param root The of the Merkle tree
    /// @param signalHash A keccak256 hash of the Semaphore signal
    /// @param nullifierHash The nullifier hash
    /// @param externalNullifierHash A keccak256 hash of the external nullifier
    /// @param proof The zero-knowledge proof
    ///
    /// @custom:reverts string If the `proof` is invalid.
    function verifyProof(
        uint256 root,
        uint256 signalHash,
        uint256 nullifierHash,
        uint256 externalNullifierHash,
        uint256[8] calldata proof
    ) external;
}

// src/libraries/Utils.sol

library Utils {
    function scaleToUSDC(uint256 _amount) internal pure returns (uint256) {
        return _amount / (Constants.WAD_PRECISION / Constants.USDC_PRECISION);
    }
}

// lib/pyth-sdk-solidity/IPyth.sol

/// @title Consume prices from the Pyth Network (https://pyth.network/).
/// @dev Please refer to the guidance at https://docs.pyth.network/consumers/best-practices for how to consume prices safely.
/// @author Pyth Data Association
interface IPyth is IPythEvents {
    /// @notice Returns the period (in seconds) that a price feed is considered valid since its publish time
    function getValidTimePeriod() external view returns (uint validTimePeriod);

    /// @notice Returns the price and confidence interval.
    /// @dev Reverts if the price has not been updated within the last `getValidTimePeriod()` seconds.
    /// @param id The Pyth Price Feed ID of which to fetch the price and confidence interval.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getPrice(
        bytes32 id
    ) external view returns (PythStructs.Price memory price);

    /// @notice Returns the exponentially-weighted moving average price and confidence interval.
    /// @dev Reverts if the EMA price is not available.
    /// @param id The Pyth Price Feed ID of which to fetch the EMA price and confidence interval.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getEmaPrice(
        bytes32 id
    ) external view returns (PythStructs.Price memory price);

    /// @notice Returns the price of a price feed without any sanity checks.
    /// @dev This function returns the most recent price update in this contract without any recency checks.
    /// This function is unsafe as the returned price update may be arbitrarily far in the past.
    ///
    /// Users of this function should check the `publishTime` in the price to ensure that the returned price is
    /// sufficiently recent for their application. If you are considering using this function, it may be
    /// safer / easier to use either `getPrice` or `getPriceNoOlderThan`.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getPriceUnsafe(
        bytes32 id
    ) external view returns (PythStructs.Price memory price);

    /// @notice Returns the price that is no older than `age` seconds of the current time.
    /// @dev This function is a sanity-checked version of `getPriceUnsafe` which is useful in
    /// applications that require a sufficiently-recent price. Reverts if the price wasn't updated sufficiently
    /// recently.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getPriceNoOlderThan(
        bytes32 id,
        uint age
    ) external view returns (PythStructs.Price memory price);

    /// @notice Returns the exponentially-weighted moving average price of a price feed without any sanity checks.
    /// @dev This function returns the same price as `getEmaPrice` in the case where the price is available.
    /// However, if the price is not recent this function returns the latest available price.
    ///
    /// The returned price can be from arbitrarily far in the past; this function makes no guarantees that
    /// the returned price is recent or useful for any particular application.
    ///
    /// Users of this function should check the `publishTime` in the price to ensure that the returned price is
    /// sufficiently recent for their application. If you are considering using this function, it may be
    /// safer / easier to use either `getEmaPrice` or `getEmaPriceNoOlderThan`.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getEmaPriceUnsafe(
        bytes32 id
    ) external view returns (PythStructs.Price memory price);

    /// @notice Returns the exponentially-weighted moving average price that is no older than `age` seconds
    /// of the current time.
    /// @dev This function is a sanity-checked version of `getEmaPriceUnsafe` which is useful in
    /// applications that require a sufficiently-recent price. Reverts if the price wasn't updated sufficiently
    /// recently.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getEmaPriceNoOlderThan(
        bytes32 id,
        uint age
    ) external view returns (PythStructs.Price memory price);

    /// @notice Update price feeds with given update messages.
    /// This method requires the caller to pay a fee in wei; the required fee can be computed by calling
    /// `getUpdateFee` with the length of the `updateData` array.
    /// Prices will be updated if they are more recent than the current stored prices.
    /// The call will succeed even if the update is not the most recent.
    /// @dev Reverts if the transferred fee is not sufficient or the updateData is invalid.
    /// @param updateData Array of price update data.
    function updatePriceFeeds(bytes[] calldata updateData) external payable;

    /// @notice Wrapper around updatePriceFeeds that rejects fast if a price update is not necessary. A price update is
    /// necessary if the current on-chain publishTime is older than the given publishTime. It relies solely on the
    /// given `publishTimes` for the price feeds and does not read the actual price update publish time within `updateData`.
    ///
    /// This method requires the caller to pay a fee in wei; the required fee can be computed by calling
    /// `getUpdateFee` with the length of the `updateData` array.
    ///
    /// `priceIds` and `publishTimes` are two arrays with the same size that correspond to senders known publishTime
    /// of each priceId when calling this method. If all of price feeds within `priceIds` have updated and have
    /// a newer or equal publish time than the given publish time, it will reject the transaction to save gas.
    /// Otherwise, it calls updatePriceFeeds method to update the prices.
    ///
    /// @dev Reverts if update is not needed or the transferred fee is not sufficient or the updateData is invalid.
    /// @param updateData Array of price update data.
    /// @param priceIds Array of price ids.
    /// @param publishTimes Array of publishTimes. `publishTimes[i]` corresponds to known `publishTime` of `priceIds[i]`
    function updatePriceFeedsIfNecessary(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64[] calldata publishTimes
    ) external payable;

    /// @notice Returns the required fee to update an array of price updates.
    /// @param updateData Array of price update data.
    /// @return feeAmount The required fee in Wei.
    function getUpdateFee(
        bytes[] calldata updateData
    ) external view returns (uint feeAmount);

    /// @notice Parse `updateData` and return price feeds of the given `priceIds` if they are all published
    /// within `minPublishTime` and `maxPublishTime`.
    ///
    /// You can use this method if you want to use a Pyth price at a fixed time and not the most recent price;
    /// otherwise, please consider using `updatePriceFeeds`. This method does not store the price updates on-chain.
    ///
    /// This method requires the caller to pay a fee in wei; the required fee can be computed by calling
    /// `getUpdateFee` with the length of the `updateData` array.
    ///
    ///
    /// @dev Reverts if the transferred fee is not sufficient or the updateData is invalid or there is
    /// no update for any of the given `priceIds` within the given time range.
    /// @param updateData Array of price update data.
    /// @param priceIds Array of price ids.
    /// @param minPublishTime minimum acceptable publishTime for the given `priceIds`.
    /// @param maxPublishTime maximum acceptable publishTime for the given `priceIds`.
    /// @return priceFeeds Array of the price feeds corresponding to the given `priceIds` (with the same order).
    function parsePriceFeedUpdates(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64 minPublishTime,
        uint64 maxPublishTime
    ) external payable returns (PythStructs.PriceFeed[] memory priceFeeds);
}

// lib/ccip/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol

/// @title CCIPReceiver - Base contract for CCIP applications that can receive messages.
abstract contract CCIPReceiver is IAny2EVMMessageReceiver, IERC165 {
  address internal immutable i_ccipRouter;

  constructor(address router) {
    if (router == address(0)) revert InvalidRouter(address(0));
    i_ccipRouter = router;
  }

  /// @notice IERC165 supports an interfaceId
  /// @param interfaceId The interfaceId to check
  /// @return true if the interfaceId is supported
  /// @dev Should indicate whether the contract implements IAny2EVMMessageReceiver
  /// e.g. return interfaceId == type(IAny2EVMMessageReceiver).interfaceId || interfaceId == type(IERC165).interfaceId
  /// This allows CCIP to check if ccipReceive is available before calling it.
  /// If this returns false or reverts, only tokens are transferred to the receiver.
  /// If this returns true, tokens are transferred and ccipReceive is called atomically.
  /// Additionally, if the receiver address does not have code associated with
  /// it at the time of execution (EXTCODESIZE returns 0), only tokens will be transferred.
  function supportsInterface(bytes4 interfaceId) public pure virtual override returns (bool) {
    return interfaceId == type(IAny2EVMMessageReceiver).interfaceId || interfaceId == type(IERC165).interfaceId;
  }

  /// @inheritdoc IAny2EVMMessageReceiver
  function ccipReceive(Client.Any2EVMMessage calldata message) external virtual override onlyRouter {
    _ccipReceive(message);
  }

  /// @notice Override this function in your implementation.
  /// @param message Any2EVMMessage
  function _ccipReceive(Client.Any2EVMMessage memory message) internal virtual;

  /////////////////////////////////////////////////////////////////////
  // Plumbing
  /////////////////////////////////////////////////////////////////////

  /// @notice Return the current router
  /// @return CCIP router address
  function getRouter() public view returns (address) {
    return address(i_ccipRouter);
  }

  error InvalidRouter(address router);

  /// @dev only calls from the set router are accepted.
  modifier onlyRouter() {
    if (msg.sender != address(i_ccipRouter)) revert InvalidRouter(msg.sender);
    _;
  }
}

// lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/utils/SafeERC20.sol)

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    /**
     * @dev An operation with an ERC20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return success && (returndata.length == 0 || abi.decode(returndata, (bool))) && address(token).code.length > 0;
    }
}

// src/CCIPPositionsManager.sol

/// @notice Deposited collateral is held by this contract
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
    error CCIPPositionsManager__InsufficientLinkBalance(uint256 balance, uint256 fees);

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
    event PositionsMessageSent(
        bytes32 indexed messageId,
        uint256 _liquidatedCollateralAmount,
        uint256 _profitAmountRequest,
        address _profitRecipientRequest,
        uint256 _openInterestLongInToken,
        uint256 _openInterestShortInUsd,
        bool _increaseLongInToken,
        bool _increaseShortInUsd,
        uint256 fees
    );
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
    constructor(address _router, address _link, address _usdc, address _positions, address _owner)
        Ownable(_owner)
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
        uint256 _liquidatedCollateralAmount,
        uint256 _profitAmountRequest,
        address _profitRecipientRequest,
        uint256 _openInterestLongInToken,
        uint256 _openInterestShortInUsd,
        bool _increaseLongInToken,
        bool _increaseShortInUsd
    ) external onlyPositions {
        address receiver = s_vaultManager;
        uint64 destinationChainSelector = s_vaultManagerChainSelector;

        Client.EVM2AnyMessage memory evm2AnyMessage;

        if (_liquidatedCollateralAmount > 0) {
            Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
            tokenAmounts[0] = Client.EVMTokenAmount({token: address(i_usdc), amount: _liquidatedCollateralAmount});

            evm2AnyMessage = Client.EVM2AnyMessage({
                receiver: abi.encode(receiver),
                data: abi.encode(
                    _liquidatedCollateralAmount,
                    _profitAmountRequest,
                    _profitRecipientRequest,
                    _openInterestLongInToken,
                    _openInterestShortInUsd,
                    _increaseLongInToken,
                    _increaseShortInUsd
                ),
                tokenAmounts: tokenAmounts,
                extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: Constants.CCIP_GAS_LIMIT})), // needs to be set
                feeToken: address(i_link)
            });

            i_usdc.approve(i_ccipRouter, _liquidatedCollateralAmount);
        } else {
            // dont send tokenAmounts
            evm2AnyMessage = Client.EVM2AnyMessage({
                receiver: abi.encode(receiver),
                data: abi.encode(
                    _liquidatedCollateralAmount,
                    _profitAmountRequest,
                    _profitRecipientRequest,
                    _openInterestLongInToken,
                    _openInterestShortInUsd,
                    _increaseLongInToken,
                    _increaseShortInUsd
                ),
                tokenAmounts: new Client.EVMTokenAmount[](0),
                extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: Constants.CCIP_GAS_LIMIT})),
                feeToken: address(i_link)
            });
        }

        uint256 fees = IRouterClient(i_ccipRouter).getFee(destinationChainSelector, evm2AnyMessage);
        if (fees > i_link.balanceOf(address(this))) {
            revert CCIPPositionsManager__InsufficientLinkBalance(i_link.balanceOf(address(this)), fees);
        }

        // approve the Router to transfer LINK tokens on contract's behalf. It will spend the fees in LINK
        i_link.approve(address(i_ccipRouter), fees);

        // Send the message through the router and store the returned message ID
        bytes32 messageId = IRouterClient(i_ccipRouter).ccipSend(destinationChainSelector, evm2AnyMessage);

        // emit messageSent event
        emit PositionsMessageSent(
            messageId,
            _liquidatedCollateralAmount,
            _profitAmountRequest,
            _profitRecipientRequest,
            _openInterestLongInToken,
            _openInterestShortInUsd,
            _increaseLongInToken,
            _increaseShortInUsd,
            fees
        );
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

    /// @notice Only callable by the Positions contract
    function approve(uint256 _amount) external onlyPositions {
        IERC20(i_usdc).approve(address(i_positions), _amount);
    }

    /*//////////////////////////////////////////////////////////////
                                 GETTER
    //////////////////////////////////////////////////////////////*/
    function getTotalLiquidity() external view returns (uint256) {
        return s_totalLiquidity;
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

// src/Positions.sol

contract Positions is IPositions, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/
    using SafeERC20 for IERC20;
    using SignedMath for int256;
    using Utils for uint256;
    using ByteHasher for bytes;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error Positions__NoZeroAddress();
    error Positions__NoZeroAmount();
    error Positions__MaxLeverageExceeded();
    error Positions__OnlyTrader();
    error Positions__InvalidPosition();
    error Positions__InvalidPositionSize();
    error Positions__InsufficientLiquidity();
    error Positions__MaxLeverageNotExceeded();
    error Positions__PositionInProfit();
    error Positions__InvalidNullifier();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @dev Chainlink PriceFeed for the token being speculated on
    AggregatorV3Interface internal immutable i_priceFeed;
    /// @dev USDC is the token used for liquidity and collateral
    IERC20 internal immutable i_usdc;
    /// @dev Contract that handles crosschain messaging
    ICCIPPositionsManager internal immutable i_ccipPositionsManager;
    /// @dev Pyth pricefeed contract for the token being speculated on
    IPyth internal immutable i_pythFeed;
    /// @dev Pyth pricefeed ID for the token being speculated on
    bytes32 internal immutable i_pythFeedId;
    /// @dev The World ID instance that will be used for verifying proofs
    IWorldID internal immutable i_worldId;
    /// @dev The contract's external nullifier hash
    uint256 internal immutable i_externalNullifier;

    /// @dev Whether a nullifier hash has been used already. Used to restrict actions to a single WorldID
    mapping(uint256 => bool) internal s_nullifierHashes;
    /// @dev Maps position ID to a position
    mapping(uint256 positionId => Position position) internal s_position;
    /// @dev Increments everytime a position is opened
    uint256 internal s_positionsCount;
    /// @dev Total deposited collateral
    uint256 internal s_totalCollateral;
    uint256 internal s_totalOpenInterestLongInToken;
    uint256 internal s_totalOpenInterestLongInUsd; // scaled to 1e18, not scaled to usdc
    uint256 internal s_totalOpenInterestShortInToken;
    uint256 internal s_totalOpenInterestShortInUsd; // scaled to 1e18, not scaled to usdc

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event PositionOpened(
        uint256 indexed positionId,
        address trader,
        uint256 indexed sizeInToken,
        uint256 sizeInUsd,
        uint256 collateralAmount,
        uint256 indexed openPrice,
        bool isLong
    );
    event PositionSizeIncreased(
        uint256 indexed positionId, uint256 indexed newSizeInToken, uint256 indexed newSizeInUsd
    );
    event PositionSizeDecreased(
        uint256 indexed positionId, uint256 indexed newSizeInToken, uint256 indexed newSizeInUsd
    );
    event PositionCollateralIncreased(uint256 indexed positionId, uint256 indexed newCollateralAmount);
    event PositionCollateralDecreased(uint256 indexed positionId, uint256 indexed newCollateralAmount);
    event PositionClosed(uint256 indexed positionId, address indexed trader, int256 indexed pnl);
    event PositionLiquidated(uint256 indexed positionId, address indexed trader, int256 indexed pnl);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier revertIfZeroAddress(address _address) {
        if (_address == address(0)) revert Positions__NoZeroAddress();
        _;
    }

    modifier revertIfZeroAmount(uint256 _amount) {
        if (_amount == 0) revert Positions__NoZeroAmount();
        _;
    }

    /// @dev If the sizeInToken of a position is 0, it isn't an open position and therefore invalid
    modifier revertIfPositionInvalid(uint256 _positionId) {
        Position memory position = s_position[_positionId];
        if (position.sizeInToken == 0) revert Positions__InvalidPosition();
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
        address _pythFeed,
        bytes32 _pythFeedId,
        address _worldId,
        string memory _appId,
        string memory _actionId
    ) revertIfZeroAddress(_priceFeed) revertIfZeroAddress(_usdc) revertIfZeroAddress(_pythFeed) {
        i_priceFeed = AggregatorV3Interface(_priceFeed);
        i_usdc = IERC20(_usdc);
        i_pythFeed = IPyth(_pythFeed);
        i_pythFeedId = _pythFeedId;
        i_ccipPositionsManager =
            ICCIPPositionsManager(new CCIPPositionsManager(_router, _link, _usdc, address(this), msg.sender));
        i_worldId = IWorldID(_worldId);
        i_externalNullifier = abi.encodePacked(abi.encodePacked(_appId).hashToField(), _actionId).hashToField();
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @dev Allows a trader to open a position
    function openPosition(
        uint256 _sizeInTokenAmount,
        uint256 _collateralAmount,
        bool _isLong,
        uint256 _root,
        uint256 _nullifierHash,
        uint256[8] calldata _proof
    ) external revertIfZeroAmount(_sizeInTokenAmount) revertIfZeroAmount(_collateralAmount) nonReentrant {
        // Check and verify the WorldID uniqueness of the caller to mitigate manipulation by bots
        if (s_nullifierHashes[_nullifierHash]) revert Positions__InvalidNullifier();
        i_worldId.verifyProof(
            _root, abi.encodePacked(msg.sender).hashToField(), _nullifierHash, i_externalNullifier, _proof
        );
        s_nullifierHashes[_nullifierHash] = true;

        // Now open a position
        uint256 currentPrice = getLatestPrice();
        uint256 sizeInUsd = (_sizeInTokenAmount * currentPrice) / Constants.WAD_PRECISION;

        s_positionsCount++;
        uint256 positionId = s_positionsCount;
        s_position[positionId] =
            Position(msg.sender, _sizeInTokenAmount, sizeInUsd, _collateralAmount, currentPrice, _isLong);

        s_totalCollateral += _collateralAmount;

        /// @dev increase open interest
        _increaseTotalOpenInterest(_sizeInTokenAmount, sizeInUsd, _isLong);

        /// @dev revert if max leverage exceeded
        if (_isMaxLeverageExceeded(positionId)) revert Positions__MaxLeverageExceeded();

        emit PositionOpened(
            positionId, msg.sender, _sizeInTokenAmount, sizeInUsd, _collateralAmount, currentPrice, _isLong
        );

        /// @dev transfer usdc from trader to ccipPositionsManager
        i_usdc.safeTransferFrom(msg.sender, address(i_ccipPositionsManager), _collateralAmount);
    }

    /// @dev The position trader can call this to increase the size of their position
    function increaseSize(uint256 _positionId, uint256 _sizeInTokenAmountToIncrease)
        external
        revertIfPositionInvalid(_positionId)
        revertIfZeroAmount(_sizeInTokenAmountToIncrease)
        nonReentrant
    {
        Position memory position = s_position[_positionId];
        if (msg.sender != position.trader) revert Positions__OnlyTrader();

        uint256 sizeInUsd = (_sizeInTokenAmountToIncrease * getLatestPrice()) / Constants.WAD_PRECISION;

        s_position[_positionId].sizeInToken += _sizeInTokenAmountToIncrease;
        _increaseTotalOpenInterest(_sizeInTokenAmountToIncrease, sizeInUsd, position.isLong);

        /// @dev revert if max leverage exceeded
        if (_isMaxLeverageExceeded(_positionId)) revert Positions__MaxLeverageExceeded();

        emit PositionSizeIncreased(
            _positionId, position.sizeInToken + _sizeInTokenAmountToIncrease, position.sizeInUsd + sizeInUsd
        );
    }

    /// @dev Anyone can currently call this function on behalf of other users' positions to increase the collateral
    function increaseCollateral(uint256 _positionId, uint256 _collateralAmountToIncrease)
        external
        revertIfPositionInvalid(_positionId)
        revertIfZeroAmount(_collateralAmountToIncrease)
        nonReentrant
    {
        Position memory position = s_position[_positionId];

        s_position[_positionId].collateralAmount += _collateralAmountToIncrease;
        s_totalCollateral += _collateralAmountToIncrease;

        /// @dev Increasing collateral is almost certainly not going to exceed the max leverage
        /// but we check for added security
        /// @dev revert if max leverage exceeded
        if (_isMaxLeverageExceeded(_positionId)) revert Positions__MaxLeverageExceeded();

        emit PositionCollateralIncreased(_positionId, position.collateralAmount + _collateralAmountToIncrease);

        i_usdc.safeTransferFrom(msg.sender, address(i_ccipPositionsManager), _collateralAmountToIncrease);
    }

    /// @notice Only the position trader can call this to decrease the size of their position
    /// @notice If a position size is decreased to 0, the position will be closed
    function decreaseSize(uint256 _positionId, uint256 _sizeInTokenAmountToDecrease)
        external
        revertIfPositionInvalid(_positionId)
        revertIfZeroAmount(_sizeInTokenAmountToDecrease)
        nonReentrant
    {
        Position memory position = s_position[_positionId];
        if (msg.sender != position.trader) revert Positions__OnlyTrader();
        if (_sizeInTokenAmountToDecrease > position.sizeInToken) revert Positions__InvalidPositionSize();

        uint256 sizeInUsd = (position.sizeInUsd * _sizeInTokenAmountToDecrease) / position.sizeInToken;

        // Get the current PnL of the position
        int256 pnl = getPositionPnl(_positionId);
        // Calculate the realized PnL based on the decrease in size
        int256 realisedPnl = (pnl * int256(_sizeInTokenAmountToDecrease)) / int256(position.sizeInToken);

        uint256 collateral = position.collateralAmount;

        if (realisedPnl > 0) {
            // If the realized PnL is positive, convert to unsigned int
            uint256 positiveRealisedPnlScaledToUsdc = uint256(realisedPnl).scaleToUSDC();

            // Check if there is enough liquidity in the vault to pay the PnL
            uint256 availableLiquidity = getAvailableLiquidity();
            if (positiveRealisedPnlScaledToUsdc > availableLiquidity) revert Positions__InsufficientLiquidity();

            // Decrease the size of the position
            s_position[_positionId].sizeInToken -= _sizeInTokenAmountToDecrease;
            s_position[_positionId].sizeInUsd -= sizeInUsd;

            /// @dev we send the message to the vault via ccip, saying "we need this much profit sent back to this trader"
            i_ccipPositionsManager.ccipSend(
                0, positiveRealisedPnlScaledToUsdc, msg.sender, _sizeInTokenAmountToDecrease, 0, false, false
            );
        } else if (realisedPnl < 0) {
            // If the realized PnL is negative, convert to unsigned int and scale to USDC precision
            uint256 negativeRealisedPnl = uint256(realisedPnl.abs());
            uint256 negativeRealisedPnlScaledToUsdc = negativeRealisedPnl.scaleToUSDC();

            if (collateral > negativeRealisedPnlScaledToUsdc) {
                // Deduct the realized loss from the collateral if there is enough
                s_position[_positionId].collateralAmount -= negativeRealisedPnlScaledToUsdc;
                s_totalCollateral -= negativeRealisedPnlScaledToUsdc;

                // Decrease the size of the position
                s_position[_positionId].sizeInToken -= _sizeInTokenAmountToDecrease;
                s_position[_positionId].sizeInUsd -= sizeInUsd;
                _decreaseTotalOpenInterest(_sizeInTokenAmountToDecrease, sizeInUsd, position.isLong);
            } else {
                // Set the collateral to zero if the realized loss exceeds it
                s_totalCollateral -= collateral;
                s_position[_positionId].collateralAmount = 0;

                // Decrease the size of the position
                s_position[_positionId].sizeInToken = 0;
                s_position[_positionId].sizeInUsd = 0;
                _decreaseTotalOpenInterestAndSendCollateral(
                    collateral, _sizeInTokenAmountToDecrease, sizeInUsd, position.isLong
                );
            }
        } else if (realisedPnl == 0) {
            s_position[_positionId].sizeInToken -= _sizeInTokenAmountToDecrease;
            s_position[_positionId].sizeInUsd -= sizeInUsd;
            _decreaseTotalOpenInterest(_sizeInTokenAmountToDecrease, sizeInUsd, position.isLong);
        }

        if (position.sizeInToken == _sizeInTokenAmountToDecrease && realisedPnl >= 0) {
            // If the position size is zero, mark the position as closed and emit the PositionClosed event
            s_totalCollateral -= collateral;
            s_position[_positionId].collateralAmount = 0;
            emit PositionClosed(_positionId, msg.sender, realisedPnl);

            // Transfer remaining collateral back to the trader
            i_ccipPositionsManager.approve(collateral);
            i_usdc.safeTransferFrom(address(i_ccipPositionsManager), msg.sender, collateral);
        } else if (s_position[_positionId].sizeInToken == 0) {
            emit PositionClosed(_positionId, msg.sender, realisedPnl);
        } else {
            emit PositionSizeDecreased(
                _positionId, position.sizeInToken - _sizeInTokenAmountToDecrease, position.sizeInUsd - sizeInUsd
            );
        }
    }

    /// @dev Only the position trader can call this to decrease the collateral of their position
    function decreaseCollateral(uint256 _positionId, uint256 _collateralAmountToDecrease)
        external
        revertIfPositionInvalid(_positionId)
        revertIfZeroAmount(_collateralAmountToDecrease)
        nonReentrant
    {
        Position memory position = s_position[_positionId];
        if (msg.sender != position.trader) revert Positions__OnlyTrader();

        s_position[_positionId].collateralAmount -= _collateralAmountToDecrease;
        s_totalCollateral -= _collateralAmountToDecrease;

        /// @dev revert if max leverage exceeded
        if (_isMaxLeverageExceeded(_positionId)) revert Positions__MaxLeverageExceeded();
        emit PositionCollateralDecreased(_positionId, position.collateralAmount - _collateralAmountToDecrease);

        i_ccipPositionsManager.approve(_collateralAmountToDecrease);
        i_usdc.safeTransferFrom(address(i_ccipPositionsManager), msg.sender, _collateralAmountToDecrease);
    }

    /// @notice Anyone can call this to liquidate and close an over leveraged position
    /// @notice Liquidators are incentivized to call this as early as possible as they will receive
    /// a liquidation reward of 20% of any remaining collateral
    /// @dev This function is called by Chainlink Automation nodes via our AutomatedLiquidator contract
    /// when a position becomes liquidatable to keep our system solvent
    function liquidate(uint256 _positionId) external revertIfPositionInvalid(_positionId) nonReentrant {
        Position memory position = s_position[_positionId];
        if (!_isMaxLeverageExceeded(_positionId)) revert Positions__MaxLeverageNotExceeded();

        // use the pnl to get any remaining collateral
        int256 pnl = getPositionPnl(_positionId);
        if (pnl >= 0) revert Positions__PositionInProfit(); // does this line even need to be here??
        uint256 remainingCollateral = position.collateralAmount;
        uint256 negativePnl = uint256(pnl.abs());
        uint256 negativePnlScaledToUsdc = negativePnl.scaleToUSDC();
        if (remainingCollateral > negativePnlScaledToUsdc) remainingCollateral -= negativePnlScaledToUsdc;
        else remainingCollateral = 0;

        // Effects: Close the position
        s_totalCollateral -= position.collateralAmount;
        s_position[_positionId].collateralAmount = 0;
        s_position[_positionId].sizeInToken = 0;
        s_position[_positionId].sizeInUsd = 0;

        emit PositionLiquidated(_positionId, position.trader, pnl);

        if (remainingCollateral > 0) {
            // calculate 20% of position.collateralAmount
            uint256 liquidationReward =
                (remainingCollateral * Constants.LIQUIDATION_BONUS) / Constants.BASIS_POINT_DIVISOR;
            i_ccipPositionsManager.approve(remainingCollateral);
            i_usdc.safeTransferFrom(address(i_ccipPositionsManager), msg.sender, liquidationReward);

            // send the other 80% to vault via ccip
            uint256 collateralToVault = remainingCollateral - liquidationReward;
            i_ccipPositionsManager.ccipSend(collateralToVault, 0, address(0), 0, 0, false, false);
        }
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _isMaxLeverageExceeded(uint256 _positionId) internal view returns (bool) {
        Position memory position = s_position[_positionId];

        int256 pnl = getPositionPnl(_positionId);

        uint256 effectiveCollateral = position.collateralAmount;
        if (pnl >= 0) {
            effectiveCollateral += uint256(pnl);
        } else {
            if (pnl.abs() > effectiveCollateral) {
                effectiveCollateral = 0;
            } else {
                effectiveCollateral -= pnl.abs();
            }
        }
        if (effectiveCollateral == 0) return true;

        uint256 currentPrice = getLatestPrice();
        uint256 sizeInUsd = (position.sizeInToken * currentPrice) / Constants.WAD_PRECISION;
        uint256 sizeInUsdScaled = sizeInUsd.scaleToUSDC();
        uint256 effectiveCollateralByLeverage = effectiveCollateral * Constants.MAX_LEVERAGE;

        return (effectiveCollateralByLeverage < sizeInUsdScaled);
    }

    function _increaseTotalOpenInterest(uint256 _sizeInToken, uint256 _sizeInUsd, bool _isLong) internal {
        if (_isLong) {
            i_ccipPositionsManager.ccipSend(0, 0, address(0), _sizeInToken, 0, true, false);
        } else {
            i_ccipPositionsManager.ccipSend(0, 0, address(0), 0, _sizeInUsd, false, true);
        }
    }

    function _decreaseTotalOpenInterest(uint256 _sizeInToken, uint256 _sizeInUsd, bool _isLong) internal {
        if (_isLong) {
            i_ccipPositionsManager.ccipSend(0, 0, address(0), _sizeInToken, 0, false, false);
        } else {
            i_ccipPositionsManager.ccipSend(0, 0, address(0), 0, _sizeInUsd, false, false);
        }
    }

    function _decreaseTotalOpenInterestAndSendCollateral(
        uint256 _liquidatedCollateralToSend,
        uint256 _sizeInToken,
        uint256 _sizeInUsd,
        bool _isLong
    ) internal {
        if (_isLong) {
            i_ccipPositionsManager.ccipSend(_liquidatedCollateralToSend, 0, address(0), _sizeInToken, 0, false, false);
        } else {
            i_ccipPositionsManager.ccipSend(_liquidatedCollateralToSend, 0, address(0), 0, _sizeInUsd, false, false);
        }
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

    /// @dev Returns the PnL for a position
    function getPositionPnl(uint256 _positionId) public view returns (int256) {
        Position memory position = s_position[_positionId];
        if (position.sizeInToken == 0) return 0;

        uint256 currentPrice = getLatestPrice();

        int256 pnl;
        if (position.isLong) {
            /// Formula for Long PnL:
            /// (Current Market Value - Average Position Price) * Size In Tokens
            pnl = ((int256(currentPrice) - int256(position.openPrice)) * int256(position.sizeInToken))
                / Constants.INT_PRECISION;
        } else {
            /// Formula for Short PnL:
            /// (Average Position Price - Current Market Value) * Size In Tokens
            pnl = ((int256(position.openPrice) - int256(currentPrice)) * int256(position.sizeInToken))
                / Constants.INT_PRECISION;
        }
        return pnl;
    }

    /// @dev Returns the available liquidity of the protocol, excluding any collateral or reserved profits
    function getAvailableLiquidity() public view returns (uint256) {
        // Total assets in the vault
        uint256 totalLiquidity = i_ccipPositionsManager.getTotalLiquidity();

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

    function getPositionData(uint256 _positionId)
        external
        view
        returns (address, uint256, uint256, uint256, uint256, bool)
    {
        Position memory position = s_position[_positionId];
        return (
            position.trader,
            position.sizeInToken,
            position.sizeInUsd,
            position.collateralAmount,
            position.openPrice,
            position.isLong
        );
    }

    function getTotalCollateral() external view returns (uint256) {
        return s_totalCollateral;
    }

    function getPositionsCount() external view returns (uint256) {
        return s_positionsCount;
    }

    function getMaxLeverageExceeded(uint256 _positionId) external view returns (bool) {
        return _isMaxLeverageExceeded(_positionId);
    }

    function getCcipPositionsManager() external view returns (address) {
        return address(i_ccipPositionsManager);
    }
}
