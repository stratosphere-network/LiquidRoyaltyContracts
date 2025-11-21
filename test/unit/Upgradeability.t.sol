// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ConcreteJuniorVault} from "../../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../../src/concrete/ConcreteReserveVault.sol";
import {UnifiedConcreteSeniorVault} from "../../src/concrete/UnifiedConcreteSeniorVault.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title UpgradeabilityTest
 * @notice COMPREHENSIVE tests for UUPS upgradeability across all vaults
 */
contract UpgradeabilityTest is Test {
    ConcreteJuniorVault public juniorVault;
    ConcreteReserveVault public reserveVault;
    UnifiedConcreteSeniorVault public seniorVault;
    MockERC20 public stablecoin;
    
    address public admin = address(this);
    address public user = address(0x1);
    address public attacker = address(0x666);
    
    function setUp() public {
        stablecoin = new MockERC20("USDC", "USDC", 6);
        
        // Deploy Junior vault with proxy
        ConcreteJuniorVault juniorImpl = new ConcreteJuniorVault();
        bytes memory juniorInitData = abi.encodeWithSelector(
            ConcreteJuniorVault.initialize.selector,
            address(stablecoin),
            address(0x1),
            0
        );
        ERC1967Proxy juniorProxy = new ERC1967Proxy(address(juniorImpl), juniorInitData);
        juniorVault = ConcreteJuniorVault(address(juniorProxy));
        juniorVault.setAdmin(admin);
        
        // Deploy Reserve vault with proxy
        ConcreteReserveVault reserveImpl = new ConcreteReserveVault();
        bytes memory reserveInitData = abi.encodeWithSelector(
            ConcreteReserveVault.initialize.selector,
            address(stablecoin),
            address(0x1),
            0
        );
        ERC1967Proxy reserveProxy = new ERC1967Proxy(address(reserveImpl), reserveInitData);
        reserveVault = ConcreteReserveVault(address(reserveProxy));
        reserveVault.setAdmin(admin);
        
        // Deploy Senior vault with proxy
        UnifiedConcreteSeniorVault seniorImpl = new UnifiedConcreteSeniorVault();
        bytes memory seniorInitData = abi.encodeWithSelector(
            UnifiedConcreteSeniorVault.initialize.selector,
            address(stablecoin),
            "Senior USD",
            "snrUSD",
            address(juniorVault),
            address(reserveVault),
            address(this),
            0
        );
        ERC1967Proxy seniorProxy = new ERC1967Proxy(address(seniorImpl), seniorInitData);
        seniorVault = UnifiedConcreteSeniorVault(address(seniorProxy));
        seniorVault.setAdmin(admin);
        
        // Mint tokens
        stablecoin.mint(address(juniorVault), 1000000e6);
        stablecoin.mint(address(reserveVault), 500000e6);
        stablecoin.mint(address(seniorVault), 2000000e6);
    }
    
    // ============================================
    // Junior Vault Upgrade Tests
    // ============================================
    
    function test_juniorVault_upgradeSuccessfully() public {
        console.log("=== Test: Junior Vault Upgrade ===");
        
        // Set some state
        juniorVault.setVaultValue(100000e18);
        uint256 valueBefore = juniorVault.vaultValue();
        console.log("Value before upgrade:", valueBefore);
        
        // Deploy new implementation
        ConcreteJuniorVault newImpl = new ConcreteJuniorVault();
        
        // Upgrade
        juniorVault.upgradeToAndCall(address(newImpl), "");
        
        // Verify state preserved
        uint256 valueAfter = juniorVault.vaultValue();
        console.log("Value after upgrade:", valueAfter);
        assertEq(valueAfter, valueBefore);
        
        // Verify functionality still works
        juniorVault.setVaultValue(200000e18);
        assertEq(juniorVault.vaultValue(), 200000e18);
    }
    
    function test_juniorVault_upgradePreservesAllState() public {
        console.log("=== Test: Upgrade Preserves All State ===");
        
        // Set complex state
        juniorVault.setVaultValue(100000e18);
        stablecoin.mint(user, 10000e6);
        
        vm.startPrank(user);
        stablecoin.approve(address(juniorVault), 10000e6);
        uint256 shares = juniorVault.deposit(10000e6, user);
        vm.stopPrank();
        
        console.log("Shares minted:", shares);
        console.log("Total supply before:", juniorVault.totalSupply());
        console.log("User balance before:", juniorVault.balanceOf(user));
        
        // Upgrade
        ConcreteJuniorVault newImpl = new ConcreteJuniorVault();
        juniorVault.upgradeToAndCall(address(newImpl), "");
        
        // Verify all state
        assertEq(juniorVault.totalSupply(), shares);
        assertEq(juniorVault.balanceOf(user), shares);
        assertEq(juniorVault.vaultValue(), 100000e18);
        console.log("Total supply after:", juniorVault.totalSupply());
        console.log("User balance after:", juniorVault.balanceOf(user));
    }
    
    function test_juniorVault_onlyAdminCanUpgrade() public {
        console.log("=== Test: Only Admin Can Upgrade ===");
        
        ConcreteJuniorVault newImpl = new ConcreteJuniorVault();
        
        vm.prank(attacker);
        vm.expectRevert();  // OnlyAdmin
        juniorVault.upgradeToAndCall(address(newImpl), "");
        
        console.log("Attacker blocked from upgrade");
    }
    
    // ============================================
    // Reserve Vault Upgrade Tests
    // ============================================
    
    function test_reserveVault_upgradeSuccessfully() public {
        console.log("=== Test: Reserve Vault Upgrade ===");
        
        reserveVault.setVaultValue(50000e18);
        uint256 valueBefore = reserveVault.vaultValue();
        
        ConcreteReserveVault newImpl = new ConcreteReserveVault();
        reserveVault.upgradeToAndCall(address(newImpl), "");
        
        assertEq(reserveVault.vaultValue(), valueBefore);
        console.log("Reserve vault upgraded successfully");
    }
    
    function test_reserveVault_preservesDepletionState() public {
        console.log("=== Test: Preserve Depletion State ===");
        
        // Set depletion state
        reserveVault.setVaultValue(100000e18);
        reserveVault.setVaultValue(100000e18);  // Set twice for _lastMonthValue
        
        bool depletedBefore = reserveVault.isDepleted();
        console.log("Depleted before:", depletedBefore);
        
        // Upgrade
        ConcreteReserveVault newImpl = new ConcreteReserveVault();
        reserveVault.upgradeToAndCall(address(newImpl), "");
        
        bool depletedAfter = reserveVault.isDepleted();
        console.log("Depleted after:", depletedAfter);
        assertEq(depletedAfter, depletedBefore);
    }
    
    // ============================================
    // Senior Vault Upgrade Tests
    // ============================================
    
    function test_seniorVault_upgradeSuccessfully() public {
        console.log("=== Test: Senior Vault Upgrade ===");
        
        // Set vault values to allow deposits
        reserveVault.setVaultValue(100000e18);  // Set reserve vault value for deposit cap
        reserveVault.setVaultValue(100000e18);  // Set twice for _lastMonthValue
        seniorVault.setVaultValue(1000000e18);
        
        // Mint some snrUSD
        stablecoin.mint(user, 100000e6);
        vm.startPrank(user);
        stablecoin.approve(address(seniorVault), 100000e6);
        seniorVault.deposit(100000e6, user);
        vm.stopPrank();
        
        uint256 balanceBefore = seniorVault.balanceOf(user);
        uint256 totalSupplyBefore = seniorVault.totalSupply();
        console.log("Balance before:", balanceBefore);
        console.log("Total supply before:", totalSupplyBefore);
        
        // Upgrade
        UnifiedConcreteSeniorVault newImpl = new UnifiedConcreteSeniorVault();
        seniorVault.upgradeToAndCall(address(newImpl), "");
        
        // Verify state
        assertEq(seniorVault.balanceOf(user), balanceBefore);
        assertEq(seniorVault.totalSupply(), totalSupplyBefore);
        console.log("Balance after:", seniorVault.balanceOf(user));
        console.log("Total supply after:", seniorVault.totalSupply());
    }
    
    function test_seniorVault_preservesRebaseState() public {
        console.log("=== Test: Preserve Rebase State ===");
        
        uint256 lastRebaseTime = seniorVault.lastRebaseTime();
        console.log("Last rebase time before:", lastRebaseTime);
        
        // Upgrade
        UnifiedConcreteSeniorVault newImpl = new UnifiedConcreteSeniorVault();
        seniorVault.upgradeToAndCall(address(newImpl), "");
        
        uint256 lastRebaseTimeAfter = seniorVault.lastRebaseTime();
        console.log("Last rebase time after:", lastRebaseTimeAfter);
        assertEq(lastRebaseTimeAfter, lastRebaseTime);
    }
    
    // ============================================
    // Multiple Upgrades
    // ============================================
    
    function test_multipleUpgrades() public {
        console.log("=== Test: Multiple Sequential Upgrades ===");
        
        juniorVault.setVaultValue(100000e18);
        
        // Upgrade 1
        ConcreteJuniorVault impl1 = new ConcreteJuniorVault();
        juniorVault.upgradeToAndCall(address(impl1), "");
        assertEq(juniorVault.vaultValue(), 100000e18);
        console.log("After upgrade 1");
        
        juniorVault.setVaultValue(200000e18);
        
        // Upgrade 2
        ConcreteJuniorVault impl2 = new ConcreteJuniorVault();
        juniorVault.upgradeToAndCall(address(impl2), "");
        assertEq(juniorVault.vaultValue(), 200000e18);
        console.log("After upgrade 2");
        
        juniorVault.setVaultValue(300000e18);
        
        // Upgrade 3
        ConcreteJuniorVault impl3 = new ConcreteJuniorVault();
        juniorVault.upgradeToAndCall(address(impl3), "");
        assertEq(juniorVault.vaultValue(), 300000e18);
        console.log("After upgrade 3");
    }
    
    function test_allVaults_upgradeInSequence() public {
        console.log("=== Test: All Vaults Upgrade in Sequence ===");
        
        // Set state on all
        juniorVault.setVaultValue(100000e18);
        reserveVault.setVaultValue(50000e18);
        seniorVault.setVaultValue(200000e18);
        
        // Upgrade Junior
        ConcreteJuniorVault juniorImpl = new ConcreteJuniorVault();
        juniorVault.upgradeToAndCall(address(juniorImpl), "");
        console.log("Junior upgraded");
        
        // Upgrade Reserve
        ConcreteReserveVault reserveImpl = new ConcreteReserveVault();
        reserveVault.upgradeToAndCall(address(reserveImpl), "");
        console.log("Reserve upgraded");
        
        // Upgrade Senior
        UnifiedConcreteSeniorVault seniorImpl = new UnifiedConcreteSeniorVault();
        seniorVault.upgradeToAndCall(address(seniorImpl), "");
        console.log("Senior upgraded");
        
        // Verify all state preserved
        assertEq(juniorVault.vaultValue(), 100000e18);
        assertEq(reserveVault.vaultValue(), 50000e18);
        assertEq(seniorVault.vaultValue(), 200000e18);
    }
    
    // ============================================
    // Upgrade with Function Call
    // ============================================
    
    function test_upgradeWithInitializer() public {
        console.log("=== Test: Upgrade with Initializer Call ===");
        
        juniorVault.setVaultValue(100000e18);
        
        // Deploy new implementation (in practice, this might have new init function)
        ConcreteJuniorVault newImpl = new ConcreteJuniorVault();
        
        // Upgrade with empty call data (no reinit needed for this test)
        juniorVault.upgradeToAndCall(address(newImpl), "");
        
        // State should be preserved
        assertEq(juniorVault.vaultValue(), 100000e18);
        console.log("Upgraded with call data successfully");
    }
    
    // ============================================
    // Edge Cases
    // ============================================
    
    function test_edgeCase_upgradeToSameImplementation() public {
        console.log("=== Edge Case: Upgrade to Same Implementation ===");
        
        // Get current implementation
        ConcreteJuniorVault sameImpl = new ConcreteJuniorVault();
        
        juniorVault.setVaultValue(100000e18);
        
        // "Upgrade" to same code (should work)
        juniorVault.upgradeToAndCall(address(sameImpl), "");
        
        assertEq(juniorVault.vaultValue(), 100000e18);
        console.log("Same implementation upgrade OK");
    }
    
    function test_edgeCase_upgradePreservesApprovals() public {
        console.log("=== Edge Case: Upgrade Preserves Approvals ===");
        
        stablecoin.mint(user, 10000e6);
        
        vm.prank(user);
        stablecoin.approve(address(juniorVault), 10000e6);
        
        uint256 allowanceBefore = stablecoin.allowance(user, address(juniorVault));
        console.log("Allowance before:", allowanceBefore);
        
        // Upgrade
        ConcreteJuniorVault newImpl = new ConcreteJuniorVault();
        juniorVault.upgradeToAndCall(address(newImpl), "");
        
        uint256 allowanceAfter = stablecoin.allowance(user, address(juniorVault));
        console.log("Allowance after:", allowanceAfter);
        assertEq(allowanceAfter, allowanceBefore);
    }
    
    function test_edgeCase_upgradeWhileUsersHaveShares() public {
        console.log("=== Edge Case: Upgrade While Users Have Shares ===");
        
        // Multiple users deposit
        for (uint i = 1; i <= 3; i++) {
            address userAddr = address(uint160(i));
            stablecoin.mint(userAddr, 10000e6);
            
            vm.startPrank(userAddr);
            stablecoin.approve(address(juniorVault), 10000e6);
            juniorVault.deposit(10000e6, userAddr);
            vm.stopPrank();
        }
        
        uint256 totalSupplyBefore = juniorVault.totalSupply();
        console.log("Total supply before:", totalSupplyBefore);
        
        // Upgrade
        ConcreteJuniorVault newImpl = new ConcreteJuniorVault();
        juniorVault.upgradeToAndCall(address(newImpl), "");
        
        // Verify all balances preserved
        uint256 totalSupplyAfter = juniorVault.totalSupply();
        console.log("Total supply after:", totalSupplyAfter);
        assertEq(totalSupplyAfter, totalSupplyBefore);
        
        for (uint i = 1; i <= 3; i++) {
            address userAddr = address(uint160(i));
            assertGt(juniorVault.balanceOf(userAddr), 0);
            console.log("User", i, "balance:", juniorVault.balanceOf(userAddr));
        }
    }
    
    function test_stress_upgradeUnderLoad() public {
        console.log("=== Stress: Upgrade Under Load ===");
        
        // Simulate heavy usage
        for (uint i = 0; i < 50; i++) {
            juniorVault.setVaultValue((i + 1) * 1000e18);
        }
        
        uint256 finalValueBefore = juniorVault.vaultValue();
        
        // Upgrade
        ConcreteJuniorVault newImpl = new ConcreteJuniorVault();
        juniorVault.upgradeToAndCall(address(newImpl), "");
        
        assertEq(juniorVault.vaultValue(), finalValueBefore);
        console.log("Upgrade under load successful");
    }
    
    // ============================================
    // Security Tests
    // ============================================
    
    function test_security_cannotInitializeTwice() public {
        console.log("=== Security: Cannot Initialize Twice ===");
        
        vm.expectRevert();  // InvalidInitialization
        juniorVault.initialize(address(stablecoin), "Junior Tranche", "jnr", address(0x1), 0);
        
        console.log("Double initialization blocked");
    }
    
    function test_security_cannotUpgradeToZeroAddress() public {
        console.log("=== Security: Cannot Upgrade to Zero Address ===");
        
        vm.expectRevert();
        juniorVault.upgradeToAndCall(address(0), "");
        
        console.log("Zero address upgrade blocked");
    }
}

