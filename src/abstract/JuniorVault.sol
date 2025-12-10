// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseVault} from "./BaseVault.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IJuniorVault} from "../interfaces/IJuniorVault.sol";
import {MathLib} from "../libraries/MathLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

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
    using SafeERC20 for IERC20;
    
    /// @dev State Variables
    uint256 internal _totalSpilloverReceived;    // Cumulative spillover
    uint256 internal _totalBackstopProvided;     // Cumulative backstop
    uint256 internal _lastMonthValue;            // For return calculation
    
    /// @dev Pending LP Deposit System
    struct PendingLPDeposit {
        address depositor;
        address lpToken;
        uint256 amount;
        uint256 timestamp;
        uint256 expiresAt;
        DepositStatus status;
    }
    
    enum DepositStatus {
        PENDING,
        APPROVED,
        REJECTED,
        EXPIRED,
        CANCELLED
    }
    
    uint256 internal _nextDepositId;
    mapping(uint256 => PendingLPDeposit) internal _pendingDeposits;
    mapping(address => uint256[]) internal _userDepositIds;
    
    uint256 internal constant DEPOSIT_EXPIRY_TIME = 48 hours;
    
    /// @dev Pending LP Deposit Events
    event PendingLPDepositCreated(
        uint256 indexed depositId,
        address indexed depositor,
        address indexed lpToken,
        uint256 amount,
        uint256 expiresAt
    );
    event PendingLPDepositApproved(
        uint256 indexed depositId,
        address indexed depositor,
        uint256 lpPrice,
        uint256 sharesMinted
    );
    event PendingLPDepositRejected(
        uint256 indexed depositId,
        address indexed depositor,
        string reason
    );
    event PendingLPDepositCancelled(
        uint256 indexed depositId,
        address indexed depositor
    );
    event PendingLPDepositExpired(
        uint256 indexed depositId,
        address indexed depositor
    );
    
    /// @dev Pending LP Deposit Errors
    error DepositNotFound();
    error DepositNotPending();
    error DepositExpired();
    error NotDepositor();
    error DepositNotExpired();
    
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
        
        // LP DECIMALS FIX: Get LP token and its decimals
        address lpToken = address(kodiakHook.island());
        uint8 lpDecimals = IERC20Metadata(lpToken).decimals();
        
        // SECURITY FIX: Use Math.mulDiv() to avoid divide-before-multiply precision loss
        // Calculate LP amount needed (accounting for LP decimals)
        // lpPrice is in 18 decimals (USD per LP token)
        uint256 lpAmountNeeded = Math.mulDiv(amountUSD, 10 ** lpDecimals, lpPrice);
        
        // Check Junior Hook's actual LP token balance
        uint256 lpBalance = kodiakHook.getIslandLPBalance();
        
        // Provide up to available LP tokens
        uint256 actualLPAmount = lpAmountNeeded > lpBalance ? lpBalance : lpAmountNeeded;
        
        if (actualLPAmount == 0) revert InsufficientBackstopFunds();
        
        // SECURITY FIX: Use Math.mulDiv() for precise USD conversion
        // Calculate actual USD amount based on LP tokens available (accounting for decimals)
        actualAmount = Math.mulDiv(actualLPAmount, lpPrice, 10 ** lpDecimals);
        
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
    // Pending LP Deposit System (Junior Only)
    // ============================================
    
    /**
     * @notice Deposit LP tokens (pending admin approval)
     * @dev LP tokens are transferred to vault's hook immediately
     * @param lpToken Address of LP token to deposit
     * @param amount Amount of LP tokens
     * @return depositId ID of pending deposit
     */
    function depositLP(address lpToken, uint256 amount) external returns (uint256 depositId) {
        if (lpToken == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (address(kodiakHook) == address(0)) revert KodiakHookNotSet();
      
        if (lpToken != address(kodiakHook.island())) revert InvalidLPToken();
        
        // Create pending deposit (Effects - state updates BEFORE external call)
        depositId = _nextDepositId++;
        uint256 expiresAt = block.timestamp + DEPOSIT_EXPIRY_TIME;
        
        _pendingDeposits[depositId] = PendingLPDeposit({
            depositor: msg.sender,
            lpToken: lpToken,
            amount: amount,
            timestamp: block.timestamp,
            expiresAt: expiresAt,
            status: DepositStatus.PENDING
        });
        
        _userDepositIds[msg.sender].push(depositId);
        
        emit PendingLPDepositCreated(depositId, msg.sender, lpToken, amount, expiresAt);
        
        // Transfer LP from user to hook (Interaction - external call LAST per CEI pattern)
        IERC20(lpToken).safeTransferFrom(msg.sender, address(kodiakHook), amount);
    }
    
    /**
     * @notice Approve pending LP deposit and mint shares
     * @dev Only admin can approve. Mints shares based on LP price.
     * @param depositId ID of pending deposit
     * @param lpPrice Price of LP token in USD (18 decimals)
     */
    function approveLPDeposit(uint256 depositId, uint256 lpPrice) external onlyLiquidityManager {
        PendingLPDeposit storage pendingDeposit = _pendingDeposits[depositId];
        
        if (pendingDeposit.depositor == address(0)) revert DepositNotFound();
        if (pendingDeposit.status != DepositStatus.PENDING) revert DepositNotPending();
        if (block.timestamp > pendingDeposit.expiresAt) revert DepositExpired();
        if (lpPrice == 0) revert InvalidLPPrice();
        
        // Calculate value and shares (Q5 FIX: account for LP token decimals)
        uint8 lpDecimals = IERC20Metadata(pendingDeposit.lpToken).decimals();
        uint256 normalizedAmount = _normalizeToDecimals(pendingDeposit.amount, lpDecimals, 18);
        uint256 valueAdded = (normalizedAmount * lpPrice) / 1e18;
        
        // N1-2 FIX: Use ERC4626 standard preview (calculates shares based on current state)
        uint256 sharesToMint = previewDeposit(valueAdded);
        if (sharesToMint == 0) revert InvalidAmount(); // Safety: prevent 0-share minting
        
        // Update status (Effects - state updates BEFORE external call)
        pendingDeposit.status = DepositStatus.APPROVED;
        
        emit PendingLPDepositApproved(depositId, pendingDeposit.depositor, lpPrice, sharesToMint);
        
        // N1-2 FIX: Mint shares BEFORE updating vault value (matches standard ERC4626 flow)
        _mint(pendingDeposit.depositor, sharesToMint);
        
        // Update vault value AFTER minting (consistent with deposit() override pattern)
        _vaultValue += valueAdded;
        _lastUpdateTime = block.timestamp;
    }
    
    /**
     * @notice Reject pending LP deposit and return LP to depositor
     * @dev Only admin can reject
     * @param depositId ID of pending deposit
     * @param reason Reason for rejection
     */
    function rejectLPDeposit(uint256 depositId, string calldata reason) external onlyLiquidityManager nonReentrant {
        PendingLPDeposit storage pendingDeposit = _pendingDeposits[depositId];
        
        if (pendingDeposit.depositor == address(0)) revert DepositNotFound();
        if (pendingDeposit.status != DepositStatus.PENDING) revert DepositNotPending();
        
        // Update status (Effects - state update BEFORE external call)
        pendingDeposit.status = DepositStatus.REJECTED;
        
        emit PendingLPDepositRejected(depositId, pendingDeposit.depositor, reason);
        
        // Transfer LP back from hook to depositor (Interaction - external call LAST per CEI pattern)
        kodiakHook.transferIslandLP(pendingDeposit.depositor, pendingDeposit.amount);
    }
    
    /**
     * @notice Cancel pending LP deposit (depositor only)
     * @dev Depositor can cancel anytime before approval
     * @param depositId ID of pending deposit
     */
    function cancelPendingDeposit(uint256 depositId) external nonReentrant {
        PendingLPDeposit storage pendingDeposit = _pendingDeposits[depositId];
        
        if (pendingDeposit.depositor == address(0)) revert DepositNotFound();
        if (pendingDeposit.depositor != msg.sender) revert NotDepositor();
        if (pendingDeposit.status != DepositStatus.PENDING) revert DepositNotPending();
        
        // Update status (Effects - state update BEFORE external call)
        pendingDeposit.status = DepositStatus.CANCELLED;
        
        emit PendingLPDepositCancelled(depositId, pendingDeposit.depositor);
        
        // Transfer LP back from hook to depositor (Interaction - external call LAST per CEI pattern)
        kodiakHook.transferIslandLP(pendingDeposit.depositor, pendingDeposit.amount);
    }
    
    /**
     * @notice Claim expired deposit (anyone can call)
     * @dev Returns LP to original depositor after expiry
     * @param depositId ID of pending deposit
     */
    function claimExpiredDeposit(uint256 depositId) external nonReentrant {
        PendingLPDeposit storage pendingDeposit = _pendingDeposits[depositId];
        
        if (pendingDeposit.depositor == address(0)) revert DepositNotFound();
        if (pendingDeposit.status != DepositStatus.PENDING) revert DepositNotPending();
        if (block.timestamp <= pendingDeposit.expiresAt) revert DepositNotExpired();
        
        // Update status (Effects - state update BEFORE external call)
        pendingDeposit.status = DepositStatus.EXPIRED;
        
        emit PendingLPDepositExpired(depositId, pendingDeposit.depositor);
        
        // Transfer LP back from hook to original depositor (Interaction - external call LAST per CEI pattern)
        kodiakHook.transferIslandLP(pendingDeposit.depositor, pendingDeposit.amount);
    }
    
    /**
     * @notice Get pending deposit details
     * @param depositId ID of pending deposit
     */
    function getPendingDeposit(uint256 depositId) external view returns (
        address depositor,
        address lpToken,
        uint256 amount,
        uint256 timestamp,
        uint256 expiresAt,
        DepositStatus status
    ) {
        PendingLPDeposit memory pendingDeposit = _pendingDeposits[depositId];
        return (
            pendingDeposit.depositor,
            pendingDeposit.lpToken,
            pendingDeposit.amount,
            pendingDeposit.timestamp,
            pendingDeposit.expiresAt,
            pendingDeposit.status
        );
    }
    
    /**
     * @notice Get all deposit IDs for a user
     * @param user Address of user
     */
    function getUserDepositIds(address user) external view returns (uint256[] memory) {
        return _userDepositIds[user];
    }
    
    /**
     * @notice Get next deposit ID
     */
    function getNextDepositId() external view returns (uint256) {
        return _nextDepositId;
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
