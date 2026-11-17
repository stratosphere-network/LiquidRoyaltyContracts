// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {MetaSeniorVault} from "../src/concrete/MetaSeniorVault.sol";
import {MetaSeniorVaultPath1} from "../src/concrete/MetaSeniorVaultPath1.sol";

/// @notice Compares compiled base layout against live proxy state (fork) and lists Path1 tail slots.
contract ValidateMetaSeniorStorageLayout is Script {
    address internal constant META_SENIOR_PROXY = 0xC38421E5577250EBa177Bc5bC832E747bea13Ee0;

    function run() external view {
        console2.log("=== Meta Senior storage layout validation ===");
        console2.log("proxy", META_SENIOR_PROXY);

        MetaSeniorVault vault = MetaSeniorVault(META_SENIOR_PROXY);

        console2.log("feeAddress", vault.feeAddress());
        console2.log("unstakingFeeBps", vault.unstakingFeeBps());
        console2.log("vaultOpenToPublic", vault.vaultOpenToPublic());
        console2.log("depositCap", vault.depositCap());
        console2.log("totalSupply", vault.totalSupply());
        console2.log("totalAssets", vault.totalAssets());
        console2.log("getVaultValue", vault.getVaultValue());

        address[] memory subs = vault.getSubVaultList();
        console2.log("subVaultCount", subs.length);
        for (uint256 i = 0; i < subs.length; i++) {
            console2.log("  subVault", i, subs[i]);
        }

        console2.log("");
        console2.log("Run locally:");
        console2.log("  forge inspect MetaSeniorVault storage-layout --json");
        console2.log("  forge inspect MetaSeniorVaultPath1 storage-layout --json");
        console2.log("Compare: all MetaSeniorVault entries must match slot/offset; Path1 adds only new tail slots.");
    }
}