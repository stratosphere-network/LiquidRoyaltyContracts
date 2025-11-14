// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {ConcreteJuniorVault} from "../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../src/concrete/ConcreteReserveVault.sol";
import {UnifiedConcreteSeniorVault} from "../src/concrete/UnifiedConcreteSeniorVault.sol";

contract ConfigureVaults is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        address juniorVault = vm.envAddress("JUNIOR_VAULT");
        address reserveVault = vm.envAddress("RESERVE_VAULT");
        address seniorVault = vm.envAddress("SENIOR_VAULT");
        
        console.log("Configuring Vaults...");
        console.log("Junior:", juniorVault);
        console.log("Reserve:", reserveVault);
        console.log("Senior:", seniorVault);
        console.log("Admin (deployer):", deployer);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // FIRST: Set admin on all vaults (deployer can call setAdmin once)
        console.log("Setting admin on all vaults...");
        UnifiedConcreteSeniorVault(seniorVault).setAdmin(deployer);
        ConcreteJuniorVault(juniorVault).setAdmin(deployer);
        ConcreteReserveVault(reserveVault).setAdmin(deployer);
        console.log("Admin set on all vaults!");
        
        // THEN: Update Senior Vault references (now that we're admin)
        console.log("Updating Senior Vault references...");
        ConcreteJuniorVault(juniorVault).updateSeniorVault(seniorVault);
        ConcreteReserveVault(reserveVault).updateSeniorVault(seniorVault);
        console.log("Senior Vault references updated!");
        
        // Set initial vault values to 0
        console.log("Setting initial vault values to 0...");
        UnifiedConcreteSeniorVault(seniorVault).setVaultValue(0);
        ConcreteJuniorVault(juniorVault).setVaultValue(0);
        ConcreteReserveVault(reserveVault).setVaultValue(0);
        console.log("Vault values initialized!");
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("========================================");
        console.log("CONFIGURATION COMPLETE!");
        console.log("========================================");
    }
}

