// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ConcreteJuniorVault} from "../../../src/concrete/ConcreteJuniorVault.sol";
import {MockERC20} from "../../../src/mocks/MockERC20.sol";
import {MathLib} from "../../../src/libraries/MathLib.sol";
import {MockKodiakHook} from "../../mocks/MockKodiakHook.sol";

contract ConcreteJuniorVaultTest is Test {
    ConcreteJuniorVault public vault;
    MockERC20 public lpToken;
    MockKodiakHook public hook;
    MockKodiakHook public seniorHook;
    
    address public seniorVault;
    address public user1;
    address public user2;
    address public keeper;
    
    uint256 constant INITIAL_VALUE = 1000e18;
    uint256 constant LP_PRICE = 1e18; // 1:1 price for simplicity
    
    function setUp() public {
        seniorVault = makeAddr("seniorVault");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        keeper = makeAddr("keeper");
        
        lpToken = new MockERC20("USDe-SAIL", "USDe-SAIL", 18);
        
        // Deploy upgradeable Junior vault using proxy
        ConcreteJuniorVault implementation = new ConcreteJuniorVault();
        bytes memory initData = abi.encodeWithSelector(
            ConcreteJuniorVault.initialize.selector,
            address(lpToken),
            seniorVault,
            0 // Start with 0 value, will be updated via deposits/vaultValue updates
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        vault = ConcreteJuniorVault(address(proxy));
        
        // Mint stablecoins
        lpToken.mint(user1, 10000e18);
        lpToken.mint(user2, 10000e18);
        // Don't pre-mint to vault - let deposits handle it naturally
        
        // Add keeper
        vault.setAdmin(keeper);
    }
    
    // Helper function to initialize vault with value (for backstop/spillover tests)
    function _initializeVaultWithValue() internal {
        // Set vault value twice to properly initialize _lastMonthValue
        // First call: _vaultValue = INITIAL_VALUE, _lastMonthValue = 0 (old value)
        // Second call: _vaultValue = INITIAL_VALUE, _lastMonthValue = INITIAL_VALUE (old value)
        vm.startPrank(keeper);
        vault.setVaultValue(INITIAL_VALUE);
        vault.setVaultValue(INITIAL_VALUE);
        
        // Create and set mock Kodiak hook
        hook = new MockKodiakHook(address(vault), address(0), address(lpToken));
        vault.setKodiakHook(address(hook));
        vm.stopPrank();
        
        // Mint LP tokens to the hook (this is where backstop LP comes from)
        lpToken.mint(address(hook), INITIAL_VALUE);
        
        // Create senior hook for backstop transfers
        seniorHook = new MockKodiakHook(seniorVault, address(0), address(lpToken));
        
        // Mock seniorVault.kodiakHook() to return our senior hook
        vm.mockCall(
            seniorVault,
            abi.encodeWithSignature("kodiakHook()"),
            abi.encode(address(seniorHook))
        );
        
        // Whitelist the LP token so provideBackstop can transfer it
        vm.prank(keeper);
        vault.addWhitelistedLPToken(address(lpToken));
    }
    
    // ============================================
    // Deployment Tests
    // ============================================
    
    function testDeployment() public {
        _initializeVaultWithValue();
        assertEq(vault.name(), "Junior Tranche Shares");
        assertEq(vault.symbol(), "jTRN");
        assertEq(vault.seniorVault(), seniorVault);
        assertEq(vault.vaultValue(), INITIAL_VALUE);
        assertEq(vault.totalSpilloverReceived(), 0);
        assertEq(vault.totalBackstopProvided(), 0);
    }
    
    // ============================================
    // ERC4626 Deposit/Withdraw Tests
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
        // Deposit first
        vm.startPrank(user1);
        lpToken.approve(address(vault), 100e18);
        uint256 shares = vault.deposit(100e18, user1);
        vm.stopPrank();
        
        // Update vault value to match deposited amount (keeper would do this in practice)
        vm.prank(keeper);
        vault.setVaultValue(100e18);
        
        // Withdraw
        vm.prank(user1);
        uint256 assets = vault.redeem(shares, user1, user1);
        
        assertEq(vault.balanceOf(user1), 0);
        assertGt(assets, 0);
    }
    
    function testMultipleUsersDeposit() public {
        // User1 deposits
        vm.startPrank(user1);
        lpToken.approve(address(vault), 100e18);
        vault.deposit(100e18, user1);
        vm.stopPrank();
        
        // User2 deposits
        vm.startPrank(user2);
        lpToken.approve(address(vault), 200e18);
        vault.deposit(200e18, user2);
        vm.stopPrank();
        
        assertGt(vault.balanceOf(user1), 0);
        assertGt(vault.balanceOf(user2), 0);
    }
    
    // ============================================
    // Spillover Tests
    // ============================================
    
    function testReceiveSpillover() public {
        _initializeVaultWithValue();
        uint256 spilloverAmount = 500e18;
        
        vm.prank(seniorVault);
        vault.receiveSpillover(spilloverAmount);
        
        assertEq(vault.totalSpilloverReceived(), spilloverAmount);
        assertEq(vault.vaultValue(), INITIAL_VALUE + spilloverAmount);
    }
    
    function testReceiveSpilloverMultipleTimes() public {
        _initializeVaultWithValue();
        vm.startPrank(seniorVault);
        vault.receiveSpillover(100e18);
        vault.receiveSpillover(200e18);
        vm.stopPrank();
        
        assertEq(vault.totalSpilloverReceived(), 300e18);
        assertEq(vault.vaultValue(), INITIAL_VALUE + 300e18);
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
        _initializeVaultWithValue();
        vm.prank(seniorVault);
        uint256 actualAmount = vault.provideBackstop(500e18, LP_PRICE);
        
        assertEq(actualAmount, 500e18);
        assertEq(vault.totalBackstopProvided(), 500e18);
        assertEq(vault.vaultValue(), INITIAL_VALUE - 500e18);
    }
    
    function testProvideBackstopExceedsValue() public {
        _initializeVaultWithValue();
        vm.prank(seniorVault);
        uint256 actualAmount = vault.provideBackstop(INITIAL_VALUE + 500e18, LP_PRICE);
        
        // Can only provide what's available
        assertEq(actualAmount, INITIAL_VALUE);
        assertEq(vault.vaultValue(), 0);
    }
    
    function testCannotProvideBackstopWhenDepleted() public {
        _initializeVaultWithValue();
        // Deplete vault
        vm.prank(seniorVault);
        vault.provideBackstop(INITIAL_VALUE, LP_PRICE);
        
        // Try to provide more
        vm.prank(seniorVault);
        vm.expectRevert();
        vault.provideBackstop(100e18, LP_PRICE);
    }
    
    function testCannotProvideBackstopNotSenior() public {
        vm.prank(user1);
        vm.expectRevert();
        vault.provideBackstop(100e18, LP_PRICE);
    }
    
    // ============================================
    // View Function Tests
    // ============================================
    
    function testCanProvideBackstop() public {
        _initializeVaultWithValue();
        assertTrue(vault.canProvideBackstop(500e18));
        assertTrue(vault.canProvideBackstop(INITIAL_VALUE));
        assertFalse(vault.canProvideBackstop(INITIAL_VALUE + 1));
    }
    
    function testBackstopCapacity() public {
        _initializeVaultWithValue();
        assertEq(vault.backstopCapacity(), INITIAL_VALUE);
    }
    
    function testEffectiveMonthlyReturn() public {
        _initializeVaultWithValue();
        // Initial return should be 0
        assertEq(vault.effectiveMonthlyReturn(), 0);
        
        // Update value
        vm.prank(keeper);
        vault.updateVaultValue(1000); // +10%
        
        // Should have positive return
        assertGt(vault.effectiveMonthlyReturn(), 0);
    }
    
    function testCurrentAPY() public {
        _initializeVaultWithValue();
        // Update value with profit
        vm.prank(keeper);
        vault.updateVaultValue(1000); // +10%
        
        int256 apy = vault.currentAPY();
        assertGt(apy, 0);
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
    // Admin Management Tests
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
        assertEq(vault.balanceOf(user1), shares);
    }
    
    function testFuzz_ReceiveSpillover(uint256 amount) public {
        amount = bound(amount, 1, 10000e18);
        
        uint256 oldValue = vault.vaultValue();
        
        vm.prank(seniorVault);
        vault.receiveSpillover(amount);
        
        assertEq(vault.vaultValue(), oldValue + amount);
        assertEq(vault.totalSpilloverReceived(), amount);
    }
    
    function testFuzz_ProvideBackstop(uint256 amount) public {
        _initializeVaultWithValue();
        amount = bound(amount, 1, INITIAL_VALUE);
        
        uint256 oldValue = vault.vaultValue();
        
        vm.prank(seniorVault);
        uint256 actualAmount = vault.provideBackstop(amount, LP_PRICE);
        
        assertEq(actualAmount, amount);
        assertEq(vault.vaultValue(), oldValue - amount);
        assertEq(vault.totalBackstopProvided(), amount);
    }
}

