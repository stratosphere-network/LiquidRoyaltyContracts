// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {KodiakVaultHook} from "../src/integrations/KodiakVaultHook.sol";

/**
 * @title DeployKodiakHook
 * @notice Deploy and verify the KodiakVaultHook contract
 * @dev Reads configuration from environment variables
 * 
 * Required .env variables:
 *   PRIVATE_KEY         - Deployer private key
 *   VAULT_ADDRESS       - Address of the vault that will use this hook
 *   ASSET_TOKEN_ADDRESS - Address of the stablecoin (e.g., HONEY/USDC)
 *   ADMIN_ADDRESS       - Admin address for the hook
 * 
 * Optional .env variables:
 *   ROUTER_ADDRESS      - Kodiak Island Router address (set after deploy if not provided)
 *   ISLAND_ADDRESS      - Kodiak Island address (set after deploy if not provided)
 *   WBERA_ADDRESS       - WBERA address for native BERA handling
 * 
 * Usage:
 *   # Deploy and verify on Berachain
 *   forge script script/DeployKodiakHook.s.sol:DeployKodiakHook \
 *     --rpc-url $RPC_URL \
 *     --broadcast \
 *     --verify \
 *     --verifier-url $VERIFIER_URL \
 *     --etherscan-api-key $ETHERSCAN_API_KEY
 * 
 *   # Dry run (simulate without broadcasting):
 *   forge script script/DeployKodiakHook.s.sol:DeployKodiakHook --rpc-url $RPC_URL
 */
contract DeployKodiakHook is Script {
    function run() external {
        // Load required environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address vault = vm.envAddress("VAULT_ADDRESS");
        address assetToken = vm.envAddress("ASSET_TOKEN_ADDRESS");
        address admin = vm.envAddress("ADMIN_ADDRESS");
        
        // Load optional environment variables
        address router = vm.envOr("ROUTER_ADDRESS", address(0));
        address island = vm.envOr("ISLAND_ADDRESS", address(0));
        address wbera = vm.envOr("WBERA_ADDRESS", address(0));
        
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("=================================================");
        console2.log("DEPLOY KODIAK VAULT HOOK");
        console2.log("=================================================");
        console2.log("Deployer:", deployer);
        console2.log("");
        console2.log("Constructor Arguments:");
        console2.log("  Vault:      ", vault);
        console2.log("  Asset Token:", assetToken);
        console2.log("  Admin:      ", admin);
        console2.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy KodiakVaultHook
        console2.log("Deploying KodiakVaultHook...");
        KodiakVaultHook hook = new KodiakVaultHook(vault, assetToken, admin);
        console2.log("[OK] KodiakVaultHook deployed at:", address(hook));
        console2.log("");
        
        // Configure optional settings if provided
        if (router != address(0)) {
            console2.log("Setting router:", router);
            hook.setRouter(router);
            console2.log("[OK] Router configured");
        }
        
        if (island != address(0)) {
            console2.log("Setting island:", island);
            hook.setIsland(island);
            console2.log("[OK] Island configured");
        }
        
        if (wbera != address(0)) {
            console2.log("Setting WBERA:", wbera);
            hook.setWBERA(wbera);
            console2.log("[OK] WBERA configured");
        }
        
        vm.stopBroadcast();
        
        // Verification
        console2.log("");
        console2.log("=================================================");
        console2.log("DEPLOYMENT SUMMARY");
        console2.log("=================================================");
        console2.log("KodiakVaultHook:", address(hook));
        console2.log("");
        console2.log("Configuration:");
        console2.log("  Vault:       ", hook.vault());
        console2.log("  Asset Token: ", address(hook.assetToken()));
        console2.log("  Router:      ", address(hook.router()));
        console2.log("  Island:      ", address(hook.island()));
        console2.log("  WBERA:       ", hook.wbera());
        console2.log("");
        console2.log("Slippage Settings:");
        console2.log("  Min Shares Per Asset Bps:", hook.minSharesPerAssetBps());
        console2.log("  Min Asset Out Bps:       ", hook.minAssetOutBps());
        console2.log("  Safety Multiplier:       ", hook.safetyMultiplier());
        console2.log("");
        console2.log("=================================================");
        console2.log("DEPLOYMENT COMPLETE");
        console2.log("=================================================");
        console2.log("");
        console2.log("NEXT STEPS:");
        console2.log("1. Verify contract on block explorer (if not auto-verified)");
        console2.log("2. Set router if not configured: hook.setRouter(routerAddress)");
        console2.log("3. Set island if not configured: hook.setIsland(islandAddress)");
        console2.log("4. Whitelist aggregators: hook.setAggregatorWhitelisted(address, true)");
        console2.log("5. Set hook on vault: vault.setHook(hookAddress)");
        console2.log("=================================================");
    }
}

