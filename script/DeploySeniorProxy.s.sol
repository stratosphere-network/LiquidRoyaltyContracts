// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UnifiedConcreteSeniorVault} from "../src/concrete/UnifiedConcreteSeniorVault.sol";

contract DeploySeniorProxy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        address seniorImpl = vm.envAddress("SENIOR_IMPL");
        address stablecoin = vm.envAddress("STABLECOIN_ADDRESS");
        address juniorVault = vm.envAddress("JUNIOR_VAULT");
        address reserveVault = vm.envAddress("RESERVE_VAULT");
        
        console.log("Deploying Senior Vault Proxy...");
        console.log("Implementation:", seniorImpl);
        console.log("Stablecoin:", stablecoin);
        console.log("Junior Vault:", juniorVault);
        console.log("Reserve Vault:", reserveVault);
        console.log("Treasury (deployer):", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        bytes memory initData = abi.encodeWithSelector(
            UnifiedConcreteSeniorVault.initialize.selector,
            stablecoin,
            "Senior HONEY",
            "snrHONEY",
            juniorVault,
            reserveVault,
            deployer,  // Treasury address (using deployer for now)
            0          // Initial value
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(seniorImpl, initData);
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("Senior Vault Proxy deployed at:", address(proxy));
        console.log("");
        console.log("Copy this address:");
        console.log("export SENIOR_VAULT=%s", address(proxy));
    }
}

