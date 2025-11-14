// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {KodiakVaultHook} from "../src/integrations/KodiakVaultHook.sol";

contract DeployHooks is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        address seniorVault = vm.envAddress("SENIOR_VAULT");
        address juniorVault = vm.envAddress("JUNIOR_VAULT");
        address reserveVault = vm.envAddress("RESERVE_VAULT");
        address stablecoin = vm.envAddress("STABLECOIN_ADDRESS");
        
        console.log("Deploying Kodiak Hooks...");
        console.log("Stablecoin:", stablecoin);
        console.log("Admin:", deployer);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy Senior Hook
        console.log("Deploying Senior Hook...");
        KodiakVaultHook seniorHook = new KodiakVaultHook(
            seniorVault,
            stablecoin,
            deployer
        );
        console.log("Senior Hook:", address(seniorHook));
        
        // Deploy Junior Hook
        console.log("Deploying Junior Hook...");
        KodiakVaultHook juniorHook = new KodiakVaultHook(
            juniorVault,
            stablecoin,
            deployer
        );
        console.log("Junior Hook:", address(juniorHook));
        
        // Deploy Reserve Hook
        console.log("Deploying Reserve Hook...");
        KodiakVaultHook reserveHook = new KodiakVaultHook(
            reserveVault,
            stablecoin,
            deployer
        );
        console.log("Reserve Hook:", address(reserveHook));
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("========================================");
        console.log("HOOKS DEPLOYED!");
        console.log("========================================");
        console.log("Copy these addresses:");
        console.log("");
        console.log("export SENIOR_HOOK=%s", address(seniorHook));
        console.log("export JUNIOR_HOOK=%s", address(juniorHook));
        console.log("export RESERVE_HOOK=%s", address(reserveHook));
    }
}

