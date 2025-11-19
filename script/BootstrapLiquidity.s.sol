// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/concrete/UnifiedConcreteSeniorVault.sol";
import "../src/concrete/ConcreteJuniorVault.sol";
import "../src/concrete/ConcreteReserveVault.sol";
import "../src/integrations/IKodiakIsland.sol";

/**
 * @notice Bootstrap initial liquidity for vaults
 * @dev One-time script to seed vaults with LP tokens and mint initial shares
 */
contract BootstrapLiquidity is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.addr(deployerPrivateKey);
        
        // Load contract addresses
        address seniorVault = vm.envAddress("SENIOR_VAULT");
        address juniorVault = vm.envAddress("JUNIOR_VAULT");
        address reserveVault = vm.envAddress("RESERVE_VAULT");
        
        address seniorHook = vm.envAddress("SENIOR_HOOK");
        address juniorHook = vm.envAddress("JUNIOR_HOOK");
        address reserveHook = vm.envAddress("RESERVE_HOOK");
        
        address kodiakIsland = vm.envAddress("KODIAK_ISLAND_ADDRESS");
        address honey = vm.envAddress("HONEY_ADDRESS");
        
        console.log("\n=== BOOTSTRAPPING VAULT LIQUIDITY ===\n");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Example: Bootstrap Senior vault with 100k HONEY worth of LP
        uint256 seniorLPValue = 100_000e18; // $100k in LP tokens
        
        console.log("1. Checking LP balance in Senior hook...");
        IKodiakIsland island = IKodiakIsland(kodiakIsland);
        uint256 seniorHookLP = island.balanceOf(seniorHook);
        console.log("   Senior Hook LP Balance:", seniorHookLP);
        
        if (seniorHookLP > 0) {
            console.log("\n2. Setting Senior vault value...");
            UnifiedConcreteSeniorVault senior = UnifiedConcreteSeniorVault(payable(seniorVault));
            senior.setVaultValue(seniorLPValue);
            console.log("   Vault value set to:", seniorLPValue);
            
            console.log("\n3. Minting initial Senior shares...");
            // Deposit HONEY to get shares at correct ratio
            IERC20 honeyToken = IERC20(honey);
            uint256 honeyBalance = honeyToken.balanceOf(admin);
            console.log("   Admin HONEY balance:", honeyBalance);
            
            if (honeyBalance >= 1000e18) {
                honeyToken.approve(seniorVault, 1000e18);
                senior.deposit(1000e18, admin);
                console.log("   Minted shares for 1000 HONEY");
            } else {
                console.log("   WARNING: Insufficient HONEY for initial deposit");
            }
        } else {
            console.log("   WARNING: No LP tokens in Senior hook. Deploy LP first!");
        }
        
        // Repeat for Junior
        console.log("\n4. Checking LP balance in Junior hook...");
        uint256 juniorHookLP = island.balanceOf(juniorHook);
        console.log("   Junior Hook LP Balance:", juniorHookLP);
        
        if (juniorHookLP > 0) {
            uint256 juniorLPValue = 50_000e18; // $50k in LP
            
            console.log("\n5. Setting Junior vault value...");
            ConcreteJuniorVault junior = ConcreteJuniorVault(juniorVault);
            junior.setVaultValue(juniorLPValue);
            console.log("   Vault value set to:", juniorLPValue);
            
            console.log("\n6. Minting initial Junior shares...");
            IERC20 honeyToken = IERC20(honey);
            if (honeyToken.balanceOf(admin) >= 1000e18) {
                honeyToken.approve(juniorVault, 1000e18);
                junior.deposit(1000e18, admin);
                console.log("   Minted shares for 1000 HONEY");
            }
        } else {
            console.log("   WARNING: No LP tokens in Junior hook. Deploy LP first!");
        }
        
        // Repeat for Reserve
        console.log("\n7. Checking LP balance in Reserve hook...");
        uint256 reserveHookLP = island.balanceOf(reserveHook);
        console.log("   Reserve Hook LP Balance:", reserveHookLP);
        
        if (reserveHookLP > 0) {
            uint256 reserveLPValue = 10_000e18; // $10k in LP
            
            console.log("\n8. Setting Reserve vault value...");
            ConcreteReserveVault reserve = ConcreteReserveVault(reserveVault);
            reserve.setVaultValue(reserveLPValue);
            console.log("   Vault value set to:", reserveLPValue);
            
            console.log("\n9. Minting initial Reserve shares...");
            IERC20 honeyToken = IERC20(honey);
            if (honeyToken.balanceOf(admin) >= 1000e18) {
                honeyToken.approve(reserveVault, 1000e18);
                reserve.deposit(1000e18, admin);
                console.log("   Minted shares for 1000 HONEY");
            }
        } else {
            console.log("   WARNING: No LP tokens in Reserve hook. Deploy LP first!");
        }
        
        vm.stopBroadcast();
        
        console.log("\n=== BOOTSTRAP COMPLETE ===\n");
    }
}


