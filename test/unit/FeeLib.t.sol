// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {FeeLib} from "../../src/libraries/FeeLib.sol";
import {MathLib} from "../../src/libraries/MathLib.sol";

/**
 * @title FeeLibTest
 * @notice Unit tests for FeeLib
 */
contract FeeLibTest is Test {
    /// @dev Test management fee calculation
    function testCalculateManagementFee() public pure {
        // 10.5M vault × (1% / 12) = 8,750 fee
        uint256 fee = FeeLib.calculateManagementFee(10_500_000e18);
        assertEq(fee, 8_750e18, "Management fee should be ~8,750");
        
        // 1M vault × (1% / 12) = 833.33 fee
        fee = FeeLib.calculateManagementFee(1_000_000e18);
        // Should be approximately 833.33
        assertApproxEqAbs(fee, 833333333333333333333, 1e18, "Management fee should be ~833.33");
    }
    
    /// @dev Test performance fee calculation
    function testCalculatePerformanceFee() public pure {
        // 100K user tokens × 2% = 2K fee tokens
        uint256 fee = FeeLib.calculatePerformanceFee(100_000e18);
        assertEq(fee, 2_000e18, "Performance fee should be 2K");
        
        // 91,670 user tokens × 2% = 1,833.4 fee tokens
        fee = FeeLib.calculatePerformanceFee(91_670e18);
        assertEq(fee, 1_833_400e15, "Performance fee should be 1,833.4");
    }
    
    /// @dev Test withdrawal penalty (cooldown met)
    function testCalculateWithdrawalPenaltyNoPenalty() public view {
        uint256 amount = 1000e18;
        uint256 cooldownStart = 1000; // Some time in past
        uint256 currentTime = cooldownStart + 8 days; // 8 days later (>7 days)
        
        (uint256 penalty, uint256 netAmount) = FeeLib.calculateWithdrawalPenalty(
            amount,
            cooldownStart,
            currentTime
        );
        
        assertEq(penalty, 0, "Penalty should be 0 after cooldown");
        assertEq(netAmount, amount, "Net amount should equal full amount");
    }
    
    /// @dev Test withdrawal penalty (cooldown NOT met)
    function testCalculateWithdrawalPenaltyWithPenalty() public view {
        uint256 amount = 1000e18;
        uint256 cooldownStart = 1000; // Some time in past
        uint256 currentTime = cooldownStart + 3 days; // 3 days later (<7 days)
        
        (uint256 penalty, uint256 netAmount) = FeeLib.calculateWithdrawalPenalty(
            amount,
            cooldownStart,
            currentTime
        );
        
        // Penalty = 1000 × 20% = 200
        assertEq(penalty, 200e18, "Penalty should be 200 (20%)");
        assertEq(netAmount, 800e18, "Net amount should be 800");
    }
    
    /// @dev Test deduct management fee
    // DEPRECATED: Management fee is now minted as tokens, not deducted from vault value
    // function testDeductManagementFee() public pure {
    //     uint256 grossValue = 10_500_000e18;
    //     
    //     (uint256 netValue, uint256 feeAmount) = FeeLib.deductManagementFee(grossValue);
    //     
    //     // Fee should be ~8,750
    //     assertEq(feeAmount, 8_750e18, "Fee should be 8,750");
    //     // Net should be 10,500,000 - 8,750 = 10,491,250
    //     assertEq(netValue, 10_491_250e18, "Net value should be 10,491,250");
    // }
    
    /// @dev Test calculate rebase supply (13% APY)
    function testCalculateRebaseSupply13APY() public pure {
        uint256 currentSupply = 10_000_000e18;
        uint256 monthlyRate = MathLib.MAX_MONTHLY_RATE; // 13% APY
        
        (uint256 newSupply, uint256 userTokens, uint256 feeTokens) = 
            FeeLib.calculateRebaseSupply(currentSupply, monthlyRate);
        
        // User tokens = 10M × 0.010833 = 108,330
        assertEq(userTokens, 108_330e18, "User tokens should be 108,330");
        
        // Fee tokens = 108,330 × 0.02 = 2,166.6
        assertEq(feeTokens, 2_166_600e15, "Fee tokens should be 2,166.6");
        
        // New supply = 10M + 108,330 + 2,166.6 = 10,110,496.6
        assertApproxEqAbs(newSupply, 10_110_496_600e15, 1e18, "New supply should be ~10,110,497");
    }
    
    /// @dev Test calculate rebase supply (12% APY)
    function testCalculateRebaseSupply12APY() public pure {
        uint256 currentSupply = 10_000_000e18;
        uint256 monthlyRate = MathLib.MID_MONTHLY_RATE; // 12% APY
        
        (uint256 newSupply, uint256 userTokens, uint256 feeTokens) = 
            FeeLib.calculateRebaseSupply(currentSupply, monthlyRate);
        
        // User tokens = 10M × 0.010000 = 100,000
        assertEq(userTokens, 100_000e18, "User tokens should be 100,000");
        
        // Fee tokens = 100,000 × 0.02 = 2,000
        assertEq(feeTokens, 2_000e18, "Fee tokens should be 2,000");
        
        // New supply = 10M + 100,000 + 2,000 = 10,102,000
        assertEq(newSupply, 10_102_000e18, "New supply should be 10,102,000");
    }
    
    /// @dev Test calculate rebase supply (11% APY)
    function testCalculateRebaseSupply11APY() public pure {
        uint256 currentSupply = 10_000_000e18;
        uint256 monthlyRate = MathLib.MIN_MONTHLY_RATE; // 11% APY
        
        (uint256 newSupply, uint256 userTokens, uint256 feeTokens) = 
            FeeLib.calculateRebaseSupply(currentSupply, monthlyRate);
        
        // User tokens = 10M × 0.009167 = 91,670
        assertEq(userTokens, 91_670e18, "User tokens should be 91,670");
        
        // Fee tokens = 91,670 × 0.02 = 1,833.4
        assertEq(feeTokens, 1_833_400e15, "Fee tokens should be 1,833.4");
        
        // New supply = 10M + 91,670 + 1,833.4 = 10,093,503.4
        assertApproxEqAbs(newSupply, 10_093_503_400e15, 1e18, "New supply should be ~10,093,503");
    }
    
    /// @dev Test calculate new rebase index
    function testCalculateNewRebaseIndex() public pure {
        uint256 oldIndex = 1e18; // 1.0
        uint256 monthlyRate = MathLib.MAX_MONTHLY_RATE; // 13% APY
        
        uint256 newIndex = FeeLib.calculateNewRebaseIndex(oldIndex, monthlyRate);
        
        // New index = 1.0 × (1 + 0.010833 × 1.02) = 1.011049660
        // Expected: 1011049660000000000 (18 decimals precision)
        assertApproxEqRel(newIndex, 1011049660000000000, 1e15, "New index should be ~1.01105");
    }
    
    /// @dev Test rebase index growth over multiple rebases
    function testRebaseIndexGrowth() public pure {
        uint256 index = 1e18; // Start at 1.0
        
        // Simulate 12 monthly rebases at 13% APY
        for (uint256 i = 0; i < 12; i++) {
            index = FeeLib.calculateNewRebaseIndex(index, MathLib.MAX_MONTHLY_RATE);
        }
        
        // After 12 months at 13% APY (with 2% perf fee)
        // Each month: 1.011049660 multiplier
        // After 12 months: 1140958504074576720 (actual compounded value)
        // Use 2% tolerance for compounding precision
        assertApproxEqRel(index, 1140958504074576720, 2e16, "After 12 months should be ~1.1410");
    }
    
    /// @dev Fuzz test management fee is always reasonable
    function testFuzz_ManagementFee(uint128 vaultValue) public pure {
        vm.assume(vaultValue > 12e18); // Minimum value to get non-zero fee
        vm.assume(vaultValue < type(uint96).max); // Prevent overflow
        
        uint256 fee = FeeLib.calculateManagementFee(vaultValue);
        
        // Fee should be approximately 1%/12 = 0.0833% of vault
        // With rounding, should be less than 0.09% and more than 0.07%
        assertTrue(fee <= (vaultValue * 9) / 10000, "Fee should be <=0.09% of vault");
        assertTrue(fee >= (vaultValue * 7) / 10000, "Fee should be >=0.07% of vault");
        assertTrue(fee > 0, "Fee should be positive");
    }
    
    /// @dev Fuzz test performance fee is always 2%
    function testFuzz_PerformanceFee(uint128 userTokens) public pure {
        vm.assume(userTokens > 0);
        vm.assume(userTokens < type(uint96).max); // Prevent overflow
        
        uint256 fee = FeeLib.calculatePerformanceFee(userTokens);
        
        // Fee should be exactly 2% of user tokens
        uint256 expected = (userTokens * 2) / 100;
        assertApproxEqRel(fee, expected, 1e15, "Fee should be ~2% of user tokens");
    }
}

