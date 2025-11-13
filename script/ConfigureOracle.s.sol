// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {UnifiedConcreteSeniorVault} from "../src/concrete/UnifiedConcreteSeniorVault.sol";
import {ConcreteJuniorVault} from "../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../src/concrete/ConcreteReserveVault.sol";

contract ConfigureOracle is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        address seniorVault = vm.envAddress("SENIOR_VAULT");
        address juniorVault = vm.envAddress("JUNIOR_VAULT");
        address reserveVault = vm.envAddress("RESERVE_VAULT");
        address kodiakIsland = vm.envAddress("KODIAK_ISLAND_ADDRESS");
        
        console.log("Configuring Oracle...");
        console.log("Island:", kodiakIsland);
        console.log("HONEY is token1 (not token0)");
        console.log("");
        
        // Oracle parameters:
        // - island: Kodiak Island address
        // - isStablecoinToken0: false (HONEY is token1)
        // - maxDeviationBps: 500 (5% max deviation)
        // - enableValidation: true
        // - useCalculated: true (automatic mode)
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Configure Senior Vault Oracle
        console.log("Configuring Senior Vault Oracle...");
        UnifiedConcreteSeniorVault(seniorVault).configureOracle(
            kodiakIsland,
            false,  // HONEY is token1
            500,    // 5% max deviation
            true,   // enable validation
            true    // use calculated value
        );
        console.log("Senior Vault Oracle configured!");
        
        // Configure Junior Vault Oracle
        console.log("Configuring Junior Vault Oracle...");
        ConcreteJuniorVault(juniorVault).configureOracle(
            kodiakIsland,
            false,  // HONEY is token1
            500,    // 5% max deviation
            true,   // enable validation
            true    // use calculated value
        );
        console.log("Junior Vault Oracle configured!");
        
        // Configure Reserve Vault Oracle
        console.log("Configuring Reserve Vault Oracle...");
        ConcreteReserveVault(reserveVault).configureOracle(
            kodiakIsland,
            false,  // HONEY is token1
            500,    // 5% max deviation
            true,   // enable validation
            true    // use calculated value
        );
        console.log("Reserve Vault Oracle configured!");
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("========================================");
        console.log("ORACLE CONFIGURED!");
        console.log("========================================");
        console.log("");
        console.log("Oracle settings:");
        console.log("- HONEY is token1 in the pool");
        console.log("- Max deviation: 5%%");
        console.log("- Validation enabled");
        console.log("- Automatic LP price calculation");
    }
}

