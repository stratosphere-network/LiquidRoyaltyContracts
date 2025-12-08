// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MathLib} from "./MathLib.sol";

/**
 * @title FeeLib
 * @notice Fee calculation utilities for the Senior Tranche Protocol
 * @dev Handles management fees, performance fees, and withdrawal penalties
 * 
 * References from Mathematical Specification:
 * - Section: Fee Calculations
 * - Section: Rebase Algorithm (Step 2)
 */
library FeeLib {
    using MathLib for uint256;
    
    /// @dev Error definitions
    error InvalidFeePercentage();
    error InvalidWithdrawalAmount();
    
    /**
     * @notice Calculate monthly management fee
     * @dev Reference: Section - Fee Calculations (Management Fee)
     * Formula: F_mgmt = V(t) × (f_mgmt / 12)
     * @param vaultValue Current vault value (V)
     * @return managementFee Fee amount in USD (F_mgmt)
     */
    function calculateManagementFee(
        uint256 vaultValue
    ) internal pure returns (uint256 managementFee) {
        // F_mgmt = vaultValue × (0.01 / 12) = vaultValue × 0.000833
        // Using precision: (vaultValue × 1e16) / (12 × 1e18) = vaultValue × 1e16 / 12
        return (vaultValue * MathLib.MGMT_FEE_ANNUAL) / (12 * MathLib.PRECISION);
    }
    
    /**
     * @notice Calculate performance fee tokens to mint
     * @dev Reference: Section - Fee Calculations (Performance Fee - Token Dilution)
     * Formula: S_fee = S_users × f_perf = S_users × 0.02
     * @param userTokensMinted Tokens minted for users (S_users)
     * @return performanceFeeTokens Additional tokens to mint for treasury (S_fee)
     */
    function calculatePerformanceFee(
        uint256 userTokensMinted
    ) internal pure returns (uint256 performanceFeeTokens) {
        // S_fee = userTokensMinted × 0.02
        return (userTokensMinted * MathLib.PERF_FEE) / MathLib.PRECISION;
    }
    
    /**
     * @notice Calculate early withdrawal penalty
     * @dev Reference: Section - Fee Calculations (Early Withdrawal Penalty)
     * Formula: P(w, t_c) = w × f_penalty if (t - t_c < τ), else 0
     * @param withdrawalAmount Amount user wants to withdraw (w)
     * @param cooldownStartTime When cooldown was initiated (t_c)
     * @param currentTime Current block timestamp (t)
     * @return penalty Penalty amount (P)
     * @return netAmount Amount user receives (w_net = w - P)
     */
    function calculateWithdrawalPenalty(
        uint256 withdrawalAmount,
        uint256 cooldownStartTime,
        uint256 currentTime
    ) internal pure returns (uint256 penalty, uint256 netAmount) {
        if (withdrawalAmount == 0) revert InvalidWithdrawalAmount();
        
        // Check if cooldown period has passed (τ = 7 days)
        bool cooldownMet = (currentTime - cooldownStartTime) >= MathLib.COOLDOWN_PERIOD;
        
        if (cooldownMet) {
            // No penalty: P = 0, w_net = w
            return (0, withdrawalAmount);
        } else {
            // Apply penalty: P = w × 0.20
            penalty = (withdrawalAmount * MathLib.EARLY_WITHDRAWAL_PENALTY) / MathLib.PRECISION;
            netAmount = withdrawalAmount - penalty;
            return (penalty, netAmount);
        }
    }
    
    /**
     * @notice Calculate management fee tokens to mint based on time elapsed
     * @dev Reference: Section - Rebase Algorithm (Step 2) - UPDATED (Q3 FIX)
     * Formula: mgmtFeeTokens = vaultValue × 1% × (timeElapsed / 365 days)
     * Q3 FIX: Now calculates based on actual time elapsed, not fixed monthly assumption
     * This prevents over-charging fees when rebases happen more frequently than monthly
     * @param vaultValue Current vault value (V_s)
     * @param timeElapsed Time since last rebase in seconds
     * @return managementFeeTokens snrUSD tokens to mint for management fee
     */
    function calculateManagementFeeTokens(
        uint256 vaultValue,
        uint256 timeElapsed
    ) internal pure returns (uint256 managementFeeTokens) {
        // Q3 FIX: Calculate based on actual time elapsed
        // Fee = vaultValue × 1% × (timeElapsed / 365 days)
        // = (vaultValue × MGMT_FEE_ANNUAL × timeElapsed) / (365 days × PRECISION)
        uint256 secondsPerYear = 365 days;
        return (vaultValue * MathLib.MGMT_FEE_ANNUAL * timeElapsed) / (secondsPerYear * MathLib.PRECISION);
    }
    
    /**
     * @notice Calculate total supply after rebase (users + performance fee)
     * @dev Reference: Section - Rebase Algorithm (Step 3)
     * Formula: S_new = S + S_users + S_fee = S × (1 + r_month × 1.02)
     * @param currentSupply Current snrUSD supply (S)
     * @param monthlyRate Selected monthly rate (r_month)
     * @return newSupply Total supply after rebase (S_new)
     * @return userTokens Tokens minted for users (S_users)
     * @return feeTokens Tokens minted for treasury (S_fee)
     */
    function calculateRebaseSupply(
        uint256 currentSupply,
        uint256 monthlyRate
    ) internal pure returns (
        uint256 newSupply,
        uint256 userTokens,
        uint256 feeTokens
    ) {
        // S_users = S × r_month
        userTokens = (currentSupply * monthlyRate) / MathLib.PRECISION;
        
        // S_fee = S_users × 0.02
        feeTokens = calculatePerformanceFee(userTokens);
        
        // S_new = S + S_users + S_fee
        newSupply = currentSupply + userTokens + feeTokens;
        
        return (newSupply, userTokens, feeTokens);
    }
    
    /**
     * @notice Calculate rebase index multiplier (VN001 FIX: exclude performance fee)
     * @dev Reference: Section - Rebase Algorithm (Step 6)
     * Formula: I_new = I_old × (1 + r_selected)
     * VN001 FIX: Performance fee is handled via token minting, not index growth
     * Including perf fee in index would double-count it (users get extra + treasury gets minted)
     * @param oldIndex Previous rebase index (I_old)
     * @param monthlyRate Selected monthly rate (r_selected)
     * @return newIndex New rebase index (I_new)
     */
    function calculateNewRebaseIndex(
        uint256 oldIndex,
        uint256 monthlyRate
    ) internal pure returns (uint256 newIndex) {
        // VN001 FIX: I_new = I_old × (1 + r_selected)
        // NO performance fee adjustment - that's handled by minting tokens to treasury
        // Multiplier = 1 + monthlyRate (just the rate, not × 1.02)
        uint256 multiplier = MathLib.PRECISION + monthlyRate;
        
        return (oldIndex * multiplier) / MathLib.PRECISION;
    }
}

