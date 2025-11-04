// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {RebaseLib} from "../../src/libraries/RebaseLib.sol";
import {MathLib} from "../../src/libraries/MathLib.sol";

/**
 * @title RebaseLibTest
 * @notice Unit tests for RebaseLib (Dynamic APY Selection)
 */
contract RebaseLibTest is Test {
    /// @dev Test 13% APY selection (high backing)
    function testSelectDynamicAPY_13Percent() public pure {
        uint256 currentSupply = 10_000_000e18;
        uint256 netVaultValue = 11_140_712e18; // High backing
        
        RebaseLib.APYSelection memory selection = RebaseLib.selectDynamicAPY(
            currentSupply,
            netVaultValue
        );
        
        assertEq(selection.apyTier, 3, "Should select 13% APY");
        assertEq(selection.selectedRate, MathLib.MAX_MONTHLY_RATE, "Rate should be 13% monthly");
        assertFalse(selection.backstopNeeded, "Should not need backstop");
        
        // Check backing is >= 100%
        uint256 backing = (netVaultValue * MathLib.PRECISION) / selection.newSupply;
        assertTrue(backing >= MathLib.PRECISION, "Backing should be >= 100%");
    }
    
    /// @dev Test 12% APY selection (medium backing)
    function testSelectDynamicAPY_12Percent() public pure {
        uint256 currentSupply = 10_000_000e18;
        // For 13% APY: newSupply = 10M * 1.011050 = 10,110,500 -> need value >= 10,110,500
        // For 12% APY: newSupply = 10M * 1.010200 = 10,102,000 -> need value >= 10,102,000
        // Use value that supports 12% but NOT 13%
        uint256 netVaultValue = 10_105_000e18; // Between 10,102,000 and 10,110,500
        
        RebaseLib.APYSelection memory selection = RebaseLib.selectDynamicAPY(
            currentSupply,
            netVaultValue
        );
        
        assertEq(selection.apyTier, 2, "Should select 12% APY");
        assertEq(selection.selectedRate, MathLib.MID_MONTHLY_RATE, "Rate should be 12% monthly");
        assertFalse(selection.backstopNeeded, "Should not need backstop");
        
        // Check backing is >= 100%
        uint256 backing = (netVaultValue * MathLib.PRECISION) / selection.newSupply;
        assertTrue(backing >= MathLib.PRECISION, "Backing should be >= 100%");
    }
    
    /// @dev Test 11% APY selection (low backing)
    function testSelectDynamicAPY_11Percent() public pure {
        uint256 currentSupply = 10_000_000e18;
        uint256 netVaultValue = 10_100_000e18; // Low backing
        
        RebaseLib.APYSelection memory selection = RebaseLib.selectDynamicAPY(
            currentSupply,
            netVaultValue
        );
        
        assertEq(selection.apyTier, 1, "Should select 11% APY");
        assertEq(selection.selectedRate, MathLib.MIN_MONTHLY_RATE, "Rate should be 11% monthly");
        assertFalse(selection.backstopNeeded, "Should not need backstop");
        
        // Check backing is >= 100%
        uint256 backing = (netVaultValue * MathLib.PRECISION) / selection.newSupply;
        assertTrue(backing >= MathLib.PRECISION, "Backing should be >= 100%");
    }
    
    /// @dev Test 11% APY with backstop needed (very low backing)
    function testSelectDynamicAPY_11PercentWithBackstop() public pure {
        uint256 currentSupply = 10_000_000e18;
        uint256 netVaultValue = 10_000_000e18; // Exactly 100% (will depeg after rebase)
        
        RebaseLib.APYSelection memory selection = RebaseLib.selectDynamicAPY(
            currentSupply,
            netVaultValue
        );
        
        assertEq(selection.apyTier, 1, "Should select 11% APY");
        assertEq(selection.selectedRate, MathLib.MIN_MONTHLY_RATE, "Rate should be 11% monthly");
        assertTrue(selection.backstopNeeded, "Should need backstop");
        
        // Check backing is < 100% (depegged)
        uint256 backing = (netVaultValue * MathLib.PRECISION) / selection.newSupply;
        assertTrue(backing < MathLib.PRECISION, "Backing should be < 100%");
    }
    
    /// @dev Test edge case: exactly at 100% after 13% APY
    function testSelectDynamicAPY_ExactlyAtPeg() public pure {
        // Calculate exact value needed for 100% backing with 13% APY
        uint256 currentSupply = 10_000_000e18;
        // New supply with 13% = 10M × 1.011050 = 10,110,500
        uint256 requiredValue = 10_110_500e18;
        
        RebaseLib.APYSelection memory selection = RebaseLib.selectDynamicAPY(
            currentSupply,
            requiredValue
        );
        
        assertEq(selection.apyTier, 3, "Should select 13% APY at exactly 100%");
        assertFalse(selection.backstopNeeded, "Should not need backstop at exactly 100%");
    }
    
    /// @dev Test simulateAllAPYs
    function testSimulateAllAPYs() public pure {
        uint256 currentSupply = 10_000_000e18;
        uint256 netVaultValue = 10_150_000e18;
        
        (uint256 backing13, uint256 backing12, uint256 backing11) = 
            RebaseLib.simulateAllAPYs(currentSupply, netVaultValue);
        
        // All backings should be positive
        assertTrue(backing13 > 0, "13% backing should be positive");
        assertTrue(backing12 > 0, "12% backing should be positive");
        assertTrue(backing11 > 0, "11% backing should be positive");
        
        // 11% should have highest backing (lowest supply increase)
        assertTrue(backing11 > backing12, "11% should have higher backing than 12%");
        assertTrue(backing12 > backing13, "12% should have higher backing than 13%");
    }
    
    /// @dev Test getAPYInBps
    function testGetAPYInBps() public pure {
        assertEq(RebaseLib.getAPYInBps(3), 1300, "Tier 3 should be 13%");
        assertEq(RebaseLib.getAPYInBps(2), 1200, "Tier 2 should be 12%");
        assertEq(RebaseLib.getAPYInBps(1), 1100, "Tier 1 should be 11%");
        assertEq(RebaseLib.getAPYInBps(0), 0, "Invalid tier should be 0");
    }
    
    /// @dev Test getMonthlyRate
    function testGetMonthlyRate() public pure {
        assertEq(RebaseLib.getMonthlyRate(3), MathLib.MAX_MONTHLY_RATE, "Tier 3 rate");
        assertEq(RebaseLib.getMonthlyRate(2), MathLib.MID_MONTHLY_RATE, "Tier 2 rate");
        assertEq(RebaseLib.getMonthlyRate(1), MathLib.MIN_MONTHLY_RATE, "Tier 1 rate");
        assertEq(RebaseLib.getMonthlyRate(0), 0, "Invalid tier rate");
    }
    
    /// @dev Test APY selection prioritizes higher rates
    function testAPYPrioritizesHigher() public pure {
        uint256 currentSupply = 10_000_000e18;
        
        // Test with increasing backing to see when each tier kicks in
        
        // Very high backing - should get 13%
        uint256 netValue = 11_200_000e18;
        RebaseLib.APYSelection memory selection = RebaseLib.selectDynamicAPY(currentSupply, netValue);
        assertEq(selection.apyTier, 3, "High backing should select 13%");
        
        // Medium backing - might get 12% or 13%
        netValue = 10_150_000e18;
        selection = RebaseLib.selectDynamicAPY(currentSupply, netValue);
        assertTrue(selection.apyTier >= 2, "Medium backing should select at least 12%");
        
        // Low backing - should get 11%
        netValue = 10_100_000e18;
        selection = RebaseLib.selectDynamicAPY(currentSupply, netValue);
        assertEq(selection.apyTier, 1, "Low backing should select 11%");
    }
    
    /// @dev Fuzz test: APY selection always maintains peg or flags backstop
    function testFuzz_APYSelection(uint128 supply, uint128 value) public pure {
        vm.assume(supply > 1000e18 && supply < type(uint96).max);
        vm.assume(value > 1000e18 && value < type(uint96).max);
        
        RebaseLib.APYSelection memory selection = RebaseLib.selectDynamicAPY(supply, value);
        
        // Calculate backing
        uint256 backing = (value * MathLib.PRECISION) / selection.newSupply;
        
        if (selection.backstopNeeded) {
            // If backstop needed, backing must be < 100%
            assertTrue(backing < MathLib.PRECISION, "Backstop implies < 100% backing");
        } else {
            // If no backstop, backing must be >= 100%
            assertTrue(backing >= MathLib.PRECISION, "No backstop implies >= 100% backing");
        }
        
        // APY tier must be valid
        assertTrue(selection.apyTier >= 1 && selection.apyTier <= 3, "APY tier must be 1-3");
    }
}

