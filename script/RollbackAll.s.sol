// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {UnifiedConcreteSeniorVault} from "../src/concrete/UnifiedConcreteSeniorVault.sol";
import {ConcreteJuniorVault} from "../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../src/concrete/ConcreteReserveVault.sol";

/**
 * @title RollbackAll
 * @notice Rollback ALL vaults to previous implementations
 * @dev EMERGENCY USE ONLY - use if upgrade went wrong
 * 
 * Usage:
 *   forge script script/RollbackAll.s.sol:RollbackAll --rpc-url $RPC_URL --broadcast
 */
contract RollbackAll is Script {
    address constant SENIOR_PROXY = 0x49298F4314eb127041b814A2616c25687Db6b650;
    address constant JUNIOR_PROXY = 0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883;
    address constant RESERVE_PROXY = 0x7754272c866892CaD4a414C76f060645bDc27203;
    
    // V1 implementation addresses (pre-upgrade with role management)
    address constant SENIOR_PREVIOUS = 0xC9Eb65414650927dd9e8839CA7c696437e982547;
    address constant JUNIOR_PREVIOUS = 0xdFCdD986F2a5E412671afC81537BA43D1f6A328b;
    address constant RESERVE_PREVIOUS = 0x657613E8265e07e542D42802515677A1199989B2;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console2.log("=================================================");
        console2.log("EMERGENCY ROLLBACK - ALL VAULTS");
        console2.log("=================================================");
        console2.log("[CRITICAL] Rolling back all vaults to previous implementations!");
        console2.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        console2.log("1/3 Rolling back Senior...");
        UnifiedConcreteSeniorVault seniorProxy = UnifiedConcreteSeniorVault(payable(SENIOR_PROXY));
        seniorProxy.upgradeToAndCall(SENIOR_PREVIOUS, "");
        console2.log("    [OK] Senior rolled back to:", SENIOR_PREVIOUS);
        
        console2.log("2/3 Rolling back Junior...");
        ConcreteJuniorVault juniorProxy = ConcreteJuniorVault(JUNIOR_PROXY);
        juniorProxy.upgradeToAndCall(JUNIOR_PREVIOUS, "");
        console2.log("    [OK] Junior rolled back to:", JUNIOR_PREVIOUS);
        
        console2.log("3/3 Rolling back Reserve...");
        ConcreteReserveVault reserveProxy = ConcreteReserveVault(RESERVE_PROXY);
        reserveProxy.upgradeToAndCall(RESERVE_PREVIOUS, "");
        console2.log("    [OK] Reserve rolled back to:", RESERVE_PREVIOUS);
        
        vm.stopBroadcast();
        
        console2.log("");
        console2.log("=================================================");
        console2.log("ROLLBACK COMPLETE");
        console2.log("=================================================");
        console2.log("Senior - Admin:", seniorProxy.admin());
        console2.log("Junior - Admin:", juniorProxy.admin());
        console2.log("Reserve - Admin:", reserveProxy.admin());
        console2.log("");
        console2.log("[SUCCESS] All vaults rolled back successfully!");
        console2.log("=================================================");
    }
}

