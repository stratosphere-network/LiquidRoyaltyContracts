// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/concrete/UnifiedConcreteSeniorVault.sol";
import "../src/concrete/ConcreteJuniorVault.sol";
import "../src/concrete/ConcreteReserveVault.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

interface IProxy {
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
}

/**
 * @title UpgradeVaultsWithLiquidity
 * @notice Deploy new implementations with automatic liquidity withdrawal and upgrade proxies
 * @dev This upgrade adds automatic LP liquidation during user withdrawals
 * 
 * New Features:
 * - Automatic liquidity withdrawal from Kodiak LP when vault balance is insufficient
 * - Proper error handling with InsufficientLiquidity error
 * - LiquidityFreedForWithdrawal event for tracking
 * - Works for all three vaults (Senior, Junior, Reserve)
 * 
 * Usage:
 *   source .env
 *   forge script script/UpgradeVaultsWithLiquidity.s.sol:UpgradeVaultsWithLiquidity \
 *     --rpc-url $RPC_URL \
 *     --private-key $PRIVATE_KEY \
 *     --broadcast \
 *     --verify \
 *     --etherscan-api-key $ETHERSCAN_API_KEY
 */
contract UpgradeVaultsWithLiquidity is Script {
    // Deployed proxy addresses (from previous deployment)
    address constant SENIOR_PROXY = 0x65691bd1972e906459954306aDa0f622a47d4744;
    address constant JUNIOR_PROXY = 0x3A1b3b300dEE06Caf0b691F1771d1Aa26d70B067;
    address constant RESERVE_PROXY = 0x2C75291479788C568A6750185CaDedf43aBFC553;
    
    // New implementation addresses (will be deployed)
    address public newSeniorImpl;
    address public newJuniorImpl;
    address public newReserveImpl;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("==============================================");
        console.log("Upgrading Vaults with Automatic Liquidity Withdrawal");
        console.log("==============================================");
        console.log("Deployer:", deployer);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Deploy new implementations
        console.log("Step 1: Deploying new implementations...");
        newSeniorImpl = address(new UnifiedConcreteSeniorVault());
        console.log("  Senior Implementation:", newSeniorImpl);
        
        newJuniorImpl = address(new ConcreteJuniorVault());
        console.log("  Junior Implementation:", newJuniorImpl);
        
        newReserveImpl = address(new ConcreteReserveVault());
        console.log("  Reserve Implementation:", newReserveImpl);
        console.log("");
        
        // Step 2: Upgrade proxies
        console.log("Step 2: Upgrading proxies...");
        
        // Upgrade Senior Vault
        console.log("  Upgrading Senior Vault proxy...");
        IProxy(SENIOR_PROXY).upgradeToAndCall(newSeniorImpl, "");
        console.log("    [OK] Senior Vault upgraded to:", newSeniorImpl);
        
        // Upgrade Junior Vault
        console.log("  Upgrading Junior Vault proxy...");
        IProxy(JUNIOR_PROXY).upgradeToAndCall(newJuniorImpl, "");
        console.log("    [OK] Junior Vault upgraded to:", newJuniorImpl);
        
        // Upgrade Reserve Vault
        console.log("  Upgrading Reserve Vault proxy...");
        IProxy(RESERVE_PROXY).upgradeToAndCall(newReserveImpl, "");
        console.log("    [OK] Reserve Vault upgraded to:", newReserveImpl);
        console.log("");
        
        vm.stopBroadcast();
        
        // Step 3: Verification
        console.log("==============================================");
        console.log("Upgrade Summary");
        console.log("==============================================");
        console.log("New Implementations:");
        console.log("  Senior:", newSeniorImpl);
        console.log("  Junior:", newJuniorImpl);
        console.log("  Reserve:", newReserveImpl);
        console.log("");
        console.log("Proxies Upgraded:");
        console.log("  Senior Proxy:", SENIOR_PROXY);
        console.log("  Junior Proxy:", JUNIOR_PROXY);
        console.log("  Reserve Proxy:", RESERVE_PROXY);
        console.log("");
        console.log("[SUCCESS] All vaults upgraded successfully!");
        console.log("");
        console.log("New Features:");
        console.log("  - Automatic LP liquidity withdrawal during user withdrawals");
        console.log("  - Better error handling with InsufficientLiquidity error");
        console.log("  - LiquidityFreedForWithdrawal event tracking");
        console.log("==============================================");
    }
}

