// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {UnifiedConcreteSeniorVault} from "../src/concrete/UnifiedConcreteSeniorVault.sol";
import {ConcreteJuniorVault} from "../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../src/concrete/ConcreteReserveVault.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


/**
 * @title UpgradeVaults
 * @notice Script to upgrade UUPS proxy implementations
 * @dev Deploys new implementation and calls upgradeTo() on existing proxy
 * 
 * Usage:
 * 1. Deploy new Senior implementation:
 *    forge script script/UpgradeVaults.s.sol:UpgradeVaults --sig "upgradeSenior(address)" <PROXY_ADDRESS> --rpc-url <RPC_URL> --broadcast --verify
 * 
 * 2. Deploy new Junior implementation:
 *    forge script script/UpgradeVaults.s.sol:UpgradeVaults --sig "upgradeJunior(address)" <PROXY_ADDRESS> --rpc-url <RPC_URL> --broadcast --verify
 * 
 * 3. Deploy new Reserve implementation:
 *    forge script script/UpgradeVaults.s.sol:UpgradeVaults --sig "upgradeReserve(address)" <PROXY_ADDRESS> --rpc-url <RPC_URL> --broadcast --verify
 */
contract UpgradeVaults is Script {
    
    /**
     * @notice Upgrade Senior Vault to new implementation
     * @param proxyAddress Address of the existing Senior Vault proxy
     * @return newImplementation Address of the newly deployed implementation
     */
    function upgradeSenior(address proxyAddress) public returns (address newImplementation) {
        require(proxyAddress != address(0), "Invalid proxy address");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("================================================");
        console.log("Upgrading Senior Vault");
        console.log("================================================");
        console.log("Proxy Address:", proxyAddress);
        
        // 1. Deploy new implementation
        console.log("\n1. Deploying new Senior implementation...");
        UnifiedConcreteSeniorVault newImpl = new UnifiedConcreteSeniorVault();
        newImplementation = address(newImpl);
        console.log("New Implementation:", newImplementation);
        
        // 2. Upgrade proxy to new implementation
        console.log("\n2. Upgrading proxy to new implementation...");
        UUPSUpgradeable proxy = UUPSUpgradeable(proxyAddress);
        proxy.upgradeToAndCall(newImplementation, "");
        console.log("Upgrade complete!");
        
        vm.stopBroadcast();
        
        console.log("\n================================================");
        console.log("Senior Vault Upgrade Summary");
        console.log("================================================");
        console.log("Proxy Address:", proxyAddress);
        console.log("New Implementation:", newImplementation);
        console.log("================================================");
        
        return newImplementation;
    }
    
    /**
     * @notice Upgrade Junior Vault to new implementation
     * @param proxyAddress Address of the existing Junior Vault proxy
     * @return newImplementation Address of the newly deployed implementation
     */
    function upgradeJunior(address proxyAddress) public returns (address newImplementation) {
        require(proxyAddress != address(0), "Invalid proxy address");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("================================================");
        console.log("Upgrading Junior Vault");
        console.log("================================================");
        console.log("Proxy Address:", proxyAddress);
        
        // 1. Deploy new implementation
        console.log("\n1. Deploying new Junior implementation...");
        ConcreteJuniorVault newImpl = new ConcreteJuniorVault();
        newImplementation = address(newImpl);
        console.log("New Implementation:", newImplementation);
        
        // 2. Upgrade proxy to new implementation
        console.log("\n2. Upgrading proxy to new implementation...");
        UUPSUpgradeable proxy = UUPSUpgradeable(proxyAddress);
        proxy.upgradeToAndCall(newImplementation, "");
        console.log("Upgrade complete!");
        
        vm.stopBroadcast();
        
        console.log("\n================================================");
        console.log("Junior Vault Upgrade Summary");
        console.log("================================================");
        console.log("Proxy Address:", proxyAddress);
        console.log("New Implementation:", newImplementation);
        console.log("================================================");
        
        return newImplementation;
    }
    
    /**
     * @notice Upgrade Reserve Vault to new implementation
     * @param proxyAddress Address of the existing Reserve Vault proxy
     * @return newImplementation Address of the newly deployed implementation
     */
    function upgradeReserve(address proxyAddress) public returns (address newImplementation) {
        require(proxyAddress != address(0), "Invalid proxy address");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("================================================");
        console.log("Upgrading Reserve Vault");
        console.log("================================================");
        console.log("Proxy Address:", proxyAddress);
        
        // 1. Deploy new implementation
        console.log("\n1. Deploying new Reserve implementation...");
        ConcreteReserveVault newImpl = new ConcreteReserveVault();
        newImplementation = address(newImpl);
        console.log("New Implementation:", newImplementation);
        
        // 2. Upgrade proxy to new implementation
        console.log("\n2. Upgrading proxy to new implementation...");
        UUPSUpgradeable proxy = UUPSUpgradeable(proxyAddress);
        proxy.upgradeToAndCall(newImplementation, "");
        console.log("Upgrade complete!");
        
        vm.stopBroadcast();
        
        console.log("\n================================================");
        console.log("Reserve Vault Upgrade Summary");
        console.log("================================================");
        console.log("Proxy Address:", proxyAddress);
        console.log("New Implementation:", newImplementation);
        console.log("================================================");
        
        return newImplementation;
    }
    
    /**
     * @notice Deploy new implementation WITHOUT upgrading (for testing)
     * @dev Useful to check if new implementation compiles and deploys
     */
    function deployNewImplementations() public returns (
        address seniorImpl,
        address juniorImpl,
        address reserveImpl
    ) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("================================================");
        console.log("Deploying New Implementations (No Upgrade)");
        console.log("================================================");
        
        // Deploy new implementations
        UnifiedConcreteSeniorVault seniorVault = new UnifiedConcreteSeniorVault();
        ConcreteJuniorVault juniorVault = new ConcreteJuniorVault();
        ConcreteReserveVault reserveVault = new ConcreteReserveVault();
        
        seniorImpl = address(seniorVault);
        juniorImpl = address(juniorVault);
        reserveImpl = address(reserveVault);
        
        vm.stopBroadcast();
        
        console.log("\nNew Senior Implementation:", seniorImpl);
        console.log("New Junior Implementation:", juniorImpl);
        console.log("New Reserve Implementation:", reserveImpl);
        console.log("\nNote: Proxies NOT upgraded. Use upgrade functions to point proxies to these implementations.");
        console.log("================================================");
        
        return (seniorImpl, juniorImpl, reserveImpl);
    }
}

