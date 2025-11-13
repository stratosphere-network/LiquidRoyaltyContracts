// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {KodiakVaultHook} from "../src/integrations/KodiakVaultHook.sol";

contract ConfigureHooks is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        address seniorHook = vm.envAddress("SENIOR_HOOK");
        address juniorHook = vm.envAddress("JUNIOR_HOOK");
        address reserveHook = vm.envAddress("RESERVE_HOOK");
        address kodiakRouter = vm.envAddress("KODIAK_ROUTER_ADDRESS");
        address kodiakIsland = vm.envAddress("KODIAK_ISLAND_ADDRESS");
        
        console.log("Configuring Hooks...");
        console.log("Router:", kodiakRouter);
        console.log("Island:", kodiakIsland);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Configure Senior Hook
        console.log("Configuring Senior Hook...");
        KodiakVaultHook(payable(seniorHook)).setRouter(kodiakRouter);
        KodiakVaultHook(payable(seniorHook)).setIsland(kodiakIsland);
        console.log("Senior Hook configured!");
        
        // Configure Junior Hook
        console.log("Configuring Junior Hook...");
        KodiakVaultHook(payable(juniorHook)).setRouter(kodiakRouter);
        KodiakVaultHook(payable(juniorHook)).setIsland(kodiakIsland);
        console.log("Junior Hook configured!");
        
        // Configure Reserve Hook
        console.log("Configuring Reserve Hook...");
        KodiakVaultHook(payable(reserveHook)).setRouter(kodiakRouter);
        KodiakVaultHook(payable(reserveHook)).setIsland(kodiakIsland);
        console.log("Reserve Hook configured!");
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("========================================");
        console.log("HOOKS CONFIGURED!");
        console.log("========================================");
        console.log("");
        console.log("Note: WBERA not set yet (set later if needed for native BERA swaps)");
    }
}

