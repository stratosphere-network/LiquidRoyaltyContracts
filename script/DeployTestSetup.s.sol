// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UnifiedConcreteSeniorVault} from "../src/concrete/UnifiedConcreteSeniorVault.sol";
import {ConcreteJuniorVault} from "../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../src/concrete/ConcreteReserveVault.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract DeployTestSetup is Script {
    // State variables to avoid stack too deep
    MockERC20 public usde;
    MockERC20 public sail;
    UnifiedConcreteSeniorVault public seniorImpl;
    ConcreteJuniorVault public juniorImpl;
    ConcreteReserveVault public reserveImpl;
    ERC1967Proxy public seniorProxy;
    ERC1967Proxy public juniorProxy;
    ERC1967Proxy public reserveProxy;
    address public deployer;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== DEPLOYING TEST SETUP ===");
        console.log("Deployer:", deployer);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        deployTokens();
        deployImplementations();
        deployProxies();
        configureVaults();
        
        vm.stopBroadcast();
        
        printSummary();
    }
    
    function deployTokens() internal {
        console.log("Step 1: Deploying Mock Tokens...");
        
        usde = new MockERC20("USDE", "USDE", 6);
        sail = new MockERC20("SAIL", "SAIL", 18);
        
        console.log("USDE Token:", address(usde));
        console.log("SAIL Token:", address(sail));
        
        usde.mint(deployer, 10_000_000 * 1e6);
        sail.mint(deployer, 1_000_000 * 1e18);
        
        console.log("Minted 10M USDE to deployer");
        console.log("Minted 1M SAIL to deployer");
        console.log("");
    }
    
    function deployImplementations() internal {
        console.log("Step 2: Deploying Vault Implementations...");
        
        seniorImpl = new UnifiedConcreteSeniorVault();
        juniorImpl = new ConcreteJuniorVault();
        reserveImpl = new ConcreteReserveVault();
        
        console.log("Senior Implementation:", address(seniorImpl));
        console.log("Junior Implementation:", address(juniorImpl));
        console.log("Reserve Implementation:", address(reserveImpl));
        console.log("");
    }
    
    function deployProxies() internal {
        console.log("Step 3: Deploying Vault Proxies...");
        
        juniorProxy = new ERC1967Proxy(
            address(juniorImpl),
            abi.encodeWithSelector(
                ConcreteJuniorVault.initialize.selector,
                address(usde),
                address(0x1),
                0
            )
        );
        
        reserveProxy = new ERC1967Proxy(
            address(reserveImpl),
            abi.encodeWithSelector(
                ConcreteReserveVault.initialize.selector,
                address(usde),
                address(0x1),
                0
            )
        );
        
        console.log("Junior Proxy (jnrUSD):", address(juniorProxy));
        console.log("Reserve Proxy (resUSD):", address(reserveProxy));
        
        seniorProxy = new ERC1967Proxy(
            address(seniorImpl),
            abi.encodeWithSelector(
                UnifiedConcreteSeniorVault.initialize.selector,
                address(usde),
                "Senior USD",
                "snrUSD",
                address(juniorProxy),
                address(reserveProxy),
                deployer,
                0
            )
        );
        
        console.log("Senior Proxy (snrUSD):", address(seniorProxy));
        console.log("");
    }
    
    function configureVaults() internal {
        console.log("Step 4: Configuring Vaults...");
        
        ConcreteJuniorVault(address(juniorProxy)).updateSeniorVault(address(seniorProxy));
        ConcreteReserveVault(address(reserveProxy)).updateSeniorVault(address(seniorProxy));
        
        UnifiedConcreteSeniorVault(address(seniorProxy)).setAdmin(deployer);
        ConcreteJuniorVault(address(juniorProxy)).setAdmin(deployer);
        ConcreteReserveVault(address(reserveProxy)).setAdmin(deployer);
        
        UnifiedConcreteSeniorVault(address(seniorProxy)).setVaultValue(0);
        ConcreteJuniorVault(address(juniorProxy)).setVaultValue(0);
        ConcreteReserveVault(address(reserveProxy)).setVaultValue(0);
        ConcreteReserveVault(address(reserveProxy)).setVaultValue(0);
        
        console.log("Vaults configured!");
        console.log("");
    }
    
    function printSummary() internal view {
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("");
        console.log("Copy these addresses:");
        console.log("--------------------------------------------");
        console.log("USDE Token:      ", address(usde));
        console.log("SAIL Token:      ", address(sail));
        console.log("Senior Vault:    ", address(seniorProxy));
        console.log("Junior Vault:    ", address(juniorProxy));
        console.log("Reserve Vault:   ", address(reserveProxy));
        console.log("--------------------------------------------");
        console.log("");
        console.log("Token Balances:");
        console.log("Your USDE:       ", usde.balanceOf(deployer) / 1e6, "USDE");
        console.log("Your SAIL:       ", sail.balanceOf(deployer) / 1e18, "SAIL");
        console.log("");
        console.log("Next Steps:");
        console.log("1. Create USDE-SAIL pool on Kodiak/Uniswap");
        console.log("2. Add liquidity (e.g., 100K USDE + 10K SAIL)");
        console.log("3. Share the pool address!");
        console.log("");
    }
    
}
