// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {KodiakVaultHook} from "../src/integrations/KodiakVaultHook.sol";

contract DeployNewSeniorHook is Script {
    function run() external {
        address newSeniorVault = 0x49298F4314eb127041b814A2616c25687Db6b650;
        address kodiakIsland = 0xB350944Be03cf5f795f48b63eAA542df6A3c8505;
        address kodiakRouter = 0x679a7C63FC83b6A4D9C1F931891d705483d4791F;
        
        console.log("Deploying new Senior Hook...");
        console.log("Vault:", newSeniorVault);
        console.log("Island:", kodiakIsland);
        console.log("Router:", kodiakRouter);
        
        vm.startBroadcast();
        
        KodiakVaultHook hook = new KodiakVaultHook(
            newSeniorVault,
            kodiakIsland,
            kodiakRouter
        );
        
        vm.stopBroadcast();
        
        console.log("\nNew Senior Hook deployed at:", address(hook));
        console.log("\nCopy this:");
        console.log("export NEW_SENIOR_HOOK=%s", address(hook));
    }
}

