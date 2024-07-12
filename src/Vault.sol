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
                           ERC4626 FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function withdraw(uint256 assets, address receiver, address owner) public override(ERC4626) returns (uint256) {
        uint256 availableLiquidity = i_perpetual.getAvailableLiquidity();
        if (assets > availableLiquidity) revert Vault__InsufficientLiquidity();

        return super.withdraw(assets, receiver, owner);
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
