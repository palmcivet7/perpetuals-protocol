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
}
