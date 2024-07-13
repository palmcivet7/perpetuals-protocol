// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {PythStructs} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

contract MockPyth {
    PythStructs.Price internal priceStruct;

    constructor(int64 _price, uint64 _conf, int32 _expo) {
        priceStruct.price = _price;
        priceStruct.conf = _conf;
        priceStruct.expo = _expo;
        priceStruct.publishTime = block.timestamp;
    }

    function getPrice(bytes32) external view returns (PythStructs.Price memory) {
        return priceStruct;
    }

    function getPriceUnsafe(bytes32) external view returns (PythStructs.Price memory) {
        return priceStruct;
    }

    function updatePrice(int64 _price, uint64 _conf, int32 _expo) external {
        priceStruct.price = _price;
        priceStruct.conf = _conf;
        priceStruct.expo = _expo;
        priceStruct.publishTime = block.timestamp;
    }
}
