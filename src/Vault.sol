// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IVault} from "./interfaces/IVault.sol";
import {IPositions} from "./interfaces/IPositions.sol";

contract Vault is IVault, ERC4626 {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error Vault__InsufficientLiquidity();
    error Vault__PublicMintDisabled();
    error Vault__PublicRedeemDisabled();
    error Vault__OnlyPositions();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    IPositions internal immutable i_positions;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _positions, address _usdc) ERC4626(IERC20(_usdc)) ERC20("Vault USDC", "vUSDC") {
        i_positions = IPositions(_positions);
    }

    /*//////////////////////////////////////////////////////////////
                       PUBLIC/EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override(ERC4626, IVault)
        returns (uint256)
    {
        uint256 availableLiquidity = i_positions.getAvailableLiquidity();
        if (assets > availableLiquidity) revert Vault__InsufficientLiquidity();

        return super.withdraw(assets, receiver, owner);
    }

    /// @dev Only callable by the Positions contract
    function approve(uint256 _amount) external {
        if (msg.sender != address(i_positions)) revert Vault__OnlyPositions();
        IERC20(asset()).approve(address(i_positions), _amount);
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Override maxWithdraw function to consider available liquidity
    function maxWithdraw(address owner) public view override(ERC4626, IVault) returns (uint256) {
        uint256 availableLiquidity = i_positions.getAvailableLiquidity();
        uint256 maxAssets = super.maxWithdraw(owner);

        return availableLiquidity < maxAssets ? availableLiquidity : maxAssets;
    }

    /// @notice Override totalAssets function to match the visibility and mutability of the base function
    function totalAssets() public view override(ERC4626, IVault) returns (uint256) {
        return super.totalAssets();
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
