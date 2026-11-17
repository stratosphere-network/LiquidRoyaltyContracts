// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {MetaSeniorVaultPath1} from "../src/concrete/MetaSeniorVaultPath1.sol";

/// @notice Deploy-only Path1 implementation for live Meta Senior proxy (no proxy upgrade broadcast).
/// @dev Live proxy: 0xC38421E5577250EBa177Bc5bC832E747bea13Ee0 (Berachain 80094).
contract DeployMetaSeniorPath1Impl is Script {
    address internal constant LIVE_PROXY = 0xC38421E5577250EBa177Bc5bC832E747bea13Ee0;

    function run() external {
        bool shouldBroadcast = vm.envOr("META_SENIOR_BROADCAST", false);

        console2.log("=== Meta Senior Path1 implementation deploy ===");
        console2.log("chainId", block.chainid);
        console2.log("liveProxy (reference)", LIVE_PROXY);
        console2.log("broadcast", shouldBroadcast);

        address impl;
        if (shouldBroadcast) {
            uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
            vm.startBroadcast(pk);
            impl = address(new MetaSeniorVaultPath1());
            vm.stopBroadcast();
        } else {
            impl = address(new MetaSeniorVaultPath1());
        }

        console2.log("implementation", impl);
        console2.log("");
        console2.log("REQUIRED upgrade calldata (Bera admin Safe) - do NOT use empty bytes:");
        console2.log("upgradeToAndCall(impl, initializePath1())");
        bytes memory initData = abi.encodeWithSelector(MetaSeniorVaultPath1.initializePath1.selector);
        console2.logBytes(
            abi.encodeWithSelector(bytes4(keccak256("upgradeToAndCall(address,bytes)")), impl, initData)
        );
        console2.log("");
        console2.log("initializePath1 calldata only (for reference):");
        console2.logBytes(initData);
        console2.log("");
        console2.log("Verify (Berachain):");
        console2.log("forge verify-contract", impl);
        console2.log("  src/concrete/MetaSeniorVaultPath1.sol:MetaSeniorVaultPath1");
        console2.log("  --chain-id 80094");
        console2.log("  --constructor-args $(cast abi-encode \"constructor()\")");
    }
}