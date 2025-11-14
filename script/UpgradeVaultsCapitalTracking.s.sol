// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/concrete/UnifiedConcreteSeniorVault.sol";
import "../src/concrete/ConcreteJuniorVault.sol";
import "../src/concrete/ConcreteReserveVault.sol";

/**
 * @notice Deploy new implementations and upgrade proxies with capital tracking fix
 * @dev Fixes the critical issue where deposits/withdrawals don't update _vaultValue
 */
contract UpgradeVaultsCapitalTracking is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Load existing proxy addresses
        address seniorProxy = vm.envAddress("SENIOR_VAULT");
        address juniorProxy = vm.envAddress("JUNIOR_VAULT");
        address reserveProxy = vm.envAddress("RESERVE_VAULT");
        
        console.log("\n=== UPGRADING VAULTS WITH CAPITAL TRACKING FIX ===\n");
        console.log("Senior Proxy:", seniorProxy);
        console.log("Junior Proxy:", juniorProxy);
        console.log("Reserve Proxy:", reserveProxy);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy new Senior implementation
        console.log("\n1. Deploying new Senior implementation...");
        UnifiedConcreteSeniorVault newSeniorImpl = new UnifiedConcreteSeniorVault();
        console.log("New Senior Implementation:", address(newSeniorImpl));
        
        // Deploy new Junior implementation
        console.log("\n2. Deploying new Junior implementation...");
        ConcreteJuniorVault newJuniorImpl = new ConcreteJuniorVault();
        console.log("New Junior Implementation:", address(newJuniorImpl));
        
        // Deploy new Reserve implementation
        console.log("\n3. Deploying new Reserve implementation...");
        ConcreteReserveVault newReserveImpl = new ConcreteReserveVault();
        console.log("New Reserve Implementation:", address(newReserveImpl));
        
        // Upgrade Senior proxy
        console.log("\n4. Upgrading Senior proxy...");
        UnifiedConcreteSeniorVault seniorVault = UnifiedConcreteSeniorVault(payable(seniorProxy));
        seniorVault.upgradeToAndCall(address(newSeniorImpl), "");
        console.log("Senior proxy upgraded!");
        
        // Upgrade Junior proxy
        console.log("\n5. Upgrading Junior proxy...");
        ConcreteJuniorVault juniorVault = ConcreteJuniorVault(juniorProxy);
        juniorVault.upgradeToAndCall(address(newJuniorImpl), "");
        console.log("Junior proxy upgraded!");
        
        // Upgrade Reserve proxy
        console.log("\n6. Upgrading Reserve proxy...");
        ConcreteReserveVault reserveVault = ConcreteReserveVault(reserveProxy);
        reserveVault.upgradeToAndCall(address(newReserveImpl), "");
        console.log("Reserve proxy upgraded!");
        
        vm.stopBroadcast();
        
        console.log("\n=== UPGRADE COMPLETE ===\n");
        console.log("Summary:");
        console.log("--------");
        console.log("Senior Implementation:", address(newSeniorImpl));
        console.log("Junior Implementation:", address(newJuniorImpl));
        console.log("Reserve Implementation:", address(newReserveImpl));
        console.log("\nFix Applied:");
        console.log("- Deposits now INCREASE _vaultValue by deposited assets");
        console.log("- Withdrawals now DECREASE _vaultValue by withdrawn assets");
        console.log("- This ensures share price calculations remain accurate");
    }
}

