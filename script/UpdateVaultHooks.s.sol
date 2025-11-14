// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";

interface IVault {
    function setKodiakHook(address hook) external;
}

contract UpdateVaultHooks is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Vault addresses
        address SENIOR_VAULT = 0x65691bd1972e906459954306aDa0f622a47d4744;
        address JUNIOR_VAULT = 0x3A1b3b300dEE06Caf0b691F1771d1Aa26d70B067;
        address RESERVE_VAULT = 0x2C75291479788C568A6750185CaDedf43aBFC553;
        
        // NEW Hook addresses (just deployed)
        address NEW_SENIOR_HOOK = 0x84a6b0727A55E9c337d31986098E834eCaD65E9b;
        address NEW_JUNIOR_HOOK = 0x2a3Fa663E1Dd4087A46A27C2aabc94F0Fe0C0892;
        address NEW_RESERVE_HOOK = 0x5f28caF1B54819d24a5CaA58EEBd3272e56DC793;
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Updating vaults to use NEW hooks...");
        
        // Update Senior Vault
        console.log("\nUpdating Senior Vault...");
        IVault(SENIOR_VAULT).setKodiakHook(NEW_SENIOR_HOOK);
        console.log("Senior Vault -> Hook:", NEW_SENIOR_HOOK);
        
        // Update Junior Vault
        console.log("\nUpdating Junior Vault...");
        IVault(JUNIOR_VAULT).setKodiakHook(NEW_JUNIOR_HOOK);
        console.log("Junior Vault -> Hook:", NEW_JUNIOR_HOOK);
        
        // Update Reserve Vault
        console.log("\nUpdating Reserve Vault...");
        IVault(RESERVE_VAULT).setKodiakHook(NEW_RESERVE_HOOK);
        console.log("Reserve Vault -> Hook:", NEW_RESERVE_HOOK);
        
        vm.stopBroadcast();
        
        console.log("\n=== ALL VAULTS UPDATED! ===");
    }
}



