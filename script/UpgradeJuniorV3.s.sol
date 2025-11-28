// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {ConcreteJuniorVault} from "../src/concrete/ConcreteJuniorVault.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title UpgradeJuniorV3
 * @notice Deploys new Junior V3 implementation (with cooldown) and upgrades proxy
 * @dev SAFE: Adds cooldown at end of contract, no storage corruption
 */
contract UpgradeJuniorV3 is Script {
    // ============================================
    // PRODUCTION ADDRESSES (Berachain Testnet)
    // ============================================
    
    address constant JUNIOR_PROXY = 0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883;
    address constant ADMIN = 0x6fa2149E69DbCBDCf6F16F755E08c10E53c40605;
    
    function run() external {
        console2.log("=================================================");
        console2.log("            UPGRADE JUNIOR VAULT TO V3");
        console2.log("=================================================");
        console2.log("");
        console2.log("Deployer:", msg.sender);
        console2.log("Admin:", ADMIN);
        console2.log("Junior Proxy:", JUNIOR_PROXY);
        console2.log("");
        
        vm.startBroadcast();
        
        // ============================================
        // STEP 1: Deploy New Implementation
        // ============================================
        
        console2.log("=================================================");
        console2.log("          DEPLOYING NEW IMPLEMENTATION");
        console2.log("=================================================");
        console2.log("");
        
        ConcreteJuniorVault juniorImpl = new ConcreteJuniorVault();
        console2.log("[OK] Junior V3 Implementation:", address(juniorImpl));
        console2.log("");
        
        // ============================================
        // STEP 2: Upgrade Proxy
        // ============================================
        
        console2.log("=================================================");
        console2.log("              UPGRADING PROXY");
        console2.log("=================================================");
        console2.log("");
        
        // Prepare upgrade data (calls initializeV3)
        bytes memory upgradeData = abi.encodeWithSignature("initializeV3()");
        
        // Get proxy interface
        ERC1967Proxy juniorProxy = ERC1967Proxy(payable(JUNIOR_PROXY));
        
        // Upgrade to V3
        ConcreteJuniorVault(address(juniorProxy)).upgradeToAndCall(address(juniorImpl), upgradeData);
        console2.log("[OK] Junior upgraded to V3!");
        console2.log("");
        
        // ============================================
        // STEP 3: Verification
        // ============================================
        
        console2.log("=================================================");
        console2.log("              VERIFICATION");
        console2.log("=================================================");
        console2.log("");
        
        ConcreteJuniorVault vault = ConcreteJuniorVault(JUNIOR_PROXY);
        
        console2.log("JUNIOR VAULT:");
        console2.log("  Name:", vault.name());
        console2.log("  Symbol:", vault.symbol());
        console2.log("  Total Supply:", vault.totalSupply());
        console2.log("  Vault Value:", vault.vaultValue());
        console2.log("  Can withdraw without penalty (test user):", vault.canWithdrawWithoutPenalty(msg.sender));
        console2.log("");
        
        vm.stopBroadcast();
        
        // ============================================
        // SUCCESS
        // ============================================
        
        console2.log("=================================================");
        console2.log("          UPGRADE COMPLETE");
        console2.log("=================================================");
        console2.log("");
        console2.log("New Implementation:");
        console2.log("  Junior V3:", address(juniorImpl));
        console2.log("");
        console2.log("Proxy Address:");
        console2.log("  Junior:", JUNIOR_PROXY);
        console2.log("");
        console2.log("[SUCCESS] Junior V3 upgrade complete!");
        console2.log("");
        console2.log("NEW FEATURES:");
        console2.log("  - initiateCooldown()");
        console2.log("  - canWithdrawWithoutPenalty()");
        console2.log("  - 20% early withdrawal penalty (if no cooldown)");
        console2.log("  - 7 day cooldown period");
        console2.log("");
        console2.log("NEXT STEPS:");
        console2.log("  1. Verify implementation on block explorer");
        console2.log("  2. Test cooldown functions");
        console2.log("  3. Update prod_addresses.md with new impl address");
        console2.log("  4. Update rollback script with old impl address");
        console2.log("");
        console2.log("=================================================");
    }
}



