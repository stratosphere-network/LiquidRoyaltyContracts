// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ConcreteReserveVault} from "../src/concrete/ConcreteReserveVault.sol";

/**
 * @title RollbackReserve
 * @notice Rollback Reserve Vault to previous implementation
 * @dev EMERGENCY USE ONLY - rolls back to last known good implementation
 * 
 * Usage:
 *   forge script script/RollbackReserve.s.sol:RollbackReserve --rpc-url $RPC_URL --broadcast
 */
contract RollbackReserve is Script {
    address constant RESERVE_PROXY = 0x7754272c866892CaD4a414C76f060645bDc27203;
    
    // V1 implementation (before role management upgrade)
    address constant PREVIOUS_IMPL = 0x657613E8265e07e542D42802515677A1199989B2;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console2.log("=================================================");
        console2.log("EMERGENCY ROLLBACK - RESERVE VAULT");
        console2.log("=================================================");
        console2.log("Proxy:", RESERVE_PROXY);
        console2.log("Rolling back to:", PREVIOUS_IMPL);
        console2.log("");
        console2.log("[WARNING] This will revert to previous implementation!");
        console2.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        ConcreteReserveVault proxy = ConcreteReserveVault(RESERVE_PROXY);
        proxy.upgradeToAndCall(PREVIOUS_IMPL, "");
        
        vm.stopBroadcast();
        
        console2.log("[SUCCESS] Rollback complete!");
        console2.log("");
        console2.log("Verify state:");
        console2.log("  Admin:", proxy.admin());
        console2.log("  Senior Vault:", proxy.seniorVault());
        console2.log("  Total Supply:", proxy.totalSupply());
        console2.log("  Vault Value:", proxy.vaultValue());
        console2.log("  Deposit Cap:", proxy.currentDepositCap());
        console2.log("=================================================");
    }
}

