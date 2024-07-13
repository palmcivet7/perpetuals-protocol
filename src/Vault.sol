// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IVault} from "./interfaces/IVault.sol";
import {ICCIPVaultManager, CCIPVaultManager} from "./CCIPVaultManager.sol";

contract Vault is IVault, ERC4626 {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error Vault__InsufficientLiquidity();
    error Vault__PublicMintDisabled();
    error Vault__PublicRedeemDisabled();
    error Vault__OnlyVaultManager();
    error Vault__NoZeroAddress();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    ICCIPVaultManager internal immutable i_ccipVaultManager;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier revertIfZeroAddress(address _address) {
        if (_address == address(0)) revert Vault__NoZeroAddress();
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
        bytes32 _pythFeedId
    )
        ERC4626(IERC20(_usdc))
        ERC20("Vault USDC", "vUSDC")
        revertIfZeroAddress(_router)
        revertIfZeroAddress(_link)
        revertIfZeroAddress(_usdc)
        revertIfZeroAddress(_priceFeed)
        revertIfZeroAddress(_pythFeed)
    {
        i_ccipVaultManager = ICCIPVaultManager(
            new CCIPVaultManager(_router, _link, _usdc, _priceFeed, address(this), _pythFeed, _pythFeedId)
        );
    }

    /*//////////////////////////////////////////////////////////////
                       PUBLIC/EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @dev When a deposit is made, we have to send a message across chains so our Perpetual positions contract
    /// is aware of the current amount of deposited liquidity we have.
    function deposit(uint256 assets, address receiver) public override(ERC4626) returns (uint256) {
        uint256 shares = super.deposit(assets, receiver);
        i_ccipVaultManager.ccipSend(assets, true, 0, address(0));
        return shares;
    }

    function withdraw(uint256 assets, address receiver, address owner)
        public
        override(ERC4626, IVault)
        returns (uint256)
    {
        uint256 availableLiquidity = i_ccipVaultManager.getAvailableLiquidity();
        if (assets > availableLiquidity) revert Vault__InsufficientLiquidity();

        uint256 shares = super.withdraw(assets, receiver, owner);
        i_ccipVaultManager.ccipSend(assets, false, 0, address(0));
        return shares;
    }

    /// @dev Only callable by the Positions contract
    function approve(uint256 _amount) external {
        if (msg.sender != address(i_ccipVaultManager)) revert Vault__OnlyVaultManager();
        IERC20(asset()).approve(address(i_ccipVaultManager), _amount);
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Override maxWithdraw function to consider available liquidity
    function maxWithdraw(address owner) public view override(ERC4626, IVault) returns (uint256) {
        uint256 availableLiquidity = i_ccipVaultManager.getAvailableLiquidity();
        uint256 maxAssets = super.maxWithdraw(owner);

        return availableLiquidity < maxAssets ? availableLiquidity : maxAssets;
    }

    /// @notice Override totalAssets function to match the visibility and mutability of the base function
    function totalAssets() public view override(ERC4626, IVault) returns (uint256) {
        return super.totalAssets();
    }

    function getCcipVaultManager() external view returns (address) {
        return address(i_ccipVaultManager);
    }

    /*//////////////////////////////////////////////////////////////
                           DISABLED FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @dev mint and redeem are disabled as we only want users interacting with the vault to deposit and withdraw
    function mint(uint256, address) public pure override returns (uint256) {
        revert Vault__PublicMintDisabled();
    }

    function redeem(uint256, address, address) public pure override returns (uint256) {
        revert Vault__PublicRedeemDisabled();
    }
}
