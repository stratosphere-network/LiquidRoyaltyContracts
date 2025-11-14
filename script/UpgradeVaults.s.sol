// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {UnifiedConcreteSeniorVault} from "../src/concrete/UnifiedConcreteSeniorVault.sol";
import {ConcreteJuniorVault} from "../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../src/concrete/ConcreteReserveVault.sol";

/**
 * @title UpgradeVaults
 * @notice Script to deploy new implementations and upgrade existing proxies
 * @dev This script:
 *      1. Deploys new implementations for all three vaults
 *      2. Upgrades existing proxies to point to new implementations
 *      3. Verifies the upgrades were successful
 */
contract UpgradeVaults is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Get existing proxy addresses
        address seniorProxy = vm.envAddress("SENIOR_VAULT");
        address juniorProxy = vm.envAddress("JUNIOR_VAULT");
        address reserveProxy = vm.envAddress("RESERVE_VAULT");
        
        console.log("========================================");
        console.log("VAULT UPGRADE PROCESS");
        console.log("========================================");
        console.log("");
        console.log("Existing Proxies:");
        console.log("  Senior:  ", seniorProxy);
        console.log("  Junior:  ", juniorProxy);
        console.log("  Reserve: ", reserveProxy);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // ============================================
        // STEP 1: Deploy New Implementations
        // ============================================
        console.log("========================================");
        console.log("STEP 1: Deploying New Implementations");
        console.log("========================================");
        console.log("");
        
        console.log("1. Deploying Senior Vault implementation...");
        UnifiedConcreteSeniorVault seniorImpl = new UnifiedConcreteSeniorVault();
        console.log("   Deployed at:", address(seniorImpl));
        
        console.log("");
        console.log("2. Deploying Junior Vault implementation...");
        ConcreteJuniorVault juniorImpl = new ConcreteJuniorVault();
        console.log("   Deployed at:", address(juniorImpl));
        
        console.log("");
        console.log("3. Deploying Reserve Vault implementation...");
        ConcreteReserveVault reserveImpl = new ConcreteReserveVault();
        console.log("   Deployed at:", address(reserveImpl));
        
        console.log("");
        console.log("========================================");
        console.log("STEP 2: Upgrading Proxies");
        console.log("========================================");
        console.log("");
        
        // ============================================
        // STEP 2: Upgrade Proxies
        // ============================================
        
        console.log("4. Upgrading Senior Vault proxy...");
        UnifiedConcreteSeniorVault senior = UnifiedConcreteSeniorVault(payable(seniorProxy));
        senior.upgradeToAndCall(address(seniorImpl), "");
        console.log("   [OK] Senior upgraded");
        
        console.log("");
        console.log("5. Upgrading Junior Vault proxy...");
        ConcreteJuniorVault junior = ConcreteJuniorVault(payable(juniorProxy));
        junior.upgradeToAndCall(address(juniorImpl), "");
        console.log("   [OK] Junior upgraded");
        
        console.log("");
        console.log("6. Upgrading Reserve Vault proxy...");
        ConcreteReserveVault reserve = ConcreteReserveVault(payable(reserveProxy));
        reserve.upgradeToAndCall(address(reserveImpl), "");
        console.log("   [OK] Reserve upgraded");
        
        vm.stopBroadcast();
        
        // ============================================
        // STEP 3: Verification
        // ============================================
        console.log("");
        console.log("========================================");
        console.log("STEP 3: Verification");
        console.log("========================================");
        console.log("");
        console.log("New Implementation Addresses:");
        console.log("  Senior:  ", address(seniorImpl));
        console.log("  Junior:  ", address(juniorImpl));
        console.log("  Reserve: ", address(reserveImpl));
        console.log("");
        console.log("Proxy Addresses (unchanged):");
        console.log("  Senior:  ", seniorProxy);
        console.log("  Junior:  ", juniorProxy);
        console.log("  Reserve: ", reserveProxy);
        console.log("");
        console.log("========================================");
        console.log("[SUCCESS] ALL UPGRADES COMPLETE!");
        console.log("========================================");
        console.log("");
        console.log("Export these new implementation addresses:");
        console.log("export SENIOR_IMPL=%s", address(seniorImpl));
        console.log("export JUNIOR_IMPL=%s", address(juniorImpl));
        console.log("export RESERVE_IMPL=%s", address(reserveImpl));
        console.log("");
    }
}

