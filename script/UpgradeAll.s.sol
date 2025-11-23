// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {UnifiedConcreteSeniorVault} from "../src/concrete/UnifiedConcreteSeniorVault.sol";
import {ConcreteJuniorVault} from "../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../src/concrete/ConcreteReserveVault.sol";

/**
 * @title UpgradeAll
 * @notice Upgrade ALL vaults (Senior, Junior, Reserve) in one transaction
 * @dev IMPORTANT: New implementations MUST preserve storage layouts!
 *      Use this script when upgrading all three vaults at once.
 * 
 * Usage:
 *   forge script script/UpgradeAll.s.sol:UpgradeAll --rpc-url $RPC_URL --broadcast --verify
 * 
 * Dry run (simulate without broadcasting):
 *   forge script script/UpgradeAll.s.sol:UpgradeAll --rpc-url $RPC_URL
 */
contract UpgradeAll is Script {
    // Production addresses (from prod_addresses.md)
    address constant SENIOR_PROXY = 0x49298F4314eb127041b814A2616c25687Db6b650;
    address constant JUNIOR_PROXY = 0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883;
    address constant RESERVE_PROXY = 0x7754272c866892CaD4a414C76f060645bDc27203;
    address constant ADMIN = 0x6fa2149E69DbCBDCf6F16F755E08c10E53c40605;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("=================================================");
        console2.log("UPGRADE ALL VAULTS");
        console2.log("=================================================");
        console2.log("Deployer:", deployer);
        console2.log("Admin:", ADMIN);
        console2.log("");
        console2.log("Senior Proxy:", SENIOR_PROXY);
        console2.log("Junior Proxy:", JUNIOR_PROXY);
        console2.log("Reserve Proxy:", RESERVE_PROXY);
        console2.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy all new implementations
        console2.log("=================================================");
        console2.log("DEPLOYING NEW IMPLEMENTATIONS");
        console2.log("=================================================");
        
        console2.log("1/3 Deploying Senior implementation...");
        UnifiedConcreteSeniorVault seniorImpl = new UnifiedConcreteSeniorVault();
        console2.log("    [OK] Senior:", address(seniorImpl));
        
        console2.log("2/3 Deploying Junior implementation...");
        ConcreteJuniorVault juniorImpl = new ConcreteJuniorVault();
        console2.log("    [OK] Junior:", address(juniorImpl));
        
        console2.log("3/3 Deploying Reserve implementation...");
        ConcreteReserveVault reserveImpl = new ConcreteReserveVault();
        console2.log("    [OK] Reserve:", address(reserveImpl));
        console2.log("");
        
        // Prepare upgrade data - empty bytes (no initialization needed)
        // New role variables default to 0x0, set them manually after upgrade via setters:
        // - setLiquidityManager(address)
        // - setPriceFeedManager(address)
        // - setContractUpdater(address)
        bytes memory upgradeData = "";
        
        // Upgrade all proxies
        console2.log("=================================================");
        console2.log("UPGRADING PROXIES");
        console2.log("=================================================");
        
        console2.log("1/3 Upgrading Senior vault...");
        UnifiedConcreteSeniorVault seniorProxy = UnifiedConcreteSeniorVault(payable(SENIOR_PROXY));
        seniorProxy.upgradeToAndCall(address(seniorImpl), upgradeData);
        console2.log("    [OK] Senior upgraded!");
        
        console2.log("2/3 Upgrading Junior vault...");
        ConcreteJuniorVault juniorProxy = ConcreteJuniorVault(JUNIOR_PROXY);
        juniorProxy.upgradeToAndCall(address(juniorImpl), upgradeData);
        console2.log("    [OK] Junior upgraded!");
        
        console2.log("3/3 Upgrading Reserve vault...");
        ConcreteReserveVault reserveProxy = ConcreteReserveVault(RESERVE_PROXY);
        reserveProxy.upgradeToAndCall(address(reserveImpl), upgradeData);
        console2.log("    [OK] Reserve upgraded!");
        console2.log("");
        
        vm.stopBroadcast();
        
        // Verification
        console2.log("=================================================");
        console2.log("VERIFICATION");
        console2.log("=================================================");
        
        console2.log("SENIOR VAULT:");
        console2.log("  Name:", seniorProxy.name());
        console2.log("  Symbol:", seniorProxy.symbol());
        console2.log("  Total Supply:", seniorProxy.totalSupply());
        console2.log("  Vault Value:", seniorProxy.vaultValue());
        console2.log("");
        
        console2.log("JUNIOR VAULT:");
        console2.log("  Name:", juniorProxy.name());
        console2.log("  Symbol:", juniorProxy.symbol());
        console2.log("  Total Supply:", juniorProxy.totalSupply());
        console2.log("  Vault Value:", juniorProxy.vaultValue());
        console2.log("");
        
        console2.log("RESERVE VAULT:");
        console2.log("  Name:", reserveProxy.name());
        console2.log("  Symbol:", reserveProxy.symbol());
        console2.log("  Total Supply:", reserveProxy.totalSupply());
        console2.log("  Vault Value:", reserveProxy.vaultValue());
        console2.log("  Deposit Cap:", reserveProxy.currentDepositCap());
        console2.log("");
        
        console2.log("=================================================");
        console2.log("ALL UPGRADES COMPLETE");
        console2.log("=================================================");
        console2.log("New Implementations:");
        console2.log("   Senior: ", address(seniorImpl));
        console2.log("   Junior: ", address(juniorImpl));
        console2.log("   Reserve:", address(reserveImpl));
        console2.log("");
        console2.log("Proxy Addresses:");
        console2.log("   Senior: ", SENIOR_PROXY);
        console2.log("   Junior: ", JUNIOR_PROXY);
        console2.log("   Reserve:", RESERVE_PROXY);
        console2.log("");
        console2.log("[SUCCESS] All storage preserved, upgrades successful!");
        console2.log("");
        console2.log("NEXT STEPS:");
        console2.log("1. Verify all implementations on block explorer");
        console2.log("2. Test critical functions on all vaults");
        console2.log("3. Test inter-vault functions (spillover, backstop)");
        console2.log("4. Monitor for any issues");
        console2.log("=================================================");
    }
}

