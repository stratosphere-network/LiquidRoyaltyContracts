// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {console2} from "forge-std/console2.sol";

contract DeployTokens is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Read custom parameters from environment (with defaults)
        string memory token1Name = vm.envOr("TOKEN1_NAME", string("SAIL Token"));
        string memory token1Symbol = vm.envOr("TOKEN1_SYMBOL", string("SAIL"));
        string memory token2Name = vm.envOr("TOKEN2_NAME", string("USD Ethena"));
        string memory token2Symbol = vm.envOr("TOKEN2_SYMBOL", string("USDe"));
        uint256 token1Supply = vm.envOr("TOKEN1_SUPPLY", uint256(1_000_000e18));
        uint256 token2Supply = vm.envOr("TOKEN2_SUPPLY", uint256(1_000_000e18));
        
        console2.log("===========================================");
        console2.log("Token 1: %s (%s) - %s supply", token1Name, token1Symbol, token1Supply);
        console2.log("Token 2: %s (%s) - %s supply", token2Name, token2Symbol, token2Supply);
        console2.log("===========================================");
        console2.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy Token 1
        MockERC20 token1 = new MockERC20(token1Name, token1Symbol, 18);
        console2.log("Token 1 deployed at:", address(token1));
        
        // Mint Token 1 to deployer
        address deployer = vm.addr(deployerPrivateKey);
        token1.mint(deployer, token1Supply);
        console2.log("Minted Token 1 to:", deployer);
        console2.log("");
        
        // Deploy Token 2
        MockERC20 token2 = new MockERC20(token2Name, token2Symbol, 18);
        console2.log("Token 2 deployed at:", address(token2));
        
        // Mint Token 2 to deployer
        token2.mint(deployer, token2Supply);
        console2.log("Minted Token 2 to:", deployer);
        
        vm.stopBroadcast();
        
        console2.log("");
        console2.log("===========================================");
        console2.log("DEPLOYMENT SUMMARY");
        console2.log("===========================================");
        console2.log("Token 1 (%s):", token1Symbol);
        console2.log("  Address: %s", address(token1));
        console2.log("  Balance: %s", token1Supply);
        console2.log("");
        console2.log("Token 2 (%s):", token2Symbol);
        console2.log("  Address: %s", address(token2));
        console2.log("  Balance: %s", token2Supply);
    }
}

