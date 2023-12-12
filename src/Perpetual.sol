// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IVault} from "./interfaces/IVault.sol";
import {Vault} from "./Vault.sol";

contract Perpetual {
    error Perpetual__InvalidAddress();

    AggregatorV3Interface public immutable i_priceFeed;
    IVault public immutable i_vault;

    constructor(address _priceFeed, address _vault) {
        if (_priceFeed == address(0)) revert Perpetual__InvalidAddress();
        if (_vault == address(0)) revert Perpetual__InvalidAddress();
        i_priceFeed = AggregatorV3Interface(_priceFeed);
        i_vault = IVault(_vault);
    }

    /////////////////////
    ////// Getter //////
    ///////////////////

    function getLatestPrice() public view returns (uint256) {
        (, int256 price,,,) = i_priceFeed.latestRoundData();
        return uint256(price);
    }

    function getTotalPnL() public view returns (int256) {}

    function getAvailableLiquidity() public view returns (uint256) {}
}
