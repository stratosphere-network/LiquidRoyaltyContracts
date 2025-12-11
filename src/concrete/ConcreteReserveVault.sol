// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReserveVault} from "../abstract/ReserveVault.sol";
import {MathLib} from "../libraries/MathLib.sol";
import {FeeLib} from "../libraries/FeeLib.sol";

/**
 * @title ConcreteReserveVault
 * @notice Concrete implementation of Reserve vault (ERC4626)
 * @dev No additional logic needed - receives spillover, provides primary backstop
 * @dev Upgradeable using UUPS proxy pattern
 */
contract ConcreteReserveVault is ReserveVault {
    /// @dev NEW role management (V2 upgrade)
    address private _liquidityManager;
    address private _priceFeedManager;
    address private _contractUpdater;
    
    /// @dev Cooldown mechanism (V3 upgrade - moved from ReserveVault for storage safety)
    mapping(address => uint256) private _cooldownStart;
    
    /// @dev Reentrancy guard state (V3 upgrade - MUST be in concrete contract)
    uint256 private _status;
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @notice Initialize Reserve vault (for proxy deployment)
     * @param stablecoin_ Stablecoin address (e.g., USDe-SAIL)
     * @param tokenName_ Token name ("Alar")
     * @param tokenSymbol_ Token symbol ("alar")
     * @param seniorVault_ Senior vault address
     * @param initialValue_ Initial vault value in USD
     * @param liquidityManager_ Liquidity manager address (N1 FIX: moved from V2)
     * @param priceFeedManager_ Price feed manager address (N1 FIX: moved from V2)
     * @param contractUpdater_ Contract updater address (N1 FIX: moved from V2)
     */
    function initialize(
        address stablecoin_,
        string memory tokenName_,
        string memory tokenSymbol_,
        address seniorVault_,
        uint256 initialValue_,
        address liquidityManager_,
        address priceFeedManager_,
        address contractUpdater_
    ) external initializer {
        __ReserveVault_init(
            stablecoin_,
            tokenName_,
            tokenSymbol_,
            seniorVault_,
            initialValue_
        );
        
        // N1 FIX: Set roles during initialization (consolidated from initializeV2)
        if (liquidityManager_ == address(0)) revert ZeroAddress();
        if (priceFeedManager_ == address(0)) revert ZeroAddress();
        if (contractUpdater_ == address(0)) revert ZeroAddress();
        _liquidityManager = liquidityManager_;
        _priceFeedManager = priceFeedManager_;
        _contractUpdater = contractUpdater_;
    }
    
    /**
     * @notice Initialize V2 - DEPRECATED (kept for backward compatibility)
     * @dev N1: Redundant - new deployments should use initialize() with all params
     * @dev Only kept for contracts already deployed with V1 initialize()
     * @dev SECURITY FIX: Added onlyAdmin to prevent front-running attack
     */
    function initializeV2(
        address liquidityManager_,
        address priceFeedManager_,
        address contractUpdater_
    ) external reinitializer(2) onlyAdmin {
        if (liquidityManager_ == address(0)) revert ZeroAddress();
        if (priceFeedManager_ == address(0)) revert ZeroAddress();
        if (contractUpdater_ == address(0)) revert ZeroAddress();
        _liquidityManager = liquidityManager_;
        _priceFeedManager = priceFeedManager_;
        _contractUpdater = contractUpdater_;
    }
    
    function liquidityManager() public view override returns (address) {
        return _liquidityManager;
    }
    
    function priceFeedManager() public view override returns (address) {
        return _priceFeedManager;
    }
    
    function contractUpdater() public view override returns (address) {
        return _contractUpdater;
    }
    
    function setLiquidityManager(address liquidityManager_) external onlyAdmin {
        if (liquidityManager_ == address(0)) revert ZeroAddress();
        _liquidityManager = liquidityManager_;
    }
    
    function setPriceFeedManager(address priceFeedManager_) external onlyAdmin {
        if (priceFeedManager_ == address(0)) revert ZeroAddress();
        _priceFeedManager = priceFeedManager_;
    }
    
    function setContractUpdater(address contractUpdater_) external onlyAdmin {
        if (contractUpdater_ == address(0)) revert ZeroAddress();
        _contractUpdater = contractUpdater_;
    }
    
    // ============================================
    // V3 Initialization
    // ============================================
    
    /**
     * @notice Initialize V3 - Initialize reentrancy guard
     * @dev Cooldown mapping defaults to 0 for all users
     * @dev SECURITY: Protected by onlyAdmin to prevent unauthorized reinitialization
     */
    function initializeV3() external reinitializer(3) onlyAdmin {
        // Initialize reentrancy guard
        _status = 1; // _NOT_ENTERED
    }
    
    // ============================================
    // Cooldown Mechanism (V3 - moved from abstract for storage safety)
    // ============================================
    
    /**
     * @notice Initiate withdrawal cooldown
     * @dev After 7 days, user can withdraw without 20% penalty
     */
    function initiateCooldown() external {
        _cooldownStart[msg.sender] = block.timestamp;
        emit CooldownInitiated(msg.sender, block.timestamp);
    }
    
    /**
     * @notice Get user's cooldown start timestamp
     * @param user User address
     * @return Cooldown start timestamp (0 if not initiated)
     */
    function cooldownStart(address user) external view returns (uint256) {
        return _cooldownStart[user];
    }
    
    /**
     * @notice Check if user can withdraw without penalty
     * @param user User address
     * @return True if cooldown period has passed
     */
    function canWithdrawWithoutPenalty(address user) external view returns (bool) {
        uint256 cooldownTime = _cooldownStart[user];
        if (cooldownTime == 0) return false;
        return (block.timestamp - cooldownTime) >= MathLib.COOLDOWN_PERIOD;
    }
    
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
    ) external view returns (uint256 penalty, uint256 netAmount) {
        uint256 cooldownTime = _cooldownStart[user];
        return FeeLib.calculateWithdrawalPenalty(amount, cooldownTime, block.timestamp);
    }
    
    /**
     * @notice Override withdraw to add cooldown penalty
     * @dev Applies 20% penalty if cooldown not met, then 1% withdrawal fee
     */
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override {
        // Check allowance if caller is not the owner
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }
        
        // Calculate early withdrawal penalty (20% if cooldown not met)
        uint256 cooldownTime = _cooldownStart[owner];
        (uint256 earlyPenalty, uint256 amountAfterEarlyPenalty) = 
            FeeLib.calculateWithdrawalPenalty(assets, cooldownTime, block.timestamp);
        
        // Calculate 1% withdrawal fee (applied to amount after early penalty)
        uint256 withdrawalFee = (amountAfterEarlyPenalty * MathLib.WITHDRAWAL_FEE) / MathLib.PRECISION;
        uint256 netAssets = amountAfterEarlyPenalty - withdrawalFee;
        
        // SECURITY FIX (CEI Pattern): Reset cooldown BEFORE external calls
        if (_cooldownStart[owner] != 0) {
            _cooldownStart[owner] = 0;
        }
        
        // Free up liquidity if needed (iterative approach)
        uint256 maxAttempts = 3;
        uint256 totalFreed = 0;
        
        for (uint256 i = 0; i < maxAttempts; i++) {
            uint256 vaultBalance = stablecoin().balanceOf(address(this));
            
            if (vaultBalance >= assets) {
                break; // We have enough
            }
            
            if (address(kodiakHook) == address(0)) {
                revert InsufficientLiquidity();
            }
            
            // Calculate how much more we need
            uint256 needed = assets - vaultBalance;
            uint256 balanceBefore = vaultBalance;
            
            // Calculate minimum expected amount with slippage tolerance
            uint256 minExpected = _calculateMinExpectedFromLP(needed);
            
            // Call hook to liquidate LP with smart estimation
            try kodiakHook.liquidateLPForAmount(needed) {
                uint256 balanceAfter = stablecoin().balanceOf(address(this));
                uint256 freedThisRound = balanceAfter > balanceBefore ? balanceAfter - balanceBefore : 0;
                totalFreed += freedThisRound;
                
                // Check slippage protection (only if minExpected > 0)
                if (minExpected > 0 && freedThisRound < minExpected) {
                    revert SlippageTooHigh();
                }
                
                emit LPLiquidationExecuted(needed, freedThisRound, minExpected);
                
                // If we didn't get any more funds, stop trying
                if (freedThisRound == 0) {
                    break;
                }
            } catch {
                // If hook call fails, stop trying
                break;
            }
        }
        
        // Final check: do we have enough now?
        uint256 finalBalance = stablecoin().balanceOf(address(this));
        if (finalBalance < assets) {
            revert InsufficientLiquidity();
        }
        
        // Emit event if we had to free up liquidity
        if (totalFreed > 0) {
            emit LiquidityFreedForWithdrawal(assets, totalFreed);
        }
        
        // REENTRANCY FIX: Effects before Interactions
        _burn(owner, shares);
        
        // Track capital outflow (must update since we override parent's _withdraw)
        _vaultValue -= amountAfterEarlyPenalty;
        
        // Interactions: Transfer assets (after state changes)
        stablecoin().transfer(receiver, netAssets);
        
        // Transfer withdrawal fee to treasury
        address treasuryAddr = treasury();
        if (treasuryAddr != address(0) && withdrawalFee > 0) {
            stablecoin().transfer(treasuryAddr, withdrawalFee);
            emit WithdrawalFeeCharged(owner, withdrawalFee, netAssets);
        }
        
        // Emit early penalty event if applicable
        if (earlyPenalty > 0) {
            emit WithdrawalPenaltyCharged(owner, earlyPenalty);
        }
        
        emit Withdraw(caller, receiver, owner, amountAfterEarlyPenalty, shares);
    }
    
    /**
     * @notice Override ERC20 _update to reset cooldown on token transfers
     * @dev SECURITY FIX: Prevents cooldown bypass by transferring tokens between addresses
     */
    function _update(address from, address to, uint256 value) internal override {
        // Call parent implementation first
        super._update(from, to, value);
        
        // SECURITY FIX: Reset cooldown when receiving tokens (transfer or mint)
        if (to != address(0) && _cooldownStart[to] != 0) {
            _cooldownStart[to] = 0;
        }
    }
    
    // ============================================
    // Reentrancy Guard Implementation (Required by BaseVault)
    // ============================================
    
    /**
     * @notice Get reentrancy guard status
     * @dev Implements virtual function from BaseVault
     */
    function _getReentrancyStatus() internal view override returns (uint256) {
        return _status;
    }
    
    /**
     * @notice Set reentrancy guard status
     * @dev Implements virtual function from BaseVault
     */
    function _setReentrancyStatus(uint256 status) internal override {
        _status = status;
    }
    
    // ============================================
    // Events (additional to parent interface)
    // ============================================
    
    event WithdrawalPenaltyCharged(address indexed user, uint256 penalty);
}

