// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseVault} from "./BaseVault.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IReserveVault} from "../interfaces/IReserveVault.sol";
import {MathLib} from "../libraries/MathLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ReserveVault
 * @notice Abstract Reserve vault (Standard ERC4626)
 * @dev Receives profit spillover (20%), provides primary backstop (no cap - can be wiped out!)
 * @dev Upgradeable using UUPS proxy pattern
 * 
 * Users deposit Stablecoins, receive standard ERC4626 shares (NOT rebasing)
 * 
 * References from Mathematical Specification:
 * - Section: Three-Zone Spillover System
 * - Section: Backstop Mechanics (Primary layer)
 * - Section: Deposit Cap (S_max = 10 × V_r)
 */
abstract contract ReserveVault is BaseVault, IReserveVault {
    using MathLib for uint256;
    
    /// @dev State Variables
    uint256 internal _totalSpilloverReceived;    // Cumulative spillover
    uint256 internal _totalBackstopProvided;     // Cumulative backstop
    uint256 internal _lastMonthValue;            // For return calculation
    
    /// @dev Minimum reserve threshold (1% of initial value)
    uint256 internal constant DEPLETION_THRESHOLD = 1e16; // 1%
    
    /// @dev Errors (defined in interface or BaseVault, no need to redeclare)
    
    /**
     * @notice Initialize Reserve vault (replaces constructor for upgradeable)
     * @param stablecoin_ Stablecoin address
     * @param vaultName_ ERC20 name for shares (e.g., "Reserve Tranche Shares")
     * @param vaultSymbol_ ERC20 symbol for shares (e.g., "rTRN")
     * @param seniorVault_ Senior vault address (can be placeholder)
     * @param initialValue_ Initial vault value
     */
    function __ReserveVault_init(
        address stablecoin_,
        string memory vaultName_,
        string memory vaultSymbol_,
        address seniorVault_,
        uint256 initialValue_
    ) internal onlyInitializing {
        __BaseVault_init(stablecoin_, vaultName_, vaultSymbol_, seniorVault_, initialValue_);
        _lastMonthValue = initialValue_;
    }
    
    // ============================================
    // View Functions
    // ============================================
    
    function seniorVault() public view virtual override(BaseVault, IVault) returns (address) {
        return _seniorVault;
    }
    
    function totalSpilloverReceived() public view virtual returns (uint256) {
        return _totalSpilloverReceived;
    }
    
    function totalBackstopProvided() public view virtual returns (uint256) {
        return _totalBackstopProvided;
    }
    
    /**
     * @notice Calculate effective monthly return
     */
    function effectiveMonthlyReturn() public view virtual returns (int256) {
        if (_lastMonthValue == 0) return 0;
        
        // Calculate profit/loss from strategy + spillover - backstop
        int256 strategyReturn = int256(_vaultValue) - int256(_lastMonthValue);
        
        // Return as percentage (in 18 decimals)
        return (strategyReturn * int256(MathLib.PRECISION)) / int256(_lastMonthValue);
    }
    
    /**
     * @notice Get current deposit cap for Senior
     * @dev Reference: Deposit Cap - S_max = γ × V_r = 10 × V_r
     */
    function currentDepositCap() public view virtual returns (uint256) {
        return MathLib.calculateDepositCap(_vaultValue);
    }
    
    /**
     * @notice Check if reserve is depleted
     * @dev Reserve considered depleted if below 1% of initial value
     */
    function isDepleted() public view virtual returns (bool) {
        uint256 initialValue = _lastMonthValue; // Simplified: use last month as reference
        uint256 threshold = (initialValue * DEPLETION_THRESHOLD) / MathLib.PRECISION;
        return _vaultValue < threshold;
    }
    
    /**
     * @notice Get available backstop capacity
     * @dev Reference: Backstop - Reserve provides EVERYTHING (no cap!)
     */
    function backstopCapacity() public view virtual returns (uint256) {
        return _vaultValue;
    }
    
    /**
     * @notice Check if can provide full backstop
     */
    function canProvideFullBackstop(uint256 amount) public view virtual returns (bool) {
        return _vaultValue >= amount;
    }
    
    /**
     * @notice Get utilization rate
     * @dev Percentage of reserve that has been used for backstop
     */
    function utilizationRate() public view virtual returns (uint256) {
        uint256 totalReceived = _totalSpilloverReceived;
        uint256 totalProvided = _totalBackstopProvided;
        
        if (totalReceived == 0 && totalProvided == 0) return 0;
        
        uint256 total = totalReceived + _lastMonthValue;
        if (total == 0) return 0;
        
        return (totalProvided * MathLib.BPS_DENOMINATOR) / total;
    }
    
    // ============================================
    // Senior Vault Functions (Restricted)
    // ============================================
    
    /**
     * @notice Receive profit spillover from Senior
     * @dev Reference: Three-Zone System - Zone 1
     * Formula: E_r = E × 0.20
     */
    function receiveSpillover(uint256 amount) public virtual onlySeniorVault {
        if (amount == 0) return;
        
        // Increase vault value
        _vaultValue += amount;
        _totalSpilloverReceived += amount;
        
        emit SpilloverReceived(amount, msg.sender);
        
        // Emit deposit cap update
        uint256 newCap = currentDepositCap();
        emit DepositCapUpdated(0, newCap);
    }
    
    /**
     * @notice Provide backstop to Senior via LP tokens (primary, no cap!)
     * @dev Reference: Three-Zone System - Zone 3
     * Formula: X_r = min(V_r, D)
     * @param amountUSD Amount requested (in USD)
     * @param lpPrice Current LP token price in USD (18 decimals)
     * @return actualAmount Actual USD amount provided (entire reserve if needed!)
     */
    function provideBackstop(uint256 amountUSD, uint256 lpPrice) public virtual onlySeniorVault returns (uint256 actualAmount) {
        if (amountUSD == 0) return 0;
        if (lpPrice == 0) return 0;
        
        // Get whitelisted LP tokens (should be only one)
        if (_whitelistedLPTokens.length == 0) revert ReserveDepleted();
        address lpToken = _whitelistedLPTokens[0];
        
        // Calculate LP amount needed
        uint256 lpAmountNeeded = (amountUSD * 1e18) / lpPrice;
        
        // Check actual LP token balance
        uint256 lpBalance = IERC20(lpToken).balanceOf(address(this));
        
        // Provide up to available LP tokens
        uint256 actualLPAmount = lpAmountNeeded > lpBalance ? lpBalance : lpAmountNeeded;
        
        if (actualLPAmount == 0) revert ReserveDepleted();
        
        // Calculate actual USD amount based on LP tokens available
        actualAmount = (actualLPAmount * lpPrice) / 1e18;
        
        // Decrease vault value (can go to zero!)
        uint256 oldCap = currentDepositCap();
        _vaultValue -= actualAmount;
        _totalBackstopProvided += actualAmount;
        uint256 newCap = currentDepositCap();
        
        // Transfer LP tokens to Senior vault
        IERC20(lpToken).transfer(_seniorVault, actualLPAmount);
        
        emit BackstopProvided(actualAmount, msg.sender);
        emit DepositCapUpdated(oldCap, newCap);
        
        // Check if depleted
        if (isDepleted()) {
            emit ReserveBelowThreshold();
        }
        
        return actualAmount;
    }
    
    // ============================================
    // Internal Functions
    // ============================================
    
    /**
     * @notice Hook after value update to track monthly returns
     */
    function _afterValueUpdate(uint256 oldValue, uint256 newValue) internal virtual override {
        _lastMonthValue = oldValue;
        emit ReserveRebaseExecuted(newValue, effectiveMonthlyReturn());
    }
}
