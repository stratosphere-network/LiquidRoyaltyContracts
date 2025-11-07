// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UnifiedConcreteSeniorVault} from "../../src/concrete/UnifiedConcreteSeniorVault.sol";
import {ConcreteJuniorVault} from "../../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../../src/concrete/ConcreteReserveVault.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MathLib} from "../../src/libraries/MathLib.sol";
import {SpilloverLib} from "../../src/libraries/SpilloverLib.sol";

contract UnifiedSeniorVaultTest is Test {
    UnifiedConcreteSeniorVault public vault;
    ConcreteJuniorVault public juniorVault;
    ConcreteReserveVault public reserveVault;
    MockERC20 public lpToken;
    
    address public treasury;
    address public keeper;
    address public user1;
    address public user2;
    address public user3;
    
    uint256 constant INITIAL_VALUE = 1000e18;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Rebase(uint256 indexed epoch, uint256 oldIndex, uint256 newIndex, uint256 newTotalSupply);
    
    function setUp() public {
        treasury = makeAddr("treasury");
        keeper = makeAddr("keeper");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        
        // Deploy stablecoin
        lpToken = new MockERC20("USDe-SAIL", "USDe-SAIL", 18);
        
        // Compute the address where Senior vault proxy will be deployed
        // Nonce: +3 implementations, +2 proxies (junior, reserve), then senior proxy
        uint64 currentNonce = vm.getNonce(address(this));
        address predictedSeniorAddress = vm.computeCreateAddress(address(this), currentNonce + 5);
        
        // Deploy implementations
        ConcreteJuniorVault juniorImpl = new ConcreteJuniorVault();
        ConcreteReserveVault reserveImpl = new ConcreteReserveVault();
        UnifiedConcreteSeniorVault seniorImpl = new UnifiedConcreteSeniorVault();
        
        // Deploy Junior and Reserve vault proxies with predicted Senior address
        bytes memory juniorInitData = abi.encodeWithSelector(
            ConcreteJuniorVault.initialize.selector,
            address(lpToken),
            predictedSeniorAddress,
            INITIAL_VALUE
        );
        ERC1967Proxy juniorProxy = new ERC1967Proxy(address(juniorImpl), juniorInitData);
        juniorVault = ConcreteJuniorVault(address(juniorProxy));
        
        bytes memory reserveInitData = abi.encodeWithSelector(
            ConcreteReserveVault.initialize.selector,
            address(lpToken),
            predictedSeniorAddress,
            INITIAL_VALUE
        );
        ERC1967Proxy reserveProxy = new ERC1967Proxy(address(reserveImpl), reserveInitData);
        reserveVault = ConcreteReserveVault(address(reserveProxy));
        
        // Deploy Senior vault proxy (should match predicted address)
        bytes memory seniorInitData = abi.encodeWithSelector(
            UnifiedConcreteSeniorVault.initialize.selector,
            address(lpToken),
            "Senior USD",
            "snrUSD",
            address(juniorVault),
            address(reserveVault),
            treasury,
            INITIAL_VALUE
        );
        ERC1967Proxy seniorProxy = new ERC1967Proxy(address(seniorImpl), seniorInitData);
        vault = UnifiedConcreteSeniorVault(address(seniorProxy));
        
        // Verify the prediction was correct
        assertEq(address(vault), predictedSeniorAddress, "Senior vault address mismatch");
        
        // Mint stablecoins
        lpToken.mint(user1, 100000e18);
        lpToken.mint(user2, 100000e18);
        lpToken.mint(user3, 100000e18);
        lpToken.mint(address(juniorVault), INITIAL_VALUE);
        lpToken.mint(address(reserveVault), INITIAL_VALUE);
        lpToken.mint(address(vault), INITIAL_VALUE);
        
        // Add keeper
        vault.setAdmin(keeper);
    }
    
    // ============================================
    // Deployment & ERC20 Metadata Tests
    // ============================================
    
    function testDeployment() public view {
        assertEq(vault.name(), "Senior USD");
        assertEq(vault.symbol(), "snrUSD");
        assertEq(vault.decimals(), 18);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.totalShares(), 0);
        assertEq(vault.rebaseIndex(), MathLib.PRECISION);
        assertEq(vault.epoch(), 0);
    }
    
    function testVaultProperties() public view {
        assertEq(vault.juniorVault(), address(juniorVault));
        assertEq(vault.reserveVault(), address(reserveVault));
        assertEq(vault.treasury(), treasury);
        assertEq(vault.vaultValue(), INITIAL_VALUE);
        assertEq(vault.minRebaseInterval(), 30 days);
    }
    
    // ============================================
    // Deposit Tests (Vault = Token, 1:1)
    // ============================================
    
    function testDeposit() public {
        uint256 amount = 100e18;
        
        vm.startPrank(user1);
        lpToken.approve(address(vault), amount);
        
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), user1, amount);
        
        vault.deposit(amount, user1);
        vm.stopPrank();
        
        // Check balances
        assertEq(vault.balanceOf(user1), amount); // 1:1 at initial index
        assertEq(vault.totalSupply(), amount);
        // Note: vaultValue is NOT auto-updated (keeper updates it via updateVaultValue)
        assertEq(vault.vaultValue(), INITIAL_VALUE); // Unchanged until keeper updates
        assertGt(vault.sharesOf(user1), 0);
    }
    
    function testDepositMultipleUsers() public {
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
        
        // User3 deposits
        vm.startPrank(user3);
        lpToken.approve(address(vault), 300e18);
        vault.deposit(300e18, user3);
        vm.stopPrank();
        
        assertEq(vault.balanceOf(user1), 100e18);
        assertEq(vault.balanceOf(user2), 200e18);
        assertEq(vault.balanceOf(user3), 300e18);
        assertEq(vault.totalSupply(), 600e18);
    }
    
    function testCannotDepositZero() public {
        vm.prank(user1);
        vm.expectRevert();
        vault.deposit(0, user1);
    }
    
    function testCannotDepositToZeroAddress() public {
        vm.startPrank(user1);
        lpToken.approve(address(vault), 100e18);
        vm.expectRevert();
        vault.deposit(100e18, address(0));
        vm.stopPrank();
    }
    
    function testPreviewDeposit() public view {
        uint256 assets = 100e18;
        uint256 shares = vault.previewDeposit(assets);
        assertEq(shares, assets); // 1:1 at initial index
    }
    
    // ============================================
    // ERC20 Transfer Tests
    // ============================================
    
    function testTransfer() public {
        // User1 deposits
        vm.startPrank(user1);
        lpToken.approve(address(vault), 100e18);
        vault.deposit(100e18, user1);
        
        // Transfer to user2
        vm.expectEmit(true, true, true, true);
        emit Transfer(user1, user2, 50e18);
        
        vault.transfer(user2, 50e18);
        vm.stopPrank();
        
        assertEq(vault.balanceOf(user1), 50e18);
        assertEq(vault.balanceOf(user2), 50e18);
    }
    
    function testTransferAll() public {
        vm.startPrank(user1);
        lpToken.approve(address(vault), 100e18);
        vault.deposit(100e18, user1);
        
        vault.transfer(user2, 100e18);
        vm.stopPrank();
        
        assertEq(vault.balanceOf(user1), 0);
        assertEq(vault.balanceOf(user2), 100e18);
    }
    
    function testCannotTransferMoreThanBalance() public {
        vm.startPrank(user1);
        lpToken.approve(address(vault), 100e18);
        vault.deposit(100e18, user1);
        
        vm.expectRevert();
        vault.transfer(user2, 101e18);
        vm.stopPrank();
    }
    
    function testCannotTransferToZeroAddress() public {
        vm.startPrank(user1);
        lpToken.approve(address(vault), 100e18);
        vault.deposit(100e18, user1);
        
        vm.expectRevert();
        vault.transfer(address(0), 50e18);
        vm.stopPrank();
    }
    
    // ============================================
    // ERC20 Approval Tests
    // ============================================
    
    function testApprove() public {
        vm.prank(user1);
        vault.approve(user2, 100e18);
        
        assertEq(vault.allowance(user1, user2), 100e18);
    }
    
    function testTransferFrom() public {
        // User1 deposits
        vm.startPrank(user1);
        lpToken.approve(address(vault), 100e18);
        vault.deposit(100e18, user1);
        
        // Approve user2
        vault.approve(user2, 50e18);
        vm.stopPrank();
        
        // User2 transfers from user1
        vm.prank(user2);
        vault.transferFrom(user1, user3, 50e18);
        
        assertEq(vault.balanceOf(user1), 50e18);
        assertEq(vault.balanceOf(user3), 50e18);
        assertEq(vault.allowance(user1, user2), 0);
    }
    
    function testCannotTransferFromWithoutApproval() public {
        vm.startPrank(user1);
        lpToken.approve(address(vault), 100e18);
        vault.deposit(100e18, user1);
        vm.stopPrank();
        
        vm.prank(user2);
        vm.expectRevert();
        vault.transferFrom(user1, user2, 50e18);
    }
    
    function testCannotTransferFromMoreThanAllowance() public {
        vm.startPrank(user1);
        lpToken.approve(address(vault), 100e18);
        vault.deposit(100e18, user1);
        vault.approve(user2, 50e18);
        vm.stopPrank();
        
        vm.prank(user2);
        vm.expectRevert();
        vault.transferFrom(user1, user2, 51e18);
    }
    
    // ============================================
    // Withdrawal Tests
    // ============================================
    
    function testWithdrawWithCooldown() public {
        // Deposit
        vm.startPrank(user1);
        lpToken.approve(address(vault), 100e18);
        vault.deposit(100e18, user1);
        
        // Initiate cooldown
        vault.initiateCooldown();
        assertEq(vault.cooldownStart(user1), block.timestamp);
        
        // Wait 7 days
        vm.warp(block.timestamp + 7 days);
        assertTrue(vault.canWithdrawWithoutPenalty(user1));
        
        // Withdraw
        uint256 balanceBefore = lpToken.balanceOf(user1);
        vault.withdraw(100e18, user1, user1);
        vm.stopPrank();
        
        assertEq(vault.balanceOf(user1), 0);
        assertEq(lpToken.balanceOf(user1) - balanceBefore, 100e18); // No penalty
    }
    
    function testWithdrawWithPenalty() public {
        // Deposit
        vm.startPrank(user1);
        lpToken.approve(address(vault), 100e18);
        vault.deposit(100e18, user1);
        
        // Withdraw immediately (no cooldown)
        uint256 balanceBefore = lpToken.balanceOf(user1);
        uint256 netAssets = vault.withdraw(100e18, user1, user1);
        vm.stopPrank();
        
        assertEq(vault.balanceOf(user1), 0);
        assertEq(netAssets, 95e18); // 5% penalty
        assertEq(lpToken.balanceOf(user1) - balanceBefore, 95e18);
    }
    
    function testWithdrawWithAllowance() public {
        // User1 deposits
        vm.startPrank(user1);
        lpToken.approve(address(vault), 100e18);
        vault.deposit(100e18, user1);
        
        // Initiate cooldown and wait
        vault.initiateCooldown();
        vm.warp(block.timestamp + 7 days);
        
        // Approve user2 to withdraw
        vault.approve(user2, 100e18);
        vm.stopPrank();
        
        // User2 withdraws on behalf of user1
        vm.prank(user2);
        vault.withdraw(100e18, user2, user1);
        
        assertEq(vault.balanceOf(user1), 0);
        assertGt(lpToken.balanceOf(user2), 0);
    }
    
    function testPreviewWithdraw() public {
        vm.startPrank(user1);
        lpToken.approve(address(vault), 100e18);
        vault.deposit(100e18, user1);
        
        // Without cooldown, should show penalty
        uint256 netAssets = vault.previewWithdraw(100e18);
        assertEq(netAssets, 95e18);
        
        // With cooldown
        vault.initiateCooldown();
        vm.warp(block.timestamp + 7 days);
        
        netAssets = vault.previewWithdraw(100e18);
        assertEq(netAssets, 100e18); // No penalty
        vm.stopPrank();
    }
    
    // ============================================
    // Cooldown Tests
    // ============================================
    
    function testInitiateCooldown() public {
        vm.startPrank(user1);
        lpToken.approve(address(vault), 100e18);
        vault.deposit(100e18, user1);
        
        vault.initiateCooldown();
        
        assertEq(vault.cooldownStart(user1), block.timestamp);
        assertFalse(vault.canWithdrawWithoutPenalty(user1));
        vm.stopPrank();
    }
    
    function testCooldownComplete() public {
        vm.startPrank(user1);
        lpToken.approve(address(vault), 100e18);
        vault.deposit(100e18, user1);
        
        vault.initiateCooldown();
        vm.warp(block.timestamp + 7 days);
        
        assertTrue(vault.canWithdrawWithoutPenalty(user1));
        vm.stopPrank();
    }
    
    function testCooldownNotComplete() public {
        vm.startPrank(user1);
        lpToken.approve(address(vault), 100e18);
        vault.deposit(100e18, user1);
        
        vault.initiateCooldown();
        vm.warp(block.timestamp + 6 days);
        
        assertFalse(vault.canWithdrawWithoutPenalty(user1));
        vm.stopPrank();
    }
    
    function testCalculateWithdrawalPenalty() public {
        vm.startPrank(user1);
        lpToken.approve(address(vault), 100e18);
        vault.deposit(100e18, user1);
        
        // No cooldown
        (uint256 penalty, uint256 netAmount) = vault.calculateWithdrawalPenalty(user1, 100e18);
        assertEq(penalty, 5e18);
        assertEq(netAmount, 95e18);
        
        // With cooldown (after 7 days)
        vault.initiateCooldown();
        vm.warp(block.timestamp + 7 days);
        
        (penalty, netAmount) = vault.calculateWithdrawalPenalty(user1, 100e18);
        assertEq(penalty, 0);
        assertEq(netAmount, 100e18);
        vm.stopPrank();
    }
    
    // ============================================
    // Rebase Tests
    // ============================================
    
    function testRebaseIncreasesBalance() public {
        // User deposits
        vm.startPrank(user1);
        lpToken.approve(address(vault), 1000e18);
        vault.deposit(1000e18, user1);
        vm.stopPrank();
        
        uint256 balanceBefore = vault.balanceOf(user1);
        uint256 sharesBefore = vault.sharesOf(user1);
        uint256 indexBefore = vault.rebaseIndex();
        
        // Wait 30 days and update vault value (+10%)
        vm.warp(block.timestamp + 30 days);
        vm.prank(keeper);
        vault.updateVaultValue(1000); // +10%
        
        // Execute rebase
        vm.prank(keeper);
        vault.rebase();
        
        uint256 balanceAfter = vault.balanceOf(user1);
        uint256 sharesAfter = vault.sharesOf(user1);
        uint256 indexAfter = vault.rebaseIndex();
        
        // Shares should be constant
        assertEq(sharesAfter, sharesBefore);
        
        // Balance should increase (rebased)
        assertGt(balanceAfter, balanceBefore);
        
        // Index should increase
        assertGt(indexAfter, indexBefore);
        
        // Epoch should increment
        assertEq(vault.epoch(), 1);
    }
    
    function testCannotRebaseTooSoon() public {
        vm.prank(keeper);
        vm.expectRevert();
        vault.rebase();
    }
    
    function testCannotRebaseNotKeeper() public {
        vm.warp(block.timestamp + 30 days);
        
        vm.prank(user1);
        vm.expectRevert();
        vault.rebase();
    }
    
    function testMultipleRebases() public {
        // User deposits
        vm.startPrank(user1);
        lpToken.approve(address(vault), 1000e18);
        vault.deposit(1000e18, user1);
        vm.stopPrank();
        
        uint256 initialBalance = vault.balanceOf(user1);
        
        // First rebase
        vm.warp(block.timestamp + 30 days);
        vm.prank(keeper);
        vault.updateVaultValue(1000);
        vm.prank(keeper);
        vault.rebase();
        
        uint256 balanceAfterFirst = vault.balanceOf(user1);
        assertGt(balanceAfterFirst, initialBalance);
        
        // Second rebase
        vm.warp(block.timestamp + 30 days);
        vm.prank(keeper);
        vault.updateVaultValue(1000);
        vm.prank(keeper);
        vault.rebase();
        
        uint256 balanceAfterSecond = vault.balanceOf(user1);
        assertGt(balanceAfterSecond, balanceAfterFirst);
        assertEq(vault.epoch(), 2);
    }
    
    // ============================================
    // Share Tests
    // ============================================
    
    function testSharesConstantDuringRebase() public {
        vm.startPrank(user1);
        lpToken.approve(address(vault), 1000e18);
        vault.deposit(1000e18, user1);
        vm.stopPrank();
        
        uint256 sharesBefore = vault.sharesOf(user1);
        
        // Rebase
        vm.warp(block.timestamp + 30 days);
        vm.prank(keeper);
        vault.updateVaultValue(1000);
        vm.prank(keeper);
        vault.rebase();
        
        uint256 sharesAfter = vault.sharesOf(user1);
        
        // Shares unchanged
        assertEq(sharesAfter, sharesBefore);
        
        // But balance increased
        assertGt(vault.balanceOf(user1), 1000e18);
    }
    
    function testTotalShares() public {
        // Multiple users deposit
        vm.startPrank(user1);
        lpToken.approve(address(vault), 100e18);
        vault.deposit(100e18, user1);
        vm.stopPrank();
        
        vm.startPrank(user2);
        lpToken.approve(address(vault), 200e18);
        vault.deposit(200e18, user2);
        vm.stopPrank();
        
        uint256 totalShares = vault.totalShares();
        assertEq(totalShares, vault.sharesOf(user1) + vault.sharesOf(user2));
    }
    
    // ============================================
    // Backing Ratio Tests
    // ============================================
    
    function testBackingRatioInitial() public {
        // No supply yet
        assertEq(vault.backingRatio(), MathLib.PRECISION);
    }
    
    function testBackingRatioAfterDeposit() public {
        vm.startPrank(user1);
        lpToken.approve(address(vault), 100e18);
        vault.deposit(100e18, user1);
        vm.stopPrank();
        
        // Note: vaultValue doesn't auto-update, so ratio = INITIAL_VALUE / supply
        // Ratio = 1000e18 / 100e18 = 10 = 1000%
        uint256 ratio = vault.backingRatio();
        assertEq(ratio, INITIAL_VALUE * MathLib.PRECISION / 100e18);
    }
    
    function testCurrentZone() public {
        vm.startPrank(user1);
        lpToken.approve(address(vault), 100e18);
        vault.deposit(100e18, user1);
        vm.stopPrank();
        
        // High backing ratio = SPILLOVER zone
        SpilloverLib.Zone zone = vault.currentZone();
        assertEq(uint256(zone), uint256(SpilloverLib.Zone.SPILLOVER));
    }
    
    // ============================================
    // Deposit Cap Tests
    // ============================================
    
    function testDepositCap() public view {
        uint256 cap = vault.depositCap();
        assertEq(cap, INITIAL_VALUE * 10); // 10x reserve value
    }
    
    function testIsDepositCapReached() public {
        assertFalse(vault.isDepositCapReached());
        
        // Deposit cap = 10 * reserve value = 10 * 1000e18 = 10000e18
        uint256 cap = vault.depositCap();
        assertEq(cap, 10 * INITIAL_VALUE);
        
        // Deposit exactly to cap
        vm.startPrank(user1);
        lpToken.approve(address(vault), cap);
        vault.deposit(cap, user1);
        vm.stopPrank();
        
        // Should be at cap now
        assertTrue(vault.isDepositCapReached());
    }
    
    // ============================================
    // Vault Value Update Tests
    // ============================================
    
    function testUpdateVaultValue() public {
        vm.prank(keeper);
        vault.updateVaultValue(1000); // +10%
        
        assertEq(vault.vaultValue(), 1100e18);
    }
    
    function testUpdateVaultValueNegative() public {
        vm.prank(keeper);
        vault.updateVaultValue(-500); // -5%
        
        assertEq(vault.vaultValue(), 950e18);
    }
    
    function testCannotUpdateVaultValueNotKeeper() public {
        vm.prank(user1);
        vm.expectRevert();
        vault.updateVaultValue(1000);
    }
    
    function testCannotUpdateVaultValueOutOfRange() public {
        vm.startPrank(keeper);
        
        // Too low (-51%)
        vm.expectRevert();
        vault.updateVaultValue(-5001);
        
        // Too high (+101%)
        vm.expectRevert();
        vault.updateVaultValue(10001);
        
        vm.stopPrank();
    }
    
    // ============================================
    // Access Control Tests
    // ============================================
    
    function testSetAdmin() public {
        // In setUp, admin is already set to `keeper` address
        assertTrue(vault.isAdmin(keeper));
        assertFalse(vault.isAdmin(user1));
    }
    
    function testTransferAdmin() public {
        address newAdmin = makeAddr("newAdmin");
        
        // Current admin transfers to new admin
        vm.prank(keeper);
        vault.transferAdmin(newAdmin);
        
        assertTrue(vault.isAdmin(newAdmin));
        assertFalse(vault.isAdmin(keeper)); // Old admin no longer admin
    }
    
    function testCannotSetAdminTwice() public {
        // Try to set admin again (should fail)
        vm.expectRevert();
        vault.setAdmin(user1);
    }
    
    function testCannotTransferAdminNotAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        vault.transferAdmin(user1);
    }
    
    // ============================================
    // Fuzz Tests
    // ============================================
    
    function testFuzz_Deposit(uint256 amount) public {
        amount = bound(amount, 1e18, 5000e18); // Keep below deposit cap
        
        lpToken.mint(user1, amount);
        
        vm.startPrank(user1);
        lpToken.approve(address(vault), amount);
        vault.deposit(amount, user1);
        vm.stopPrank();
        
        assertEq(vault.balanceOf(user1), amount);
        assertGt(vault.sharesOf(user1), 0);
    }
    
    function testFuzz_Transfer(uint256 depositAmount, uint256 transferAmount) public {
        depositAmount = bound(depositAmount, 1e18, 5000e18);
        transferAmount = bound(transferAmount, 0, depositAmount);
        
        lpToken.mint(user1, depositAmount);
        
        vm.startPrank(user1);
        lpToken.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);
        
        vault.transfer(user2, transferAmount);
        vm.stopPrank();
        
        assertEq(vault.balanceOf(user1), depositAmount - transferAmount);
        assertEq(vault.balanceOf(user2), transferAmount);
    }
    
    function testFuzz_UpdateVaultValue(int256 profitBps) public {
        profitBps = int256(bound(uint256(profitBps), 0, 10000));
        
        uint256 oldValue = vault.vaultValue();
        
        vm.prank(keeper);
        vault.updateVaultValue(profitBps);
        
        uint256 newValue = vault.vaultValue();
        
        if (profitBps > 0) {
            assertGt(newValue, oldValue);
        } else if (profitBps < 0) {
            assertLt(newValue, oldValue);
        } else {
            assertEq(newValue, oldValue);
        }
    }
}

