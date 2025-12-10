// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/libraries/SpilloverLib.sol";
import "../../src/libraries/MathLib.sol";

/**
 * @title SpilloverLibHarness
 * @notice Harness contract to expose SpilloverLib internal functions for Certora verification
 * @dev Wraps all SpilloverLib functions for formal verification
 */
contract SpilloverLibHarness {
    using SpilloverLib for uint256;
    
    /**
     * @notice Determine which operating zone Senior is in
     * @dev Reference: Math Spec Section 4.2.4 (Three Operating Zones)
     */
    function determineZone(uint256 backingRatio) external pure returns (uint8) {
        SpilloverLib.Zone zone = SpilloverLib.determineZone(backingRatio);
        return uint8(zone); // 0=BACKSTOP, 1=HEALTHY, 2=SPILLOVER
    }
    
    /**
     * @notice Calculate profit spillover amounts (Zone 1)
     * @dev Reference: Math Spec Section 5.1 Step 4A
     * Formulas:
     * - V_target = 1.10 × S_new
     * - E = V_s - V_target
     * - E_j = E × 0.80
     * - E_r = E × 0.20
     */
    function calculateProfitSpillover(
        uint256 netVaultValue,
        uint256 newSupply
    ) external pure returns (
        uint256 excessAmount,
        uint256 toJunior,
        uint256 toReserve,
        uint256 seniorFinalValue
    ) {
        SpilloverLib.ProfitSpillover memory spillover = 
            SpilloverLib.calculateProfitSpillover(netVaultValue, newSupply);
        
        return (
            spillover.excessAmount,
            spillover.toJunior,
            spillover.toReserve,
            spillover.seniorFinalValue
        );
    }
    
    /**
     * @notice Calculate backstop amounts (Zone 3)
     * @dev Reference: Math Spec Section 5.1 Step 4B
     * Formulas:
     * - V_restore = 1.009 × S_new
     * - D = V_restore - V_s
     * - X_r = min(V_r, D)
     * - X_j = min(V_j, D - X_r)
     */
    function calculateBackstop(
        uint256 netVaultValue,
        uint256 newSupply,
        uint256 reserveValue,
        uint256 juniorValue
    ) external pure returns (
        uint256 deficitAmount,
        uint256 fromReserve,
        uint256 fromJunior,
        uint256 seniorFinalValue,
        bool fullyRestored
    ) {
        SpilloverLib.BackstopResult memory backstop =
            SpilloverLib.calculateBackstop(
                netVaultValue,
                newSupply,
                reserveValue,
                juniorValue
            );
        
        return (
            backstop.deficitAmount,
            backstop.fromReserve,
            backstop.fromJunior,
            backstop.seniorFinalValue,
            backstop.fullyRestored
        );
    }
    
    /**
     * @notice Check if backing ratio is in healthy buffer zone
     * @dev Reference: Math Spec Section 4.2.4 (Zone 2)
     */
    function isHealthyBufferZone(uint256 backingRatio) external pure returns (bool) {
        return SpilloverLib.isHealthyBufferZone(backingRatio);
    }
    
    /**
     * @notice Check if backing ratio requires profit spillover
     * @dev Reference: Math Spec Section 4.2.4 (Zone 1)
     */
    function needsProfitSpillover(uint256 backingRatio) external pure returns (bool) {
        return SpilloverLib.needsProfitSpillover(backingRatio);
    }
    
    /**
     * @notice Check if backing ratio requires backstop
     * @dev Reference: Math Spec Section 4.2.4 (Zone 3)
     */
    function needsBackstop(uint256 backingRatio) external pure returns (bool) {
        return SpilloverLib.needsBackstop(backingRatio);
    }
    
    /**
     * @notice Calculate backing ratio targets for all zones
     */
    function calculateZoneThresholds(
        uint256 newSupply
    ) external pure returns (
        uint256 targetValue,
        uint256 triggerValue,
        uint256 restoreValue
    ) {
        return SpilloverLib.calculateZoneThresholds(newSupply);
    }
}

