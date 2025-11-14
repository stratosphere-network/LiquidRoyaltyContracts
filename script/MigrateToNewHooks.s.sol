// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVault {
    function setKodiakHook(address newHook) external;
    function kodiakHook() external view returns (address);
}

interface IKodiakHook {
    function adminRescueTokens(address token, address to, uint256 amount) external;
    function getIslandLPBalance() external view returns (uint256);
}

contract MigrateToNewHooks is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Vault addresses
        address SENIOR_VAULT = 0x65691bd1972e906459954306aDa0f622a47d4744;
        address JUNIOR_VAULT = 0x3A1b3b300dEE06Caf0b691F1771d1Aa26d70B067;
        address RESERVE_VAULT = 0x2C75291479788C568A6750185CaDedf43aBFC553;
        
        // OLD Hook addresses
        address OLD_SENIOR_HOOK = 0x5256B4628F4A315c35C77A2DfbE968d9b4C4A261;
        address OLD_JUNIOR_HOOK = 0x4c40B07F9589d3D6DD2996113f1317c64dCB7255;
        address OLD_RESERVE_HOOK = 0xFf046FaF98025817348618615a6eDA91B4f28Bb3;
        
        // NEW Hook addresses (from RedeployHooks.s.sol output)
        address NEW_SENIOR_HOOK = vm.envAddress("NEW_SENIOR_HOOK");
        address NEW_JUNIOR_HOOK = vm.envAddress("NEW_JUNIOR_HOOK");
        address NEW_RESERVE_HOOK = vm.envAddress("NEW_RESERVE_HOOK");
        
        // Token addresses
        address HONEY = 0xFCBD14DC51f0A4d49d5E53C2E0950e0bC26d0Dce;
        address WBTC = 0x0555E30da8f98308EdB960aa94C0Db47230d2B9c;
        address KODIAK_ISLAND = 0xf6b16E73d3b0e2784AAe8C4cd06099BE65d092Bf;
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("=================================================");
        console.log("MIGRATING TO NEW HOOKS WITH FIXED LP LIQUIDATION");
        console.log("=================================================");
        console.log("");
        
        // ============================================
        // STEP 1: Transfer LP tokens from old to new
        // ============================================
        console.log("=== STEP 1: TRANSFERRING LP TOKENS ===");
        console.log("");
        
        _transferLPTokens("SENIOR", OLD_SENIOR_HOOK, NEW_SENIOR_HOOK, KODIAK_ISLAND);
        _transferLPTokens("JUNIOR", OLD_JUNIOR_HOOK, NEW_JUNIOR_HOOK, KODIAK_ISLAND);
        _transferLPTokens("RESERVE", OLD_RESERVE_HOOK, NEW_RESERVE_HOOK, KODIAK_ISLAND);
        
        // ============================================
        // STEP 2: Transfer HONEY dust
        // ============================================
        console.log("");
        console.log("=== STEP 2: TRANSFERRING HONEY DUST ===");
        console.log("");
        
        _transferToken("SENIOR", OLD_SENIOR_HOOK, NEW_SENIOR_HOOK, HONEY, "HONEY");
        _transferToken("JUNIOR", OLD_JUNIOR_HOOK, NEW_JUNIOR_HOOK, HONEY, "HONEY");
        _transferToken("RESERVE", OLD_RESERVE_HOOK, NEW_RESERVE_HOOK, HONEY, "HONEY");
        
        // ============================================
        // STEP 3: Transfer WBTC dust
        // ============================================
        console.log("");
        console.log("=== STEP 3: TRANSFERRING WBTC DUST ===");
        console.log("");
        
        _transferToken("SENIOR", OLD_SENIOR_HOOK, NEW_SENIOR_HOOK, WBTC, "WBTC");
        _transferToken("JUNIOR", OLD_JUNIOR_HOOK, NEW_JUNIOR_HOOK, WBTC, "WBTC");
        _transferToken("RESERVE", OLD_RESERVE_HOOK, NEW_RESERVE_HOOK, WBTC, "WBTC");
        
        // ============================================
        // STEP 4: Update vaults to point to new hooks
        // ============================================
        console.log("");
        console.log("=== STEP 4: UPDATING VAULT HOOKS ===");
        console.log("");
        
        _updateVaultHook("SENIOR", SENIOR_VAULT, NEW_SENIOR_HOOK);
        _updateVaultHook("JUNIOR", JUNIOR_VAULT, NEW_JUNIOR_HOOK);
        _updateVaultHook("RESERVE", RESERVE_VAULT, NEW_RESERVE_HOOK);
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("=== MIGRATION COMPLETE! ===");
        console.log("");
        console.log("New Hook Addresses:");
        console.log("  Senior:  ", NEW_SENIOR_HOOK);
        console.log("  Junior:  ", NEW_JUNIOR_HOOK);
        console.log("  Reserve: ", NEW_RESERVE_HOOK);
        console.log("");
        console.log("Changes:");
        console.log("  - LP liquidation now uses Island pool data directly");
        console.log("  - No more vaultValue() dependency");
        console.log("  - 6x more accurate LP burning");
        console.log("  - Withdrawals should work correctly now!");
    }
    
    function _transferLPTokens(
        string memory vaultName,
        address oldHook,
        address newHook,
        address lpToken
    ) internal {
        uint256 lpBalance = IERC20(lpToken).balanceOf(oldHook);
        
        console.log(string.concat(vaultName, " Hook LP balance:"), lpBalance);
        
        if (lpBalance > 0) {
            console.log("  Transferring LP from old to new hook...");
            IKodiakHook(oldHook).adminRescueTokens(lpToken, newHook, 0);
            uint256 newBalance = IERC20(lpToken).balanceOf(newHook);
            console.log("  New hook LP balance:", newBalance);
            require(newBalance == lpBalance, "LP transfer failed");
            console.log("  SUCCESS!");
        } else {
            console.log("  No LP to transfer");
        }
        console.log("");
    }
    
    function _transferToken(
        string memory vaultName,
        address oldHook,
        address newHook,
        address token,
        string memory tokenName
    ) internal {
        uint256 balance = IERC20(token).balanceOf(oldHook);
        
        console.log(string.concat(vaultName, " Hook ", tokenName, " balance:"), balance);
        
        if (balance > 0) {
            console.log("  Transferring ", tokenName, " from old to new hook...");
            IKodiakHook(oldHook).adminRescueTokens(token, newHook, 0);
            uint256 newBalance = IERC20(token).balanceOf(newHook);
            console.log("  New hook ", tokenName, " balance:", newBalance);
            require(newBalance == balance, string.concat(tokenName, " transfer failed"));
            console.log("  SUCCESS!");
        } else {
            console.log("  No ", tokenName, " to transfer");
        }
        console.log("");
    }
    
    function _updateVaultHook(
        string memory vaultName,
        address vault,
        address newHook
    ) internal {
        address oldHook = IVault(vault).kodiakHook();
        
        console.log(string.concat(vaultName, " Vault:"), vault);
        console.log("  Old Hook:", oldHook);
        
        IVault(vault).setKodiakHook(newHook);
        
        address currentHook = IVault(vault).kodiakHook();
        console.log("  New Hook:", currentHook);
        require(currentHook == newHook, "Hook update failed");
        console.log("  SUCCESS!");
        console.log("");
    }
}

