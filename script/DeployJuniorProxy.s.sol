// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ConcreteJuniorVault} from "../src/concrete/ConcreteJuniorVault.sol";

contract DeployJuniorProxy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address juniorImpl = vm.envAddress("JUNIOR_IMPL");
        address stablecoin = vm.envAddress("STABLECOIN_ADDRESS");
        
        console.log("Deploying Junior Vault Proxy...");
        console.log("Implementation:", juniorImpl);
        console.log("Stablecoin:", stablecoin);
        
        vm.startBroadcast(deployerPrivateKey);
        
        bytes memory initData = abi.encodeWithSelector(
            ConcreteJuniorVault.initialize.selector,
            stablecoin,
            address(0x0000000000000000000000000000000000000001),
            0
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(juniorImpl, initData);
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("Junior Vault Proxy deployed at:", address(proxy));
        console.log("");
        console.log("Copy this address:");
        console.log("export JUNIOR_VAULT=%s", address(proxy));
    }
}

