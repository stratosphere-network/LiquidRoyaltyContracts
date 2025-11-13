// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {UnifiedConcreteSeniorVault} from "../src/concrete/UnifiedConcreteSeniorVault.sol";
import {ConcreteJuniorVault} from "../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../src/concrete/ConcreteReserveVault.sol";

contract WhitelistLPToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        address seniorVault = vm.envAddress("SENIOR_VAULT");
        address juniorVault = vm.envAddress("JUNIOR_VAULT");
        address reserveVault = vm.envAddress("RESERVE_VAULT");
        address kodiakIsland = vm.envAddress("KODIAK_ISLAND_ADDRESS");
        
        console.log("Whitelisting LP Token...");
        console.log("LP Token (Island):", kodiakIsland);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Whitelist in Senior Vault
        console.log("Whitelisting in Senior Vault...");
        UnifiedConcreteSeniorVault(seniorVault).addWhitelistedLPToken(kodiakIsland);
        console.log("LP Token whitelisted in Senior Vault!");
        
        // Whitelist in Junior Vault
        console.log("Whitelisting in Junior Vault...");
        ConcreteJuniorVault(juniorVault).addWhitelistedLPToken(kodiakIsland);
        console.log("LP Token whitelisted in Junior Vault!");
        
        // Whitelist in Reserve Vault
        console.log("Whitelisting in Reserve Vault...");
        ConcreteReserveVault(reserveVault).addWhitelistedLPToken(kodiakIsland);
        console.log("LP Token whitelisted in Reserve Vault!");
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("========================================");
        console.log("LP TOKEN WHITELISTED!");
        console.log("========================================");
        console.log("");
        console.log("Vaults can now:");
        console.log("- Transfer LP tokens between each other");
        console.log("- Execute spillover operations");
        console.log("- Execute backstop operations");
    }
}

