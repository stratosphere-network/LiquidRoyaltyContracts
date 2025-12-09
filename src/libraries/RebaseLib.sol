// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MathLib} from "./MathLib.sol";
import {FeeLib} from "./FeeLib.sol";

/**
 * @title RebaseLib
 * @notice Dynamic APY selection and rebase calculation logic
 * @dev Implements the waterfall APY selection (13% → 12% → 11%)
 * 
 * References from Mathematical Specification:
 * - Section: Rebase Algorithm (Step 3 - Dynamic APY Selection)
 * - Section: Quick Reference (Dynamic APY Selection 11-13%)
 */
library RebaseLib {
    using MathLib for uint256;
    
    /// @dev APY selection result
    struct APYSelection {
        uint256 selectedRate;      // Monthly rate selected (r_selected)
        uint256 newSupply;         // Total new supply (S_new)
        uint256 userTokens;        // Tokens for users (S_users)
        uint256 feeTokens;         // Tokens for treasury (S_fee)
        uint8 apyTier;            // Which APY was selected: 3=13%, 2=12%, 1=11%
        bool backstopNeeded;       // Whether backstop is required
    }
    
    /// @dev Error definitions
    error InvalidSupply();
    error InvalidVaultValue();
    
    /**
     * @notice Dynamically select highest APY that maintains peg
     * @dev Reference: Section - Dynamic APY Selection (Waterfall Algorithm)
     * Tries 13% → 12% → 11% and selects highest that keeps R ≥ 100%
     * TIME-BASED FIX: Accepts time elapsed and management fee tokens
     * 
     * @param currentSupply Current snrUSD supply (S)
     * @param netVaultValue Vault value after management fee (V_s^net)
     * @param timeElapsed Time since last rebase in seconds
     * @param mgmtFeeTokens Management fee tokens to include in calculations
     * @return selection APY selection result with chosen rate and new supply
     */
    function selectDynamicAPY(
        uint256 currentSupply,
        uint256 netVaultValue,
        uint256 timeElapsed,
        uint256 mgmtFeeTokens
    ) internal pure returns (APYSelection memory selection) {
        if (currentSupply == 0) revert InvalidSupply();
        if (netVaultValue == 0) revert InvalidVaultValue();
        
        // Try 13% APY first (greedy maximization)
        (uint256 newSupply13, uint256 userTokens13, uint256 feeTokens13) = 
            FeeLib.calculateRebaseSupply(currentSupply, MathLib.MAX_MONTHLY_RATE, timeElapsed, mgmtFeeTokens);
        
        uint256 backing13 = MathLib.calculateBackingRatio(netVaultValue, newSupply13);
        
        // Check if 13% APY maintains peg (R_13 ≥ 100%)
        if (backing13 >= MathLib.PRECISION) {
            // ✅ Use 13% APY
            return APYSelection({
                selectedRate: MathLib.MAX_MONTHLY_RATE,
                newSupply: newSupply13,
                userTokens: userTokens13,
                feeTokens: feeTokens13,
                apyTier: 3,
                backstopNeeded: false
            });
        }
        
        // Try 12% APY
        (uint256 newSupply12, uint256 userTokens12, uint256 feeTokens12) = 
            FeeLib.calculateRebaseSupply(currentSupply, MathLib.MID_MONTHLY_RATE, timeElapsed, mgmtFeeTokens);
        
        uint256 backing12 = MathLib.calculateBackingRatio(netVaultValue, newSupply12);
        
        if (backing12 >= MathLib.PRECISION) {
           
            return APYSelection({
                selectedRate: MathLib.MID_MONTHLY_RATE,
                newSupply: newSupply12,
                userTokens: userTokens12,
                feeTokens: feeTokens12,
                apyTier: 2,
                backstopNeeded: false
            });
        }
        
        // Try 11% APY
        (uint256 newSupply11, uint256 userTokens11, uint256 feeTokens11) = 
            FeeLib.calculateRebaseSupply(currentSupply, MathLib.MIN_MONTHLY_RATE, timeElapsed, mgmtFeeTokens);
        
        uint256 backing11 = MathLib.calculateBackingRatio(netVaultValue, newSupply11);
        
        if (backing11 >= MathLib.PRECISION) {
            // ✅ Use 11% APY
            return APYSelection({
                selectedRate: MathLib.MIN_MONTHLY_RATE,
                newSupply: newSupply11,
                userTokens: userTokens11,
                feeTokens: feeTokens11,
                apyTier: 1,
                backstopNeeded: false
            });
        }
        
        // 🚨 Even 11% would cause depeg - use 11% anyway and flag backstop needed
        return APYSelection({
            selectedRate: MathLib.MIN_MONTHLY_RATE,
            newSupply: newSupply11,
            userTokens: userTokens11,
            feeTokens: feeTokens11,
            apyTier: 1,
            backstopNeeded: true
        });
    }
    
    /**
     * @notice Calculate new rebase index
     * @dev Reference: Section - Rebase Algorithm (Step 6)
     * Formula: I_new = I_old × (1 + r_selected × timeScaling)
     * TIME-BASED FIX: Accepts time elapsed parameter
     * 
     * @param oldIndex Previous rebase index (I_old)
     * @param selectedRate Selected monthly rate (r_selected)
     * @param timeElapsed Time since last rebase in seconds
     * @return newIndex New rebase index (I_new)
     */
    function calculateNewIndex(
        uint256 oldIndex,
        uint256 selectedRate,
        uint256 timeElapsed
    ) internal pure returns (uint256 newIndex) {
        return FeeLib.calculateNewRebaseIndex(oldIndex, selectedRate, timeElapsed);
    }
    
    /**
     * @notice Simulate all three APY tiers and their backing ratios
     * @dev Useful for off-chain analysis and testing
     * TIME-BASED FIX: Accepts time elapsed and management fee tokens
     * @param currentSupply Current snrUSD supply
     * @param netVaultValue Vault value after fees
     * @param timeElapsed Time since last rebase in seconds
     * @param mgmtFeeTokens Management fee tokens to include
     * @return backing13 Backing ratio with 13% APY
     * @return backing12 Backing ratio with 12% APY
     * @return backing11 Backing ratio with 11% APY
     */
    function simulateAllAPYs(
        uint256 currentSupply,
        uint256 netVaultValue,
        uint256 timeElapsed,
        uint256 mgmtFeeTokens
    ) internal pure returns (
        uint256 backing13,
        uint256 backing12,
        uint256 backing11
    ) {
        if (currentSupply == 0) revert InvalidSupply();
        
        // 13% APY simulation
        (uint256 newSupply13,,) = FeeLib.calculateRebaseSupply(currentSupply, MathLib.MAX_MONTHLY_RATE, timeElapsed, mgmtFeeTokens);
        backing13 = MathLib.calculateBackingRatio(netVaultValue, newSupply13);
        
        // 12% APY simulation
        (uint256 newSupply12,,) = FeeLib.calculateRebaseSupply(currentSupply, MathLib.MID_MONTHLY_RATE, timeElapsed, mgmtFeeTokens);
        backing12 = MathLib.calculateBackingRatio(netVaultValue, newSupply12);
        
        // 11% APY simulation
        (uint256 newSupply11,,) = FeeLib.calculateRebaseSupply(currentSupply, MathLib.MIN_MONTHLY_RATE, timeElapsed, mgmtFeeTokens);
        backing11 = MathLib.calculateBackingRatio(netVaultValue, newSupply11);
        
        return (backing13, backing12, backing11);
    }
    
    /**
     * @notice Get APY tier as human-readable percentage
     * @param apyTier Tier number (1=11%, 2=12%, 3=13%)
     * @return apyBps APY in basis points
     */
    function getAPYInBps(uint8 apyTier) internal pure returns (uint256 apyBps) {
        if (apyTier == 3) return 1300; // 13.00%
        if (apyTier == 2) return 1200; // 12.00%
        if (apyTier == 1) return 1100; // 11.00%
        return 0; // Invalid tier
    }
    
    /**
     * @notice Get monthly rate from APY tier
     * @param apyTier Tier number (1=11%, 2=12%, 3=13%)
     * @return monthlyRate Monthly rate in 18 decimal precision
     */
    function getMonthlyRate(uint8 apyTier) internal pure returns (uint256 monthlyRate) {
        if (apyTier == 3) return MathLib.MAX_MONTHLY_RATE;
        if (apyTier == 2) return MathLib.MID_MONTHLY_RATE;
        if (apyTier == 1) return MathLib.MIN_MONTHLY_RATE;
        return 0; // Invalid tier
    }
}

