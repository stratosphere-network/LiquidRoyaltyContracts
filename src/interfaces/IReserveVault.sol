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
     * @notice Provide backstop to Senior (primary, no cap!)
     * @dev Reference: Three-Zone System - Zone 3 (Backstop)
     * Formula: X_r = min(V_r, D) - Takes ALL reserve if needed!
     * @param amount Amount of USD needed
     * @return actualAmount Actual amount provided (entire reserve if needed)
     */
    function provideBackstop(uint256 amount) external returns (uint256 actualAmount);
    
    /**
     * @notice Get total spillover received (lifetime)
     * @return totalSpillover Cumulative spillover from Senior
     */
    function totalSpilloverReceived() external view returns (uint256 totalSpillover);
    
    /**
     * @notice Get total backstop provided (lifetime)
     * @return totalBackstop Cumulative backstop to Senior
     */
    function totalBackstopProvided() external view returns (uint256 totalBackstop);
    
    /**
     * @notice Calculate effective monthly return including spillover/backstop
     * @dev Reference: Reserve growth tracking
     * @return effectiveReturn Monthly return in 18 decimal precision
     */
    function effectiveMonthlyReturn() external view returns (int256 effectiveReturn);
    
    /**
     * @notice Get current deposit cap for Senior based on Reserve
     * @dev Reference: Deposit Cap - S_max = γ × V_r = 10 × V_r
     * @return cap Maximum Senior supply allowed (10x reserve value)
     */
    function currentDepositCap() external view returns (uint256 cap);
    
    /**
     * @notice Check if Reserve is depleted (wiped out)
     * @dev Can happen in catastrophic backstop scenarios
     * @return isDepleted True if reserve value is effectively zero
     */
    function isDepleted() external view returns (bool isDepleted);
    
    /**
     * @notice Get available backstop capacity
     * @dev Reference: Backstop waterfall - Reserve provides EVERYTHING if needed
     * @return capacity Full reserve value (no limits!)
     */
    function backstopCapacity() external view returns (uint256 capacity);
    
    /**
     * @notice Check if Reserve can provide full backstop amount
     * @param amount Amount needed
     * @return canProvide True if reserve has enough, false if would be depleted
     */
    function canProvideFullBackstop(uint256 amount) external view returns (bool canProvide);
    
    /**
     * @notice Get utilization rate (how much has been used for backstop vs total)
     * @dev Useful for risk assessment
     * @return utilization Percentage in basis points (10000 = 100%)
     */
    function utilizationRate() external view returns (uint256 utilization);
}

