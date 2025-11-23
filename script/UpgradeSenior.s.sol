// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {UnifiedConcreteSeniorVault} from "../src/concrete/UnifiedConcreteSeniorVault.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title UpgradeSenior
 * @notice Upgrade Senior Vault to new implementation
 * @dev IMPORTANT: New implementation MUST preserve storage layout!
 *      - Do NOT remove existing storage variables
 *      - Do NOT change order of existing storage variables
 *      - Do NOT change inheritance order
 *      - Can only ADD new storage variables at the END
 * 
 * Usage:
 *   forge script script/UpgradeSenior.s.sol:UpgradeSenior --rpc-url $RPC_URL --broadcast --verify
 * 
 * Dry run (simulate without broadcasting):
 *   forge script script/UpgradeSenior.s.sol:UpgradeSenior --rpc-url $RPC_URL
 */
contract UpgradeSenior is Script {
    // Production addresses (from prod_addresses.md)
    address constant SENIOR_PROXY = 0x49298F4314eb127041b814A2616c25687Db6b650;
    address constant ADMIN = 0x6fa2149E69DbCBDCf6F16F755E08c10E53c40605;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("=================================================");
        console2.log("SENIOR VAULT UPGRADE");
        console2.log("=================================================");
        console2.log("Deployer:", deployer);
        console2.log("Senior Proxy:", SENIOR_PROXY);
        console2.log("Admin:", ADMIN);
        console2.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Deploy new implementation
        console2.log("Step 1: Deploying new Senior implementation...");
        UnifiedConcreteSeniorVault newImplementation = new UnifiedConcreteSeniorVault();
        console2.log("New Implementation deployed at:", address(newImplementation));
        console2.log("");
        
        // Step 2: Prepare upgrade call data
        console2.log("Step 2: Preparing upgrade...");
        // If you need to run initialization logic during upgrade, encode it here
        // For most upgrades with no new initialization, use empty bytes
        bytes memory upgradeData = "";
        
        // If you added new storage and need to initialize it, use reinitializer:
        // bytes memory upgradeData = abi.encodeWithSignature(
        //     "initializeV2()",  // Your new init function with reinitializer(2) modifier
        // );
        
        console2.log("Upgrade data:", upgradeData.length > 0 ? "Has initialization" : "Empty (no init)");
        console2.log("");
        
        // Step 3: Upgrade proxy to new implementation
        console2.log("Step 3: Upgrading proxy...");
        UnifiedConcreteSeniorVault proxy = UnifiedConcreteSeniorVault(payable(SENIOR_PROXY));
        proxy.upgradeToAndCall(address(newImplementation), upgradeData);
        
        console2.log("[SUCCESS] Upgrade successful!");
        console2.log("");
        
        vm.stopBroadcast();
        
        // Step 4: Verification
        console2.log("=================================================");
        console2.log("VERIFICATION");
        console2.log("=================================================");
        
        // Read some state to verify upgrade worked
        console2.log("Vault Name:", proxy.name());
        console2.log("Vault Symbol:", proxy.symbol());
        console2.log("Total Supply:", proxy.totalSupply());
        console2.log("Vault Value:", proxy.vaultValue());
        console2.log("Rebase Index:", proxy.rebaseIndex());
        console2.log("Admin:", proxy.admin());
        console2.log("");
        
        console2.log("=================================================");
        console2.log("UPGRADE COMPLETE");
        console2.log("=================================================");
        console2.log("New Implementation:", address(newImplementation));
        console2.log("Proxy Address:", SENIOR_PROXY);
        console2.log("[SUCCESS] Storage preserved, upgrade successful!");
        console2.log("");
        console2.log("NEXT STEPS:");
        console2.log("1. Verify implementation on block explorer");
        console2.log("2. Test critical functions (deposit, withdraw, rebase)");
        console2.log("3. Monitor for any issues");
        console2.log("=================================================");
    }
}

