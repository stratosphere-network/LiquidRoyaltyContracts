// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MathLib} from "./MathLib.sol";

/**
 * @title SpilloverLib
 * @notice Three-zone spillover system logic for the Senior Tranche Protocol
 * @dev Implements profit spillover (>110%), healthy buffer (100-110%), and backstop (<100%)
 * 
 * References from Mathematical Specification:
 * - Section: Three-Zone Spillover System
 * - Section: Rebase Algorithm (Steps 4, 5A, 5B)
 */
library SpilloverLib {
    using MathLib for uint256;
    
    /// @dev Operating zones
    enum Zone {
        BACKSTOP,      // Zone 3: R < 100% (Depegged)
        HEALTHY,       // Zone 2: 100% ≤ R ≤ 110% (No action)
        SPILLOVER      // Zone 1: R > 110% (Excess profits)
    }
    
    /// @dev Profit spillover result (Zone 1)
    struct ProfitSpillover {
        uint256 excessAmount;          // Total excess to distribute (E)
        uint256 toJunior;              // Amount to Junior (E_j = E × 80%)
        uint256 toReserve;             // Amount to Reserve (E_r = E × 20%)
        uint256 seniorFinalValue;      // Senior value after spillover (V_s^final)
    }
    
    /// @dev Backstop result (Zone 3)
    struct BackstopResult {
        uint256 deficitAmount;         // Total deficit to cover (D)
        uint256 fromReserve;           // Amount from Reserve (X_r)
        uint256 fromJunior;            // Amount from Junior (X_j)
        uint256 seniorFinalValue;      // Senior value after backstop (V_s^final)
        bool fullyRestored;            // Whether deficit was fully covered
    }
    
    /// @dev Error definitions
    error InvalidBackingRatio();
    error InvalidZone();
    
    /**
     * @notice Determine which operating zone Senior is in
     * @dev Reference: Section - Three-Zone Spillover System
     * @param backingRatio Senior backing ratio (R_senior)
     * @return zone Current operating zone
     */
    function determineZone(uint256 backingRatio) internal pure returns (Zone zone) {
        if (backingRatio > MathLib.SENIOR_TARGET_BACKING) {
            // Zone 1: > 110% (Profit Spillover)
            return Zone.SPILLOVER;
        } else if (backingRatio >= MathLib.SENIOR_TRIGGER_BACKING) {
            // Zone 2: 100% to 110% (Healthy Buffer)
            return Zone.HEALTHY;
        } else {
            // Zone 3: < 100% (Backstop Needed)
            return Zone.BACKSTOP;
        }
    }
    
    /**
     * @notice Calculate profit spillover amounts (Zone 1)
     * @dev Reference: Section - Three-Zone Spillover System (Zone 1)
     * Formulas:
     * - V_target = 1.10 × S_new
     * - E = V_s^net - V_target
     * - E_j = E × 0.80
     * - E_r = E × 0.20
     * 
     * @param netVaultValue Senior vault value after fees (V_s^net)
     * @param newSupply Total supply after rebase (S_new)
     * @return spillover Profit spillover calculation results
     */
    function calculateProfitSpillover(
        uint256 netVaultValue,
        uint256 newSupply
    ) internal pure returns (ProfitSpillover memory spillover) {
        // Calculate 110% target: V_target = 1.10 × S_new
        uint256 targetValue = (newSupply * MathLib.SENIOR_TARGET_BACKING) / MathLib.PRECISION;
        
        // Excess above 110%: E = V_s^net - V_target
        if (netVaultValue <= targetValue) {
            // No excess (shouldn't happen in Zone 1, but safety check)
            return ProfitSpillover({
                excessAmount: 0,
                toJunior: 0,
                toReserve: 0,
                seniorFinalValue: netVaultValue
            });
        }
        
        uint256 excess = netVaultValue - targetValue;
        
        // Split 80/20: E_j = E × 0.80, E_r = E × 0.20
        uint256 toJunior = (excess * MathLib.JUNIOR_SPILLOVER_SHARE) / MathLib.PRECISION;
        uint256 toReserve = (excess * MathLib.RESERVE_SPILLOVER_SHARE) / MathLib.PRECISION;
        
        // Senior returns to exactly 110%
        uint256 seniorFinalValue = targetValue;
        
        return ProfitSpillover({
            excessAmount: excess,
            toJunior: toJunior,
            toReserve: toReserve,
            seniorFinalValue: seniorFinalValue
        });
    }
    
    /**
     * @notice Calculate backstop amounts (Zone 3)
     * @dev Reference: Section - Three-Zone Spillover System (Zone 3)
     * Formulas:
     * - V_restore = 1.009 × S_new
     * - D = V_restore - V_s^net
     * - X_r = min(V_r, D) [Reserve first, no cap!]
     * - X_j = min(V_j, D - X_r) [Junior second, no cap!]
     * 
     * @param netVaultValue Senior vault value 
     * @param newSupply Total supply after rebase (S_new)
     * @param reserveValue Available reserve vault value (V_r)
     * @param juniorValue Available junior vault value (V_j)
     * @return backstop Backstop calculation results
     */
    function calculateBackstop(
        uint256 netVaultValue,
        uint256 newSupply,
        uint256 reserveValue,
        uint256 juniorValue
    ) internal pure returns (BackstopResult memory backstop) {
        // Calculate 100.9% restoration target: V_restore = 1.009 × S_new
        uint256 restoreValue = (newSupply * MathLib.SENIOR_RESTORE_BACKING) / MathLib.PRECISION;
        
        // Check if already above restoration target (shouldn't happen in Zone 3)
        if (netVaultValue >= restoreValue) {
            return BackstopResult({
                deficitAmount: 0,
                fromReserve: 0,
                fromJunior: 0,
                seniorFinalValue: netVaultValue,
                fullyRestored: true
            });
        }
        
        // Calculate deficit: D = V_restore - V_s^net
        uint256 deficit = restoreValue - netVaultValue;
        
        // Backstop waterfall: Reserve first (no cap!)
        uint256 fromReserve = MathLib.min(reserveValue, deficit);
        uint256 remainingDeficit = deficit - fromReserve;
        
        // Then Junior if needed (no cap!)
        uint256 fromJunior = 0;
        bool fullyRestored = false;
        
        if (remainingDeficit > 0) {
            fromJunior = MathLib.min(juniorValue, remainingDeficit);
            remainingDeficit = remainingDeficit - fromJunior;
            fullyRestored = (remainingDeficit == 0);
        } else {
            fullyRestored = true;
        }
        
        // Calculate Senior's final value after backstop
        uint256 seniorFinalValue = netVaultValue + fromReserve + fromJunior;
        
        return BackstopResult({
            deficitAmount: deficit,
            fromReserve: fromReserve,
            fromJunior: fromJunior,
            seniorFinalValue: seniorFinalValue,
            fullyRestored: fullyRestored
        });
    }
    
    /**
     * @notice Check if backing ratio is in healthy buffer zone
     * @dev Reference: Section - Three-Zone System (Zone 2)
     * @param backingRatio Senior backing ratio
     * @return isHealthy True if 100% ≤ R ≤ 110%
     */
    function isHealthyBufferZone(uint256 backingRatio) internal pure returns (bool isHealthy) {
        return backingRatio >= MathLib.SENIOR_TRIGGER_BACKING 
            && backingRatio <= MathLib.SENIOR_TARGET_BACKING;
    }
    
    /**
     * @notice Check if backing ratio requires profit spillover
     * @dev Reference: Section - Three-Zone System (Zone 1)
     * @param backingRatio Senior backing ratio
     * @return needsSpillover True if R > 110%
     */
    function needsProfitSpillover(uint256 backingRatio) internal pure returns (bool needsSpillover) {
        return backingRatio > MathLib.SENIOR_TARGET_BACKING;
    }
    
    /**
     * @notice Check if backing ratio requires backstop
     * @dev Reference: Section - Three-Zone System (Zone 3)
     * @param backingRatio Senior backing ratio
     * @return required True if R < 100%
     */
    function needsBackstop(uint256 backingRatio) internal pure returns (bool required) {
        return backingRatio < MathLib.SENIOR_TRIGGER_BACKING;
    }
    
    /**
     * @notice Calculate backing ratio targets for all zones
     * @param newSupply Total supply after rebase
     * @return targetValue 110% target value (spillover threshold)
     * @return triggerValue 100% trigger value (backstop threshold)
     * @return restoreValue 100.9% restore value (backstop target)
     */
    function calculateZoneThresholds(
        uint256 newSupply
    ) internal pure returns (
        uint256 targetValue,
        uint256 triggerValue,
        uint256 restoreValue
    ) {
        targetValue = (newSupply * MathLib.SENIOR_TARGET_BACKING) / MathLib.PRECISION;
        triggerValue = (newSupply * MathLib.SENIOR_TRIGGER_BACKING) / MathLib.PRECISION;
        restoreValue = (newSupply * MathLib.SENIOR_RESTORE_BACKING) / MathLib.PRECISION;
        
        return (targetValue, triggerValue, restoreValue);
    }
}

