// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../src/integrations/KodiakVaultHook.sol";

contract RedeployHooks is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.addr(deployerPrivateKey);
        
        // Vault addresses
        address SENIOR_VAULT = 0x65691bd1972e906459954306aDa0f622a47d4744;
        address JUNIOR_VAULT = 0x3A1b3b300dEE06Caf0b691F1771d1Aa26d70B067;
        address RESERVE_VAULT = 0x2C75291479788C568A6750185CaDedf43aBFC553;
        
        // HONEY token
        address HONEY = 0xFCBD14DC51f0A4d49d5E53C2E0950e0bC26d0Dce;
        
        // Kodiak addresses
        address KODIAK_ISLAND = 0xf6b16E73d3b0e2784AAe8C4cd06099BE65d092Bf;
        address KODIAK_ROUTER = 0x679a7C63FC83b6A4D9C1F931891d705483d4791F;
        
        // Enso aggregator
        address ENSO_AGG = 0xF75584eF6673aD213a685a1B58Cc0330B8eA22Cf;
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Deploying NEW hooks with fix...");
        console.log("Admin:", admin);
        
        // Deploy Senior Hook
        console.log("\n=== SENIOR HOOK ===");
        KodiakVaultHook seniorHook = new KodiakVaultHook(SENIOR_VAULT, HONEY, admin);
        console.log("Deployed at:", address(seniorHook));
        seniorHook.setRouter(KODIAK_ROUTER);
        seniorHook.setIsland(KODIAK_ISLAND);
        seniorHook.setAggregatorWhitelisted(ENSO_AGG, true);
        console.log("Configured!");
        
        // Deploy Junior Hook
        console.log("\n=== JUNIOR HOOK ===");
        KodiakVaultHook juniorHook = new KodiakVaultHook(JUNIOR_VAULT, HONEY, admin);
        console.log("Deployed at:", address(juniorHook));
        juniorHook.setRouter(KODIAK_ROUTER);
        juniorHook.setIsland(KODIAK_ISLAND);
        juniorHook.setAggregatorWhitelisted(ENSO_AGG, true);
        console.log("Configured!");
        
        // Deploy Reserve Hook
        console.log("\n=== RESERVE HOOK ===");
        KodiakVaultHook reserveHook = new KodiakVaultHook(RESERVE_VAULT, HONEY, admin);
        console.log("Deployed at:", address(reserveHook));
        reserveHook.setRouter(KODIAK_ROUTER);
        reserveHook.setIsland(KODIAK_ISLAND);
        reserveHook.setAggregatorWhitelisted(ENSO_AGG, true);
        console.log("Configured!");
        
        vm.stopBroadcast();
        
        console.log("\n=== SUMMARY ===");
        console.log("Senior Hook:", address(seniorHook));
        console.log("Junior Hook:", address(juniorHook));
        console.log("Reserve Hook:", address(reserveHook));
    }
}


