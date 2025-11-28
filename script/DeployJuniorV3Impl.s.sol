// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {ConcreteJuniorVault} from "../src/concrete/ConcreteJuniorVault.sol";

/**
 * @title DeployJuniorV3Impl
 * @notice ONLY deploys Junior V3 implementation (doesn't upgrade)
 * @dev Admin multisig will upgrade via Safe after deployment
 */
contract DeployJuniorV3Impl is Script {
    function run() external {
        console2.log("=================================================");
        console2.log("       DEPLOY JUNIOR V3 IMPLEMENTATION ONLY");
        console2.log("=================================================");
        console2.log("");
        console2.log("Deployer:", msg.sender);
        console2.log("");
        
        vm.startBroadcast();
        
        // Deploy implementation
        ConcreteJuniorVault juniorImpl = new ConcreteJuniorVault();
        
        vm.stopBroadcast();
        
        console2.log("=================================================");
        console2.log("                 DEPLOYMENT COMPLETE");
        console2.log("=================================================");
        console2.log("");
        console2.log("[OK] Junior V3 Implementation:", address(juniorImpl));
        console2.log("");
        console2.log("=================================================");
        console2.log("           NEXT STEPS (VIA SAFE MULTISIG)");
        console2.log("=================================================");
        console2.log("");
        console2.log("1. Go to Safe app");
        console2.log("2. Create new transaction to Junior Proxy:");
        console2.log("   Address: 0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883");
        console2.log("");
        console2.log("3. Call function: upgradeToAndCall");
        console2.log("   - newImplementation:", address(juniorImpl));
        console2.log("   - data: 0x38e454b1");
        console2.log("     (this is initializeV3() selector)");
        console2.log("");
        console2.log("4. Sign with multisig");
        console2.log("5. Execute transaction");
        console2.log("");
        console2.log("NEW FEATURES IN V3:");
        console2.log("  - initiateCooldown() - start 7-day timer");
        console2.log("  - canWithdrawWithoutPenalty(user) - check cooldown");
        console2.log("  - 20% early withdrawal penalty (if no cooldown)");
        console2.log("  - 1% withdrawal fee (same as before)");
        console2.log("");
        console2.log("=================================================");
    }
}

