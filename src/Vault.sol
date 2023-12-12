// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {ERC4626, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IPerpetual} from "./interfaces/IPerpetual.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Vault is ERC4626, Ownable {
    error Vault__NotEnoughLiquidity();

    IPerpetual public s_perpetual;

    constructor(IERC20 _asset) ERC4626(_asset) ERC20("Vault USDC", "vUSDC") {}

    function withdraw(uint256 _assets, address _receiver, address _owner) public override returns (uint256) {
        uint256 availableLiquidity = s_perpetual.getAvailableLiquidity();
        if (_assets > availableLiquidity) revert Vault__NotEnoughLiquidity();
        return super.withdraw(_assets, _receiver, _owner);
    }

    function totalAssets() public view override returns (uint256) {
        int256 totalPnL = s_perpetual.getTotalPnL();
        if (totalPnL <= 0) return super.totalAssets();
        return super.totalAssets() - uint256(totalPnL);
    }

    /////////////////////
    ////// Setter //////
    ///////////////////

    function setPerpetual(address _perpetual) public onlyOwner {
        s_perpetual = IPerpetual(_perpetual);
    }
}
