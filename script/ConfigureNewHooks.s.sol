// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";

interface IVault {
    function setKodiakHook(address newHook) external;
    function kodiakHook() external view returns (address);
}

contract ConfigureNewHooks is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Vault addresses (proxies)
        address SENIOR_VAULT = 0x65691bd1972e906459954306aDa0f622a47d4744;
        address JUNIOR_VAULT = 0x3A1b3b300dEE06Caf0b691F1771d1Aa26d70B067;
        address RESERVE_VAULT = 0x2C75291479788C568A6750185CaDedf43aBFC553;
        
        // NEW Hook addresses from deployment
        address NEW_SENIOR_HOOK = 0x5256B4628F4A315c35C77A2DfbE968d9b4C4A261;
        address NEW_JUNIOR_HOOK = 0x4c40B07F9589d3D6DD2996113f1317c64dCB7255;
        address NEW_RESERVE_HOOK = 0xFf046FaF98025817348618615a6eDA91B4f28Bb3;
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Configuring vaults to use new hooks...");
        console.log("");
        
        // Configure Senior Vault
        console.log("=== SENIOR VAULT ===");
        console.log("Vault:", SENIOR_VAULT);
        console.log("Old Hook:", IVault(SENIOR_VAULT).kodiakHook());
        IVault(SENIOR_VAULT).setKodiakHook(NEW_SENIOR_HOOK);
        console.log("New Hook:", IVault(SENIOR_VAULT).kodiakHook());
        console.log("");
        
        // Configure Junior Vault
        console.log("=== JUNIOR VAULT ===");
        console.log("Vault:", JUNIOR_VAULT);
        console.log("Old Hook:", IVault(JUNIOR_VAULT).kodiakHook());
        IVault(JUNIOR_VAULT).setKodiakHook(NEW_JUNIOR_HOOK);
        console.log("New Hook:", IVault(JUNIOR_VAULT).kodiakHook());
        console.log("");
        
        // Configure Reserve Vault
        console.log("=== RESERVE VAULT ===");
        console.log("Vault:", RESERVE_VAULT);
        console.log("Old Hook:", IVault(RESERVE_VAULT).kodiakHook());
        IVault(RESERVE_VAULT).setKodiakHook(NEW_RESERVE_HOOK);
        console.log("New Hook:", IVault(RESERVE_VAULT).kodiakHook());
        console.log("");
        
        vm.stopBroadcast();
        
        console.log("=== CONFIGURATION COMPLETE ===");
        console.log("All vaults now point to new hooks with:");
        console.log("- Smart LP liquidation (2.5x buffer algorithm)");
        console.log("- WBTC accumulation (no auto-send to vault)");
        console.log("- Iterative withdrawal (max 3 attempts)");
    }
}


