// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IVault} from "./IVault.sol";
import {SpilloverLib} from "../libraries/SpilloverLib.sol";
import {RebaseLib} from "../libraries/RebaseLib.sol";

/**
 * @title ISeniorVault
 * @notice Interface for unified Senior Tranche vault (IS the snrUSD token)
 * @dev UNIFIED ARCHITECTURE: This vault IS the ERC20 token, not a separate contract
 *      Implements rebase mechanism, three-zone system, and dynamic APY selection
 * 
 * References from Mathematical Specification:
 * - Section: User Balance & Shares (b_i = σ_i × I)
 * - Section: Rebase Algorithm
 * - Section: Three-Zone Spillover System
 * - Section: Dynamic APY Selection (11-13%)
 */
interface ISeniorVault is IVault {
    /// @dev Events
    event RebaseExecuted(
        uint256 indexed epoch,
        uint8 apyTier,
        uint256 oldIndex,
        uint256 newIndex,
        uint256 newSupply,
        SpilloverLib.Zone zone
    );
    event ProfitSpillover(
        uint256 excessAmount,
        uint256 toJunior,
        uint256 toReserve
    );
    event BackstopTriggered(
        uint256 deficitAmount,
        uint256 fromReserve,
        uint256 fromJunior,
        bool fullyRestored
    );
    event CooldownInitiated(address indexed user, uint256 timestamp);
    event WithdrawalPenaltyCharged(address indexed user, uint256 penalty);
    
    /// @dev Errors
    error CooldownNotMet();
    error RebaseTooSoon();
    error InvalidAPYTier();
    
    /**
     * @notice Get user's share balance (σ_i)
     * @dev Reference: User State - shares are constant unless user mints/burns
     * @param account User address
     * @return shares User's share balance
     */
    function sharesOf(address account) external view returns (uint256 shares);
    
    /**
     * @notice Get total shares (Σ)
     * @dev Reference: Total Supply - S = I × Σ
     * @return totalShares Total shares across all users
     */
    function totalShares() external view returns (uint256 totalShares);
    
    /**
     * @notice Get current rebase index (I)
     * @dev Reference: Core Formulas - b_i = σ_i × I
     * @return index Current rebase index (18 decimals)
     */
    function rebaseIndex() external view returns (uint256 index);
    
    /**
     * @notice Get current rebase epoch
     * @return epoch Rebase counter (increments each rebase)
     */
    function epoch() external view returns (uint256 epoch);
    
    /**
     * @notice Get Junior vault address
     * @dev Reference: State Variables (V_j - Junior vault value)
     * Used for backstop and profit spillover
     * @return juniorVault Address of Junior vault
     */
    function juniorVault() external view returns (address juniorVault);
    
    /**
     * @notice Get Reserve vault address
     * @dev Reference: State Variables (V_r - Reserve vault value)
     * Used for backstop and profit spillover
     * @return reserveVault Address of Reserve vault
     */
    function reserveVault() external view returns (address reserveVault);
    
    /**
     * @notice Get current backing ratio
     * @dev Reference: Core Formulas - R_senior = V_s / S
     * @return backingRatio Ratio in 18 decimal precision (1e18 = 100%)
     */
    function backingRatio() external view returns (uint256 backingRatio);
    
    /**
     * @notice Get current operating zone
     * @dev Reference: Three-Zone Spillover System
     * @return zone Current zone (BACKSTOP, HEALTHY, or SPILLOVER)
     */
    function currentZone() external view returns (SpilloverLib.Zone zone);
    
    /**
     * @notice Execute monthly rebase
     * @dev Reference: Rebase Algorithm (all steps)
     * 1. Calculate management fee
     * 2. Dynamic APY selection (13% → 12% → 11%)
     * 3. Mint new tokens (users + performance fee)
     * 4. Determine zone & execute spillover/backstop
     * 5. Update rebase index
     */
    function rebase() external;
    
    /**
     * @notice Simulate rebase without executing
     * @dev Useful for off-chain analysis
     * @return selection APY selection result
     * @return zone Operating zone after rebase
     * @return newBackingRatio Backing ratio after rebase
     */
    function simulateRebase() external view returns (
        RebaseLib.APYSelection memory selection,
        SpilloverLib.Zone zone,
        uint256 newBackingRatio
    );
    
    /**
     * @notice Initiate withdrawal cooldown
     * @dev Reference: Parameters (τ = 7 days cooldown)
     * Must be called before penalty-free withdrawal
     */
    function initiateCooldown() external;
    
    /**
     * @notice Get user's cooldown initiation time
     * @dev Reference: User State (t_c^(i))
     * @param user User address
     * @return cooldownStart Timestamp when cooldown was initiated (0 if not initiated)
     */
    function cooldownStart(address user) external view returns (uint256 cooldownStart);
    
    /**
     * @notice Check if user can withdraw without penalty
     * @dev Reference: Fee Calculations - Early Withdrawal Penalty
     * @param user User address
     * @return canWithdraw True if cooldown period has passed
     */
    function canWithdrawWithoutPenalty(address user) external view returns (bool canWithdraw);
    
    /**
     * @notice Calculate withdrawal penalty for user
     * @dev Reference: Fee Calculations - P(w, t_c)
     * @param user User address
     * @param amount Withdrawal amount
     * @return penalty Penalty amount (0 if cooldown met)
     * @return netAmount Amount after penalty
     */
    function calculateWithdrawalPenalty(
        address user,
        uint256 amount
    ) external view returns (uint256 penalty, uint256 netAmount);
    
    /**
     * @notice Get last rebase timestamp
     * @dev Reference: State Variables (T_r)
     * @return timestamp Last rebase execution time
     */
    function lastRebaseTime() external view returns (uint256 timestamp);
    
    /**
     * @notice Get minimum time between rebases (30 days)
     * @return minInterval Minimum rebase interval in seconds
     */
    function minRebaseInterval() external view returns (uint256 minInterval);
    
    /**
     * @notice Get protocol treasury address
     * @dev Receives performance fee tokens
     * @return treasury Treasury address
     */
    function treasury() external view returns (address treasury);
    
    /**
     * @notice Get total snrUSD supply
     * @dev Reference: Total Supply - S = I × Σ
     * @return supply Current circulating supply
     */
    function totalSupply() external view returns (uint256 supply);
    
    /**
     * @notice Check if deposit cap is reached
     * @dev Reference: Deposit Cap - S_max = 10 × V_r
     * @return isReached True if at/above cap
     */
    function isDepositCapReached() external view returns (bool isReached);
    
    /**
     * @notice Get current deposit cap
     * @dev Reference: Constraints & Invariants (Invariant 4)
     * @return cap Maximum allowed supply based on reserve
     */
    function depositCap() external view returns (uint256 cap);
}

