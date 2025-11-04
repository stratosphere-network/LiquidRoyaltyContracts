// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ConcreteJuniorVault} from "../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../src/concrete/ConcreteReserveVault.sol";
import {UnifiedConcreteSeniorVault} from "../src/concrete/UnifiedConcreteSeniorVault.sol";

/**
 * @title DeployVaults
 * @notice Deploys Senior, Junior, and Reserve vaults with your own LP token
 * @dev Set LP_TOKEN environment variable before running
 * 
 * Usage:
 *   export LP_TOKEN=0xYourLPTokenAddress
 *   forge script script/DeployVaults.s.sol:DeployVaults --rpc-url $RPC_URL --broadcast
 */
contract DeployVaults is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address lpToken = vm.envAddress("LP_TOKEN");
        
        // Read optional parameters (with defaults)
        uint256 seniorInitialValue = vm.envOr("SENIOR_INITIAL_VALUE", uint256(833_000e18));
        uint256 juniorInitialValue = vm.envOr("JUNIOR_INITIAL_VALUE", uint256(833_000e18));
        uint256 reserveInitialValue = vm.envOr("RESERVE_INITIAL_VALUE", uint256(625_000e18));
        address treasury = vm.envOr("TREASURY", msg.sender);
        
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("===========================================");
        console2.log("VAULT DEPLOYMENT");
        console2.log("===========================================");
        console2.log("Deployer:", deployer);
        console2.log("LP Token:", lpToken);
        console2.log("Senior Initial Value:", seniorInitialValue);
        console2.log("Junior Initial Value:", juniorInitialValue);
        console2.log("Reserve Initial Value:", reserveInitialValue);
        console2.log("Treasury:", treasury);
        console2.log("===========================================");
        console2.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // ============================================
        // STEP 1: Deploy Implementation Contracts
        // ============================================
        console2.log("STEP 1: Deploying Implementations...");
        
        ConcreteJuniorVault juniorImpl = new ConcreteJuniorVault();
        console2.log("  Junior Implementation:", address(juniorImpl));
        
        ConcreteReserveVault reserveImpl = new ConcreteReserveVault();
        console2.log("  Reserve Implementation:", address(reserveImpl));
        
        UnifiedConcreteSeniorVault seniorImpl = new UnifiedConcreteSeniorVault();
        console2.log("  Senior Implementation:", address(seniorImpl));
        console2.log("");
        
        // ============================================
        // STEP 2: Deploy Proxies (with placeholders)
        // ============================================
        console2.log("STEP 2: Deploying Proxies...");
        
        address placeholder = address(0x1);
        
        // Junior Proxy
        bytes memory juniorInit = abi.encodeWithSignature(
            "initialize(address,address,uint256)",
            lpToken,
            placeholder,  // Senior vault (set later)
            juniorInitialValue
        );
        ERC1967Proxy juniorProxy = new ERC1967Proxy(address(juniorImpl), juniorInit);
        console2.log("  Junior Vault:", address(juniorProxy));
        
        // Reserve Proxy
        bytes memory reserveInit = abi.encodeWithSignature(
            "initialize(address,address,uint256)",
            lpToken,
            placeholder,  // Senior vault (set later)
            reserveInitialValue
        );
        ERC1967Proxy reserveProxy = new ERC1967Proxy(address(reserveImpl), reserveInit);
        console2.log("  Reserve Vault:", address(reserveProxy));
        
        // Senior Proxy
        bytes memory seniorInit = abi.encodeWithSignature(
            "initialize(address,string,string,address,address,address,uint256)",
            lpToken,
            "Senior USD",
            "snrUSD",
            address(juniorProxy),
            address(reserveProxy),
            treasury,
            seniorInitialValue
        );
        ERC1967Proxy seniorProxy = new ERC1967Proxy(address(seniorImpl), seniorInit);
        console2.log("  Senior Vault:", address(seniorProxy));
        console2.log("");
        
        // ============================================
        // STEP 3: Set Admin (deployer sets admin = deployer)
        // ============================================
        console2.log("STEP 3: Setting Admin...");
        
        ConcreteJuniorVault(address(juniorProxy)).setAdmin(deployer);
        console2.log("  Junior admin set to deployer");
        
        ConcreteReserveVault(address(reserveProxy)).setAdmin(deployer);
        console2.log("  Reserve admin set to deployer");
        
        UnifiedConcreteSeniorVault(address(seniorProxy)).setAdmin(deployer);
        console2.log("  Senior admin set to deployer");
        console2.log("");
        
        // ============================================
        // STEP 4: Fix Circular Dependencies
        // ============================================
        console2.log("STEP 4: Fixing Circular Dependencies...");
        
        ConcreteJuniorVault(address(juniorProxy)).setSeniorVault(address(seniorProxy));
        console2.log("  Junior -> Senior link established");
        
        ConcreteReserveVault(address(reserveProxy)).setSeniorVault(address(seniorProxy));
        console2.log("  Reserve -> Senior link established");
        console2.log("  (Senior already has Junior/Reserve from initialization)");
        console2.log("");
        
        vm.stopBroadcast();
        
        // ============================================
        // DEPLOYMENT SUMMARY
        // ============================================
        console2.log("===========================================");
        console2.log("DEPLOYMENT COMPLETE!");
        console2.log("===========================================");
        console2.log("");
        console2.log("LP Token:");
        console2.log("  Address:", lpToken);
        console2.log("");
        console2.log("Junior Vault:");
        console2.log("  Proxy:", address(juniorProxy));
        console2.log("  Implementation:", address(juniorImpl));
        console2.log("  Initial Value:", juniorInitialValue);
        console2.log("");
        console2.log("Reserve Vault:");
        console2.log("  Proxy:", address(reserveProxy));
        console2.log("  Implementation:", address(reserveImpl));
        console2.log("  Initial Value:", reserveInitialValue);
        console2.log("");
        console2.log("Senior Vault (snrUSD):");
        console2.log("  Proxy:", address(seniorProxy));
        console2.log("  Implementation:", address(seniorImpl));
        console2.log("  Initial Value:", seniorInitialValue);
        console2.log("");
        console2.log("===========================================");
        console2.log("NEXT STEPS:");
        console2.log("===========================================");
        console2.log("1. Set admin for Senior vault");
        console2.log("2. Approve & deposit LP tokens to vaults");
        console2.log("3. Update vault values monthly (admin only)");
        console2.log("4. Trigger rebase (admin only)");
        console2.log("===========================================");
    }
}

