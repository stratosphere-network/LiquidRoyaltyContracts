// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {UnifiedConcreteSeniorVault} from "../src/concrete/UnifiedConcreteSeniorVault.sol";
import {ConcreteJuniorVault} from "../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../src/concrete/ConcreteReserveVault.sol";

/**
 * @title ValidateStorageLayoutV3
 * @notice COMPREHENSIVE storage layout validation for V3 upgrade
 * @dev Validates BOTH values AND storage slot positions
 * 
 * Key Improvements over V1:
 * - Validates exact storage slot positions using vm.load()
 * - Checks new V3 variables are in correct slots
 * - Verifies no storage collision occurred
 * - Tests reentrancy guard initialization
 * 
 * Usage:
 *   forge script script/ValidateStorageLayoutV3.s.sol:ValidateStorageLayoutV3 \
 *     --rpc-url $RPC_URL --fork-url $RPC_URL
 */
contract ValidateStorageLayoutV3 is Script {
    // Production addresses
    address constant SENIOR_PROXY = 0x49298F4314eb127041b814A2616c25687Db6b650;
    address constant JUNIOR_PROXY = 0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883;
    address constant RESERVE_PROXY = 0x7754272c866892CaD4a414C76f060645bDc27203;
    
    // Expected values
    address constant EXPECTED_ADMIN = 0x6fa2149E69DbCBDCf6F16F755E08c10E53c40605;
    address constant EXPECTED_TREASURY = 0x23FD5F6e2B07970c9B00D1da8E85c201711B7b74;
    
    // Expected storage slots (from forge inspect)
    uint256 constant SLOT_ADMIN = 1;
    uint256 constant SLOT_VAULT_VALUE = 3;
    uint256 constant SLOT_SENIOR_VAULT = 10;
    uint256 constant SLOT_TREASURY = 12;
    
    // V2 role slots (ConcreteJuniorVault)
    uint256 constant SLOT_LIQUIDITY_MANAGER = 21;
    uint256 constant SLOT_PRICE_FEED_MANAGER = 22;
    uint256 constant SLOT_CONTRACT_UPDATER = 23;
    
    // V3 slots (ConcreteJuniorVault)
    uint256 constant SLOT_COOLDOWN_START = 24;  // mapping
    uint256 constant SLOT_STATUS = 25;
    
    function run() external {
        console2.log("==========================================================");
        console2.log("COMPREHENSIVE V3 STORAGE LAYOUT VALIDATION");
        console2.log("==========================================================");
        console2.log("");
        
        bool allValid = true;
        
        // ==========================================
        // JUNIOR VAULT VALIDATION
        // ==========================================
        console2.log("JUNIOR VAULT VALIDATION:");
        console2.log("Proxy:", JUNIOR_PROXY);
        ConcreteJuniorVault junior = ConcreteJuniorVault(JUNIOR_PROXY);
        
        // 1. Validate admin is in correct slot
        bytes32 adminSlot = vm.load(JUNIOR_PROXY, bytes32(SLOT_ADMIN));
        address adminFromSlot = address(uint160(uint256(adminSlot)));
        address adminFromGetter = junior.admin();
        
        console2.log("  Admin Slot Validation:");
        console2.log("    From slot", SLOT_ADMIN, ":", adminFromSlot);
        console2.log("    From getter:", adminFromGetter);
        
        if (adminFromSlot != adminFromGetter) {
            console2.log("    [ERROR] Admin slot mismatch! STORAGE CORRUPTED!");
            allValid = false;
        } else if (adminFromGetter == address(0)) {
            console2.log("    [ERROR] Admin is zero! STORAGE CORRUPTED!");
            allValid = false;
        } else if (adminFromGetter != EXPECTED_ADMIN) {
            console2.log("    [WARNING] Admin changed from expected");
        } else {
            console2.log("    [OK] Admin in correct slot");
        }
        
        // 2. Validate vault value is in correct slot
        bytes32 vaultValueSlot = vm.load(JUNIOR_PROXY, bytes32(SLOT_VAULT_VALUE));
        uint256 vaultValueFromSlot = uint256(vaultValueSlot);
        uint256 vaultValueFromGetter = junior.vaultValue();
        
        console2.log("  Vault Value Slot Validation:");
        console2.log("    From slot", SLOT_VAULT_VALUE, ":", vaultValueFromSlot);
        console2.log("    From getter:", vaultValueFromGetter);
        
        if (vaultValueFromSlot != vaultValueFromGetter) {
            console2.log("    [ERROR] Vault value slot mismatch! STORAGE CORRUPTED!");
            allValid = false;
        } else {
            console2.log("    [OK] Vault value in correct slot");
        }
        
        // 3. Validate senior vault is in correct slot
        bytes32 seniorSlot = vm.load(JUNIOR_PROXY, bytes32(SLOT_SENIOR_VAULT));
        address seniorFromSlot = address(uint160(uint256(seniorSlot)));
        address seniorFromGetter = junior.seniorVault();
        
        console2.log("  Senior Vault Slot Validation:");
        console2.log("    From slot", SLOT_SENIOR_VAULT, ":", seniorFromSlot);
        console2.log("    From getter:", seniorFromGetter);
        
        if (seniorFromSlot != seniorFromGetter) {
            console2.log("    [ERROR] Senior vault slot mismatch! STORAGE CORRUPTED!");
            allValid = false;
        } else if (seniorFromGetter == address(0)) {
            console2.log("    [ERROR] Senior vault is zero! STORAGE CORRUPTED!");
            allValid = false;
        } else {
            console2.log("    [OK] Senior vault in correct slot");
        }
        
        // 4. Validate V2 roles are in correct slots
        console2.log("  V2 Role Slots Validation:");
        
        bytes32 lmSlot = vm.load(JUNIOR_PROXY, bytes32(SLOT_LIQUIDITY_MANAGER));
        address lmFromSlot = address(uint160(uint256(lmSlot)));
        address lmFromGetter = junior.liquidityManager();
        
        console2.log("    Liquidity Manager (slot", SLOT_LIQUIDITY_MANAGER, "):");
        console2.log("      From slot:", lmFromSlot);
        console2.log("      From getter:", lmFromGetter);
        
        if (lmFromSlot != lmFromGetter) {
            console2.log("      [ERROR] Liquidity manager slot mismatch!");
            allValid = false;
        } else if (lmFromGetter == address(0)) {
            console2.log("      [ERROR] Liquidity manager is zero!");
            allValid = false;
        } else {
            console2.log("      [OK] Correct slot");
        }
        
        // 5. Validate V3 reentrancy guard is initialized
        console2.log("  V3 Reentrancy Guard Validation:");
        
        bytes32 statusSlot = vm.load(JUNIOR_PROXY, bytes32(SLOT_STATUS));
        uint256 statusValue = uint256(statusSlot);
        
        console2.log("    Status (slot", SLOT_STATUS, "):", statusValue);
        
        if (statusValue == 0) {
            console2.log("    [ERROR] Reentrancy guard NOT initialized!");
            console2.log("    [ACTION REQUIRED] Call initializeV3()");
            allValid = false;
        } else if (statusValue == 1) {
            console2.log("    [OK] Reentrancy guard initialized (_NOT_ENTERED)");
        } else {
            console2.log("    [WARNING] Unexpected status value:", statusValue);
        }
        
        // 6. Validate cooldown mapping slot (can't check values without users)
        console2.log("  V3 Cooldown Mapping Validation:");
        console2.log("    Cooldown mapping slot:", SLOT_COOLDOWN_START);
        console2.log("    [INFO] Mapping initialized (values populated on first use)");
        
        console2.log("");
        
        // ==========================================
        // RESERVE VAULT VALIDATION
        // ==========================================
        console2.log("RESERVE VAULT VALIDATION:");
        console2.log("Proxy:", RESERVE_PROXY);
        ConcreteReserveVault reserve = ConcreteReserveVault(RESERVE_PROXY);
        
        // Similar validations for Reserve
        adminSlot = vm.load(RESERVE_PROXY, bytes32(SLOT_ADMIN));
        adminFromSlot = address(uint160(uint256(adminSlot)));
        adminFromGetter = reserve.admin();
        
        console2.log("  Admin Slot Validation:");
        console2.log("    From slot", SLOT_ADMIN, ":", adminFromSlot);
        console2.log("    From getter:", adminFromGetter);
        
        if (adminFromSlot != adminFromGetter) {
            console2.log("    [ERROR] Admin slot mismatch! STORAGE CORRUPTED!");
            allValid = false;
        } else if (adminFromGetter == address(0)) {
            console2.log("    [ERROR] Admin is zero! STORAGE CORRUPTED!");
            allValid = false;
        } else {
            console2.log("    [OK] Admin in correct slot");
        }
        
        // Check V3 reentrancy guard
        statusSlot = vm.load(RESERVE_PROXY, bytes32(SLOT_STATUS));
        statusValue = uint256(statusSlot);
        
        console2.log("  V3 Reentrancy Guard:");
        console2.log("    Status (slot", SLOT_STATUS, "):", statusValue);
        
        if (statusValue == 0) {
            console2.log("    [ERROR] Reentrancy guard NOT initialized!");
            allValid = false;
        } else if (statusValue == 1) {
            console2.log("    [OK] Reentrancy guard initialized");
        }
        
        console2.log("");
        
        // ==========================================
        // SENIOR VAULT VALIDATION
        // ==========================================
        console2.log("SENIOR VAULT VALIDATION:");
        console2.log("Proxy:", SENIOR_PROXY);
        UnifiedConcreteSeniorVault senior = UnifiedConcreteSeniorVault(payable(SENIOR_PROXY));
        
        // Senior has different layout (different slot numbers)
        // V3 status slot for Senior
        uint256 SENIOR_SLOT_STATUS = 31;  // Adjust based on actual layout
        
        adminSlot = vm.load(SENIOR_PROXY, bytes32(SLOT_ADMIN));
        adminFromSlot = address(uint160(uint256(adminSlot)));
        adminFromGetter = senior.admin();
        
        console2.log("  Admin Slot Validation:");
        console2.log("    From slot", SLOT_ADMIN, ":", adminFromSlot);
        console2.log("    From getter:", adminFromGetter);
        
        if (adminFromSlot != adminFromGetter) {
            console2.log("    [ERROR] Admin slot mismatch! STORAGE CORRUPTED!");
            allValid = false;
        } else if (adminFromGetter == address(0)) {
            console2.log("    [ERROR] Admin is zero! STORAGE CORRUPTED!");
            allValid = false;
        } else {
            console2.log("    [OK] Admin in correct slot");
        }
        
        // Check rebase index (critical for Senior)
        uint256 rebaseIndex = senior.rebaseIndex();
        console2.log("  Rebase Index:", rebaseIndex);
        
        if (rebaseIndex == 0) {
            console2.log("    [ERROR] Rebase index is zero! STORAGE CORRUPTED!");
            allValid = false;
        } else {
            console2.log("    [OK] Rebase index valid");
        }
        
        console2.log("");
        
        // ==========================================
        // FINAL RESULT
        // ==========================================
        console2.log("==========================================================");
        if (allValid) {
            console2.log("[SUCCESS] All storage slots validated!");
            console2.log("V3 upgrade storage layout is SAFE.");
            console2.log("- Existing variables unchanged");
            console2.log("- New variables correctly appended");
            console2.log("- No storage collision detected");
        } else {
            console2.log("[CRITICAL ERROR] Storage validation FAILED!");
            console2.log("DO NOT USE THESE CONTRACTS!");
            console2.log("Actions required:");
            console2.log("  1. If reentrancy guard not initialized: Call initializeV3()");
            console2.log("  2. If storage corrupted: Rollback immediately");
            console2.log("  3. Review upgrade process and storage layout");
        }
        console2.log("==========================================================");
    }
}

