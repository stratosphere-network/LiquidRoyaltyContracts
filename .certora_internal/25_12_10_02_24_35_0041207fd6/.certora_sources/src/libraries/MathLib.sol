// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MathLib
 * @notice Mathematical utilities for the Senior Tranche Protocol
 * @dev All calculations use 18 decimal precision (1e18 = 100%)
 * 
 * References from Mathematical Specification:
 * - Section: Core Formulas
 * - Section: Constraints & Invariants
 */
library MathLib {
    /// @dev Precision constants
    uint256 public constant PRECISION = 1e18; // 100%
    uint256 public constant BPS_DENOMINATOR = 10000; // Basis points denominator
    
    /// @dev Protocol constants from math spec
    /// Reference: Notation & Definitions - Parameters (Constants)
    uint256 public constant MIN_APY = 11e16; // 0.11 = 11% (r_min)
    uint256 public constant MID_APY = 12e16; // 0.12 = 12% (r_mid)
    uint256 public constant MAX_APY = 13e16; // 0.13 = 13% (r_max)
    
    uint256 public constant MIN_MONTHLY_RATE = 9167e12; // 0.009167 = 11%/12 (r_month^min)
    uint256 public constant MID_MONTHLY_RATE = 10000e12; // 0.010000 = 12%/12 (r_month^mid)
    uint256 public constant MAX_MONTHLY_RATE = 10833e12; // 0.010833 = 13%/12 (r_month^max)
    
    uint256 public constant MGMT_FEE_ANNUAL = 1e16; // 0.01 = 1% (f_mgmt)
    uint256 public constant PERF_FEE = 2e16; // 0.02 = 2% (f_perf)
    uint256 public constant EARLY_WITHDRAWAL_PENALTY = 2e17; // 0.20 = 20% (f_penalty)
    uint256 public constant WITHDRAWAL_FEE = 1e16; // 0.01 = 1% (f_withdrawal)
    
    uint256 public constant SENIOR_TARGET_BACKING = 110e16; // 1.10 = 110% (α_target)
    uint256 public constant SENIOR_TRIGGER_BACKING = 100e16; // 1.00 = 100% (α_trigger)
    uint256 public constant SENIOR_RESTORE_BACKING = 1009e15; // 1.009 = 100.9% (α_restore)
    
    uint256 public constant JUNIOR_SPILLOVER_SHARE = 80e16; // 0.80 = 80% (β_j^spillover)
    uint256 public constant RESERVE_SPILLOVER_SHARE = 20e16; // 0.20 = 20% (β_r^spillover)
    
    uint256 public constant DEPOSIT_CAP_MULTIPLIER = 10; // γ
    uint256 public constant COOLDOWN_PERIOD = 7 days; // τ
    
    /// @dev Error definitions
    error DivisionByZero();
    error Overflow();
    error InvalidPercentage();
    
    /**
     * @notice Calculate backing ratio
     * @dev Reference: Section 4 - Senior Backing Ratio
     * Formula: R_senior = V_s / S
     * @param vaultValue USD value of vault assets (V_s)
     * @param totalSupply Circulating supply of snrUSD (S)
     * @return backingRatio Ratio in 18 decimal precision
     */
    function calculateBackingRatio(
        uint256 vaultValue,
        uint256 totalSupply
    ) internal pure returns (uint256 backingRatio) {
        if (totalSupply == 0) revert DivisionByZero();
        return (vaultValue * PRECISION) / totalSupply;
    }
    
    /**
     * @notice Calculate user balance from shares
     * @dev Reference: Section 1 - User Balance (via Rebase Index)
     * Formula: b_i = σ_i × I
     * @param shares User's share balance (σ_i)
     * @param rebaseIndex Current rebase index (I)
     * @return balance User's snrUSD balance (b_i)
     */
    function calculateBalanceFromShares(
        uint256 shares,
        uint256 rebaseIndex
    ) internal pure returns (uint256 balance) {
        return (shares * rebaseIndex) / PRECISION;
    }
    
    /**
     * @notice Calculate shares from balance
     * @dev Reference: Section 6 - User Balance & Shares (Deposit)
     * Formula: σ_new = d / I
     * @param balance Balance amount
     * @param rebaseIndex Current rebase index (I)
     * @return shares Shares to mint/burn
     */
    function calculateSharesFromBalance(
        uint256 balance,
        uint256 rebaseIndex
    ) internal pure returns (uint256 shares) {
        if (rebaseIndex == 0) revert DivisionByZero();
        return (balance * PRECISION) / rebaseIndex;
    }
    
    /**
     * @notice Calculate internal shares from balance (ROUND UP - for burning)
     * @dev Used in _burn() to ensure protocol burns enough shares (favors protocol)
     * @dev Ceiling division: (a + b - 1) / b
     * @param balance User's visible balance to burn
     * @param rebaseIndex Current rebase index
     * @return shares Internal shares to burn (rounded up)
     */
    function calculateSharesFromBalanceCeil(
        uint256 balance,
        uint256 rebaseIndex
    ) internal pure returns (uint256 shares) {
        if (rebaseIndex == 0) revert DivisionByZero();
        // Ceiling division to round up
        return (balance * PRECISION + rebaseIndex - 1) / rebaseIndex;
    }
    
    /**
     * @notice Calculate total supply from shares and index
     * @dev Reference: Section 2 - Total Supply
     * Formula: S = I × Σ
     * @param totalShares Sum of all shares (Σ)
     * @param rebaseIndex Current rebase index (I)
     * @return totalSupply Total snrUSD supply (S)
     */
    function calculateTotalSupply(
        uint256 totalShares,
        uint256 rebaseIndex
    ) internal pure returns (uint256 totalSupply) {
        return (totalShares * rebaseIndex) / PRECISION;
    }
    
    /**
     * @notice Calculate deposit cap based on reserve
     * @dev Reference: Section 5 - Deposit Cap
     * Formula: S_max = γ × V_r = 10 × V_r
     * @param reserveValue Reserve vault value (V_r)
     * @return maxSupply Maximum allowed supply (S_max)
     */
    function calculateDepositCap(
        uint256 reserveValue
    ) internal pure returns (uint256 maxSupply) {
        return reserveValue * DEPOSIT_CAP_MULTIPLIER;
    }
    
    /**
     * @notice Apply percentage to value (supports positive and negative)
     * @param value Base value
     * @param percentageBps Percentage in basis points (can be negative)
     * @return newValue Value after applying percentage
     */
    function applyPercentage(
        uint256 value,
        int256 percentageBps
    ) internal pure returns (uint256 newValue) {
        if (percentageBps >= 0) {
            // Positive: value * (1 + percentage)
            return value * (BPS_DENOMINATOR + uint256(percentageBps)) / BPS_DENOMINATOR;
        } else {
            // Negative: value * (1 - percentage)
            uint256 absBps = uint256(-percentageBps);
            if (absBps >= BPS_DENOMINATOR) revert Overflow();
            return value * (BPS_DENOMINATOR - absBps) / BPS_DENOMINATOR;
        }
    }
    
    /**
     * @notice Safe multiplication with precision handling
     * @param a First value
     * @param b Second value (in PRECISION units)
     * @return result a × b / PRECISION
     */
    function mulDiv(
        uint256 a,
        uint256 b
    ) internal pure returns (uint256 result) {
        return (a * b) / PRECISION;
    }
    
    /**
     * @notice Calculate minimum of two values
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
    
    /**
     * @notice Calculate maximum of two values
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }
}

