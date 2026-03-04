// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {OrderManager} from "../src/OrderManager.sol";

/// @title Deploy - Deployment script for orlimeth
/// @dev Usage: forge script script/Deploy.s.sol --rpc-url sepolia --broadcast --verify
contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        uint256 feeBps = vm.envOr("FEE_BPS", uint256(30)); // Default: 0.3%

        vm.startBroadcast(deployerPrivateKey);

        OrderManager orderManager = new OrderManager(feeBps, treasury);
        console.log("OrderManager deployed at:", address(orderManager));
        console.log("  Fee (bps):", feeBps);
        console.log("  Treasury:", treasury);

        vm.stopBroadcast();
    }
}
