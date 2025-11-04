// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {SpilloverLib} from "../../src/libraries/SpilloverLib.sol";
import {MathLib} from "../../src/libraries/MathLib.sol";

/**
 * @title SpilloverLibTest
 * @notice Unit tests for SpilloverLib (Three-Zone System)
 */
contract SpilloverLibTest is Test {
    /// @dev Test zone determination
    function testDetermineZone() public pure {
        // Zone 1: > 110%
        SpilloverLib.Zone zone = SpilloverLib.determineZone(115e16);
        assertEq(uint8(zone), uint8(SpilloverLib.Zone.SPILLOVER), "115% should be SPILLOVER");
        
        // Zone 2: 100% to 110%
        zone = SpilloverLib.determineZone(105e16);
        assertEq(uint8(zone), uint8(SpilloverLib.Zone.HEALTHY), "105% should be HEALTHY");
        
        zone = SpilloverLib.determineZone(100e16);
        assertEq(uint8(zone), uint8(SpilloverLib.Zone.HEALTHY), "100% should be HEALTHY");
        
        zone = SpilloverLib.determineZone(110e16);
        assertEq(uint8(zone), uint8(SpilloverLib.Zone.HEALTHY), "110% should be HEALTHY");
        
        // Zone 3: < 100%
        zone = SpilloverLib.determineZone(98e16);
        assertEq(uint8(zone), uint8(SpilloverLib.Zone.BACKSTOP), "98% should be BACKSTOP");
    }
    
    /// @dev Test profit spillover calculation (Zone 1)
    function testCalculateProfitSpillover() public pure {
        uint256 netValue = 1_150_000e18; // Senior has $1.15M
        uint256 newSupply = 1_000_000e18; // Supply is 1M snrUSD
        // Backing: 115%
        
        SpilloverLib.ProfitSpillover memory spillover = 
            SpilloverLib.calculateProfitSpillover(netValue, newSupply);
        
        // Target (110%): 1M × 1.10 = 1.1M
        // Excess: 1.15M - 1.1M = 50K
        assertEq(spillover.excessAmount, 50_000e18, "Excess should be 50K");
        
        // Junior (80%): 50K × 0.80 = 40K
        assertEq(spillover.toJunior, 40_000e18, "Junior should get 40K");
        
        // Reserve (20%): 50K × 0.20 = 10K
        assertEq(spillover.toReserve, 10_000e18, "Reserve should get 10K");
        
        // Senior final: exactly 110%
        assertEq(spillover.seniorFinalValue, 1_100_000e18, "Senior should be 1.1M (110%)");
    }
    
    /// @dev Test no spillover when at exactly 110%
    function testCalculateProfitSpilloverAtTarget() public pure {
        uint256 netValue = 1_100_000e18; // Exactly 110%
        uint256 newSupply = 1_000_000e18;
        
        SpilloverLib.ProfitSpillover memory spillover = 
            SpilloverLib.calculateProfitSpillover(netValue, newSupply);
        
        // No excess at exactly 110%
        assertEq(spillover.excessAmount, 0, "Should be no excess at 110%");
        assertEq(spillover.toJunior, 0, "Junior should get 0");
        assertEq(spillover.toReserve, 0, "Reserve should get 0");
        assertEq(spillover.seniorFinalValue, netValue, "Senior value unchanged");
    }
    
    /// @dev Test backstop calculation (Zone 3)
    function testCalculateBackstop() public pure {
        uint256 netValue = 980_000e18; // Senior has $980K (98% backing)
        uint256 newSupply = 1_000_000e18; // Supply is 1M snrUSD
        uint256 reserveValue = 625_000e18; // Reserve has $625K
        uint256 juniorValue = 850_000e18; // Junior has $850K
        
        SpilloverLib.BackstopResult memory backstop = 
            SpilloverLib.calculateBackstop(netValue, newSupply, reserveValue, juniorValue);
        
        // Restore target (100.9%): 1M × 1.009 = 1.009M
        // Deficit: 1.009M - 980K = 29K
        assertEq(backstop.deficitAmount, 29_000e18, "Deficit should be 29K");
        
        // Reserve provides: min(625K, 29K) = 29K
        assertEq(backstop.fromReserve, 29_000e18, "Reserve should provide 29K");
        
        // Junior not needed
        assertEq(backstop.fromJunior, 0, "Junior should provide 0");
        
        // Fully restored
        assertTrue(backstop.fullyRestored, "Should be fully restored");
        
        // Senior final: 980K + 29K = 1.009M
        assertEq(backstop.seniorFinalValue, 1_009_000e18, "Senior should be 1.009M");
    }
    
    /// @dev Test backstop with Reserve depleted (Junior kicks in)
    function testCalculateBackstopJuniorNeeded() public pure {
        uint256 netValue = 500_000e18; // Senior has $500K (severe depeg!)
        uint256 newSupply = 1_000_000e18;
        uint256 reserveValue = 200_000e18; // Reserve has only $200K
        uint256 juniorValue = 850_000e18;
        
        SpilloverLib.BackstopResult memory backstop = 
            SpilloverLib.calculateBackstop(netValue, newSupply, reserveValue, juniorValue);
        
        // Deficit: 1.009M - 500K = 509K
        assertEq(backstop.deficitAmount, 509_000e18, "Deficit should be 509K");
        
        // Reserve provides all: 200K
        assertEq(backstop.fromReserve, 200_000e18, "Reserve should provide all 200K");
        
        // Junior provides remaining: 509K - 200K = 309K
        assertEq(backstop.fromJunior, 309_000e18, "Junior should provide 309K");
        
        // Fully restored
        assertTrue(backstop.fullyRestored, "Should be fully restored");
        
        // Senior final: 500K + 200K + 309K = 1.009M
        assertEq(backstop.seniorFinalValue, 1_009_000e18, "Senior should be 1.009M");
    }
    
    /// @dev Test backstop insufficient (catastrophic scenario)
    function testCalculateBackstopInsufficient() public pure {
        uint256 netValue = 100_000e18; // Senior has only $100K (catastrophic!)
        uint256 newSupply = 1_000_000e18;
        uint256 reserveValue = 200_000e18;
        uint256 juniorValue = 300_000e18;
        
        SpilloverLib.BackstopResult memory backstop = 
            SpilloverLib.calculateBackstop(netValue, newSupply, reserveValue, juniorValue);
        
        // Deficit: 1.009M - 100K = 909K
        assertEq(backstop.deficitAmount, 909_000e18, "Deficit should be 909K");
        
        // Reserve provides all: 200K
        assertEq(backstop.fromReserve, 200_000e18, "Reserve depleted");
        
        // Junior provides all: 300K
        assertEq(backstop.fromJunior, 300_000e18, "Junior depleted");
        
        // NOT fully restored (still 409K short!)
        assertFalse(backstop.fullyRestored, "Should NOT be fully restored");
        
        // Senior final: 100K + 200K + 300K = 600K (still only 60% backing!)
        assertEq(backstop.seniorFinalValue, 600_000e18, "Senior should be 600K");
    }
    
    /// @dev Test helper functions
    function testHelperFunctions() public pure {
        // isHealthyBufferZone
        assertTrue(SpilloverLib.isHealthyBufferZone(105e16), "105% is healthy");
        assertTrue(SpilloverLib.isHealthyBufferZone(100e16), "100% is healthy");
        assertTrue(SpilloverLib.isHealthyBufferZone(110e16), "110% is healthy");
        assertFalse(SpilloverLib.isHealthyBufferZone(111e16), "111% is not healthy");
        assertFalse(SpilloverLib.isHealthyBufferZone(99e16), "99% is not healthy");
        
        // needsProfitSpillover
        assertTrue(SpilloverLib.needsProfitSpillover(115e16), "115% needs spillover");
        assertFalse(SpilloverLib.needsProfitSpillover(110e16), "110% doesn't need spillover");
        assertFalse(SpilloverLib.needsProfitSpillover(105e16), "105% doesn't need spillover");
        
        // needsBackstop
        assertTrue(SpilloverLib.needsBackstop(98e16), "98% needs backstop");
        assertFalse(SpilloverLib.needsBackstop(100e16), "100% doesn't need backstop");
        assertFalse(SpilloverLib.needsBackstop(105e16), "105% doesn't need backstop");
    }
    
    /// @dev Test zone thresholds calculation
    function testCalculateZoneThresholds() public pure {
        uint256 newSupply = 1_000_000e18;
        
        (uint256 targetValue, uint256 triggerValue, uint256 restoreValue) = 
            SpilloverLib.calculateZoneThresholds(newSupply);
        
        // Target (110%): 1M × 1.10 = 1.1M
        assertEq(targetValue, 1_100_000e18, "Target should be 1.1M");
        
        // Trigger (100%): 1M × 1.00 = 1M
        assertEq(triggerValue, 1_000_000e18, "Trigger should be 1M");
        
        // Restore (100.9%): 1M × 1.009 = 1.009M
        assertEq(restoreValue, 1_009_000e18, "Restore should be 1.009M");
    }
    
    /// @dev Fuzz test: Spillover always returns to 110%
    function testFuzz_SpilloverReturnsTo110(uint128 netValue, uint128 supply) public pure {
        vm.assume(supply > 1000e18 && supply < type(uint96).max);
        vm.assume(netValue > supply); // Must have > 100% to potentially spillover
        // Prevent extreme values that cause overflow
        vm.assume(netValue < type(uint96).max);
        
        uint256 backing = (uint256(netValue) * MathLib.PRECISION) / supply;
        
        if (backing > MathLib.SENIOR_TARGET_BACKING) {
            SpilloverLib.ProfitSpillover memory spillover = 
                SpilloverLib.calculateProfitSpillover(netValue, supply);
            
            // Final value should be exactly 110% of supply
            uint256 expectedFinal = (uint256(supply) * MathLib.SENIOR_TARGET_BACKING) / MathLib.PRECISION;
            assertEq(spillover.seniorFinalValue, expectedFinal, "Should return to exactly 110%");
            
            // Sum of distributions should equal excess (allow 1 wei rounding)
            uint256 totalDistributed = spillover.toJunior + spillover.toReserve;
            assertApproxEqAbs(
                totalDistributed,
                spillover.excessAmount,
                1,
                "Distributions should sum to excess (within 1 wei)"
            );
        }
    }
    
    /// @dev Fuzz test: Backstop targets 100.9%
    function testFuzz_BackstopTargets1009(
        uint96 netValue,
        uint96 supply,
        uint96 reserveValue,
        uint96 juniorValue
    ) public pure {
        vm.assume(supply > 1000e18);
        vm.assume(netValue < supply && netValue > 100e18); // Must be < 100% backing
        vm.assume(reserveValue > 0);
        vm.assume(juniorValue > 0);
        
        SpilloverLib.BackstopResult memory backstop = 
            SpilloverLib.calculateBackstop(netValue, supply, reserveValue, juniorValue);
        
        // Target should always be 100.9%
        uint256 expectedTarget = (uint256(supply) * MathLib.SENIOR_RESTORE_BACKING) / MathLib.PRECISION;
        
        if (backstop.fullyRestored) {
            assertEq(backstop.seniorFinalValue, expectedTarget, "Should restore to exactly 100.9%");
        } else {
            // If not fully restored, used all available funds
            assertEq(backstop.fromReserve, reserveValue, "Should use all reserve");
            assertEq(backstop.fromJunior, juniorValue, "Should use all junior");
        }
    }
}

