// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IVault} from "./IVault.sol";

/**
 * @title IJuniorVault
 * @notice Interface for Junior Tranche vault
 * @dev Receives profit spillover from Senior, provides secondary backstop
 * 
 * References from Mathematical Specification:
 * - Section: Three-Zone Spillover System (Junior APY Impact)
 * - Section: Backstop Mechanics (Secondary layer after Reserve)
 */
interface IJuniorVault is IVault {
    /// @dev Events
    event SpilloverReceived(uint256 amount, address fromSenior);
    event BackstopProvided(uint256 amount, address toSenior);
    event JuniorRebaseExecuted(uint256 newValue, int256 effectiveReturn);
    
    /// @dev Errors
    error InsufficientBackstopFunds();
    
    /**
     * @notice Receive profit spillover from Senior
     * @dev Reference: Three-Zone System - Zone 1 (Profit Spillover)
     * Formula: E_j = E × 0.80 (Junior receives 80% of Senior's excess)
     * @param amount Amount of USD to receive (E_j)
     */
    function receiveSpillover(uint256 amount) external;
    
    /**
     * @notice Provide backstop to Senior via LP tokens (secondary, after Reserve)
     * @dev Reference: Three-Zone System - Zone 3 (Backstop)
     * Formula: X_j = min(V_j, D') where D' is remaining deficit after Reserve
     * @param amountUSD Amount of USD needed
     * @param lpPrice Current LP token price in USD (18 decimals)
     * @return actualAmount Actual USD amount provided (may be less if insufficient)
     */
    function provideBackstop(uint256 amountUSD, uint256 lpPrice) external returns (uint256 actualAmount);
    
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
     * @dev Reference: Junior APY Impact - r_j^eff = (Π_j - F_j ± E_j/X_j) / V_j
     * @return effectiveReturn Monthly return in 18 decimal precision
     */
    function effectiveMonthlyReturn() external view returns (int256 effectiveReturn);
    
    /**
     * @notice Get Junior's current APY (annualized)
     * @dev Reference: Junior APY Impact - APY_j = (1 + r_j^eff)^12 - 1
     * @return apy Annual percentage yield in basis points
     */
    function currentAPY() external view returns (int256 apy);
    
    /**
     * @notice Check if Junior has sufficient funds for backstop
     * @param amount Amount needed
     * @return hasFunds True if can provide full amount
     */
    function canProvideBackstop(uint256 amount) external view returns (bool hasFunds);
    
    /**
     * @notice Get available backstop capacity
     * @dev Maximum amount Junior can provide right now
     * @return capacity Available funds for backstop
     */
    function backstopCapacity() external view returns (uint256 capacity);
}


