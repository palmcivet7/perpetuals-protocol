// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Constants} from "./Constants.sol";

library Utils {
    function scaleToUSDC(uint256 _amount) internal pure returns (uint256) {
        return _amount / (Constants.WAD_PRECISION / Constants.USDC_PRECISION);
    }
}
