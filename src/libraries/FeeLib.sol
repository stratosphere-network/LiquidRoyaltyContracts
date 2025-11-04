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
            // Apply penalty: P = w × 0.05
            penalty = (withdrawalAmount * MathLib.EARLY_WITHDRAWAL_PENALTY) / MathLib.PRECISION;
            netAmount = withdrawalAmount - penalty;
            return (penalty, netAmount);
        }
    }
    
    /**
     * @notice Calculate net vault value after management fee deduction
     * @dev Reference: Section - Rebase Algorithm (Step 2)
     * Formula: V_s^net = V_s - F_mgmt
     * @param grossValue Vault value before fees (V_s)
     * @return netValue Value after management fee (V_s^net)
     * @return feeAmount Management fee deducted (F_mgmt)
     */
    function deductManagementFee(
        uint256 grossValue
    ) internal pure returns (uint256 netValue, uint256 feeAmount) {
        feeAmount = calculateManagementFee(grossValue);
        netValue = grossValue - feeAmount;
        return (netValue, feeAmount);
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
     * @notice Calculate rebase index multiplier including performance fee
     * @dev Reference: Section - Rebase Algorithm (Step 6)
     * Formula: I_new = I_old × (1 + r_selected × (1 + f_perf))
     * @param oldIndex Previous rebase index (I_old)
     * @param monthlyRate Selected monthly rate (r_selected)
     * @return newIndex New rebase index (I_new)
     */
    function calculateNewRebaseIndex(
        uint256 oldIndex,
        uint256 monthlyRate
    ) internal pure returns (uint256 newIndex) {
        // I_new = I_old × (1 + r_selected × 1.02)
        // Multiplier = 1 + (monthlyRate × 1.02)
        uint256 multiplier = MathLib.PRECISION + 
            ((monthlyRate * (MathLib.PRECISION + MathLib.PERF_FEE)) / MathLib.PRECISION);
        
        return (oldIndex * multiplier) / MathLib.PRECISION;
    }
}

