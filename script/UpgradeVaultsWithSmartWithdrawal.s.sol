// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../src/concrete/UnifiedConcreteSeniorVault.sol";
import "../src/concrete/ConcreteJuniorVault.sol";
import "../src/concrete/ConcreteReserveVault.sol";

interface IProxy {
    function upgradeToAndCall(address newImplementation, bytes memory data) external;
}

contract UpgradeVaultsWithSmartWithdrawal is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Proxy addresses
        address SENIOR_PROXY = 0x65691bd1972e906459954306aDa0f622a47d4744;
        address JUNIOR_PROXY = 0x3A1b3b300dEE06Caf0b691F1771d1Aa26d70B067;
        address RESERVE_PROXY = 0x2C75291479788C568A6750185CaDedf43aBFC553;
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("=== DEPLOYING NEW VAULT IMPLEMENTATIONS ===");
        console.log("With iterative withdrawal logic (max 3 attempts)");
        console.log("");
        
        // Deploy new implementations
        console.log("Deploying new implementations...");
        
        UnifiedConcreteSeniorVault newSeniorImpl = new UnifiedConcreteSeniorVault();
        console.log("New Senior Implementation:", address(newSeniorImpl));
        
        ConcreteJuniorVault newJuniorImpl = new ConcreteJuniorVault();
        console.log("New Junior Implementation:", address(newJuniorImpl));
        
        ConcreteReserveVault newReserveImpl = new ConcreteReserveVault();
        console.log("New Reserve Implementation:", address(newReserveImpl));
        console.log("");
        
        // Upgrade proxies
        console.log("=== UPGRADING PROXIES ===");
        
        console.log("Upgrading Senior Vault...");
        IProxy(SENIOR_PROXY).upgradeToAndCall(address(newSeniorImpl), "");
        console.log("  Upgraded to:", address(newSeniorImpl));
        console.log("");
        
        console.log("Upgrading Junior Vault...");
        IProxy(JUNIOR_PROXY).upgradeToAndCall(address(newJuniorImpl), "");
        console.log("  Upgraded to:", address(newJuniorImpl));
        console.log("");
        
        console.log("Upgrading Reserve Vault...");
        IProxy(RESERVE_PROXY).upgradeToAndCall(address(newReserveImpl), "");
        console.log("  Upgraded to:", address(newReserveImpl));
        console.log("");
        
        vm.stopBroadcast();
        
        console.log("=== UPGRADE COMPLETE ===");
        console.log("");
        console.log("New Features:");
        console.log("  - Iterative withdrawal (max 3 attempts)");
        console.log("  - Calls hook.liquidateLPForAmount() with smart estimation");
        console.log("  - Better error handling and event emission");
        console.log("");
        console.log("All vaults now have complete smart withdrawal system!");
    }
}

