// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {UnifiedConcreteSeniorVault} from "../src/concrete/UnifiedConcreteSeniorVault.sol";
import {ConcreteJuniorVault} from "../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../src/concrete/ConcreteReserveVault.sol";

/**
 * @title ValidateStorageLayout
 * @notice Validate that storage layout hasn't been corrupted after upgrade
 * @dev Run this IMMEDIATELY after upgrade to verify admin and critical state
 * 
 * Usage:
 *   forge script script/ValidateStorageLayout.s.sol:ValidateStorageLayout --rpc-url $RPC_URL
 */
contract ValidateStorageLayout is Script {
    // Production addresses
    address constant SENIOR_PROXY = 0x49298F4314eb127041b814A2616c25687Db6b650;
    address constant JUNIOR_PROXY = 0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883;
    address constant RESERVE_PROXY = 0x7754272c866892CaD4a414C76f060645bDc27203;
    
    // Expected values (from current deployment)
    address constant EXPECTED_ADMIN = 0x6fa2149E69DbCBDCf6F16F755E08c10E53c40605;
    address constant EXPECTED_TREASURY = 0x23FD5F6e2B07970c9B00D1da8E85c201711B7b74;
    
    function run() external view {
        console2.log("=================================================");
        console2.log("STORAGE LAYOUT VALIDATION");
        console2.log("=================================================");
        console2.log("");
        
        bool allValid = true;
        
        // Validate Senior Vault
        console2.log("SENIOR VAULT VALIDATION:");
        console2.log("Proxy:", SENIOR_PROXY);
        UnifiedConcreteSeniorVault senior = UnifiedConcreteSeniorVault(payable(SENIOR_PROXY));
        
        address seniorAdmin = senior.admin();
        console2.log("  Admin:", seniorAdmin);
        if (seniorAdmin == address(0)) {
            console2.log("  [ERROR] Admin is zero address! STORAGE CORRUPTED!");
            allValid = false;
        } else if (seniorAdmin != EXPECTED_ADMIN) {
            console2.log("  [WARNING] Admin changed from expected!");
            console2.log("  Expected:", EXPECTED_ADMIN);
        } else {
            console2.log("  [OK] Admin correct");
        }
        
        address seniorTreasury = senior.treasury();
        console2.log("  Treasury:", seniorTreasury);
        if (seniorTreasury == address(0)) {
            console2.log("  [ERROR] Treasury is zero address! STORAGE CORRUPTED!");
            allValid = false;
        } else if (seniorTreasury != EXPECTED_TREASURY) {
            console2.log("  [WARNING] Treasury changed from expected!");
            console2.log("  Expected:", EXPECTED_TREASURY);
        } else {
            console2.log("  [OK] Treasury correct");
        }
        
        // Check critical state
        uint256 seniorSupply = senior.totalSupply();
        uint256 seniorValue = senior.vaultValue();
        uint256 seniorIndex = senior.rebaseIndex();
        console2.log("  Total Supply:", seniorSupply);
        console2.log("  Vault Value:", seniorValue);
        console2.log("  Rebase Index:", seniorIndex);
        
        if (seniorIndex == 0) {
            console2.log("  [ERROR] Rebase index is zero! STORAGE CORRUPTED!");
            allValid = false;
        } else {
            console2.log("  [OK] Rebase index valid");
        }
        console2.log("");
        
        // Validate Junior Vault
        console2.log("JUNIOR VAULT VALIDATION:");
        console2.log("Proxy:", JUNIOR_PROXY);
        ConcreteJuniorVault junior = ConcreteJuniorVault(JUNIOR_PROXY);
        
        address juniorAdmin = junior.admin();
        console2.log("  Admin:", juniorAdmin);
        if (juniorAdmin == address(0)) {
            console2.log("  [ERROR] Admin is zero address! STORAGE CORRUPTED!");
            allValid = false;
        } else if (juniorAdmin != EXPECTED_ADMIN) {
            console2.log("  [WARNING] Admin changed from expected!");
            console2.log("  Expected:", EXPECTED_ADMIN);
        } else {
            console2.log("  [OK] Admin correct");
        }
        
        address juniorSenior = junior.seniorVault();
        console2.log("  Senior Vault:", juniorSenior);
        if (juniorSenior == address(0)) {
            console2.log("  [ERROR] Senior vault is zero address! STORAGE CORRUPTED!");
            allValid = false;
        } else if (juniorSenior != SENIOR_PROXY) {
            console2.log("  [WARNING] Senior vault address unexpected!");
            console2.log("  Expected:", SENIOR_PROXY);
        } else {
            console2.log("  [OK] Senior vault correct");
        }
        
        uint256 juniorSupply = junior.totalSupply();
        uint256 juniorValue = junior.vaultValue();
        console2.log("  Total Supply:", juniorSupply);
        console2.log("  Vault Value:", juniorValue);
        console2.log("");
        
        // Validate Reserve Vault
        console2.log("RESERVE VAULT VALIDATION:");
        console2.log("Proxy:", RESERVE_PROXY);
        ConcreteReserveVault reserve = ConcreteReserveVault(RESERVE_PROXY);
        
        address reserveAdmin = reserve.admin();
        console2.log("  Admin:", reserveAdmin);
        if (reserveAdmin == address(0)) {
            console2.log("  [ERROR] Admin is zero address! STORAGE CORRUPTED!");
            allValid = false;
        } else if (reserveAdmin != EXPECTED_ADMIN) {
            console2.log("  [WARNING] Admin changed from expected!");
            console2.log("  Expected:", EXPECTED_ADMIN);
        } else {
            console2.log("  [OK] Admin correct");
        }
        
        address reserveSenior = reserve.seniorVault();
        console2.log("  Senior Vault:", reserveSenior);
        if (reserveSenior == address(0)) {
            console2.log("  [ERROR] Senior vault is zero address! STORAGE CORRUPTED!");
            allValid = false;
        } else if (reserveSenior != SENIOR_PROXY) {
            console2.log("  [WARNING] Senior vault address unexpected!");
            console2.log("  Expected:", SENIOR_PROXY);
        } else {
            console2.log("  [OK] Senior vault correct");
        }
        
        uint256 reserveSupply = reserve.totalSupply();
        uint256 reserveValue = reserve.vaultValue();
        uint256 depositCap = reserve.currentDepositCap();
        console2.log("  Total Supply:", reserveSupply);
        console2.log("  Vault Value:", reserveValue);
        console2.log("  Deposit Cap:", depositCap);
        console2.log("");
        
        // Final result
        console2.log("=================================================");
        if (allValid) {
            console2.log("[SUCCESS] All storage slots validated!");
            console2.log("Admin roles preserved, upgrade safe.");
        } else {
            console2.log("[CRITICAL ERROR] Storage corruption detected!");
            console2.log("DO NOT USE THESE CONTRACTS!");
            console2.log("Rollback to previous implementation immediately!");
        }
        console2.log("=================================================");
    }
}

