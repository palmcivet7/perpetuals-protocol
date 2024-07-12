// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IVault} from "./interfaces/IVault.sol";
import {IPositions} from "./interfaces/IPositions.sol";

contract Vault is IVault, ERC4626 {
    IPositions internal immutable i_positions;

    constructor(address _positions, address _usdc) ERC4626(IERC20(_usdc)) ERC20("Vault USDC", "vUSDC") {
        i_positions = IPositions(_positions);
    }
}
