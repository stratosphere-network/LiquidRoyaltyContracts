// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {UnifiedConcreteSeniorVault} from "../src/concrete/UnifiedConcreteSeniorVault.sol";
import {ConcreteJuniorVault} from "../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../src/concrete/ConcreteReserveVault.sol";

/**
 * @title CheckRoles
 * @notice Security script to check all role addresses across all vaults
 * @dev Use this to verify roles after a security incident
 * 
 * Usage:
 *   forge script script/CheckRoles.s.sol:CheckRoles --rpc-url $RPC_URL
 */
contract CheckRoles is Script {
    // Production addresses (update these)
    address constant SENIOR_PROXY = 0x49298F4314eb127041b814A2616c25687Db6b650;
    address constant JUNIOR_PROXY = 0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883;
    address constant RESERVE_PROXY = 0x7754272c866892CaD4a414C76f060645bDc27203;
    
    function run() external view {
        console2.log("=================================================");
        console2.log("ROLE SECURITY AUDIT");
        console2.log("=================================================");
        console2.log("");
        
        // Senior Vault
        console2.log("SENIOR VAULT:", SENIOR_PROXY);
        _checkVaultRoles("Senior", SENIOR_PROXY);
        console2.log("");
        
        // Junior Vault
        console2.log("JUNIOR VAULT:", JUNIOR_PROXY);
        _checkVaultRoles("Junior", JUNIOR_PROXY);
        console2.log("");
        
        // Reserve Vault
        console2.log("RESERVE VAULT:", RESERVE_PROXY);
        _checkVaultRoles("Reserve", RESERVE_PROXY);
        console2.log("");
        
        console2.log("=================================================");
        console2.log("AUDIT COMPLETE");
        console2.log("=================================================");
        console2.log("");
        console2.log("⚠️  ACTION REQUIRED:");
        console2.log("1. Verify all addresses are secure");
        console2.log("2. If any role is compromised, change it immediately");
        console2.log("3. Check recent transactions from these addresses");
        console2.log("4. Review upgrade history");
    }
    
    function _checkVaultRoles(string memory vaultName, address vaultAddress) internal view {
        try UnifiedConcreteSeniorVault(payable(vaultAddress)).admin() returns (address admin) {
            console2.log("  Admin:", admin);
            _checkIfZero(admin, "Admin is ZERO - CRITICAL!");
        } catch {
            console2.log("  Admin: [ERROR - not a Senior vault]");
        }
        
        try UnifiedConcreteSeniorVault(payable(vaultAddress)).contractUpdater() returns (address cu) {
            console2.log("  ContractUpdater:", cu);
            _checkIfZero(cu, "ContractUpdater is ZERO - CRITICAL!");
        } catch {
            try ConcreteJuniorVault(vaultAddress).contractUpdater() returns (address cu) {
                console2.log("  ContractUpdater:", cu);
                _checkIfZero(cu, "ContractUpdater is ZERO - CRITICAL!");
            } catch {
                try ConcreteReserveVault(vaultAddress).contractUpdater() returns (address cu) {
                    console2.log("  ContractUpdater:", cu);
                    _checkIfZero(cu, "ContractUpdater is ZERO - CRITICAL!");
                } catch {
                    console2.log("  ContractUpdater: [ERROR]");
                }
            }
        }
        
        try UnifiedConcreteSeniorVault(payable(vaultAddress)).liquidityManager() returns (address lm) {
            console2.log("  LiquidityManager:", lm);
            _checkIfZero(lm, "LiquidityManager is ZERO!");
        } catch {
            try ConcreteJuniorVault(vaultAddress).liquidityManager() returns (address lm) {
                console2.log("  LiquidityManager:", lm);
                _checkIfZero(lm, "LiquidityManager is ZERO!");
            } catch {
                try ConcreteReserveVault(vaultAddress).liquidityManager() returns (address lm) {
                    console2.log("  LiquidityManager:", lm);
                    _checkIfZero(lm, "LiquidityManager is ZERO!");
                } catch {
                    console2.log("  LiquidityManager: [ERROR]");
                }
            }
        }
        
        try UnifiedConcreteSeniorVault(payable(vaultAddress)).priceFeedManager() returns (address pf) {
            console2.log("  PriceFeedManager:", pf);
            _checkIfZero(pf, "PriceFeedManager is ZERO!");
        } catch {
            try ConcreteJuniorVault(vaultAddress).priceFeedManager() returns (address pf) {
                console2.log("  PriceFeedManager:", pf);
                _checkIfZero(pf, "PriceFeedManager is ZERO!");
            } catch {
                try ConcreteReserveVault(vaultAddress).priceFeedManager() returns (address pf) {
                    console2.log("  PriceFeedManager:", pf);
                    _checkIfZero(pf, "PriceFeedManager is ZERO!");
                } catch {
                    console2.log("  PriceFeedManager: [ERROR]");
                }
            }
        }
        
        try UnifiedConcreteSeniorVault(payable(vaultAddress)).deployer() returns (address deployer) {
            console2.log("  Deployer:", deployer);
            console2.log("    ⚠️  This is your compromised key (should be harmless after admin set)");
        } catch {
            try ConcreteJuniorVault(vaultAddress).deployer() returns (address deployer) {
                console2.log("  Deployer:", deployer);
                console2.log("    ⚠️  This is your compromised key (should be harmless after admin set)");
            } catch {
                try ConcreteReserveVault(vaultAddress).deployer() returns (address deployer) {
                    console2.log("  Deployer:", deployer);
                    console2.log("    ⚠️  This is your compromised key (should be harmless after admin set)");
                } catch {
                    console2.log("  Deployer: [ERROR]");
                }
            }
        }
        
        // Check pause status
        try UnifiedConcreteSeniorVault(payable(vaultAddress)).paused() returns (bool paused) {
            if (paused) {
                console2.log("  Status: ⏸️  PAUSED");
            } else {
                console2.log("  Status: ▶️  ACTIVE");
            }
        } catch {
            try ConcreteJuniorVault(vaultAddress).paused() returns (bool paused) {
                if (paused) {
                    console2.log("  Status: ⏸️  PAUSED");
                } else {
                    console2.log("  Status: ▶️  ACTIVE");
                }
            } catch {
                try ConcreteReserveVault(vaultAddress).paused() returns (bool paused) {
                    if (paused) {
                        console2.log("  Status: ⏸️  PAUSED");
                    } else {
                        console2.log("  Status: ▶️  ACTIVE");
                    }
                } catch {
                    console2.log("  Status: [ERROR]");
                }
            }
        }
    }
    
    function _checkIfZero(address addr, string memory warning) internal pure {
        if (addr == address(0)) {
            console2.log("    ⚠️  WARNING:", warning);
        }
    }
}
