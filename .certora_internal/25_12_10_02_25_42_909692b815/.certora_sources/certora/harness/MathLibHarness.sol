// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/libraries/MathLib.sol";

/**
 * @title MathLibHarness
 * @notice Harness contract to expose MathLib internal functions for Certora verification
 * @dev Wraps all MathLib functions to make them accessible for formal verification
 */
contract MathLibHarness {
    using MathLib for uint256;
    
    // Expose constants for verification
    function PRECISION() external pure returns (uint256) {
        return MathLib.PRECISION;
    }
    
    function BPS_DENOMINATOR() external pure returns (uint256) {
        return MathLib.BPS_DENOMINATOR;
    }
    
    function MIN_APY() external pure returns (uint256) {
        return MathLib.MIN_APY;
    }
    
    function MID_APY() external pure returns (uint256) {
        return MathLib.MID_APY;
    }
    
    function MAX_APY() external pure returns (uint256) {
        return MathLib.MAX_APY;
    }
    
    function MIN_MONTHLY_RATE() external pure returns (uint256) {
        return MathLib.MIN_MONTHLY_RATE;
    }
    
    function MID_MONTHLY_RATE() external pure returns (uint256) {
        return MathLib.MID_MONTHLY_RATE;
    }
    
    function MAX_MONTHLY_RATE() external pure returns (uint256) {
        return MathLib.MAX_MONTHLY_RATE;
    }
    
    function MGMT_FEE_ANNUAL() external pure returns (uint256) {
        return MathLib.MGMT_FEE_ANNUAL;
    }
    
    function PERF_FEE() external pure returns (uint256) {
        return MathLib.PERF_FEE;
    }
    
    function EARLY_WITHDRAWAL_PENALTY() external pure returns (uint256) {
        return MathLib.EARLY_WITHDRAWAL_PENALTY;
    }
    
    function SENIOR_TARGET_BACKING() external pure returns (uint256) {
        return MathLib.SENIOR_TARGET_BACKING;
    }
    
    function SENIOR_TRIGGER_BACKING() external pure returns (uint256) {
        return MathLib.SENIOR_TRIGGER_BACKING;
    }
    
    function SENIOR_RESTORE_BACKING() external pure returns (uint256) {
        return MathLib.SENIOR_RESTORE_BACKING;
    }
    
    function JUNIOR_SPILLOVER_SHARE() external pure returns (uint256) {
        return MathLib.JUNIOR_SPILLOVER_SHARE;
    }
    
    function RESERVE_SPILLOVER_SHARE() external pure returns (uint256) {
        return MathLib.RESERVE_SPILLOVER_SHARE;
    }
    
    function DEPOSIT_CAP_MULTIPLIER() external pure returns (uint256) {
        return MathLib.DEPOSIT_CAP_MULTIPLIER;
    }
    
    function COOLDOWN_PERIOD() external pure returns (uint256) {
        return MathLib.COOLDOWN_PERIOD;
    }
    
    // Expose core functions
    
    /**
     * @notice Calculate backing ratio: R_senior = V_s / S
     * @dev Reference: Math Spec Section 4.2.4
     */
    function calculateBackingRatio(
        uint256 vaultValue,
        uint256 totalSupply
    ) external pure returns (uint256) {
        return MathLib.calculateBackingRatio(vaultValue, totalSupply);
    }
    
    /**
     * @notice Calculate user balance from shares: b_i = σ_i × I
     * @dev Reference: Math Spec Section 4.2.1
     */
    function calculateBalanceFromShares(
        uint256 shares,
        uint256 rebaseIndex
    ) external pure returns (uint256) {
        return MathLib.calculateBalanceFromShares(shares, rebaseIndex);
    }
    
    /**
     * @notice Calculate shares from balance: σ_new = d / I
     * @dev Reference: Math Spec Section 9.3 (Deposit)
     */
    function calculateSharesFromBalance(
        uint256 balance,
        uint256 rebaseIndex
    ) external pure returns (uint256) {
        return MathLib.calculateSharesFromBalance(balance, rebaseIndex);
    }
    
    /**
     * @notice Calculate shares from balance (ceiling division)
     * @dev Used for burning to favor protocol
     */
    function calculateSharesFromBalanceCeil(
        uint256 balance,
        uint256 rebaseIndex
    ) external pure returns (uint256) {
        return MathLib.calculateSharesFromBalanceCeil(balance, rebaseIndex);
    }
    
    /**
     * @notice Calculate total supply: S = I × Σ
     * @dev Reference: Math Spec Section 4.2.2
     */
    function calculateTotalSupply(
        uint256 totalShares,
        uint256 rebaseIndex
    ) external pure returns (uint256) {
        return MathLib.calculateTotalSupply(totalShares, rebaseIndex);
    }
    
    /**
     * @notice Calculate deposit cap: S_max = γ × V_r = 10 × V_r
     * @dev Reference: Math Spec Section 4.2.6
     */
    function calculateDepositCap(
        uint256 reserveValue
    ) external pure returns (uint256) {
        return MathLib.calculateDepositCap(reserveValue);
    }
    
    /**
     * @notice Apply percentage to value
     */
    function applyPercentage(
        uint256 value,
        int256 percentageBps
    ) external pure returns (uint256) {
        return MathLib.applyPercentage(value, percentageBps);
    }
    
    /**
     * @notice Safe multiplication with precision handling
     */
    function mulDiv(
        uint256 a,
        uint256 b
    ) external pure returns (uint256) {
        return MathLib.mulDiv(a, b);
    }
    
    /**
     * @notice Calculate minimum of two values
     */
    function min(uint256 a, uint256 b) external pure returns (uint256) {
        return MathLib.min(a, b);
    }
    
    /**
     * @notice Calculate maximum of two values
     */
    function max(uint256 a, uint256 b) external pure returns (uint256) {
        return MathLib.max(a, b);
    }
}

