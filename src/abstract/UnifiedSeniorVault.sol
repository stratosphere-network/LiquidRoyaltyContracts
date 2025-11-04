// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISeniorVault} from "../interfaces/ISeniorVault.sol";
import {IJuniorVault} from "../interfaces/IJuniorVault.sol";
import {IReserveVault} from "../interfaces/IReserveVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {MathLib} from "../libraries/MathLib.sol";
import {FeeLib} from "../libraries/FeeLib.sol";
import {RebaseLib} from "../libraries/RebaseLib.sol";
import {SpilloverLib} from "../libraries/SpilloverLib.sol";
import {AdminControlled} from "./AdminControlled.sol";

/**
 * @title UnifiedSeniorVault
 * @notice Senior vault that IS the snrUSD rebasing token (unified architecture)
 * @dev This contract is both the ERC20 token AND the vault logic
 * @dev Upgradeable using UUPS proxy pattern
 * 
 * ARCHITECTURAL DECISION:
 * - NOT ERC4626 (rebasing incompatible with share-based vaults)
 * - Unified contract (vault logic + token logic together)
 * - Simpler, more secure, better UX
 * - Lower gas costs (no cross-contract calls)
 * 
 * Mathematical Specification Compliance:
 * - Section: User Balance & Shares (b_i = σ_i × I)
 * - Section: Rebase Algorithm (all steps preserved)
 * - Section: Three-Zone Spillover System (exact formulas)
 * - Section: Dynamic APY Selection (11-13%)
 * - Section: Fee Calculations (management + performance fees)
 */
