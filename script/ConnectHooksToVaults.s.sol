// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {UnifiedConcreteSeniorVault} from "../src/concrete/UnifiedConcreteSeniorVault.sol";
import {ConcreteJuniorVault} from "../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../src/concrete/ConcreteReserveVault.sol";

contract ConnectHooksToVaults is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        address seniorVault = vm.envAddress("SENIOR_VAULT");
        address juniorVault = vm.envAddress("JUNIOR_VAULT");
        address reserveVault = vm.envAddress("RESERVE_VAULT");
        address seniorHook = vm.envAddress("SENIOR_HOOK");
        address juniorHook = vm.envAddress("JUNIOR_HOOK");
        address reserveHook = vm.envAddress("RESERVE_HOOK");
        
        console.log("Connecting Hooks to Vaults...");
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Connect Senior Hook to Senior Vault
        console.log("Connecting Senior Hook to Senior Vault...");
        UnifiedConcreteSeniorVault(seniorVault).setKodiakHook(seniorHook);
        console.log("Senior Hook connected!");
        
        // Connect Junior Hook to Junior Vault
        console.log("Connecting Junior Hook to Junior Vault...");
        ConcreteJuniorVault(juniorVault).setKodiakHook(juniorHook);
        console.log("Junior Hook connected!");
        
        // Connect Reserve Hook to Reserve Vault
        console.log("Connecting Reserve Hook to Reserve Vault...");
        ConcreteReserveVault(reserveVault).setKodiakHook(reserveHook);
        console.log("Reserve Hook connected!");
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("========================================");
        console.log("HOOKS CONNECTED TO VAULTS!");
        console.log("========================================");
        console.log("");
        console.log("Hooks are now automatically whitelisted as LP protocols");
    }
}

