// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ConcreteJuniorVault} from "../src/concrete/ConcreteJuniorVault.sol";

/**
 * @title RollbackJunior
 * @notice Rollback Junior Vault to previous implementation
 * @dev EMERGENCY USE ONLY - rolls back to last known good implementation
 * 
 * Usage:
 *   forge script script/RollbackJunior.s.sol:RollbackJunior --rpc-url $RPC_URL --broadcast
 */
contract RollbackJunior is Script {
    address constant JUNIOR_PROXY = 0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883;
    
    // V1 implementation (before role management upgrade)
    address constant PREVIOUS_IMPL = 0xdFCdD986F2a5E412671afC81537BA43D1f6A328b;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console2.log("=================================================");
        console2.log("EMERGENCY ROLLBACK - JUNIOR VAULT");
        console2.log("=================================================");
        console2.log("Proxy:", JUNIOR_PROXY);
        console2.log("Rolling back to:", PREVIOUS_IMPL);
        console2.log("");
        console2.log("[WARNING] This will revert to previous implementation!");
        console2.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        ConcreteJuniorVault proxy = ConcreteJuniorVault(JUNIOR_PROXY);
        proxy.upgradeToAndCall(PREVIOUS_IMPL, "");
        
        vm.stopBroadcast();
        
        console2.log("[SUCCESS] Rollback complete!");
        console2.log("");
        console2.log("Verify state:");
        console2.log("  Admin:", proxy.admin());
        console2.log("  Senior Vault:", proxy.seniorVault());
        console2.log("  Total Supply:", proxy.totalSupply());
        console2.log("  Vault Value:", proxy.vaultValue());
        console2.log("=================================================");
    }
}

