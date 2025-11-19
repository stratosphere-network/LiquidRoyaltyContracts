// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MathLib} from "../../src/libraries/MathLib.sol";

/**
 * @title MathLibTest
 * @notice Unit tests for MathLib
 */
contract MathLibTest is Test {
    using MathLib for uint256;
    
    /// @dev Test constants match spec
    function testConstants() public pure {
        assertEq(MathLib.PRECISION, 1e18, "PRECISION should be 1e18");
        assertEq(MathLib.BPS_DENOMINATOR, 10000, "BPS_DENOMINATOR should be 10000");
        
        // APY constants
        assertEq(MathLib.MIN_APY, 11e16, "MIN_APY should be 11%");
        assertEq(MathLib.MID_APY, 12e16, "MID_APY should be 12%");
        assertEq(MathLib.MAX_APY, 13e16, "MAX_APY should be 13%");
        
        // Monthly rates
        assertEq(MathLib.MIN_MONTHLY_RATE, 9167e12, "MIN_MONTHLY_RATE should be 0.009167");
        assertEq(MathLib.MID_MONTHLY_RATE, 10000e12, "MID_MONTHLY_RATE should be 0.010000");
        assertEq(MathLib.MAX_MONTHLY_RATE, 10833e12, "MAX_MONTHLY_RATE should be 0.010833");
        
        // Fee constants
        assertEq(MathLib.MGMT_FEE_ANNUAL, 1e16, "MGMT_FEE_ANNUAL should be 1%");
        assertEq(MathLib.PERF_FEE, 2e16, "PERF_FEE should be 2%");
        assertEq(MathLib.EARLY_WITHDRAWAL_PENALTY, 2e17, "EARLY_WITHDRAWAL_PENALTY should be 20%");
        assertEq(MathLib.WITHDRAWAL_FEE, 1e16, "WITHDRAWAL_FEE should be 1%");
        
        // Backing ratios
        assertEq(MathLib.SENIOR_TARGET_BACKING, 110e16, "SENIOR_TARGET_BACKING should be 110%");
        assertEq(MathLib.SENIOR_TRIGGER_BACKING, 100e16, "SENIOR_TRIGGER_BACKING should be 100%");
        assertEq(MathLib.SENIOR_RESTORE_BACKING, 1009e15, "SENIOR_RESTORE_BACKING should be 100.9%");
        
        // Spillover shares
        assertEq(MathLib.JUNIOR_SPILLOVER_SHARE, 80e16, "JUNIOR_SPILLOVER_SHARE should be 80%");
        assertEq(MathLib.RESERVE_SPILLOVER_SHARE, 20e16, "RESERVE_SPILLOVER_SHARE should be 20%");
        
        // Other
        assertEq(MathLib.DEPOSIT_CAP_MULTIPLIER, 10, "DEPOSIT_CAP_MULTIPLIER should be 10");
        assertEq(MathLib.COOLDOWN_PERIOD, 7 days, "COOLDOWN_PERIOD should be 7 days");
    }
    
    /// @dev Test backing ratio calculation
    function testCalculateBackingRatio() public pure {
        // 100% backing: 1M USD / 1M snrUSD = 1.0
        uint256 ratio = MathLib.calculateBackingRatio(1_000_000e18, 1_000_000e18);
        assertEq(ratio, 1e18, "100% backing should be 1e18");
        
        // 110% backing: 1.1M USD / 1M snrUSD = 1.1
        ratio = MathLib.calculateBackingRatio(1_100_000e18, 1_000_000e18);
        assertEq(ratio, 11e17, "110% backing should be 1.1e18");
        
        // 98% backing: 980K USD / 1M snrUSD = 0.98
        ratio = MathLib.calculateBackingRatio(980_000e18, 1_000_000e18);
        assertEq(ratio, 98e16, "98% backing should be 0.98e18");
    }
    
    /// @dev Test division by zero revert
    function testCalculateBackingRatioZeroSupply() public view {
        // Test that function reverts with zero supply
        try this.externalCalculateBackingRatio(1_000_000e18, 0) {
            revert("Should have reverted");
        } catch {
            // Expected to revert
        }
    }
    
    /// @dev External wrapper for testing revert
    function externalCalculateBackingRatio(uint256 value, uint256 supply) external pure returns (uint256) {
        return MathLib.calculateBackingRatio(value, supply);
    }
    
    /// @dev Test balance from shares calculation
    function testCalculateBalanceFromShares() public pure {
        // Initial: 1000 shares × 1.0 index = 1000 balance
        uint256 balance = MathLib.calculateBalanceFromShares(1000e18, 1e18);
        assertEq(balance, 1000e18, "Initial balance should be 1000");
        
        // After rebase: 1000 shares × 1.01 index = 1010 balance
        balance = MathLib.calculateBalanceFromShares(1000e18, 101e16);
        assertEq(balance, 1010e18, "After rebase balance should be 1010");
    }
    
    /// @dev Test shares from balance calculation
    function testCalculateSharesFromBalance() public pure {
        // Initial: 1000 balance / 1.0 index = 1000 shares
        uint256 shares = MathLib.calculateSharesFromBalance(1000e18, 1e18);
        assertEq(shares, 1000e18, "Initial shares should be 1000");
        
        // After rebase: 1000 balance / 1.05 index = 952.38 shares
        shares = MathLib.calculateSharesFromBalance(1000e18, 105e16);
        assertEq(shares, 952380952380952380952, "After rebase shares should be ~952.38");
    }
    
    /// @dev Test total supply calculation
    function testCalculateTotalSupply() public pure {
        // 1M shares × 1.0 index = 1M supply
        uint256 supply = MathLib.calculateTotalSupply(1_000_000e18, 1e18);
        assertEq(supply, 1_000_000e18, "Initial supply should be 1M");
        
        // 1M shares × 1.1 index = 1.1M supply
        supply = MathLib.calculateTotalSupply(1_000_000e18, 11e17);
        assertEq(supply, 1_100_000e18, "After rebase supply should be 1.1M");
    }
    
    /// @dev Test deposit cap calculation
    function testCalculateDepositCap() public pure {
        // Reserve 625K × 10 = 6.25M cap
        uint256 cap = MathLib.calculateDepositCap(625_000e18);
        assertEq(cap, 6_250_000e18, "Cap should be 10x reserve");
        
        // Reserve 1M × 10 = 10M cap
        cap = MathLib.calculateDepositCap(1_000_000e18);
        assertEq(cap, 10_000_000e18, "Cap should be 10M");
    }
    
    /// @dev Test apply percentage (positive)
    function testApplyPercentagePositive() public pure {
        // 1M + 2.5% = 1.025M
        uint256 result = MathLib.applyPercentage(1_000_000e18, 250);
        assertEq(result, 1_025_000e18, "Should add 2.5%");
        
        // 1M + 10% = 1.1M
        result = MathLib.applyPercentage(1_000_000e18, 1000);
        assertEq(result, 1_100_000e18, "Should add 10%");
    }
    
    /// @dev Test apply percentage (negative)
    function testApplyPercentageNegative() public pure {
        // 1M - 2.5% = 975K
        uint256 result = MathLib.applyPercentage(1_000_000e18, -250);
        assertEq(result, 975_000e18, "Should subtract 2.5%");
        
        // 1M - 10% = 900K
        result = MathLib.applyPercentage(1_000_000e18, -1000);
        assertEq(result, 900_000e18, "Should subtract 10%");
    }
    
    /// @dev Test apply percentage overflow
    function testApplyPercentageOverflow() public view {
        // Test that function reverts with >100% negative percentage
        try this.externalApplyPercentage(1_000_000e18, -10001) {
            revert("Should have reverted");
        } catch {
            // Expected to revert
        }
    }
    
    /// @dev External wrapper for testing revert
    function externalApplyPercentage(uint256 value, int256 pct) external pure returns (uint256) {
        return MathLib.applyPercentage(value, pct);
    }
    
    /// @dev Test mulDiv
    function testMulDiv() public pure {
        // (1000 × 1.1) / 1 = 1100
        uint256 result = MathLib.mulDiv(1000e18, 11e17);
        assertEq(result, 1100e18, "Should multiply correctly");
        
        // (1000 × 0.5) / 1 = 500
        result = MathLib.mulDiv(1000e18, 5e17);
        assertEq(result, 500e18, "Should multiply by 0.5");
    }
    
    /// @dev Test min
    function testMin() public pure {
        assertEq(MathLib.min(100, 200), 100, "Min should return 100");
        assertEq(MathLib.min(200, 100), 100, "Min should return 100");
        assertEq(MathLib.min(100, 100), 100, "Min of equal should return value");
    }
    
    /// @dev Test max
    function testMax() public pure {
        assertEq(MathLib.max(100, 200), 200, "Max should return 200");
        assertEq(MathLib.max(200, 100), 200, "Max should return 200");
        assertEq(MathLib.max(100, 100), 100, "Max of equal should return value");
    }
    
    /// @dev Fuzz test backing ratio
    function testFuzz_CalculateBackingRatio(uint128 vaultValue, uint128 supply) public pure {
        // Set reasonable bounds to avoid rounding to zero or overflow
        vm.assume(supply > 1e18 && supply < type(uint96).max);
        vm.assume(vaultValue > 1e18 && vaultValue < type(uint96).max);
        // Prevent overflow: vaultValue * 1e18 must not overflow
        vm.assume(vaultValue < type(uint128).max / 1e18);
        
        uint256 ratio = MathLib.calculateBackingRatio(vaultValue, supply);
        
        // Ratio should be proportional
        assertTrue(ratio > 0, "Ratio should be positive");
        
        // Check ratio makes sense relative to inputs
        // ratio = (vaultValue * 1e18) / supply
        uint256 expectedRatio = (uint256(vaultValue) * 1e18) / supply;
        assertEq(ratio, expectedRatio, "Ratio calculation should be correct");
    }
}