abstract contract UnifiedSeniorVault is ISeniorVault, IERC20, AdminControlled, PausableUpgradeable, UUPSUpgradeable {
    using MathLib for uint256;
    using FeeLib for uint256;
    using RebaseLib for uint256;
    using SpilloverLib for uint256;
    
    // ============================================
    // ERC20 Token State (snrUSD)
    // ============================================
    
    /// @dev Token metadata
    string private _name;
    string private _symbol;
    uint8 private constant _decimals = 18;
    
    /// @dev Reference: User Balance & Shares
    /// σ_i - User's share balance (constant unless user mints/burns)
    /// I - Rebase index (grows over time)
    /// b_i = σ_i × I (user's token balance)
    mapping(address => uint256) private _shares;      // σ_i - User shares
    uint256 private _totalShares;                      // Σ - Total shares
    uint256 private _rebaseIndex;                      // I - Rebase index
    uint256 private _epoch;                            // Rebase counter
    
    /// @dev ERC20 allowances
    mapping(address => mapping(address => uint256)) private _allowances;
    
    // ============================================
    // Vault State Variables
    // ============================================
    
    uint256 internal _vaultValue;                // Current USD value (V_s)
    uint256 internal _lastUpdateTime;            // Last value update timestamp
    
    IERC20 internal _lpToken;                    // LP token (USDe-SAIL)
    IJuniorVault internal _juniorVault;          // Junior vault (V_j)
    IReserveVault internal _reserveVault;        // Reserve vault (V_r)
    address internal _treasury;                   // Protocol treasury
    
    /// @dev Reference: State Variables (T_r - last rebase timestamp)
    uint256 internal _lastRebaseTime;
    uint256 internal constant MIN_REBASE_INTERVAL = 30 days;
    
    /// @dev Reference: Parameters (τ - cooldown period = 7 days)
    mapping(address => uint256) internal _cooldownStart; // t_c^(i) - user cooldown time
    
    /// @dev Profit/loss tracking
    int256 internal constant MIN_PROFIT_BPS = -5000;
    int256 internal constant MAX_PROFIT_BPS = 10000;
    
    /// @dev Errors (ZeroAddress inherited from AdminControlled)
    error InvalidProfitRange();
    error InvalidRecipient();
    error InsufficientAllowance();
    error JuniorReserveAlreadySet();
    // InsufficientBalance inherited from IVault
    
    /// @dev Events (ERC20 Transfer and Approval inherited from IERC20)
    event Rebase(uint256 indexed epoch, uint256 oldIndex, uint256 newIndex, uint256 newTotalSupply);
    event EmergencyWithdraw(address indexed to, uint256 amount);
    
    /// @dev Modifiers
    modifier whenNotPausedOrAdmin() {
        if (paused() && msg.sender != admin()) revert EnforcedPause();
        _;
    }
    
    /**
     * @notice Initialize unified Senior vault (IS snrUSD token)
     * @param lpToken_ LP token address
     * @param tokenName_ Token name (e.g., "Senior USD")
     * @param tokenSymbol_ Token symbol (e.g., "snrUSD")
     * @param juniorVault_ Junior vault address
     * @param reserveVault_ Reserve vault address
     * @param treasury_ Treasury address
     * @param initialValue_ Initial vault value
     */
    function __UnifiedSeniorVault_init(
        address lpToken_,
        string memory tokenName_,
        string memory tokenSymbol_,
        address juniorVault_,
        address reserveVault_,
        address treasury_,
        uint256 initialValue_
    ) internal onlyInitializing {
        if (lpToken_ == address(0)) revert AdminControlled.ZeroAddress();
        if (treasury_ == address(0)) revert AdminControlled.ZeroAddress();
        
        __AdminControlled_init();
        __Pausable_init();
        
        _name = tokenName_;
        _symbol = tokenSymbol_;
        _lpToken = IERC20(lpToken_);
        _juniorVault = IJuniorVault(juniorVault_);   // Can be placeholder initially
        _reserveVault = IReserveVault(reserveVault_);  // Can be placeholder initially
        _treasury = treasury_;
        _vaultValue = initialValue_;
        _lastUpdateTime = block.timestamp;
        _lastRebaseTime = block.timestamp;
        
        // Initialize rebase index to 1.0
        _rebaseIndex = MathLib.PRECISION;
        _epoch = 0;
    }
    
    /**
     * @notice Set Junior and Reserve vault addresses (fixes circular dependency)
     * @dev Can only be called once by admin after deployment
     * @param juniorVault_ Address of Junior vault
     * @param reserveVault_ Address of Reserve vault
     */
    function setJuniorReserve(address juniorVault_, address reserveVault_) external onlyAdmin {
        if (address(_juniorVault) != address(0) && address(_juniorVault) != address(0x1)) {
            revert JuniorReserveAlreadySet();
        }
        if (juniorVault_ == address(0)) revert AdminControlled.ZeroAddress();
        if (reserveVault_ == address(0)) revert AdminControlled.ZeroAddress();
        
        _juniorVault = IJuniorVault(juniorVault_);
        _reserveVault = IReserveVault(reserveVault_);
    }
    
    // ============================================
    // ERC20 Implementation (Rebasing)
    // ============================================
    
    /**
     * @notice Token name
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }
    
    /**
     * @notice Token symbol
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }
    
    /**
     * @notice Token decimals
     */
    function decimals() public pure virtual returns (uint8) {
        return _decimals;
    }
    
    /**
     * @notice Get user's rebased token balance
     * @dev Reference: Core Formulas - b_i = σ_i × I
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        return MathLib.calculateBalanceFromShares(_shares[account], _rebaseIndex);
    }
    
    /**
     * @notice Get total token supply (rebased)
     * @dev Reference: Total Supply - S = I × Σ
     */
    function totalSupply() public view virtual override(IERC20, ISeniorVault) returns (uint256) {
        return MathLib.calculateBalanceFromShares(_totalShares, _rebaseIndex);
    }
    
    /**
     * @notice Transfer tokens
     * @dev Transfers shares, balances adjust via rebase index
     */
    function transfer(address to, uint256 amount) public virtual returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }
    
    /**
     * @notice Get allowance
     */
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }
    
    /**
     * @notice Approve spender
     */
    function approve(address spender, uint256 amount) public virtual returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    /**
     * @notice Transfer from (with allowance)
     */
    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) revert InsufficientAllowance();
            unchecked {
                _approve(from, msg.sender, currentAllowance - amount);
            }
        }
        _transfer(from, to, amount);
        return true;
    }
    
    /**
     * @notice Get user's share balance
     * @dev Reference: User State (σ_i)
     */
    function sharesOf(address account) public view virtual returns (uint256) {
        return _shares[account];
    }
    
    /**
     * @notice Get total shares
     * @dev Reference: Notation (Σ)
     */
    function totalShares() public view virtual returns (uint256) {
        return _totalShares;
    }
    
    /**
     * @notice Get current rebase index
     * @dev Reference: Core Formulas (I)
     */
    function rebaseIndex() public view virtual returns (uint256) {
        return _rebaseIndex;
    }
    
    /**
     * @notice Get current rebase epoch
     */
    function epoch() public view virtual returns (uint256) {
        return _epoch;
    }
    
    // ============================================
    // Internal ERC20 Functions
    // ============================================
    
    /**
     * @dev Internal transfer (shares-based)
     */
    function _transfer(address from, address to, uint256 amount) internal virtual {
        if (from == address(0)) revert InvalidRecipient();
        if (to == address(0)) revert InvalidRecipient();
        
        uint256 sharesToTransfer = MathLib.calculateSharesFromBalance(amount, _rebaseIndex);
        
        if (_shares[from] < sharesToTransfer) revert InvalidAmount(); // Use IVault error
        
        unchecked {
            _shares[from] -= sharesToTransfer;
            _shares[to] += sharesToTransfer;
        }
        
        emit Transfer(from, to, amount);
    }
    
    /**
     * @dev Internal mint (creates shares)
     */
    function _mint(address to, uint256 amount) internal virtual {
        if (to == address(0)) revert InvalidRecipient();
        
        uint256 sharesToMint = MathLib.calculateSharesFromBalance(amount, _rebaseIndex);
        
        _totalShares += sharesToMint;
        _shares[to] += sharesToMint;
        
        emit Transfer(address(0), to, amount);
    }
    
    /**
     * @dev Internal burn (destroys shares)
     */
    function _burn(address from, uint256 amount) internal virtual {
        if (from == address(0)) revert InvalidRecipient();
        
        uint256 sharesToBurn = MathLib.calculateSharesFromBalance(amount, _rebaseIndex);
        
        if (_shares[from] < sharesToBurn) revert InvalidAmount(); // Use IVault error
        
        unchecked {
            _shares[from] -= sharesToBurn;
            _totalShares -= sharesToBurn;
        }
        
        emit Transfer(from, address(0), amount);
    }
    
    /**
     * @dev Internal approve
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        if (owner == address(0)) revert InvalidRecipient();
        if (spender == address(0)) revert InvalidRecipient();
        
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    // ============================================
    // Vault Functions (IVault Interface)
    // ============================================
    
    function vaultValue() public view virtual returns (uint256) {
        return _vaultValue;
    }
    
    function lpToken() public view virtual returns (IERC20) {
        return _lpToken;
    }
    
    function depositToken() public view virtual returns (IERC20) {
        return _lpToken;
    }
    
    function lastUpdateTime() public view virtual returns (uint256) {
        return _lastUpdateTime;
    }
    
    function seniorVault() public view virtual returns (address) {
        return address(this); // Senior vault IS itself
    }
    
    function totalAssets() public view virtual returns (uint256) {
        return _vaultValue;
    }
    
    /**
     * @notice Update vault value based on off-chain calculation
     * @dev Reference: Instructions - Monthly Rebase Flow
     */
    function updateVaultValue(int256 profitBps) public virtual onlyAdmin {
        if (profitBps < MIN_PROFIT_BPS || profitBps > MAX_PROFIT_BPS) {
            revert InvalidProfitRange();
        }
        
        uint256 oldValue = _vaultValue;
        _vaultValue = MathLib.applyPercentage(oldValue, profitBps);
        _lastUpdateTime = block.timestamp;
        
        emit VaultValueUpdated(oldValue, _vaultValue, profitBps);
    }
    
    /**
     * @notice Deposit LP tokens, receive snrUSD (1:1)
     * @param assets Amount of LP tokens to deposit
     * @param receiver Address to receive snrUSD
     * @return shares Amount of snrUSD minted (approximately equals assets at index ~1.0)
     */
    function deposit(uint256 assets, address receiver) public virtual whenNotPaused returns (uint256 shares) {
        if (assets == 0) revert InvalidAmount();
        if (receiver == address(0)) revert AdminControlled.ZeroAddress();
        
        // Check deposit cap
        if (isDepositCapReached()) revert DepositCapExceeded();
        
        // Transfer LP tokens from user
        _lpToken.transferFrom(msg.sender, address(this), assets);
        
        // Mint snrUSD to receiver (1:1 at current index)
        _mint(receiver, assets);
        
        // Note: _vaultValue is NOT auto-updated here
        // Vault value (USD) is updated by keeper via updateVaultValue()
        // This follows the "off-chain profit calculation" model
        
        emit Deposit(receiver, assets, assets);
        
        return assets; // Balance minted (shares calculated internally)
    }
    
    /**
     * @notice Withdraw LP tokens by burning snrUSD
     * @param amount Amount of snrUSD to burn
     * @param receiver Address to receive LP tokens
     * @param owner Owner of snrUSD
     * @return assets Amount of LP tokens withdrawn (after penalty if applicable)
     */
    function withdraw(uint256 amount, address receiver, address owner) public virtual whenNotPausedOrAdmin returns (uint256 assets) {
        if (amount == 0) revert InvalidAmount();
        if (receiver == address(0)) revert AdminControlled.ZeroAddress();
        
        // Check allowance if not owner
        if (msg.sender != owner) {
            uint256 currentAllowance = _allowances[owner][msg.sender];
            if (currentAllowance < amount) revert InsufficientAllowance();
            if (currentAllowance != type(uint256).max) {
                _approve(owner, msg.sender, currentAllowance - amount);
            }
        }
        
        // Calculate withdrawal penalty
        (uint256 penalty, uint256 netAssets) = calculateWithdrawalPenalty(owner, amount);
        
        // Burn snrUSD
        _burn(owner, amount);
        
        // Transfer LP tokens to receiver (net of penalty)
        _lpToken.transfer(receiver, netAssets);
        
        // Note: _vaultValue is NOT auto-updated here
        // Vault value (USD) is updated by keeper via updateVaultValue()
        // This follows the "off-chain profit calculation" model
        
        if (penalty > 0) {
            emit WithdrawalPenaltyCharged(owner, penalty);
        }
        
        emit Withdraw(owner, netAssets, amount);
        
        return netAssets;
    }
    
    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        return assets; // 1:1 at current index
    }
    
    function previewWithdraw(uint256 amount) public view virtual returns (uint256) {
        (,uint256 netAssets) = calculateWithdrawalPenalty(msg.sender, amount);
        return netAssets;
    }
    
    // ============================================
    // ISeniorVault Interface Implementation
    // ============================================
    
    function juniorVault() public view virtual returns (address) {
        return address(_juniorVault);
    }
    
    function reserveVault() public view virtual returns (address) {
        return address(_reserveVault);
    }
    
    function treasury() public view virtual returns (address) {
        return _treasury;
    }
    
    function lastRebaseTime() public view virtual returns (uint256) {
        return _lastRebaseTime;
    }
    
    function minRebaseInterval() public view virtual returns (uint256) {
        return MIN_REBASE_INTERVAL;
    }
    
    /**
     * @notice Get current backing ratio
     * @dev Reference: Core Formulas - R_senior = V_s / S
     */
    function backingRatio() public view virtual returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return MathLib.PRECISION;
        return MathLib.calculateBackingRatio(_vaultValue, supply);
    }
    
    /**
     * @notice Get current operating zone
     * @dev Reference: Three-Zone Spillover System
     */
    function currentZone() public view virtual returns (SpilloverLib.Zone) {
        return SpilloverLib.determineZone(backingRatio());
    }
    
    /**
     * @notice Check if deposit cap is reached
     * @dev Reference: Deposit Cap - S_max = 10 × V_r
     */
    function isDepositCapReached() public view virtual returns (bool) {
        uint256 supply = totalSupply();
        uint256 cap = depositCap();
        return supply >= cap;
    }
    
    /**
     * @notice Get current deposit cap
     * @dev Reference: Constraints & Invariants (Invariant 4)
     */
    function depositCap() public view virtual returns (uint256) {
        uint256 reserveValue = _reserveVault.vaultValue();
        return MathLib.calculateDepositCap(reserveValue);
    }
    
    // ============================================
    // Cooldown Functions
    // ============================================
    
    /**
     * @notice Initiate withdrawal cooldown
     * @dev Reference: Parameters (τ = 7 days)
     */
    function initiateCooldown() public virtual {
        _cooldownStart[msg.sender] = block.timestamp;
        emit CooldownInitiated(msg.sender, block.timestamp);
    }
    
    /**
     * @notice Get user's cooldown start time
     * @dev Reference: User State (t_c^(i))
     */
    function cooldownStart(address user) public view virtual returns (uint256) {
        return _cooldownStart[user];
    }
    
    /**
     * @notice Check if user can withdraw without penalty
     * @dev Reference: Fee Calculations - Early Withdrawal Penalty
     */
    function canWithdrawWithoutPenalty(address user) public view virtual returns (bool) {
        uint256 cooldownTime = _cooldownStart[user];
        if (cooldownTime == 0) return false;
        return (block.timestamp - cooldownTime) >= MathLib.COOLDOWN_PERIOD;
    }
    
    /**
     * @notice Calculate withdrawal penalty
     * @dev Reference: Fee Calculations - P(w, t_c)
     */
    function calculateWithdrawalPenalty(
        address user,
        uint256 amount
    ) public view virtual returns (uint256 penalty, uint256 netAmount) {
        uint256 cooldownTime = _cooldownStart[user];
        if (cooldownTime == 0) {
            return FeeLib.calculateWithdrawalPenalty(amount, 0, block.timestamp);
        }
        return FeeLib.calculateWithdrawalPenalty(amount, cooldownTime, block.timestamp);
    }
    
    // ============================================
    // Rebase Functions
    // ============================================
    
    /**
     * @notice Execute monthly rebase
     * @dev Reference: Rebase Algorithm (all steps) - MATH SPEC PRESERVED
     */
    function rebase() public virtual onlyAdmin {
        if (block.timestamp < _lastRebaseTime + MIN_REBASE_INTERVAL) {
            revert RebaseTooSoon();
        }
        
        uint256 currentSupply = totalSupply();
        if (currentSupply == 0) revert InvalidAmount();
        
        // Step 1: Deduct management fee
        (uint256 netValue, uint256 mgmtFee) = FeeLib.deductManagementFee(_vaultValue);
        
        // Step 2 & 3: Dynamic APY selection
        RebaseLib.APYSelection memory selection = RebaseLib.selectDynamicAPY(
            currentSupply,
            netValue
        );
        
        // Step 4: Determine zone and execute spillover/backstop
        uint256 finalBackingRatio = MathLib.calculateBackingRatio(netValue, selection.newSupply);
        SpilloverLib.Zone zone = SpilloverLib.determineZone(finalBackingRatio);
        
        if (zone == SpilloverLib.Zone.SPILLOVER) {
            _executeProfitSpillover(netValue, selection.newSupply);
        } else if (zone == SpilloverLib.Zone.BACKSTOP || selection.backstopNeeded) {
            _executeBackstop(netValue, selection.newSupply);
        }
        
        // Step 5: Update rebase index
        uint256 oldIndex = _rebaseIndex;
        _rebaseIndex = FeeLib.calculateNewRebaseIndex(oldIndex, selection.selectedRate);
        _epoch++;
        
        // Mint performance fee tokens to treasury
        if (selection.feeTokens > 0) {
            _mint(_treasury, selection.feeTokens);
        }
        
        _lastRebaseTime = block.timestamp;
        
        emit Rebase(_epoch, oldIndex, _rebaseIndex, totalSupply());
        emit RebaseExecuted(_epoch, selection.apyTier, oldIndex, _rebaseIndex, selection.newSupply, zone);
        emit FeesCollected(mgmtFee, selection.feeTokens);
    }
    
    /**
     * @notice Simulate rebase without executing
     * @dev Reference: Rebase Algorithm - for off-chain analysis
     */
    function simulateRebase() public view virtual returns (
        RebaseLib.APYSelection memory selection,
        SpilloverLib.Zone zone,
        uint256 newBackingRatio
    ) {
        uint256 currentSupply = totalSupply();
        if (currentSupply == 0) {
            return (selection, SpilloverLib.Zone.HEALTHY, MathLib.PRECISION);
        }
        
        (uint256 netValue,) = FeeLib.deductManagementFee(_vaultValue);
        selection = RebaseLib.selectDynamicAPY(currentSupply, netValue);
        newBackingRatio = MathLib.calculateBackingRatio(netValue, selection.newSupply);
        zone = SpilloverLib.determineZone(newBackingRatio);
        
        return (selection, zone, newBackingRatio);
    }
    
    // ============================================
    // Emergency Functions
    // ============================================
    
    /**
     * @notice Pause all deposits and withdrawals
     * @dev Can only be called by admin
     */
    function pause() external onlyAdmin {
        _pause();
    }
    
    /**
     * @notice Unpause all deposits and withdrawals
     * @dev Can only be called by admin
     */
    function unpause() external onlyAdmin {
        _unpause();
    }
    
    // ============================================
    // UUPS Upgrade Authorization
    // ============================================
    
    /**
     * @notice Authorize upgrade to new implementation
     * @dev Only admin can upgrade the contract
     * @param newImplementation Address of new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {
        // Admin authorization check via modifier
    }
    
    /**
     * @notice Emergency withdraw LP tokens to treasury
     * @dev Can only be called by admin when paused, for emergency situations
     * @param amount Amount of LP tokens to withdraw
     */
    function emergencyWithdraw(uint256 amount) external onlyAdmin {
        if (!paused()) revert("Must be paused");
        if (amount == 0) revert InvalidAmount();
        
        _lpToken.transfer(_treasury, amount);
        emit EmergencyWithdraw(_treasury, amount);
    }
    
    // ============================================
    // Internal Functions
    // ============================================
    
    /**
     * @notice Execute profit spillover (Zone 1)
     * @dev Reference: Three-Zone System - Profit Spillover
     */
    function _executeProfitSpillover(uint256 netValue, uint256 newSupply) internal virtual {
        SpilloverLib.ProfitSpillover memory spillover = 
            SpilloverLib.calculateProfitSpillover(netValue, newSupply);
        
        if (spillover.excessAmount == 0) return;
        
        // Update Senior value to exactly 110%
        _vaultValue = spillover.seniorFinalValue;
        
        // Transfer to Junior and Reserve
        _transferToJunior(spillover.toJunior);
        _transferToReserve(spillover.toReserve);
        
        emit ProfitSpillover(spillover.excessAmount, spillover.toJunior, spillover.toReserve);
    }
    
    /**
     * @notice Execute backstop (Zone 3)
     * @dev Reference: Three-Zone System - Backstop
     */
    function _executeBackstop(uint256 netValue, uint256 newSupply) internal virtual {
        uint256 reserveValue = _reserveVault.vaultValue();
        uint256 juniorValue = _juniorVault.vaultValue();
        
        SpilloverLib.BackstopResult memory backstop = 
            SpilloverLib.calculateBackstop(netValue, newSupply, reserveValue, juniorValue);
        
        if (backstop.deficitAmount == 0) return;
        
        // Pull from Reserve first
        if (backstop.fromReserve > 0) {
            _pullFromReserve(backstop.fromReserve);
        }
        
        // Then Junior if needed
        if (backstop.fromJunior > 0) {
            _pullFromJunior(backstop.fromJunior);
        }
        
        // Update Senior value
        _vaultValue = backstop.seniorFinalValue;
        
        emit BackstopTriggered(
            backstop.deficitAmount,
            backstop.fromReserve,
            backstop.fromJunior,
            backstop.fullyRestored
        );
    }
    
    // ============================================
    // Abstract Transfer Functions (Must implement in concrete contract)
    // ============================================
    
    /**
     * @notice Transfer assets to Junior vault
     * @dev Must be implemented to handle actual asset transfers
     */
    function _transferToJunior(uint256 amount) internal virtual;
    
    /**
     * @notice Transfer assets to Reserve vault
     * @dev Must be implemented to handle actual asset transfers
     */
    function _transferToReserve(uint256 amount) internal virtual;
    
    /**
     * @notice Pull assets from Reserve vault
     * @dev Must be implemented to handle actual asset transfers
     */
    function _pullFromReserve(uint256 amount) internal virtual;
    
    /**
     * @notice Pull assets from Junior vault
     * @dev Must be implemented to handle actual asset transfers
     */
    function _pullFromJunior(uint256 amount) internal virtual;
}

