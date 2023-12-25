// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockWETH is ERC20 {
    constructor() ERC20("Mock WETH", "WETH") {}

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function mintTokens(uint256 value) public {
        _mint(msg.sender, value);
    }
}
