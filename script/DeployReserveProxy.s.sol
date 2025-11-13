// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ConcreteReserveVault} from "../src/concrete/ConcreteReserveVault.sol";

contract DeployReserveProxy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address reserveImpl = vm.envAddress("RESERVE_IMPL");
        address stablecoin = vm.envAddress("STABLECOIN_ADDRESS");
        
        console.log("Deploying Reserve Vault Proxy...");
        console.log("Implementation:", reserveImpl);
        console.log("Stablecoin:", stablecoin);
        
        vm.startBroadcast(deployerPrivateKey);
        
        bytes memory initData = abi.encodeWithSelector(
            ConcreteReserveVault.initialize.selector,
            stablecoin,
            address(0x0000000000000000000000000000000000000001),
            0
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(reserveImpl, initData);
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("Reserve Vault Proxy deployed at:", address(proxy));
        console.log("");
        console.log("Copy this address:");
        console.log("export RESERVE_VAULT=%s", address(proxy));
    }
}

