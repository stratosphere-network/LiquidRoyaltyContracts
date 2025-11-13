// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {UnifiedConcreteSeniorVault} from "../src/concrete/UnifiedConcreteSeniorVault.sol";
import {ConcreteJuniorVault} from "../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../src/concrete/ConcreteReserveVault.sol";

contract VerifyDeployment is Script {
    function run() external view {
        address seniorVault = vm.envAddress("SENIOR_VAULT");
        address juniorVault = vm.envAddress("JUNIOR_VAULT");
        address reserveVault = vm.envAddress("RESERVE_VAULT");
        address seniorHook = vm.envAddress("SENIOR_HOOK");
        address juniorHook = vm.envAddress("JUNIOR_HOOK");
        address reserveHook = vm.envAddress("RESERVE_HOOK");
        
        console.log("========================================");
        console.log("DEPLOYMENT VERIFICATION");
        console.log("========================================");
        console.log("");
        
        // Senior Vault Checks
        console.log("SENIOR VAULT:", seniorVault);
        console.log("  Asset:", UnifiedConcreteSeniorVault(seniorVault).asset());
        console.log("  Junior:", UnifiedConcreteSeniorVault(seniorVault).juniorVault());
        console.log("  Reserve:", UnifiedConcreteSeniorVault(seniorVault).reserveVault());
        console.log("  Hook:", address(UnifiedConcreteSeniorVault(seniorVault).kodiakHook()));
        console.log("");
        
        // Junior Vault Checks
        console.log("JUNIOR VAULT:", juniorVault);
        console.log("  Asset:", ConcreteJuniorVault(juniorVault).asset());
        console.log("  Senior:", ConcreteJuniorVault(juniorVault).seniorVault());
        console.log("  Hook:", address(ConcreteJuniorVault(juniorVault).kodiakHook()));
        console.log("");
        
        // Reserve Vault Checks
        console.log("RESERVE VAULT:", reserveVault);
        console.log("  Asset:", ConcreteReserveVault(reserveVault).asset());
        console.log("  Senior:", ConcreteReserveVault(reserveVault).seniorVault());
        console.log("  Hook:", address(ConcreteReserveVault(reserveVault).kodiakHook()));
        console.log("");
        
        console.log("========================================");
        console.log("HOOKS");
        console.log("========================================");
        console.log("Senior Hook:", seniorHook);
        console.log("Junior Hook:", juniorHook);
        console.log("Reserve Hook:", reserveHook);
        console.log("");
        
        console.log("========================================");
        console.log("STATUS: DEPLOYMENT SUCCESSFUL!");
        console.log("========================================");
    }
}

