// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {UnifiedConcreteSeniorVault} from "../src/concrete/UnifiedConcreteSeniorVault.sol";

/**
 * @title RollbackSenior
 * @notice Rollback Senior Vault to previous implementation
 * @dev EMERGENCY USE ONLY - rolls back to last known good implementation
 * 
 * Usage:
 *   forge script script/RollbackSenior.s.sol:RollbackSenior --rpc-url $RPC_URL --broadcast
 */
contract RollbackSenior is Script {
    address constant SENIOR_PROXY = 0x49298F4314eb127041b814A2616c25687Db6b650;
    
    // V1 implementation (before role management upgrade)
    address constant PREVIOUS_IMPL = 0xC9Eb65414650927dd9e8839CA7c696437e982547;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console2.log("=================================================");
        console2.log("EMERGENCY ROLLBACK - SENIOR VAULT");
        console2.log("=================================================");
        console2.log("Proxy:", SENIOR_PROXY);
        console2.log("Rolling back to:", PREVIOUS_IMPL);
        console2.log("");
        console2.log("[WARNING] This will revert to previous implementation!");
        console2.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        UnifiedConcreteSeniorVault proxy = UnifiedConcreteSeniorVault(payable(SENIOR_PROXY));
        proxy.upgradeToAndCall(PREVIOUS_IMPL, "");
        
        vm.stopBroadcast();
        
        console2.log("[SUCCESS] Rollback complete!");
        console2.log("");
        console2.log("Verify state:");
        console2.log("  Admin:", proxy.admin());
        console2.log("  Treasury:", proxy.treasury());
        console2.log("  Total Supply:", proxy.totalSupply());
        console2.log("  Vault Value:", proxy.vaultValue());
        console2.log("=================================================");
    }
}

