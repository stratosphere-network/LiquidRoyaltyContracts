// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {ConcreteJuniorVault} from "../src/concrete/ConcreteJuniorVault.sol";

/**
 * @title UpgradeJuniorToV3
 * @notice Upgrades Junior vault to V3 (with cooldown)
 * @dev Uses already-deployed implementation
 */
contract UpgradeJuniorToV3 is Script {
    // From prod_addresses.md
    address constant JUNIOR_PROXY = 0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883;
    
    // Your new V3 implementation
    address constant JUNIOR_V3_IMPL = 0xCf094387f9A94A867947E78E9A66774dbfC7187E;
    
    function run() external {
        console2.log("=================================================");
        console2.log("          UPGRADE JUNIOR VAULT TO V3");
        console2.log("=================================================");
        console2.log("");
        console2.log("Upgrader:", msg.sender);
        console2.log("Junior Proxy:", JUNIOR_PROXY);
        console2.log("New Implementation:", JUNIOR_V3_IMPL);
        console2.log("");
        
        vm.startBroadcast();
        
        // Prepare initializeV3() calldata
        bytes memory initData = abi.encodeWithSignature("initializeV3()");
        
        // Upgrade!
        ConcreteJuniorVault(JUNIOR_PROXY).upgradeToAndCall(JUNIOR_V3_IMPL, initData);
        
        vm.stopBroadcast();
        
        console2.log("=================================================");
        console2.log("              UPGRADE COMPLETE!");
        console2.log("=================================================");
        console2.log("");
        console2.log("[OK] Junior vault upgraded to V3");
        console2.log("");
        console2.log("NEW FEATURES:");
        console2.log("  - initiateCooldown() - start 7-day timer");
        console2.log("  - canWithdrawWithoutPenalty(user)");
        console2.log("  - 20% early withdrawal penalty");
        console2.log("  - 1% withdrawal fee (unchanged)");
        console2.log("");
        console2.log("=================================================");
    }
}

