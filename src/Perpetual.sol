// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IVault} from "./interfaces/IVault.sol";
import {Vault} from "./Vault.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Perpetual {
    error Perpetual__InvalidAddress();

    using SafeERC20 for IERC20;

    AggregatorV3Interface public immutable i_priceFeed;
    IVault public immutable i_vault;
    IERC20 public immutable i_collateralToken;

    constructor(address _priceFeed, address _vault, address _collateralToken) {
        if (_priceFeed == address(0)) revert Perpetual__InvalidAddress();
        if (_vault == address(0)) revert Perpetual__InvalidAddress();
        if (_collateralToken == address(0)) revert Perpetual__InvalidAddress();
        i_priceFeed = AggregatorV3Interface(_priceFeed);
        i_vault = IVault(_vault);
        i_collateralToken = IERC20(_collateralToken);
    }

    /////////////////////
    ////// User ////////
    ///////////////////

    function openPosition(uint256 _size, uint256 _collateralAmount) external {
        uint256 leverage = _size / _collateralAmount;
    }

    function increaseSize() external {}

    function increaseCollateral() external {}

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
