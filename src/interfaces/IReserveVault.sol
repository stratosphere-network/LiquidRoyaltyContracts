// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IVault} from "./IVault.sol";

/**
 * @title IReserveVault
 * @notice Interface for Reserve vault
 * @dev Receives profit spillover from Senior, provides primary backstop (no cap!)
 * 
 * References from Mathematical Specification:
 * - Section: Three-Zone Spillover System
 * - Section: Backstop Mechanics (Primary layer, can be wiped out!)
 * - Section: Deposit Cap (S_max = 10 × V_r)
 */
interface IReserveVault is IVault {
    /// @dev Events
    event SpilloverReceived(uint256 amount, address fromSenior);
    event BackstopProvided(uint256 amount, address toSenior);
    event ReserveRebaseExecuted(uint256 newValue, int256 effectiveReturn);
    event DepositCapUpdated(uint256 oldCap, uint256 newCap);
    event ReserveBelowThreshold();
    event CooldownInitiated(address indexed user, uint256 timestamp);
    
    /// @dev Errors
    error InsufficientBackstopFunds();
    error ReserveDepleted();
    
    /**
     * @notice Receive profit spillover from Senior
     * @dev Reference: Three-Zone System - Zone 1 (Profit Spillover)
     * Formula: E_r = E × 0.20 (Reserve receives 20% of Senior's excess)
     * @param amount Amount of USD to receive (E_r)
     */
    function receiveSpillover(uint256 amount) external;
    
    /**
     * @notice Provide backstop to Senior via LP tokens (primary, no cap!)
     * @dev Reference: Three-Zone System - Zone 3 (Backstop)
     * Formula: X_r = min(V_r, D) - Takes ALL reserve if needed!
     * @param amountUSD Amount of USD needed
     * @param lpPrice Current LP token price in USD (18 decimals)
     * @return actualAmount Actual USD amount provided (entire reserve if needed)
     */
    function provideBackstop(uint256 amountUSD, uint256 lpPrice) external returns (uint256 actualAmount);
    
    function totalSpilloverReceived() external view returns (uint256);
    function totalBackstopProvided() external view returns (uint256);
    function currentDepositCap() external view returns (uint256);
    function backstopCapacity() external view returns (uint256);
    function isDepleted() external view returns (bool);
    function canProvideFullBackstop(uint256 amount) external view returns (bool);
    function utilizationRate() external view returns (uint256);
    
    /**
     * @notice Initiate withdrawal cooldown
     * @dev After 7 days, user can withdraw without 20% penalty
     */
    function initiateCooldown() external;
    
    /**
     * @notice Get user's cooldown start timestamp
     * @param user User address
     * @return Cooldown start timestamp (0 if not initiated)
     */
    function cooldownStart(address user) external view returns (uint256);
    
    /**
     * @notice Check if user can withdraw without penalty
     * @param user User address
     * @return True if cooldown period has passed
     */
    function canWithdrawWithoutPenalty(address user) external view returns (bool);
    
    /**
     * @notice Calculate withdrawal penalty for user
     * @param user User address
     * @param amount Withdrawal amount
     * @return penalty Penalty amount
     * @return netAmount Amount after penalty
     */
    function calculateWithdrawalPenalty(
        address user,
        uint256 amount
    ) external view returns (uint256 penalty, uint256 netAmount);
}


