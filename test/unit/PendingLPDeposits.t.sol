// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UnifiedConcreteSeniorVault} from "../../src/concrete/UnifiedConcreteSeniorVault.sol";
import {ConcreteJuniorVault} from "../../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../../src/concrete/ConcreteReserveVault.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MockKodiakHook} from "../mocks/MockKodiakHook.sol";

// Import enum from base contracts
import {BaseVault} from "../../src/abstract/BaseVault.sol";
import {UnifiedSeniorVault} from "../../src/abstract/UnifiedSeniorVault.sol";

/**
 * @title PendingLPDepositsTest
 * @notice Comprehensive tests for pending LP deposit system across all vaults
 */
contract PendingLPDepositsTest is Test {
    UnifiedConcreteSeniorVault public seniorVault;
    ConcreteJuniorVault public juniorVault;
    ConcreteReserveVault public reserveVault;
    
    MockERC20 public stablecoin;
    MockERC20 public lpToken1;
    MockERC20 public lpToken2;
    
    MockKodiakHook public seniorHook;
    MockKodiakHook public juniorHook;
    MockKodiakHook public reserveHook;
    
    address public deployer = address(1);
    address public admin = address(2);
    address public user1 = address(3);
    address public user2 = address(4);
    address public user3 = address(5);
    
    uint256 constant LP_PRICE = 2e18; // $2 per LP
    uint256 constant DEPOSIT_AMOUNT = 100e18; // 100 LP tokens
    
    // Events to test
    event PendingLPDepositCreated(
        uint256 indexed depositId,
        address indexed depositor,
        address indexed lpToken,
        uint256 amount,
        uint256 expiresAt
    );
    event PendingLPDepositApproved(
        uint256 indexed depositId,
        address indexed depositor,
        uint256 lpPrice,
        uint256 sharesMinted
    );
    event PendingLPDepositRejected(
        uint256 indexed depositId,
        address indexed depositor,
        string reason
    );
    event PendingLPDepositCancelled(
        uint256 indexed depositId,
        address indexed depositor
    );
    event PendingLPDepositExpired(
        uint256 indexed depositId,
        address indexed depositor
    );
    
    function setUp() public {
        vm.startPrank(deployer);
        
        // Deploy tokens
        stablecoin = new MockERC20("HONEY", "HONEY", 18);
        lpToken1 = new MockERC20("LP Token 1", "LP1", 18);
        lpToken2 = new MockERC20("LP Token 2", "LP2", 18);
        
        // Deploy Junior vault (with placeholder senior)
        ConcreteJuniorVault juniorImpl = new ConcreteJuniorVault();
        bytes memory juniorInitData = abi.encodeWithSignature(
            "initialize(address,address,uint256)",
            address(stablecoin),
            address(0x1),
            0
        );
        ERC1967Proxy juniorProxy = new ERC1967Proxy(address(juniorImpl), juniorInitData);
        juniorVault = ConcreteJuniorVault(address(juniorProxy));
        
        // Deploy Reserve vault (with placeholder senior)
        ConcreteReserveVault reserveImpl = new ConcreteReserveVault();
        bytes memory reserveInitData = abi.encodeWithSignature(
            "initialize(address,address,uint256)",
            address(stablecoin),
            address(0x1),
            0
        );
        ERC1967Proxy reserveProxy = new ERC1967Proxy(address(reserveImpl), reserveInitData);
        reserveVault = ConcreteReserveVault(address(reserveProxy));
        
        // Deploy Senior vault
        UnifiedConcreteSeniorVault seniorImpl = new UnifiedConcreteSeniorVault();
        bytes memory seniorInitData = abi.encodeWithSignature(
            "initialize(address,string,string,address,address,address,uint256)",
            address(stablecoin),
            "Senior Tranche",
            "snrUSD",
            address(juniorVault),
            address(reserveVault),
            admin,
            0
        );
        ERC1967Proxy seniorProxy = new ERC1967Proxy(address(seniorImpl), seniorInitData);
        seniorVault = UnifiedConcreteSeniorVault(address(seniorProxy));
        
        // Set admins
        seniorVault.setAdmin(admin);
        juniorVault.setAdmin(admin);
        reserveVault.setAdmin(admin);
        
        vm.stopPrank();
        
        // Update junior/reserve with actual senior address
        vm.startPrank(admin);
        juniorVault.setSeniorVault(address(seniorVault));
        reserveVault.setSeniorVault(address(seniorVault));
        vm.stopPrank();
        
        // Deploy hooks
        seniorHook = new MockKodiakHook(address(seniorVault), address(lpToken1), address(lpToken1));
        juniorHook = new MockKodiakHook(address(juniorVault), address(lpToken1), address(lpToken1));
        reserveHook = new MockKodiakHook(address(reserveVault), address(lpToken1), address(lpToken1));
        
        // Set hooks
        vm.startPrank(admin);
        seniorVault.setKodiakHook(address(seniorHook));
        juniorVault.setKodiakHook(address(juniorHook));
        reserveVault.setKodiakHook(address(reserveHook));
        vm.stopPrank();
        
        // Mint LP tokens to users
        lpToken1.mint(user1, 1000e18);
        lpToken1.mint(user2, 1000e18);
        lpToken1.mint(user3, 1000e18);
        lpToken2.mint(user1, 1000e18);
    }
    
    // ============================================
    // depositLP() Tests
    // ============================================
    
    function testDepositLP_Senior_Success() public {
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), DEPOSIT_AMOUNT);
        
        uint256 expectedExpiresAt = block.timestamp + 48 hours;
        
        vm.expectEmit(true, true, true, false);
        emit PendingLPDepositCreated(0, user1, address(lpToken1), DEPOSIT_AMOUNT, expectedExpiresAt);
        
        uint256 depositId = seniorVault.depositLP(address(lpToken1), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        assertEq(depositId, 0, "First deposit ID should be 0");
        assertEq(lpToken1.balanceOf(address(seniorHook)), DEPOSIT_AMOUNT, "LP should be in hook");
        assertEq(lpToken1.balanceOf(user1), 900e18, "User balance should decrease");
        
        // Check deposit details
        (address depositor, address lpToken, uint256 amount, uint256 timestamp, uint256 expiresAt,) = 
            seniorVault.getPendingDeposit(depositId);
        
        assertEq(depositor, user1);
        assertEq(lpToken, address(lpToken1));
        assertEq(amount, DEPOSIT_AMOUNT);
        assertEq(timestamp, block.timestamp);
        assertEq(expiresAt, expectedExpiresAt);
    }
    
    function testDepositLP_Junior_Success() public {
        vm.startPrank(user1);
        lpToken1.approve(address(juniorVault), DEPOSIT_AMOUNT);
        
        uint256 depositId = juniorVault.depositLP(address(lpToken1), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        assertEq(depositId, 0);
        assertEq(lpToken1.balanceOf(address(juniorHook)), DEPOSIT_AMOUNT);
    }
    
    // SKIPPED: Reserve doesn't have pending LP deposits (uses Senior/Junior for LP deposits)
    // Reserve is for token management only (WBTC swaps, etc.)
    function skip_testDepositLP_Reserve_Success() public {
        vm.startPrank(user1);
        lpToken1.approve(address(reserveVault), DEPOSIT_AMOUNT);
        
        // uint256 depositId = reserveVault.depositLP(address(lpToken1), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // assertEq(depositId, 0);
        // assertEq(lpToken1.balanceOf(address(reserveHook)), DEPOSIT_AMOUNT);
    }
    
    function testDepositLP_MultipleDeposits() public {
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), 300e18);
        
        uint256 depositId1 = seniorVault.depositLP(address(lpToken1), 100e18);
        uint256 depositId2 = seniorVault.depositLP(address(lpToken1), 100e18);
        uint256 depositId3 = seniorVault.depositLP(address(lpToken1), 100e18);
        vm.stopPrank();
        
        assertEq(depositId1, 0);
        assertEq(depositId2, 1);
        assertEq(depositId3, 2);
        
        uint256[] memory userDeposits = seniorVault.getUserDepositIds(user1);
        assertEq(userDeposits.length, 3);
        assertEq(userDeposits[0], 0);
        assertEq(userDeposits[1], 1);
        assertEq(userDeposits[2], 2);
    }
    
    function testDepositLP_MultipleUsers() public {
        // User1 deposits
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), DEPOSIT_AMOUNT);
        uint256 depositId1 = seniorVault.depositLP(address(lpToken1), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // User2 deposits
        vm.startPrank(user2);
        lpToken1.approve(address(seniorVault), DEPOSIT_AMOUNT);
        uint256 depositId2 = seniorVault.depositLP(address(lpToken1), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        assertEq(depositId1, 0);
        assertEq(depositId2, 1);
        
        uint256[] memory user1Deposits = seniorVault.getUserDepositIds(user1);
        uint256[] memory user2Deposits = seniorVault.getUserDepositIds(user2);
        
        assertEq(user1Deposits.length, 1);
        assertEq(user2Deposits.length, 1);
        assertEq(user1Deposits[0], 0);
        assertEq(user2Deposits[0], 1);
    }
    
    function testDepositLP_ZeroAddress() public {
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), DEPOSIT_AMOUNT);
        
        vm.expectRevert();
        seniorVault.depositLP(address(0), DEPOSIT_AMOUNT);
        vm.stopPrank();
    }
    
    function testDepositLP_ZeroAmount() public {
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), DEPOSIT_AMOUNT);
        
        vm.expectRevert();
        seniorVault.depositLP(address(lpToken1), 0);
        vm.stopPrank();
    }
    
    function testDepositLP_NoHookSet() public {
        // Deploy new vault without hook
        vm.startPrank(deployer);
        UnifiedConcreteSeniorVault seniorImpl = new UnifiedConcreteSeniorVault();
        bytes memory seniorInitData = abi.encodeWithSignature(
            "initialize(address,string,string,address,address,address,uint256)",
            address(stablecoin),
            "Senior Tranche",
            "snrUSD",
            address(juniorVault),
            address(reserveVault),
            admin,
            0
        );
        ERC1967Proxy seniorProxy = new ERC1967Proxy(address(seniorImpl), seniorInitData);
        UnifiedConcreteSeniorVault newSenior = UnifiedConcreteSeniorVault(address(seniorProxy));
        newSenior.setAdmin(admin);
        vm.stopPrank();
        
        vm.startPrank(user1);
        lpToken1.approve(address(newSenior), DEPOSIT_AMOUNT);
        
        vm.expectRevert();
        newSenior.depositLP(address(lpToken1), DEPOSIT_AMOUNT);
        vm.stopPrank();
    }
    
    // ============================================
    // approveLPDeposit() Tests
    // ============================================
    
    function testApproveLPDeposit_Senior_Success() public {
        // Create deposit
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), DEPOSIT_AMOUNT);
        uint256 depositId = seniorVault.depositLP(address(lpToken1), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        uint256 userBalanceBefore = seniorVault.balanceOf(user1);
        uint256 vaultValueBefore = seniorVault.vaultValue();
        
        // Admin approves
        vm.prank(admin);
        vm.expectEmit(true, true, false, false);
        emit PendingLPDepositApproved(depositId, user1, LP_PRICE, 200e18);
        seniorVault.approveLPDeposit(depositId, LP_PRICE);
        
        uint256 userBalanceAfter = seniorVault.balanceOf(user1);
        uint256 vaultValueAfter = seniorVault.vaultValue();
        
        // Check shares minted (100 LP * $2 = $200 = 200 snrUSD for senior)
        assertEq(userBalanceAfter - userBalanceBefore, 200e18, "Should mint 200 snrUSD");
        assertEq(vaultValueAfter - vaultValueBefore, 200e18, "Vault value should increase");
        
        // Status updated to APPROVED (checked via event)
    }
    
    function testApproveLPDeposit_Junior_Success() public {
        // Bootstrap junior vault first
        vm.startPrank(admin);
        juniorVault.setTreasury(admin);
        juniorVault.setVaultValue(1000e18);
        vm.stopPrank();
        
        stablecoin.mint(user1, 1000e18);
        vm.startPrank(user1);
        stablecoin.approve(address(juniorVault), 1000e18);
        juniorVault.deposit(1000e18, user1);
        vm.stopPrank();
        
        // Now deposit LP
        vm.startPrank(user1);
        lpToken1.approve(address(juniorVault), DEPOSIT_AMOUNT);
        uint256 depositId = juniorVault.depositLP(address(lpToken1), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        uint256 userSharesBefore = juniorVault.balanceOf(user1);
        
        // Admin approves
        vm.prank(admin);
        juniorVault.approveLPDeposit(depositId, LP_PRICE);
        
        uint256 userSharesAfter = juniorVault.balanceOf(user1);
        
        // Check shares minted (based on share price)
        assertGt(userSharesAfter, userSharesBefore, "Should mint shares");
    }
    
    function testApproveLPDeposit_DepositNotFound() public {
        vm.prank(admin);
        vm.expectRevert();
        seniorVault.approveLPDeposit(999, LP_PRICE);
    }
    
    function testApproveLPDeposit_NotPending() public {
        // Create and approve deposit
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), DEPOSIT_AMOUNT);
        uint256 depositId = seniorVault.depositLP(address(lpToken1), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        vm.prank(admin);
        seniorVault.approveLPDeposit(depositId, LP_PRICE);
        
        // Try to approve again
        vm.prank(admin);
        vm.expectRevert();
        seniorVault.approveLPDeposit(depositId, LP_PRICE);
    }
    
    function testApproveLPDeposit_Expired() public {
        // Create deposit
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), DEPOSIT_AMOUNT);
        uint256 depositId = seniorVault.depositLP(address(lpToken1), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Warp past expiry
        vm.warp(block.timestamp + 49 hours);
        
        // Try to approve
        vm.prank(admin);
        vm.expectRevert();
        seniorVault.approveLPDeposit(depositId, LP_PRICE);
    }
    
    function testApproveLPDeposit_ZeroPrice() public {
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), DEPOSIT_AMOUNT);
        uint256 depositId = seniorVault.depositLP(address(lpToken1), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        vm.prank(admin);
        vm.expectRevert();
        seniorVault.approveLPDeposit(depositId, 0);
    }
    
    function testApproveLPDeposit_OnlyAdmin() public {
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), DEPOSIT_AMOUNT);
        uint256 depositId = seniorVault.depositLP(address(lpToken1), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        vm.prank(user2);
        vm.expectRevert();
        seniorVault.approveLPDeposit(depositId, LP_PRICE);
    }
    
    // ============================================
    // rejectLPDeposit() Tests
    // ============================================
    
    function testRejectLPDeposit_Success() public {
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), DEPOSIT_AMOUNT);
        uint256 depositId = seniorVault.depositLP(address(lpToken1), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        uint256 userBalanceBefore = lpToken1.balanceOf(user1);
        uint256 hookBalanceBefore = lpToken1.balanceOf(address(seniorHook));
        
        vm.prank(admin);
        vm.expectEmit(true, true, false, false);
        emit PendingLPDepositRejected(depositId, user1, "Suspicious LP token");
        seniorVault.rejectLPDeposit(depositId, "Suspicious LP token");
        
        uint256 userBalanceAfter = lpToken1.balanceOf(user1);
        uint256 hookBalanceAfter = lpToken1.balanceOf(address(seniorHook));
        
        // Check LP returned
        assertEq(userBalanceAfter - userBalanceBefore, DEPOSIT_AMOUNT, "LP should be returned");
        assertEq(hookBalanceBefore - hookBalanceAfter, DEPOSIT_AMOUNT, "LP removed from hook");
    }
    
    function testRejectLPDeposit_DepositNotFound() public {
        vm.prank(admin);
        vm.expectRevert();
        seniorVault.rejectLPDeposit(999, "Not found");
    }
    
    function testRejectLPDeposit_NotPending() public {
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), DEPOSIT_AMOUNT);
        uint256 depositId = seniorVault.depositLP(address(lpToken1), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        vm.prank(admin);
        seniorVault.rejectLPDeposit(depositId, "First rejection");
        
        // Try to reject again
        vm.prank(admin);
        vm.expectRevert();
        seniorVault.rejectLPDeposit(depositId, "Second rejection");
    }
    
    function testRejectLPDeposit_OnlyAdmin() public {
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), DEPOSIT_AMOUNT);
        uint256 depositId = seniorVault.depositLP(address(lpToken1), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        vm.prank(user2);
        vm.expectRevert();
        seniorVault.rejectLPDeposit(depositId, "Unauthorized");
    }
    
    // ============================================
    // cancelPendingDeposit() Tests
    // ============================================
    
    function testCancelPendingDeposit_Success() public {
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), DEPOSIT_AMOUNT);
        uint256 depositId = seniorVault.depositLP(address(lpToken1), DEPOSIT_AMOUNT);
        
        uint256 userBalanceBefore = lpToken1.balanceOf(user1);
        
        vm.expectEmit(true, true, false, false);
        emit PendingLPDepositCancelled(depositId, user1);
        seniorVault.cancelPendingDeposit(depositId);
        vm.stopPrank();
        
        uint256 userBalanceAfter = lpToken1.balanceOf(user1);
        
        // Check LP returned
        assertEq(userBalanceAfter - userBalanceBefore, DEPOSIT_AMOUNT);
    }
    
    function testCancelPendingDeposit_DepositNotFound() public {
        vm.prank(user1);
        vm.expectRevert();
        seniorVault.cancelPendingDeposit(999);
    }
    
    function testCancelPendingDeposit_NotDepositor() public {
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), DEPOSIT_AMOUNT);
        uint256 depositId = seniorVault.depositLP(address(lpToken1), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        vm.prank(user2);
        vm.expectRevert();
        seniorVault.cancelPendingDeposit(depositId);
    }
    
    function testCancelPendingDeposit_NotPending() public {
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), DEPOSIT_AMOUNT);
        uint256 depositId = seniorVault.depositLP(address(lpToken1), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Admin approves
        vm.prank(admin);
        seniorVault.approveLPDeposit(depositId, LP_PRICE);
        
        // User tries to cancel
        vm.prank(user1);
        vm.expectRevert();
        seniorVault.cancelPendingDeposit(depositId);
    }
    
    // ============================================
    // claimExpiredDeposit() Tests
    // ============================================
    
    function testClaimExpiredDeposit_Success() public {
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), DEPOSIT_AMOUNT);
        uint256 depositId = seniorVault.depositLP(address(lpToken1), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        uint256 userBalanceBefore = lpToken1.balanceOf(user1);
        
        // Warp past expiry
        vm.warp(block.timestamp + 49 hours);
        
        // Anyone can claim
        vm.prank(user2);
        vm.expectEmit(true, true, false, false);
        emit PendingLPDepositExpired(depositId, user1);
        seniorVault.claimExpiredDeposit(depositId);
        
        uint256 userBalanceAfter = lpToken1.balanceOf(user1);
        
        // Check LP returned to original depositor
        assertEq(userBalanceAfter - userBalanceBefore, DEPOSIT_AMOUNT);
    }
    
    function testClaimExpiredDeposit_DepositNotFound() public {
        vm.prank(user1);
        vm.expectRevert();
        seniorVault.claimExpiredDeposit(999);
    }
    
    function testClaimExpiredDeposit_NotExpired() public {
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), DEPOSIT_AMOUNT);
        uint256 depositId = seniorVault.depositLP(address(lpToken1), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Try to claim before expiry
        vm.prank(user2);
        vm.expectRevert();
        seniorVault.claimExpiredDeposit(depositId);
    }
    
    function testClaimExpiredDeposit_NotPending() public {
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), DEPOSIT_AMOUNT);
        uint256 depositId = seniorVault.depositLP(address(lpToken1), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // User cancels
        vm.prank(user1);
        seniorVault.cancelPendingDeposit(depositId);
        
        // Warp past expiry
        vm.warp(block.timestamp + 49 hours);
        
        // Try to claim
        vm.prank(user2);
        vm.expectRevert();
        seniorVault.claimExpiredDeposit(depositId);
    }
    
    // ============================================
    // View Functions Tests
    // ============================================
    
    function testGetPendingDeposit() public {
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), DEPOSIT_AMOUNT);
        uint256 depositId = seniorVault.depositLP(address(lpToken1), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        (address depositor, address lpToken, uint256 amount, uint256 timestamp, uint256 expiresAt,) = 
            seniorVault.getPendingDeposit(depositId);
        
        assertEq(depositor, user1);
        assertEq(lpToken, address(lpToken1));
        assertEq(amount, DEPOSIT_AMOUNT);
        assertEq(timestamp, block.timestamp);
        assertEq(expiresAt, block.timestamp + 48 hours);
    }
    
    function testGetUserDepositIds() public {
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), 300e18);
        
        seniorVault.depositLP(address(lpToken1), 100e18);
        seniorVault.depositLP(address(lpToken1), 100e18);
        seniorVault.depositLP(address(lpToken1), 100e18);
        vm.stopPrank();
        
        uint256[] memory depositIds = seniorVault.getUserDepositIds(user1);
        
        assertEq(depositIds.length, 3);
        assertEq(depositIds[0], 0);
        assertEq(depositIds[1], 1);
        assertEq(depositIds[2], 2);
    }
    
    function testGetUserDepositIds_EmptyArray() public {
        uint256[] memory depositIds = seniorVault.getUserDepositIds(user3);
        assertEq(depositIds.length, 0);
    }
    
    function testGetNextDepositId() public {
        uint256 nextId1 = seniorVault.getNextDepositId();
        assertEq(nextId1, 0);
        
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), DEPOSIT_AMOUNT);
        seniorVault.depositLP(address(lpToken1), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        uint256 nextId2 = seniorVault.getNextDepositId();
        assertEq(nextId2, 1);
    }
    
    // ============================================
    // Complex Workflow Tests
    // ============================================
    
    function testWorkflow_DepositApproveWithdraw() public {
        // 1. User deposits LP
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), DEPOSIT_AMOUNT);
        uint256 depositId = seniorVault.depositLP(address(lpToken1), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // 2. Admin approves
        vm.prank(admin);
        seniorVault.approveLPDeposit(depositId, LP_PRICE);
        
        // 3. User has shares
        uint256 userShares = seniorVault.balanceOf(user1);
        assertGt(userShares, 0, "User should have shares");
    }
    
    function testWorkflow_MultipleUsersMultipleDeposits() public {
        // User1 deposits twice
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), 200e18);
        uint256 depositId1 = seniorVault.depositLP(address(lpToken1), 100e18);
        uint256 depositId2 = seniorVault.depositLP(address(lpToken1), 100e18);
        vm.stopPrank();
        
        // User2 deposits once
        vm.startPrank(user2);
        lpToken1.approve(address(seniorVault), 100e18);
        uint256 depositId3 = seniorVault.depositLP(address(lpToken1), 100e18);
        vm.stopPrank();
        
        // Admin approves user1's first, rejects second
        vm.startPrank(admin);
        seniorVault.approveLPDeposit(depositId1, LP_PRICE);
        seniorVault.rejectLPDeposit(depositId2, "Too many deposits");
        vm.stopPrank();
        
        // User2 cancels their deposit
        vm.prank(user2);
        seniorVault.cancelPendingDeposit(depositId3);
        
        // Check final states
        assertGt(seniorVault.balanceOf(user1), 0, "User1 should have shares");
        assertEq(seniorVault.balanceOf(user2), 0, "User2 should have no shares");
        assertEq(lpToken1.balanceOf(user1), 900e18, "User1 got rejected LP back");
        assertEq(lpToken1.balanceOf(user2), 1000e18, "User2 got cancelled LP back");
    }
    
    function testWorkflow_ExpiredDepositsCleaned() public {
        // Multiple users deposit
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), 100e18);
        uint256 depositId1 = seniorVault.depositLP(address(lpToken1), 100e18);
        vm.stopPrank();
        
        vm.startPrank(user2);
        lpToken1.approve(address(seniorVault), 100e18);
        uint256 depositId2 = seniorVault.depositLP(address(lpToken1), 100e18);
        vm.stopPrank();
        
        vm.startPrank(user3);
        lpToken1.approve(address(seniorVault), 100e18);
        uint256 depositId3 = seniorVault.depositLP(address(lpToken1), 100e18);
        vm.stopPrank();
        
        // Admin approves one
        vm.prank(admin);
        seniorVault.approveLPDeposit(depositId1, LP_PRICE);
        
        // Time passes, others expire
        vm.warp(block.timestamp + 49 hours);
        
        // Good Samaritan claims expired deposits
        vm.startPrank(user1);
        seniorVault.claimExpiredDeposit(depositId2);
        seniorVault.claimExpiredDeposit(depositId3);
        vm.stopPrank();
        
        // Check everyone got their LP back
        assertGt(lpToken1.balanceOf(user2), 0);
        assertGt(lpToken1.balanceOf(user3), 0);
    }
    
    function testWorkflow_DifferentLPTokens() public {
        vm.startPrank(user1);
        
        // Deposit two different LP tokens
        lpToken1.approve(address(seniorVault), 100e18);
        uint256 depositId1 = seniorVault.depositLP(address(lpToken1), 100e18);
        
        lpToken2.approve(address(seniorVault), 100e18);
        uint256 depositId2 = seniorVault.depositLP(address(lpToken2), 100e18);
        
        vm.stopPrank();
        
        // Admin approves both with different prices
        vm.startPrank(admin);
        seniorVault.approveLPDeposit(depositId1, 2e18); // $2 per LP1
        seniorVault.approveLPDeposit(depositId2, 3e18); // $3 per LP2
        vm.stopPrank();
        
        // User should have 200 + 300 = 500 snrUSD
        assertEq(seniorVault.balanceOf(user1), 500e18);
    }
    
    // ============================================
    // Edge Cases
    // ============================================
    
    function testEdgeCase_ApproveJustBeforeExpiry() public {
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), DEPOSIT_AMOUNT);
        uint256 depositId = seniorVault.depositLP(address(lpToken1), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Warp to 1 second before expiry
        vm.warp(block.timestamp + 48 hours - 1);
        
        // Should still work
        vm.prank(admin);
        seniorVault.approveLPDeposit(depositId, LP_PRICE);
        
        assertGt(seniorVault.balanceOf(user1), 0);
    }
    
    function testEdgeCase_CancelAfterExpiry() public {
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), DEPOSIT_AMOUNT);
        uint256 depositId = seniorVault.depositLP(address(lpToken1), DEPOSIT_AMOUNT);
        
        // Warp past expiry
        vm.warp(block.timestamp + 49 hours);
        
        // User can still cancel (they get it back either way)
        seniorVault.cancelPendingDeposit(depositId);
        vm.stopPrank();
        
        assertEq(lpToken1.balanceOf(user1), 1000e18);
    }
    
    function testEdgeCase_VerySmallDeposit() public {
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), 1);
        uint256 depositId = seniorVault.depositLP(address(lpToken1), 1);
        vm.stopPrank();
        
        vm.prank(admin);
        seniorVault.approveLPDeposit(depositId, LP_PRICE);
        
        // Should mint tiny amount of shares
        assertGt(seniorVault.balanceOf(user1), 0);
    }
    
    function testEdgeCase_VeryLargeDeposit() public {
        lpToken1.mint(user1, 1000000e18);
        
        vm.startPrank(user1);
        lpToken1.approve(address(seniorVault), 1000000e18);
        uint256 depositId = seniorVault.depositLP(address(lpToken1), 1000000e18);
        vm.stopPrank();
        
        vm.prank(admin);
        seniorVault.approveLPDeposit(depositId, LP_PRICE);
        
        // Should mint 2M snrUSD
        assertEq(seniorVault.balanceOf(user1), 2000000e18);
    }
}

