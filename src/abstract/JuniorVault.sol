// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseVault} from "./BaseVault.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IJuniorVault} from "../interfaces/IJuniorVault.sol";
import {MathLib} from "../libraries/MathLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title JuniorVault
 * @notice Abstract Junior Tranche vault (Standard ERC4626)
 * @dev Receives profit spillover (80%), provides secondary backstop (no cap!)
 * @dev Upgradeable using UUPS proxy pattern
 * 
 * Users deposit Stablecoins, receive standard ERC4626 shares (NOT rebasing)
 * 
 * References from Mathematical Specification:
 * - Section: Three-Zone Spillover System (Junior APY Impact)
 * - Section: Backstop Mechanics (Secondary layer)
 */
abstract contract JuniorVault is BaseVault, IJuniorVault {
    using MathLib for uint256;
    
    /// @dev State Variables
    uint256 internal _totalSpilloverReceived;    // Cumulative spillover
    uint256 internal _totalBackstopProvided;     // Cumulative backstop
    uint256 internal _lastMonthValue;            // For return calculation
    
    /// @dev Errors (defined in interface or BaseVault, no need to redeclare)
    
    /**
     * @notice Initialize Junior vault (replaces constructor for upgradeable)
     * @param stablecoin_ Stablecoin address
     * @param vaultName_ ERC20 name for shares (e.g., "Junior Tranche Shares")
     * @param vaultSymbol_ ERC20 symbol for shares (e.g., "jTRN")
     * @param seniorVault_ Senior vault address (can be placeholder)
     * @param initialValue_ Initial vault value
     */
    function __JuniorVault_init(
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
     * @dev Reference: Junior APY Impact - r_j^eff = (Π_j - F_j ± E_j/X_j) / V_j
     */
    function effectiveMonthlyReturn() public view virtual returns (int256) {
        if (_lastMonthValue == 0) return 0;
        
        // Calculate profit/loss from strategy
        int256 strategyReturn = int256(_vaultValue) - int256(_lastMonthValue);
        
        // Return as percentage (in 18 decimals)
        return (strategyReturn * int256(MathLib.PRECISION)) / int256(_lastMonthValue);
    }
    
    /**
     * @notice Get current APY (annualized)
     * @dev Reference: Junior APY Impact - APY_j = (1 + r_j^eff)^12 - 1
     * Note: Simplified calculation, actual implementation should use proper compounding
     */
    function currentAPY() public view virtual returns (int256) {
        int256 monthlyReturn = effectiveMonthlyReturn();
        // Simplified: APY ≈ monthly return × 12 (actual should compound)
        return monthlyReturn * 12;
    }
    
    /**
     * @notice Check if can provide backstop
     */
    function canProvideBackstop(uint256 amount) public view virtual returns (bool) {
        return _vaultValue >= amount;
    }
    
    /**
     * @notice Get available backstop capacity
     * @dev Junior provides EVERYTHING if needed (no cap!)
     */
    function backstopCapacity() public view virtual returns (uint256) {
        return _vaultValue;
    }
    
    // ============================================
    // Senior Vault Functions (Restricted)
    // ============================================
    
    /**
     * @notice Receive profit spillover from Senior
     * @dev Reference: Three-Zone System - Zone 1
     * Formula: E_j = E × 0.80
     */
    function receiveSpillover(uint256 amount) public virtual onlySeniorVault {
        if (amount == 0) return;
        
        // Increase vault value
        _vaultValue += amount;
        _totalSpilloverReceived += amount;
        
        emit SpilloverReceived(amount, msg.sender);
    }
    
    /**
     * @notice Provide backstop to Senior via LP tokens (secondary, after Reserve)
     * @dev Reference: Three-Zone System - Zone 3
     * Formula: X_j = min(V_j, D')
     * @param amountUSD Amount requested (in USD)
     * @param lpPrice Current LP token price in USD (18 decimals)
     * @return actualAmount Actual USD amount provided (may be entire vault!)
     */
    function provideBackstop(uint256 amountUSD, uint256 lpPrice) public virtual onlySeniorVault returns (uint256 actualAmount) {
        if (amountUSD == 0) return 0;
        if (lpPrice == 0) return 0;
        if (address(kodiakHook) == address(0)) revert InsufficientBackstopFunds();
        
        // Calculate LP amount needed
        uint256 lpAmountNeeded = (amountUSD * 1e18) / lpPrice;
        
        // Check Junior Hook's actual LP token balance
        uint256 lpBalance = kodiakHook.getIslandLPBalance();
        
        // Provide up to available LP tokens
        uint256 actualLPAmount = lpAmountNeeded > lpBalance ? lpBalance : lpAmountNeeded;
        
        if (actualLPAmount == 0) revert InsufficientBackstopFunds();
        
        // Calculate actual USD amount based on LP tokens available
        actualAmount = (actualLPAmount * lpPrice) / 1e18;
        
        // Decrease vault value
        _vaultValue -= actualAmount;
        _totalBackstopProvided += actualAmount;
        
        // Get Senior's hook address and transfer LP from Junior Hook to Senior Hook
        address seniorHook = address(IVault(_seniorVault).kodiakHook());
        require(seniorHook != address(0), "Senior hook not set");
        kodiakHook.transferIslandLP(seniorHook, actualLPAmount);
        
        emit BackstopProvided(actualAmount, msg.sender);
        
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
        emit JuniorRebaseExecuted(newValue, effectiveMonthlyReturn());
    }
}
