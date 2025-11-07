// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ConcreteReserveVault} from "../../../src/concrete/ConcreteReserveVault.sol";
import {MockERC20} from "../../../src/mocks/MockERC20.sol";
import {MathLib} from "../../../src/libraries/MathLib.sol";

contract ConcreteReserveVaultTest is Test {
    ConcreteReserveVault public vault;
    MockERC20 public lpToken;
    
    address public seniorVault;
    address public user1;
    address public user2;
    address public keeper;
    
    uint256 constant INITIAL_VALUE = 1000e18;
    
    function setUp() public {
        seniorVault = makeAddr("seniorVault");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        keeper = makeAddr("keeper");
        
        lpToken = new MockERC20("USDe-SAIL", "USDe-SAIL", 18);
        
        // Deploy upgradeable Reserve vault using proxy
        ConcreteReserveVault implementation = new ConcreteReserveVault();
        bytes memory initData = abi.encodeWithSelector(
            ConcreteReserveVault.initialize.selector,
            address(lpToken),
            seniorVault,
            INITIAL_VALUE
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        vault = ConcreteReserveVault(address(proxy));
        
        // Mint stablecoins
        lpToken.mint(user1, 10000e18);
        lpToken.mint(user2, 10000e18);
        // Don't pre-mint to vault - ERC4626 handles first deposit correctly
        
        // Add keeper
        vault.setAdmin(keeper);
    }
    
    // ============================================
    // Deployment Tests
    // ============================================
    
    function testDeployment() public view {
        assertEq(vault.name(), "Reserve Tranche Shares");
        assertEq(vault.symbol(), "rTRN");
        assertEq(vault.seniorVault(), seniorVault);
        assertEq(vault.vaultValue(), INITIAL_VALUE);
        assertEq(vault.totalSpilloverReceived(), 0);
        assertEq(vault.totalBackstopProvided(), 0);
        assertFalse(vault.isDepleted());
    }
    
    // ============================================
    // ERC4626 Tests
    // ============================================
    
    function testDeposit() public {
        uint256 assets = 100e18;
        
        vm.startPrank(user1);
        lpToken.approve(address(vault), assets);
        uint256 shares = vault.deposit(assets, user1);
        vm.stopPrank();
        
        assertEq(vault.balanceOf(user1), shares);
        assertGt(shares, 0);
    }
    
    function testWithdraw() public {
        vm.startPrank(user1);
        lpToken.approve(address(vault), 100e18);
        uint256 shares = vault.deposit(100e18, user1);
        
        uint256 assets = vault.redeem(shares, user1, user1);
        vm.stopPrank();
        
        assertEq(vault.balanceOf(user1), 0);
        assertGt(assets, 0);
    }
    
    // ============================================
    // Spillover Tests
    // ============================================
    
    function testReceiveSpillover() public {
        uint256 spilloverAmount = 500e18;
        
        vm.prank(seniorVault);
        vault.receiveSpillover(spilloverAmount);
        
        assertEq(vault.totalSpilloverReceived(), spilloverAmount);
        assertEq(vault.vaultValue(), INITIAL_VALUE + spilloverAmount);
    }
    
    function testReceiveSpilloverUpdatesDepositCap() public {
        uint256 oldCap = vault.currentDepositCap();
        
        vm.prank(seniorVault);
        vault.receiveSpillover(1000e18);
        
        uint256 newCap = vault.currentDepositCap();
        assertGt(newCap, oldCap);
    }
    
    function testCannotReceiveSpilloverNotSenior() public {
        vm.prank(user1);
        vm.expectRevert();
        vault.receiveSpillover(100e18);
    }
    
    // ============================================
    // Backstop Tests
    // ============================================
    
    function testProvideBackstop() public {
        vm.prank(seniorVault);
        uint256 actualAmount = vault.provideBackstop(500e18);
        
        assertEq(actualAmount, 500e18);
        assertEq(vault.totalBackstopProvided(), 500e18);
        assertEq(vault.vaultValue(), INITIAL_VALUE - 500e18);
    }
    
    function testProvideBackstopCanDeplete() public {
        vm.prank(seniorVault);
        uint256 actualAmount = vault.provideBackstop(INITIAL_VALUE);
        
        assertEq(actualAmount, INITIAL_VALUE);
        assertEq(vault.vaultValue(), 0);
        assertTrue(vault.isDepleted());
    }
    
    function testProvideBackstopExceedsValue() public {
        vm.prank(seniorVault);
        uint256 actualAmount = vault.provideBackstop(INITIAL_VALUE + 500e18);
        
        // Provides full reserve
        assertEq(actualAmount, INITIAL_VALUE);
        assertEq(vault.vaultValue(), 0);
    }
    
    function testCannotProvideBackstopWhenDepleted() public {
        // Deplete vault
        vm.prank(seniorVault);
        vault.provideBackstop(INITIAL_VALUE);
        
        // Try to provide more
        vm.prank(seniorVault);
        vm.expectRevert();
        vault.provideBackstop(100e18);
    }
    
    function testCannotProvideBackstopNotSenior() public {
        vm.prank(user1);
        vm.expectRevert();
        vault.provideBackstop(100e18);
    }
    
    // ============================================
    // Deposit Cap Tests
    // ============================================
    
    function testCurrentDepositCap() public view {
        uint256 cap = vault.currentDepositCap();
        assertEq(cap, INITIAL_VALUE * 10);
    }
    
    function testDepositCapChangesWithValue() public {
        vm.prank(keeper);
        vault.updateVaultValue(1000); // +10%
        
        uint256 newCap = vault.currentDepositCap();
        assertEq(newCap, 1100e18 * 10);
    }
    
    // ============================================
    // Depletion Tests
    // ============================================
    
    function testIsDepletedFalse() public view {
        assertFalse(vault.isDepleted());
    }
    
    function testIsDepletedTrue() public {
        vm.prank(seniorVault);
        vault.provideBackstop(INITIAL_VALUE); // Full depletion
        
        assertTrue(vault.isDepleted());
    }
    
    function testIsDepletedNearThreshold() public {
        // Threshold is 1% of lastMonthValue (INITIAL_VALUE) = 10e18
        // Leave slightly above threshold: 11e18 (1.1%)
        vm.prank(seniorVault);
        vault.provideBackstop(INITIAL_VALUE - 11e18); // Leave 11e18 (1.1%)
        
        // Should NOT be depleted (above 1% threshold)
        assertFalse(vault.isDepleted());
        
        // Now reduce below threshold
        vm.prank(seniorVault);
        vault.provideBackstop(2e18); // Leave 9e18 (<1%)
        
        // Should be depleted now
        assertTrue(vault.isDepleted());
    }
    
    // ============================================
    // View Function Tests
    // ============================================
    
    function testCanProvideFullBackstop() public view {
        assertTrue(vault.canProvideFullBackstop(500e18));
        assertTrue(vault.canProvideFullBackstop(INITIAL_VALUE));
        assertFalse(vault.canProvideFullBackstop(INITIAL_VALUE + 1));
    }
    
    function testBackstopCapacity() public view {
        assertEq(vault.backstopCapacity(), INITIAL_VALUE);
    }
    
    function testUtilizationRate() public {
        // No utilization initially
        assertEq(vault.utilizationRate(), 0);
        
        // Provide backstop
        vm.prank(seniorVault);
        vault.provideBackstop(500e18);
        
        // Should have utilization now
        assertGt(vault.utilizationRate(), 0);
    }
    
    function testEffectiveMonthlyReturn() public {
        assertEq(vault.effectiveMonthlyReturn(), 0);
        
        vm.prank(keeper);
        vault.updateVaultValue(1000); // +10%
        
        assertGt(vault.effectiveMonthlyReturn(), 0);
    }
    
    // ============================================
    // Vault Value Update Tests
    // ============================================
    
    function testUpdateVaultValue() public {
        uint256 oldValue = vault.vaultValue();
        
        vm.prank(keeper);
        vault.updateVaultValue(1000); // +10%
        
        assertEq(vault.vaultValue(), oldValue + oldValue / 10);
    }
    
    function testCannotUpdateVaultValueNotKeeper() public {
        vm.prank(user1);
        vm.expectRevert();
        vault.updateVaultValue(1000);
    }
    
    // ============================================
    // Keeper Management Tests
    // ============================================
    
    function testSetAdmin() public {
        // Admin is already set to keeper in setUp
        assertTrue(vault.isAdmin(keeper));
        assertFalse(vault.isAdmin(user1));
    }
    
    function testTransferAdmin() public {
        address newAdmin = makeAddr("newAdmin");
        
        vm.prank(keeper);
        vault.transferAdmin(newAdmin);
        
        assertTrue(vault.isAdmin(newAdmin));
        assertFalse(vault.isAdmin(keeper));
    }
    
    function testCannotSetAdminTwice() public {
        vm.expectRevert();
        vault.setAdmin(user1);
    }
    
    // ============================================
    // Fuzz Tests
    // ============================================
    
    function testFuzz_Deposit(uint256 amount) public {
        amount = bound(amount, 1, 5000e18);
        
        lpToken.mint(user1, amount);
        
        vm.startPrank(user1);
        lpToken.approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, user1);
        vm.stopPrank();
        
        assertGt(shares, 0);
    }
    
    function testFuzz_ReceiveSpillover(uint256 amount) public {
        amount = bound(amount, 1, 10000e18);
        
        uint256 oldValue = vault.vaultValue();
        
        vm.prank(seniorVault);
        vault.receiveSpillover(amount);
        
        assertEq(vault.vaultValue(), oldValue + amount);
    }
    
    function testFuzz_ProvideBackstop(uint256 amount) public {
        amount = bound(amount, 1, INITIAL_VALUE);
        
        uint256 oldValue = vault.vaultValue();
        
        vm.prank(seniorVault);
        uint256 actualAmount = vault.provideBackstop(amount);
        
        assertEq(actualAmount, amount);
        assertEq(vault.vaultValue(), oldValue - amount);
    }
}

