// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {Positions, CCIPPositionsManager} from "../src/Positions.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract OpenPosition is Script {
    // these worldcoin values are not correct... WHERE DO WE GET THEM????????
    uint256 nullifierHash = 0x18310f83;
    uint256 root = 0x81f2c09a8b0e23de088837588ccb46e5565af92a09e943fe17aaa7a3ec6960f;
    uint256[8] proof = [
        0x29cddd130f81c1a0abd4b1077c82e556fe9e6a7d8915baac867dd6392e03fc10,
        0x1fabf9e4a1b45abcb1580565c9d615c8616ad588b1a01ade07a00ff7d965442b,
        0x23ccc263123e8cd76ea7773c6d4eddc2d4f7b4feba213f85dfb56070e42a87b7,
        0x226b40abc0db1a9fa7c8a440e30ca321639df97c844d1a1d385d3e3073e805a0,
        0x13779875425d9baa6f71597fe9ac21e3c0ef35b27802068c5528ed28231c050c,
        0x68e7081aa8912a70d404f5ac668709898e496e79af27a41228f94ee501f2f84,
        0x249471298db747c1e1e7388bb41e58ec2d541bdd6eee00be3b6ce9f02977df90,
        0x19ce330c2870c52b0855be468f9bc91e8bb6b6c0e26545363b1be467f92eb40e
    ];

    // uint256 nullifierHash = 8948157585783663789838107275528263032620185158510998613324903049109766495560;
    // uint256 root = 3279946369261550620565137787328089596547413227207252702421755543618432337005;
    // uint256[8] proof = [
    //     954483983823815442438886060840308254886542273532424968945368477772528689647,
    //     16265283516263487471683711734972400957456069087608195953375626127120553290508,
    //     6220466705902493461073267709480915937326724337377530966379369832056152910855,
    //     2857984551543312170906400043653393414294288627614320047432150055624816608483,
    //     19698481773678402312844388215970577995527022292525395325342753110061950005068,
    //     5978942657511820312535324256421858283517258967472521923088339501588273725063,
    //     19761801149144845789217289109603238753387736657046549667147699180902601096619,
    //     18843849550096527523986320016395836099230665974248916686031352588493945024373
    // ];

    address positionsAddress = 0xAa829eabEC1ec37033c7eFF60C4527Dcf510E28d;
    address usdcAddress = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;

    function run() external {
        vm.startBroadcast();

        // Create an instance of the token contract
        IERC20 token = IERC20(usdcAddress);

        // Approve the contract to spend tokens
        token.approve(positionsAddress, 20000000);

        // Create an instance of the contract
        Positions positions = Positions(positionsAddress);

        positions.openPosition(0.000005 ether, 20000000, true, root, nullifierHash, proof);

        vm.stopBroadcast();
    }
}

// forge script script/OpenPosition.s.sol --broadcast --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
