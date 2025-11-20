// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UnifiedConcreteSeniorVault} from "../../src/concrete/UnifiedConcreteSeniorVault.sol";
import {ConcreteJuniorVault} from "../../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../../src/concrete/ConcreteReserveVault.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MockKodiakHook} from "../mocks/MockKodiakHook.sol";

/**
 * @title SeederRoleTest
 * @notice Tests for seeder role functionality across all vaults
 */
contract SeederRoleTest is Test {
    UnifiedConcreteSeniorVault public seniorVault;
    ConcreteJuniorVault public juniorVault;
    ConcreteReserveVault public reserveVault;
    
    MockERC20 public stablecoin;
    MockERC20 public lpToken;
    MockERC20 public wbtc;
    MockKodiakHook public seniorHook;
    MockKodiakHook public juniorHook;
    MockKodiakHook public reserveHook;
    
    address public deployer = address(1);
    address public admin = address(2);
    address public seeder1 = address(3);
    address public seeder2 = address(4);
    address public user = address(5);
    
    function setUp() public {
        vm.startPrank(deployer);
        
        // Deploy mock tokens
        stablecoin = new MockERC20("Stablecoin", "STABLE", 18);
        lpToken = new MockERC20("LP Token", "LP", 18);
        wbtc = new MockERC20("Wrapped BTC", "WBTC", 8);
        
        // Deploy Junior Vault (with placeholder senior)
        ConcreteJuniorVault juniorImpl = new ConcreteJuniorVault();
        bytes memory juniorInitData = abi.encodeWithSignature(
            "initialize(address,address,uint256)",
            address(stablecoin),
            address(0x1), // Placeholder senior
            0
        );
        ERC1967Proxy juniorProxy = new ERC1967Proxy(address(juniorImpl), juniorInitData);
        juniorVault = ConcreteJuniorVault(address(juniorProxy));
        
        // Deploy Reserve Vault (with placeholder senior)
        ConcreteReserveVault reserveImpl = new ConcreteReserveVault();
        bytes memory reserveInitData = abi.encodeWithSignature(
            "initialize(address,address,uint256)",
            address(stablecoin),
            address(0x1), // Placeholder senior
            0
        );
        ERC1967Proxy reserveProxy = new ERC1967Proxy(address(reserveImpl), reserveInitData);
        reserveVault = ConcreteReserveVault(address(reserveProxy));
        
        // Deploy Senior Vault (with actual junior/reserve)
        UnifiedConcreteSeniorVault seniorImpl = new UnifiedConcreteSeniorVault();
        bytes memory seniorInitData = abi.encodeWithSignature(
            "initialize(address,string,string,address,address,address,uint256)",
            address(stablecoin),
            "Senior Tranche",
            "snrUSD",
            address(juniorVault),
            address(reserveVault),
            admin, // Treasury
            0
        );
        ERC1967Proxy seniorProxy = new ERC1967Proxy(address(seniorImpl), seniorInitData);
        seniorVault = UnifiedConcreteSeniorVault(address(seniorProxy));
        
        // Set admin
        seniorVault.setAdmin(admin);
        juniorVault.setAdmin(admin);
        reserveVault.setAdmin(admin);
        
        vm.stopPrank();
        
        // Update junior and reserve with actual senior address
        vm.startPrank(admin);
        juniorVault.setSeniorVault(address(seniorVault));
        reserveVault.setSeniorVault(address(seniorVault));
        vm.stopPrank();
        
        // Deploy hooks for each vault
        seniorHook = new MockKodiakHook(address(seniorVault), address(lpToken), address(lpToken));
        juniorHook = new MockKodiakHook(address(juniorVault), address(lpToken), address(lpToken));
        reserveHook = new MockKodiakHook(address(reserveVault), address(lpToken), address(lpToken));
        
        // Admin sets hooks
        vm.startPrank(admin);
        seniorVault.setKodiakHook(address(seniorHook));
        juniorVault.setKodiakHook(address(juniorHook));
        reserveVault.setKodiakHook(address(reserveHook));
        vm.stopPrank();
        
        // Mint tokens to seeders
        lpToken.mint(seeder1, 1000e18);
        lpToken.mint(seeder2, 1000e18);
        wbtc.mint(seeder1, 10e8); // 10 WBTC
    }
    
    // ============================================
    // Admin Functions Tests
    // ============================================
    
    function testAdminCanAddSeeder() public {
        vm.prank(admin);
        seniorVault.addSeeder(seeder1);
        
        assertTrue(seniorVault.isSeeder(seeder1));
    }
    
    function testAdminCanRevokeSeeder() public {
        vm.startPrank(admin);
        seniorVault.addSeeder(seeder1);
        assertTrue(seniorVault.isSeeder(seeder1));
        
        seniorVault.revokeSeeder(seeder1);
        assertFalse(seniorVault.isSeeder(seeder1));
        vm.stopPrank();
    }
    
    function testAdminCanAddMultipleSeeders() public {
        vm.startPrank(admin);
        seniorVault.addSeeder(seeder1);
        seniorVault.addSeeder(seeder2);
        vm.stopPrank();
        
        assertTrue(seniorVault.isSeeder(seeder1));
        assertTrue(seniorVault.isSeeder(seeder2));
    }
    
    function testCannotAddSeederTwice() public {
        vm.startPrank(admin);
        seniorVault.addSeeder(seeder1);
        
        vm.expectRevert();
        seniorVault.addSeeder(seeder1);
        vm.stopPrank();
    }
    
    function testCannotRevokeNonExistentSeeder() public {
        vm.prank(admin);
        vm.expectRevert();
        seniorVault.revokeSeeder(seeder1);
    }
    
    function testCannotAddZeroAddressAsSeeder() public {
        vm.prank(admin);
        vm.expectRevert();
        seniorVault.addSeeder(address(0));
    }
    
    function testNonAdminCannotAddSeeder() public {
        vm.prank(user);
        vm.expectRevert();
        seniorVault.addSeeder(seeder1);
    }
    
    function testNonAdminCannotRevokeSeeder() public {
        vm.prank(admin);
        seniorVault.addSeeder(seeder1);
        
        vm.prank(user);
        vm.expectRevert();
        seniorVault.revokeSeeder(seeder1);
    }
    
    // ============================================
    // Seeder Functions Tests - Senior Vault
    // ============================================
    
    function testSeederCanSeedSeniorVault() public {
        // Add seeder
        vm.prank(admin);
        seniorVault.addSeeder(seeder1);
        
        // Seeder approves vault
        vm.prank(seeder1);
        lpToken.approve(address(seniorVault), 100e18);
        
        // Seeder seeds vault
        vm.prank(seeder1);
        seniorVault.seedVault(
            address(lpToken),
            100e18,
            seeder1,
            2e18 // $2 per LP token
        );
        
        // Check seeder received shares
        assertGt(seniorVault.balanceOf(seeder1), 0);
    }
    
    function testNonSeederCannotSeedSeniorVault() public {
        vm.prank(user);
        lpToken.approve(address(seniorVault), 100e18);
        
        vm.prank(user);
        vm.expectRevert();
        seniorVault.seedVault(
            address(lpToken),
            100e18,
            user,
            2e18
        );
    }
    
    function testRevokedSeederCannotSeedSeniorVault() public {
        // Add and then revoke seeder
        vm.startPrank(admin);
        seniorVault.addSeeder(seeder1);
        seniorVault.revokeSeeder(seeder1);
        vm.stopPrank();
        
        vm.prank(seeder1);
        lpToken.approve(address(seniorVault), 100e18);
        
        vm.prank(seeder1);
        vm.expectRevert();
        seniorVault.seedVault(
            address(lpToken),
            100e18,
            seeder1,
            2e18
        );
    }
    
    // ============================================
    // Seeder Functions Tests - Junior Vault
    // ============================================
    
    function testSeederCanSeedJuniorVault() public {
        // Add seeder
        vm.prank(admin);
        juniorVault.addSeeder(seeder1);
        
        // Seeder approves vault
        vm.prank(seeder1);
        lpToken.approve(address(juniorVault), 100e18);
        
        // Seeder seeds vault
        vm.prank(seeder1);
        juniorVault.seedVault(
            address(lpToken),
            100e18,
            seeder1,
            2e18
        );
        
        // Check seeder received shares
        assertGt(juniorVault.balanceOf(seeder1), 0);
    }
    
    function testNonSeederCannotSeedJuniorVault() public {
        vm.prank(user);
        lpToken.approve(address(juniorVault), 100e18);
        
        vm.prank(user);
        vm.expectRevert();
        juniorVault.seedVault(
            address(lpToken),
            100e18,
            user,
            2e18
        );
    }
    
    // ============================================
    // Seeder Functions Tests - Reserve Vault
    // ============================================
    
    function testSeederCanSeedReserveVault() public {
        // Add seeder
        vm.prank(admin);
        reserveVault.addSeeder(seeder1);
        
        // Seeder approves vault
        vm.prank(seeder1);
        lpToken.approve(address(reserveVault), 100e18);
        
        // Seeder seeds vault
        vm.prank(seeder1);
        reserveVault.seedVault(
            address(lpToken),
            100e18,
            seeder1,
            2e18
        );
        
        // Check seeder received shares
        assertGt(reserveVault.balanceOf(seeder1), 0);
    }
    
    function testSeederCanSeedReserveWithWBTC() public {
        // Add seeder
        vm.prank(admin);
        reserveVault.addSeeder(seeder1);
        
        // Seeder approves vault
        vm.prank(seeder1);
        wbtc.approve(address(reserveVault), 1e8); // 1 WBTC
        
        // Seeder seeds reserve with WBTC
        vm.prank(seeder1);
        reserveVault.seedReserveWithToken(
            address(wbtc),
            1e8, // 1 WBTC
            seeder1,
            50000e18 // $50,000 per WBTC
        );
        
        // Check seeder received shares
        assertGt(reserveVault.balanceOf(seeder1), 0);
        
        // Check WBTC is in reserve vault
        assertEq(wbtc.balanceOf(address(reserveVault)), 1e8);
    }
    
    function testNonSeederCannotSeedReserveVault() public {
        vm.prank(user);
        lpToken.approve(address(reserveVault), 100e18);
        
        vm.prank(user);
        vm.expectRevert();
        reserveVault.seedVault(
            address(lpToken),
            100e18,
            user,
            2e18
        );
    }
    
    function testNonSeederCannotSeedReserveWithToken() public {
        vm.prank(user);
        wbtc.approve(address(reserveVault), 1e8);
        
        vm.prank(user);
        vm.expectRevert();
        reserveVault.seedReserveWithToken(
            address(wbtc),
            1e8,
            user,
            50000e18
        );
    }
    
    // ============================================
    // Multi-Vault Tests
    // ============================================
    
    function testSeederCanSeedAllVaults() public {
        // Add seeder to all vaults
        vm.startPrank(admin);
        seniorVault.addSeeder(seeder1);
        juniorVault.addSeeder(seeder1);
        reserveVault.addSeeder(seeder1);
        vm.stopPrank();
        
        // Approve all vaults
        vm.startPrank(seeder1);
        lpToken.approve(address(seniorVault), 100e18);
        lpToken.approve(address(juniorVault), 100e18);
        lpToken.approve(address(reserveVault), 100e18);
        
        // Seed all vaults
        seniorVault.seedVault(address(lpToken), 100e18, seeder1, 2e18);
        juniorVault.seedVault(address(lpToken), 100e18, seeder1, 2e18);
        reserveVault.seedVault(address(lpToken), 100e18, seeder1, 2e18);
        vm.stopPrank();
        
        // Check all vaults have shares for seeder
        assertGt(seniorVault.balanceOf(seeder1), 0);
        assertGt(juniorVault.balanceOf(seeder1), 0);
        assertGt(reserveVault.balanceOf(seeder1), 0);
    }
    
    function testDifferentSeedersCanSeedDifferentVaults() public {
        // Add seeder1 to senior, seeder2 to junior
        vm.startPrank(admin);
        seniorVault.addSeeder(seeder1);
        juniorVault.addSeeder(seeder2);
        vm.stopPrank();
        
        // Seeder1 seeds senior
        vm.startPrank(seeder1);
        lpToken.approve(address(seniorVault), 100e18);
        seniorVault.seedVault(address(lpToken), 100e18, seeder1, 2e18);
        vm.stopPrank();
        
        // Seeder2 seeds junior
        vm.startPrank(seeder2);
        lpToken.approve(address(juniorVault), 100e18);
        juniorVault.seedVault(address(lpToken), 100e18, seeder2, 2e18);
        vm.stopPrank();
        
        // Check correct seeders have shares
        assertGt(seniorVault.balanceOf(seeder1), 0);
        assertEq(seniorVault.balanceOf(seeder2), 0);
        assertEq(juniorVault.balanceOf(seeder1), 0);
        assertGt(juniorVault.balanceOf(seeder2), 0);
    }
    
    // ============================================
    // View Functions Tests
    // ============================================
    
    function testIsSeederReturnsFalseForNonSeeder() public {
        assertFalse(seniorVault.isSeeder(user));
    }
    
    function testIsSeederReturnsTrueForSeeder() public {
        vm.prank(admin);
        seniorVault.addSeeder(seeder1);
        
        assertTrue(seniorVault.isSeeder(seeder1));
    }
}

