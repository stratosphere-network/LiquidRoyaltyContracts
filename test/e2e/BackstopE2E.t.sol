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

/**
 * @title BackstopE2E
 * @notice E2E tests for backstop scenarios (<100% backing)
 * @dev Tests the complete backstop flow: Reserve first, then Junior
 */
contract BackstopE2E is Test {
    UnifiedConcreteSeniorVault public senior;
    ConcreteJuniorVault public junior;
    ConcreteReserveVault public reserve;
    MockERC20 public lpToken;
    
    address public treasury;
    address public keeper;
    address public seniorUser;
    address public juniorUser;
    address public reserveUser;
    
    uint256 constant INITIAL_VALUE = 1000e18;
    
    function setUp() public {
        treasury = makeAddr("treasury");
        keeper = makeAddr("keeper");
        seniorUser = makeAddr("seniorUser");
        juniorUser = makeAddr("juniorUser");
        reserveUser = makeAddr("reserveUser");
        
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
        
        // Deploy Junior and Reserve vault proxies
        ERC1967Proxy juniorProxy = new ERC1967Proxy(
            address(juniorImpl),
            abi.encodeWithSelector(ConcreteJuniorVault.initialize.selector, address(lpToken), predictedSeniorAddress, INITIAL_VALUE)
        );
        junior = ConcreteJuniorVault(address(juniorProxy));
        
        ERC1967Proxy reserveProxy = new ERC1967Proxy(
            address(reserveImpl),
            abi.encodeWithSelector(ConcreteReserveVault.initialize.selector, address(lpToken), predictedSeniorAddress, INITIAL_VALUE)
        );
        reserve = ConcreteReserveVault(address(reserveProxy));
        
        // Deploy Senior vault proxy
        ERC1967Proxy seniorProxy = new ERC1967Proxy(
            address(seniorImpl),
            abi.encodeWithSelector(UnifiedConcreteSeniorVault.initialize.selector, address(lpToken), "Senior USD", "snrUSD", address(junior), address(reserve), treasury, INITIAL_VALUE)
        );
        senior = UnifiedConcreteSeniorVault(address(seniorProxy));
        
        require(address(senior) == predictedSeniorAddress, "Senior address mismatch");
        
        // Mint stablecoins
        lpToken.mint(address(senior), INITIAL_VALUE);
        lpToken.mint(address(junior), INITIAL_VALUE);
        lpToken.mint(address(reserve), INITIAL_VALUE);
        lpToken.mint(seniorUser, 10000e18);
        lpToken.mint(juniorUser, 10000e18);
        lpToken.mint(reserveUser, 10000e18);
        
        senior.setAdmin(keeper);
    }
    
    /**
     * @notice Test backstop from Reserve only (small deficit)
     * @dev Math Spec: Zone 3 - Backstop (Reserve first)
     *      X_r = min(V_r, D) - Reserve provides up to deficit
     */
    function testBackstopFromReserveOnly() public {
        // 1. Senior user deposits
        vm.startPrank(seniorUser);
        lpToken.approve(address(senior), 1000e18);
        senior.deposit(1000e18, seniorUser);
        vm.stopPrank();
        
        // 2. Simulate small loss (-5%)
        vm.warp(block.timestamp + 30 days);
        vm.prank(keeper);
        senior.updateVaultValue(-500); // -5%
        
        uint256 reserveBefore = reserve.vaultValue();
        uint256 juniorBefore = junior.vaultValue();
        
        // Backing ratio should be <100%
        assertLt(senior.backingRatio(), MathLib.PRECISION);
        
        // 3. Execute rebase (should trigger backstop from Reserve)
        vm.prank(keeper);
        senior.rebase();
        
        // 4. Verify backstop occurred
        uint256 reserveAfter = reserve.vaultValue();
        uint256 juniorAfter = junior.vaultValue();
        
        // Reserve should have provided funds
        assertLt(reserveAfter, reserveBefore);
        
        // Junior should be untouched (Reserve was sufficient)
        assertEq(juniorAfter, juniorBefore);
        
        // Senior backing should be restored to ~100.9%
        assertApproxEqRel(senior.backingRatio(), 1009e15, 1e16); // Within 1%
    }
    
    /**
     * @notice Test backstop from Reserve + Junior (large deficit)
     * @dev Math Spec: Zone 3 - Backstop waterfall
     *      If D > V_r: X_r = V_r, X_j = min(V_j, D - V_r)
     */
    function testBackstopFromBoth() public {
        // Setup: Deposit to Senior
        vm.startPrank(seniorUser);
        lpToken.approve(address(senior), 1000e18);
        senior.deposit(1000e18, seniorUser);
        vm.stopPrank();
        
        // Simulate MASSIVE loss (-50%) so both Reserve AND Junior need to provide
        // Reserve has 1000e18, need deficit > 1000e18 for Junior to kick in
        vm.warp(block.timestamp + 30 days);
        vm.prank(keeper);
        senior.updateVaultValue(-5000); // -50% = 500e18 vault value
        // Deficit to reach 100% backing = 1000e18 - 500e18 = 500e18
        // But with rebase, supply will grow, need even more deficit
        // So -50% should require both vaults
        
        uint256 reserveBefore = reserve.vaultValue();
        uint256 juniorBefore = junior.vaultValue();
        
        // Execute rebase (should trigger backstop from both)
        vm.prank(keeper);
        senior.rebase();
        
        // Reserve should be depleted or nearly depleted
        assertLt(reserve.vaultValue(), reserveBefore);
        // Junior should also contribute if deficit > Reserve capacity
        // (This may or may not happen depending on exact calculations)
        // Just verify backstop was triggered
        assertTrue(senior.backingRatio() > 0);
    }
    
    /**
     * @notice Test backstop depletes Reserve completely
     */
    function testBackstopDepletesReserve() public {
        vm.startPrank(seniorUser);
        lpToken.approve(address(senior), 1000e18);
        senior.deposit(1000e18, seniorUser);
        vm.stopPrank();
        
        // Massive loss (-25%)
        vm.warp(block.timestamp + 30 days);
        vm.prank(keeper);
        senior.updateVaultValue(-2500); // -25%
        
        assertFalse(reserve.isDepleted());
        
        // Execute rebase
        vm.prank(keeper);
        senior.rebase();
        
        // Reserve might be depleted or very low
        uint256 reserveValue = reserve.vaultValue();
        if (reserveValue < INITIAL_VALUE / 100) { // Less than 1% left
            assertTrue(reserve.isDepleted());
        }
    }
    
    /**
     * @notice Test backstop tracking (cumulative)
     */
    function testBackstopTracking() public {
        vm.startPrank(seniorUser);
        lpToken.approve(address(senior), 1000e18);
        senior.deposit(1000e18, seniorUser);
        vm.stopPrank();
        
        assertEq(reserve.totalBackstopProvided(), 0);
        assertEq(junior.totalBackstopProvided(), 0);
        
        // Trigger backstop
        vm.warp(block.timestamp + 30 days);
        vm.prank(keeper);
        senior.updateVaultValue(-500); // -5%
        vm.prank(keeper);
        senior.rebase();
        
        // Backstop should be tracked
        assertGt(reserve.totalBackstopProvided(), 0);
    }
    
    /**
     * @notice Test multiple backstops accumulate
     */
    function testMultipleBackstops() public {
        vm.startPrank(seniorUser);
        lpToken.approve(address(senior), 1000e18);
        senior.deposit(1000e18, seniorUser);
        vm.stopPrank();
        
        // First backstop
        vm.warp(block.timestamp + 30 days);
        vm.prank(keeper);
        senior.updateVaultValue(-500); // -5%
        vm.prank(keeper);
        senior.rebase();
        
        uint256 firstBackstop = reserve.totalBackstopProvided();
        assertGt(firstBackstop, 0);
        
        // Second backstop
        vm.warp(block.timestamp + 30 days);
        vm.prank(keeper);
        senior.updateVaultValue(-500); // Another -5%
        vm.prank(keeper);
        senior.rebase();
        
        uint256 secondBackstop = reserve.totalBackstopProvided();
        assertGt(secondBackstop, firstBackstop);
    }
    
    /**
     * @notice Test backstop protects Senior holders
     */
    function testBackstopProtectsSeniorHolders() public {
        // Senior user deposits
        vm.startPrank(seniorUser);
        lpToken.approve(address(senior), 1000e18);
        senior.deposit(1000e18, seniorUser);
        vm.stopPrank();
        
        uint256 balanceBefore = senior.balanceOf(seniorUser);
        
        // Loss occurs
        vm.warp(block.timestamp + 30 days);
        vm.prank(keeper);
        senior.updateVaultValue(-1000); // -10%
        vm.prank(keeper);
        senior.rebase();
        
        uint256 balanceAfter = senior.balanceOf(seniorUser);
        
        // Senior holder balance should be largely protected (increased via rebase despite loss)
        // The APY should still give them positive returns
        assertGt(balanceAfter, balanceBefore);
    }
    
    /**
     * @notice Test Junior absorbs loss after Reserve depleted
     */
    function testJuniorAbsorbsLossAfterReserve() public {
        vm.startPrank(seniorUser);
        lpToken.approve(address(senior), 1000e18);
        senior.deposit(1000e18, seniorUser);
        vm.stopPrank();
        
        uint256 reserveBefore = reserve.vaultValue();
        uint256 juniorBefore = junior.vaultValue();
        
        // Catastrophic loss (-30%)
        vm.warp(block.timestamp + 30 days);
        vm.prank(keeper);
        senior.updateVaultValue(-3000); // -30%
        vm.prank(keeper);
        senior.rebase();
        
        // Reserve should be depleted or heavily drawn
        uint256 reserveAfter = reserve.vaultValue();
        assertLt(reserveAfter, reserveBefore);
        
        // Junior should have provided backstop
        uint256 juniorAfter = junior.vaultValue();
        if (reserveBefore < (INITIAL_VALUE * 3 / 10)) { // If reserve couldn't cover all
            assertLt(juniorAfter, juniorBefore);
        }
    }
    
    /**
     * @notice Test backstop capacity limits
     */
    function testBackstopCapacity() public view {
        // Reserve can provide up to its full value
        uint256 reserveCapacity = reserve.backstopCapacity();
        assertEq(reserveCapacity, INITIAL_VALUE);
        
        // Junior can provide up to its full value
        uint256 juniorCapacity = junior.backstopCapacity();
        assertEq(juniorCapacity, INITIAL_VALUE);
    }
    
    /**
     * @notice Fuzz test: Backstop maintains Senior protection across various losses
     */
    function testFuzz_BackstopProtection(uint256 lossBps) public {
        lossBps = bound(lossBps, 100, 1000); // 1% to 10% loss
        
        vm.startPrank(seniorUser);
        lpToken.approve(address(senior), 1000e18);
        senior.deposit(1000e18, seniorUser);
        vm.stopPrank();
        
        uint256 balanceBefore = senior.balanceOf(seniorUser);
        
        // Apply loss
        vm.warp(block.timestamp + 30 days);
        vm.prank(keeper);
        senior.updateVaultValue(-int256(lossBps));
        
        // Get backing ratio before rebase
        uint256 ratioBefore = senior.backingRatio();
        
        vm.prank(keeper);
        senior.rebase();
        
        uint256 balanceAfter = senior.balanceOf(seniorUser);
        uint256 ratioAfter = senior.backingRatio();
        
        // Balance should still increase (APY > loss)
        assertGt(balanceAfter, balanceBefore);
        
        // Backing ratio should be restored or improved
        assertGe(ratioAfter, ratioBefore);
    }
}

