// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISeniorVault} from "../interfaces/ISeniorVault.sol";
import {IJuniorVault} from "../interfaces/IJuniorVault.sol";
import {IReserveVault} from "../interfaces/IReserveVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {MathLib} from "../libraries/MathLib.sol";
import {FeeLib} from "../libraries/FeeLib.sol";
import {RebaseLib} from "../libraries/RebaseLib.sol";
import {SpilloverLib} from "../libraries/SpilloverLib.sol";
import {AdminControlled} from "./AdminControlled.sol";
import {IKodiakVaultHook} from "../integrations/IKodiakVaultHook.sol";
import {IKodiakIsland} from "../integrations/IKodiakIsland.sol";
import {IRewardVault} from "../integrations/IRewardVault.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
/**
 * @title UnifiedSeniorVault
 * @notice Senior vault that IS the snrUSD rebasing token (unified architecture)
 * @dev This contract is both the ERC20 token AND the vault logic
 * @dev Upgradeable using UUPS proxy pattern
 * but 
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
    using SafeERC20 for IERC20;
    using MathLib for uint256;
    using FeeLib for uint256;
    using RebaseLib for uint256;
    using SpilloverLib for uint256;
    
    /// @dev Reentrancy guard constants
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    
    error ReentrantCall();
    
    modifier nonReentrant() {
        if (_getReentrancyStatus() == _ENTERED) revert ReentrantCall();
        _setReentrancyStatus(_ENTERED);
        _;
        _setReentrancyStatus(_NOT_ENTERED);
    }
    
    /// @dev Virtual functions for reentrancy guard (implemented in concrete contracts)
    function _getReentrancyStatus() internal view virtual returns (uint256);
    function _setReentrancyStatus(uint256 status) internal virtual;
    
    /// @dev Virtual function to get reward vault (implemented in concrete contracts)
    function _getRewardVault() internal view virtual returns (IRewardVault);
    
    /// @dev Struct for LP holdings data
    struct LPHolding {
        address lpToken;
        uint256 amount;
    }
    
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
    IKodiakVaultHook public kodiakHook;                // Kodiak vault hook
    
    /// @dev ERC20 allowances
    mapping(address => mapping(address => uint256)) private _allowances;
    
    // ============================================
    // Vault State Variables
    // ============================================
    
    uint256 internal _vaultValue;                // Current USD value (V_s)
    uint256 internal _lastUpdateTime;            // Last value update timestamp
    
    IERC20 internal _stablecoin;                    // Stablecoin (USDe-SAIL)
    IJuniorVault internal _juniorVault;          // Junior vault (V_j)
    IReserveVault internal _reserveVault;        // Reserve vault (V_r)
    address internal _treasury;                   // Protocol treasury
    
    /// @dev Reference: State Variables (T_r - last rebase timestamp)
    uint256 internal _lastRebaseTime;
    uint256 internal _minRebaseInterval; // Settable by admin, default 30 days
    
    /// @dev Reference: Parameters (τ - cooldown period = 7 days)
    mapping(address => uint256) internal _cooldownStart; // t_c^(i) - user cooldown time
    
    /// @dev Whitelisted LPs (Liquidity Providers/Protocols) Kodiak hook should be here.
    address[] internal _whitelistedLPs;
    address[] internal _whitelistedLPTokens;
    mapping(address => bool) internal _isWhitelistedLP;
    mapping(address => bool) internal _isWhitelistedLPToken;
    
    /// @dev DEPRECATED: LP deposit storage (kept for upgrade compatibility)
    struct PendingLPDeposit { address depositor; address lpToken; uint256 amount; uint256 timestamp; uint256 expiresAt; uint8 status; }
    enum DepositStatus { PENDING, APPROVED, REJECTED, EXPIRED, CANCELLED } // DEPRECATED
    
    /// @dev Admin actions for whitelist management
    enum WhitelistAction {
        ADD_LP,
        REMOVE_LP,
        ADD_LP_TOKEN,
        REMOVE_LP_TOKEN
    }
    
    /// @dev Actions for vault value updates
    enum VaultValueAction {
        UPDATE_BY_BPS,
        SET_ABSOLUTE
    }
    
    uint256 internal _nextDepositId;
    mapping(uint256 => PendingLPDeposit) internal _pendingDeposits;
    mapping(address => uint256[]) internal _userDepositIds;
    
    uint256 internal constant DEPOSIT_EXPIRY_TIME = 48 hours;
    
    /// @dev Profit/loss tracking
    int256 internal constant MIN_PROFIT_BPS = -5000;
    int256 internal constant MAX_PROFIT_BPS = 10000;
    
    /// @dev Events (ERC20 Transfer and Approval inherited from IERC20)
    event Rebase(uint256 indexed epoch, uint256 oldIndex, uint256 newIndex, uint256 newTotalSupply);
    event EmergencyWithdraw(address indexed to, uint256 amount);
    event MinRebaseIntervalUpdated(uint256 oldInterval, uint256 newInterval);
    event LPInvestment(address indexed lp, uint256 amount);
    event LPTokensWithdrawn(address indexed lpToken, address indexed lp, uint256 amount);
    event WhitelistedLPAdded(address indexed lp);
    event WhitelistedLPRemoved(address indexed lp);
    event WhitelistedLPTokenAdded(address indexed lpToken);
    event WhitelistedLPTokenRemoved(address indexed lpToken);
    event KodiakDeployment(uint256 amount, uint256 lpReceived, uint256 timestamp);
    event LiquidityFreedForWithdrawal(uint256 requested, uint256 freedFromLP);
    event LPLiquidationExecuted(uint256 requested, uint256 received, uint256 minExpected);
    event TokenSwappedToStable(address indexed tokenIn, uint256 amountIn, uint256 stableOut);
    event WithdrawalFeeCharged(address indexed user, uint256 fee, uint256 netAmount);
    event VaultSeeded(address indexed lpToken, address indexed seedProvider, uint256 amount, uint256 lpPrice, uint256 valueAdded, uint256 sharesMinted);
    event JuniorReserveUpdated(address indexed juniorVault, address indexed reserveVault);
    event KodiakHookUpdated(address indexed newHook);

    /// @dev Errors (ZeroAddress inherited from AdminControlled, InsufficientBalance and InvalidAmount from IVault)
    error NotPaused();
    error InvalidProfitRange();
    error InvalidLPPrice();
    error InvalidRecipient();
    error InsufficientAllowance();
    error WhitelistedLPNotFound();
    error LPAlreadyWhitelisted();
    error WrongVault();
    error KodiakHookNotSet();
    error SlippageTooHigh();
    error InsufficientLiquidity();
    error InvalidLPToken();
    error IdleBalanceDeviation();
    error InvalidStablecoinDecimals();
    error InvalidToken();
    
    /// @dev Modifiers
    modifier whenNotPausedOrAdmin() {
        if (paused() && msg.sender != admin()) revert EnforcedPause();
        _;
    }
    
    /**
     * @notice Initialize unified Senior vault (IS snrUSD token)
     * @param stablecoin_ Stablecoin address
     * @param tokenName_ Token name (e.g., "Senior USD")
     * @param tokenSymbol_ Token symbol (e.g., "snrUSD")
     * @param juniorVault_ Junior vault address
     * @param reserveVault_ Reserve vault address
     * @param treasury_ Treasury address
     * @param initialValue_ Initial vault value
     */
    function __UnifiedSeniorVault_init(
        address stablecoin_,
        string memory tokenName_,
        string memory tokenSymbol_,
        address juniorVault_,
        address reserveVault_,
        address treasury_,
        uint256 initialValue_
    ) internal onlyInitializing {
        if (stablecoin_ == address(0)) revert AdminControlled.ZeroAddress();
        if (treasury_ == address(0)) revert AdminControlled.ZeroAddress();

        // Sanity check: Ensure stablecoin is 18 decimals (vault accounting assumes 18 decimals)
        if (IERC20Metadata(stablecoin_).decimals() != 18) revert InvalidStablecoinDecimals();
        
        __AdminControlled_init();
        __Pausable_init();
        
        _name = tokenName_;
        _symbol = tokenSymbol_;
        _stablecoin = IERC20(stablecoin_);
        _juniorVault = IJuniorVault(juniorVault_);   // Can be placeholder initially
        _reserveVault = IReserveVault(reserveVault_);  // Can be placeholder initially
        _treasury = treasury_;
        _vaultValue = initialValue_;
        _lastUpdateTime = block.timestamp;
        _lastRebaseTime = block.timestamp;
        _minRebaseInterval = 30 days; // Default: 30 days (monthly rebase cycle, settable by admin)
        
        // Initialize rebase index to 1.0
        _rebaseIndex = MathLib.PRECISION;
        _epoch = 0;
    }
    
    /**
     * @notice Update Junior and Reserve vault addresses (admin only)
     * @dev Allows admin to set or update vault addresses
     * @param juniorVault_ Address of Junior vault
     * @param reserveVault_ Address of Reserve vault
     */
    function updateJuniorReserve(address juniorVault_, address reserveVault_) external onlyAdmin {
        if (juniorVault_ == address(0)) revert AdminControlled.ZeroAddress();
        if (reserveVault_ == address(0)) revert AdminControlled.ZeroAddress();
        
        _juniorVault = IJuniorVault(juniorVault_);
        _reserveVault = IReserveVault(reserveVault_);
        
        emit JuniorReserveUpdated(juniorVault_, reserveVault_);
    }
    
    /**
     * @notice Execute whitelist management actions (add/remove LP or LP token)
     * @dev Consolidates 4 whitelist functions to reduce contract size
     * @param action ADD_LP, REMOVE_LP, ADD_LP_TOKEN, or REMOVE_LP_TOKEN
     * @param target Address to add/remove from whitelist
     */
    function executeWhitelistAction(WhitelistAction action, address target) external onlyAdmin {
        if (target == address(0)) revert AdminControlled.ZeroAddress();
        
        if (action == WhitelistAction.ADD_LP) {
            if (_isWhitelistedLP[target]) revert LPAlreadyWhitelisted();
            _whitelistedLPs.push(target);
            _isWhitelistedLP[target] = true;
            emit WhitelistedLPAdded(target);
            
        } else if (action == WhitelistAction.REMOVE_LP) {
            if (!_isWhitelistedLP[target]) revert WhitelistedLPNotFound();
            _removeFromWhitelist(target, false);
            emit WhitelistedLPRemoved(target);
            
        } else if (action == WhitelistAction.ADD_LP_TOKEN) {
            if (_isWhitelistedLPToken[target]) revert LPAlreadyWhitelisted();
            _whitelistedLPTokens.push(target);
            _isWhitelistedLPToken[target] = true;
            emit WhitelistedLPTokenAdded(target);
            
        } else if (action == WhitelistAction.REMOVE_LP_TOKEN) {
            if (!_isWhitelistedLPToken[target]) revert WhitelistedLPNotFound();
            _removeFromWhitelist(target, true);
            emit WhitelistedLPTokenRemoved(target);
        }
    }
    
    /// @notice Set Kodiak hook and auto-whitelist
    function setKodiakHook(address hook) external onlyAdmin {
        if (address(kodiakHook) != address(0) && _isWhitelistedLP[address(kodiakHook)]) _removeFromWhitelist(address(kodiakHook), false);
        if (hook != address(0)) {
            (bool ok, bytes memory data) = hook.staticcall(abi.encodeWithSignature("vault()"));
            if (!(ok && data.length >= 32 && abi.decode(data, (address)) == address(this))) revert WrongVault();
            if (!_isWhitelistedLP[hook]) { _whitelistedLPs.push(hook); _isWhitelistedLP[hook] = true; emit WhitelistedLPAdded(hook); }
        }
        kodiakHook = IKodiakVaultHook(hook);
        emit KodiakHookUpdated(hook);
    }
    
    /// @dev Remove from whitelist (isToken=false for LP, true for LPToken)
    function _removeFromWhitelist(address addr, bool isToken) internal {
        if (isToken) {
            for (uint256 i = 0; i < _whitelistedLPTokens.length; i++) {
                if (_whitelistedLPTokens[i] == addr) { _whitelistedLPTokens[i] = _whitelistedLPTokens[_whitelistedLPTokens.length - 1]; _whitelistedLPTokens.pop(); break; }
            }
            _isWhitelistedLPToken[addr] = false;
        } else {
            for (uint256 i = 0; i < _whitelistedLPs.length; i++) {
                if (_whitelistedLPs[i] == addr) { _whitelistedLPs[i] = _whitelistedLPs[_whitelistedLPs.length - 1]; _whitelistedLPs.pop(); break; }
            }
            _isWhitelistedLP[addr] = false;
        }
    }

    /// @notice Invest stablecoin into whitelisted LP
    function investInLP(address lp, uint256 amount) external onlyLiquidityManager nonReentrant {
        if (lp == address(0) || amount == 0) revert InvalidAmount();
        if (!_isWhitelistedLP[lp]) revert WhitelistedLPNotFound();
        if (_stablecoin.balanceOf(address(this)) < amount) revert InsufficientBalance();
        _stablecoin.safeTransfer(lp, amount);
        emit LPInvestment(lp, amount);
    }

    /// @notice Consolidated deploy to Kodiak (amount=0 means sweep all, expectedIdle/maxDeviation for sweep mode)
    function deployToKodiak(
        uint256 amount, uint256 minLPTokens, uint256 expectedIdle, uint256 maxDeviation,
        address agg0, bytes calldata data0, address agg1, bytes calldata data1
    ) external onlyLiquidityManager nonReentrant {
        if (address(kodiakHook) == address(0)) revert KodiakHookNotSet();
        uint256 deployAmt = amount;
        if (amount == 0) {
            deployAmt = _stablecoin.balanceOf(address(this));
            if (deployAmt == 0) revert InvalidAmount();
            if (deployAmt != expectedIdle) {
                uint256 dev = deployAmt > expectedIdle ? deployAmt - expectedIdle : expectedIdle - deployAmt;
                if (dev > (expectedIdle * maxDeviation) / 10000) revert IdleBalanceDeviation();
            }
        } else {
            if (_stablecoin.balanceOf(address(this)) < amount) revert InsufficientBalance();
        }
        uint256 lpBefore = kodiakHook.getIslandLPBalance();
        _stablecoin.safeTransfer(address(kodiakHook), deployAmt);
        kodiakHook.onAfterDepositWithSwaps(deployAmt, agg0, data0, agg1, data1);
        uint256 lpReceived = kodiakHook.getIslandLPBalance() - lpBefore;
        if (lpReceived < minLPTokens) revert SlippageTooHigh();
        emit KodiakDeployment(deployAmt, lpReceived, block.timestamp);
    }

    /// @notice Swap non-stablecoin tokens stuck in vault to stablecoin
    /// @param tokenIn Token to swap, amount Amount (0=all), minOut Min output, aggregator Swap aggregator, swapData Calldata
    function swapTokenToStable(address tokenIn, uint256 amount, uint256 minOut, address aggregator, bytes calldata swapData) external onlyLiquidityManager nonReentrant {
        if (tokenIn == address(0) || aggregator == address(0)) revert AdminControlled.ZeroAddress();
        if (tokenIn == address(_stablecoin)) revert InvalidToken();
        uint256 swapAmount = amount == 0 ? IERC20(tokenIn).balanceOf(address(this)) : amount;
        if (swapAmount == 0 || IERC20(tokenIn).balanceOf(address(this)) < swapAmount) revert InsufficientBalance();
        uint256 stableBefore = _stablecoin.balanceOf(address(this));
        IERC20(tokenIn).forceApprove(aggregator, swapAmount);
        (bool ok,) = aggregator.call(swapData);
        if (!ok) revert SlippageTooHigh();
        IERC20(tokenIn).forceApprove(aggregator, 0);
        uint256 received = _stablecoin.balanceOf(address(this)) - stableBefore;
        if (received < minOut) revert SlippageTooHigh();
        emit TokenSwappedToStable(tokenIn, swapAmount, received);
    }

    /// @notice Withdraw LP tokens to whitelisted LP (amount=0 withdraws all)
    function withdrawLPTokens(address lpToken, address lp, uint256 amount) external onlyLiquidityManager nonReentrant {
        if (lpToken == address(0) || lp == address(0)) revert AdminControlled.ZeroAddress();
        if (!_isWhitelistedLP[lp] || !_isWhitelistedLPToken[lpToken]) revert WhitelistedLPNotFound();
        uint256 bal = IERC20(lpToken).balanceOf(address(this));
        uint256 amt = amount == 0 ? bal : amount;
        if (amt == 0 || bal < amt) revert InsufficientBalance();
        IERC20(lpToken).safeTransfer(lp, amt);
        emit LPTokensWithdrawn(lpToken, lp, amt);
    }
    
    /// @notice Admin config actions
    enum AdminConfig { SET_MIN_REBASE_INTERVAL, SET_TREASURY }
    
    /// @notice Consolidated admin config setter
    function setAdminConfig(AdminConfig config, uint256 value, address addr) external onlyAdmin {
        if (config == AdminConfig.SET_MIN_REBASE_INTERVAL) {
            uint256 old = _minRebaseInterval;
            _minRebaseInterval = value;
            emit MinRebaseIntervalUpdated(old, value);
        } else if (config == AdminConfig.SET_TREASURY) {
            if (addr == address(0)) revert AdminControlled.ZeroAddress();
            _treasury = addr;
        }
    }
    
    /**
     * @notice Seed vault with LP tokens from caller
     * @param lpToken Address of the LP token
     * @param amount Amount of LP tokens to seed
     * @param lpPrice Current LP token price (18 decimals)
     * @dev Caller must have seeder role and approve this vault to transfer LP tokens first
     * @dev Transfers LP to hook, calculates value, mints shares to caller
     */
    function seedVault(
        address lpToken,
        uint256 amount,
        uint256 lpPrice
    ) external onlySeeder nonReentrant {
        if (lpToken == address(0)) revert AdminControlled.ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (lpPrice == 0) revert InvalidLPPrice();
        if (address(kodiakHook) == address(0)) revert KodiakHookNotSet();
        if (lpToken != address(kodiakHook.island())) revert InvalidLPToken();
        
        // Transfer LP tokens from caller (seeder) to hook
        IERC20(lpToken).safeTransferFrom(msg.sender, address(kodiakHook), amount);
        
        // Calculate value = amount * lpPrice / 1e18
        // Account for LP token decimals
        uint8 lpDecimals = IERC20Metadata(lpToken).decimals();
        uint256 normalizedAmount = MathLib.normalizeDecimals(amount, lpDecimals, 18);
        uint256 valueAdded = (normalizedAmount * lpPrice) / 1e18;
        
        // Mint tokens to caller (seeder) - use _mint which handles shares internally
        _mint(msg.sender, valueAdded);
        
        // Update vault value
        _vaultValue += valueAdded;
        _lastUpdateTime = block.timestamp;
        
        // Calculate shares for event
        uint256 sharesToMint = MathLib.calculateSharesFromBalance(valueAdded, _rebaseIndex);
        
        emit VaultSeeded(lpToken, msg.sender, amount, lpPrice, valueAdded, sharesToMint);
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
    
    function sharesOf(address account) public view virtual returns (uint256) { return _shares[account]; }
    function totalShares() public view virtual returns (uint256) { return _totalShares; }
    function rebaseIndex() public view virtual returns (uint256) { return _rebaseIndex; }
    function epoch() public view virtual returns (uint256) { return _epoch; }
    
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
        
        // SECURITY FIX: Reset cooldown on token transfer to prevent bypass
        // Receiving tokens resets your cooldown - must re-initiate to get penalty-free withdrawal
        if (to != address(0) && _cooldownStart[to] != 0) {
            _cooldownStart[to] = 0;
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
        
        // SECURITY FIX: Reset cooldown when receiving new tokens via mint
        // This prevents bypassing cooldown by depositing more tokens
        if (_cooldownStart[to] != 0) {
            _cooldownStart[to] = 0;
        }
        
        emit Transfer(address(0), to, amount);
    }
    
    /**
     * @dev Internal burn (destroys shares)
     */
    function _burn(address from, uint256 amount) internal virtual {
        if (from == address(0)) revert InvalidRecipient();
        
        // Round UP when burning (favors protocol, prevents dust accumulation)
        uint256 sharesToBurn = MathLib.calculateSharesFromBalanceCeil(amount, _rebaseIndex);
        
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
    
    /**
     * @notice Get current vault value
     * @dev Returns stored value set by admin
     * @return value Current vault value in USD (18 decimals)
     */
    function vaultValue() public view virtual returns (uint256 value) {
        return _vaultValue;
    }
    
    function stablecoin() public view virtual returns (IERC20) {
        return _stablecoin;
    }
    
    /**
     * @notice Update vault value (consolidated: by BPS or absolute)
     * @dev Consolidates updateVaultValue and setVaultValue to reduce contract size
     * @param action UPDATE_BY_BPS (apply percentage) or SET_ABSOLUTE (set exact value)
     * @param value For UPDATE_BY_BPS: profitBps (int256, can be negative)
     *              For SET_ABSOLUTE: new absolute value (must be positive, cast to uint256)
     */
    function executeVaultValueAction(VaultValueAction action, int256 value) public virtual onlyPriceFeedManager {
        uint256 oldValue = _vaultValue;
        
        if (action == VaultValueAction.UPDATE_BY_BPS) {
            // value is profitBps (can be negative for losses)
            if (value < MIN_PROFIT_BPS || value > MAX_PROFIT_BPS) {
                revert InvalidProfitRange();
            }
            
            uint256 newValue = MathLib.applyPercentage(oldValue, value);
            _vaultValue = newValue;
            _lastUpdateTime = block.timestamp;
            
            emit VaultValueUpdated(oldValue, _vaultValue, value);
            
        } else if (action == VaultValueAction.SET_ABSOLUTE) {
            // value is absolute value (must be positive)
            if (value < 0) revert InvalidAmount();
            
            uint256 newValue = uint256(value);
            _vaultValue = newValue;
            _lastUpdateTime = block.timestamp;
            
            // Calculate BPS for event logging
            int256 bps = 0;
            if (oldValue > 0) {
                bps = int256((newValue * 10000 / oldValue)) - 10000;
            }
            
            emit VaultValueUpdated(oldValue, _vaultValue, bps);
        }
    }
    
    /**
     * @notice Deposit stablecoin, receive snrUSD (1:1)
     * @param assets Amount of stablecoin tokens to deposit
     * @param receiver Address to receive snrUSD
     * @return shares Amount of snrUSD minted (approximately equals assets at index ~1.0)
     */
    function deposit(uint256 assets, address receiver) public virtual whenNotPaused nonReentrant returns (uint256 shares) {
        if (assets == 0) revert InvalidAmount();
        if (receiver == address(0)) revert AdminControlled.ZeroAddress();
        
        // Check deposit cap
        if (isDepositCapReached()) revert DepositCapExceeded();
        
        // N5 FIX: Transfer stablecoin from user (use safeTransferFrom for non-standard ERC20)
        _stablecoin.safeTransferFrom(msg.sender, address(this), assets);
        
        // Track capital inflow: increase vault value by deposited assets
        _vaultValue += assets;
        
        // Mint snrUSD to receiver (1:1 at current index)
        _mint(receiver, assets);
        
        emit Deposit(receiver, assets, assets);
        
        return assets; // Balance minted (shares calculated internally)
    }
    
    /**
     * @notice Calculate minimum expected amount from LP liquidation with slippage tolerance
     * @dev VN003 FIX: Queries Kodiak Island pool to calculate expected return and applies slippage tolerance
     * @param needed Amount of stablecoin needed
     * @return minExpected Minimum acceptable amount after applying slippage tolerance
     */
    /// @dev Calculate minimum expected output with 2% slippage tolerance
    function _calculateMinExpectedFromLP(uint256 needed) internal pure returns (uint256) {
        return (needed * 9800) / 10000; // 98% of needed (2% slippage)
    }
    
    /// @dev Get LP conversion data for USD amount
    function _getLpConversionData(uint256 usdAmt) internal view returns (uint256 lpTokens, uint256 lpValUsd, uint256 honey, uint256 lpSupply) {
        if (address(kodiakHook) == address(0)) return (0, 0, 0, 0);
        try kodiakHook.island() returns (IKodiakIsland island) {
            if (address(island) == address(0)) return (0, 0, 0, 0);
            (, honey) = island.getUnderlyingBalances();
            lpSupply = island.totalSupply();
            if (lpSupply == 0 || honey == 0) return (0, 0, 0, 0);
            lpValUsd = Math.mulDiv(kodiakHook.getIslandLPBalance(), honey, lpSupply);
            lpTokens = Math.mulDiv(usdAmt, lpSupply, honey) * 102 / 100;
        } catch { return (0, 0, 0, 0); }
    }
    
    /// @notice Ensures liquidity by freeing LP if needed (up to 3 attempts)
    function _ensureLiquidityAvailable(uint256 amountNeeded) internal returns (uint256 totalFreed) {
        for (uint256 i = 0; i < 3; i++) {
            uint256 bal = _stablecoin.balanceOf(address(this));
            if (bal >= amountNeeded) break;
            if (address(kodiakHook) == address(0)) revert InsufficientLiquidity();
            
            uint256 needed = amountNeeded - bal;
            uint256 minExp = _calculateMinExpectedFromLP(needed);
            
            // Try withdraw from reward vault if hook LP insufficient
            (uint256 lpNeeded, uint256 lpVal, uint256 honey, uint256 lpSupply) = _getLpConversionData(needed);
            if (lpVal < needed && lpNeeded > 0 && honey > 0 && lpSupply > 0) {
                uint256 lpToGet = Math.mulDiv(needed - lpVal, lpSupply, honey) * 102 / 100;
                IRewardVault rv = _getRewardVault();
                if (address(rv) != address(0)) {
                    uint256 staked = rv.getTotalDelegateStaked(admin());
                    uint256 toWithdraw = lpToGet > staked ? staked : lpToGet;
                    if (toWithdraw > 0) { rv.delegateWithdraw(admin(), toWithdraw); IERC20(address(kodiakHook.island())).safeTransfer(address(kodiakHook), toWithdraw); }
                }
            }
            
            try kodiakHook.liquidateLPForAmount(needed) {
                uint256 freed = _stablecoin.balanceOf(address(this)) - bal;
                totalFreed += freed;
                if (minExp > 0 && freed < minExp) revert SlippageTooHigh();
                emit LPLiquidationExecuted(needed, freed, minExp);
                if (freed == 0) break;
            } catch { break; }
        }
        if (_stablecoin.balanceOf(address(this)) < amountNeeded) revert InsufficientLiquidity();
        if (totalFreed > 0) emit LiquidityFreedForWithdrawal(amountNeeded, totalFreed);
    }
    
    /// @notice Withdraw stablecoin by burning snrUSD
    function withdraw(uint256 amount, address receiver, address owner) public virtual whenNotPausedOrAdmin nonReentrant returns (uint256 assets) {
        if (amount == 0) revert InvalidAmount();
        if (receiver == address(0)) revert AdminControlled.ZeroAddress();
        if (msg.sender != owner) {
            uint256 allow = _allowances[owner][msg.sender];
            if (allow < amount) revert InsufficientAllowance();
            if (allow != type(uint256).max) _approve(owner, msg.sender, allow - amount);
        }
        (uint256 penalty, uint256 afterPenalty) = calculateWithdrawalPenalty(owner, amount);
        uint256 fee = (afterPenalty * MathLib.SENIOR_WITHDRAWAL_FEE) / MathLib.PRECISION;
        uint256 net = afterPenalty - fee;
        
        _burn(owner, amount);
        _vaultValue -= afterPenalty;
        if (_cooldownStart[owner] != 0) _cooldownStart[owner] = 0;
        
        _ensureLiquidityAvailable(afterPenalty);
        _stablecoin.safeTransfer(receiver, net);
        if (_treasury != address(0) && fee > 0) { _stablecoin.safeTransfer(_treasury, fee); emit WithdrawalFeeCharged(owner, fee, net); }
        if (penalty > 0) emit WithdrawalPenaltyCharged(owner, penalty);
        emit Withdraw(owner, net, amount);
        return net;
    }
    
    // ============================================
    // ISeniorVault Interface Implementation
    // ============================================
    
    // Interface-required view functions (single-line to minimize bytecode)
    function juniorVault() public view virtual returns (address) { return address(_juniorVault); }
    function reserveVault() public view virtual returns (address) { return address(_reserveVault); }
    function treasury() public view virtual returns (address) { return _treasury; }
    function lastRebaseTime() public view virtual returns (uint256) { return _lastRebaseTime; }
    function minRebaseInterval() public view virtual returns (uint256) { return _minRebaseInterval; }
    function depositCap() public view virtual returns (uint256) { return MathLib.calculateDepositCap(_reserveVault.vaultValue()); }
    function isDepositCapReached() public view virtual returns (bool) { return totalSupply() >= depositCap(); }
    function backingRatio() public view virtual returns (uint256) { 
        uint256 s = totalSupply(); 
        return s == 0 ? MathLib.PRECISION : MathLib.calculateBackingRatio(_vaultValue, s); 
    }
    function currentZone() public view virtual returns (SpilloverLib.Zone) { return SpilloverLib.determineZone(backingRatio()); }
    
    // ============================================
    // Rebase Simulation (View Only)
    // ============================================
    
    /// @notice Result of rebase simulation
    struct RebaseSimulation {
        uint256 currentBackingRatio;      // Current backing ratio before rebase
        uint256 newBackingRatio;          // Backing ratio after rebase
        uint256 selectedAPY;              // APY tier that would be selected (11%, 12%, or 13%)
        uint256 mgmtFeeTokens;            // Management fee tokens to mint
        uint256 perfFeeTokens;            // Performance fee tokens to mint
        uint256 newSupply;                // Total supply after rebase
        SpilloverLib.Zone currentZoneVal; // Current zone
        SpilloverLib.Zone newZone;        // Zone after rebase
        bool willSpillover;               // True if spillover will occur
        bool willBackstop;                // True if backstop will be needed
        uint256 spilloverAmount;          // Amount that would spillover (if any)
        uint256 backstopNeeded;           // Amount of backstop needed (if any)
        uint256 timeUntilNextRebase;      // Seconds until next rebase allowed (0 if can rebase now)
    }
    
    /// @notice Simulate rebase without executing - shows what would happen
    /// @return sim Simulation results
    function simulateRebase() external view returns (RebaseSimulation memory sim) {
        uint256 currentSupply = totalSupply();
        if (currentSupply == 0) return sim;
        
        // Time calculations
        uint256 timeElapsed = block.timestamp > _lastRebaseTime ? block.timestamp - _lastRebaseTime : 0;
        sim.timeUntilNextRebase = block.timestamp < _lastRebaseTime + _minRebaseInterval 
            ? (_lastRebaseTime + _minRebaseInterval) - block.timestamp : 0;
        
        // Current state
        sim.currentBackingRatio = backingRatio();
        sim.currentZoneVal = SpilloverLib.determineZone(sim.currentBackingRatio);
        
        // Step 1: Management fee calculation
        sim.mgmtFeeTokens = FeeLib.calculateManagementFeeTokens(_vaultValue, timeElapsed);
        
        // Step 2 & 3: Dynamic APY selection
        RebaseLib.APYSelection memory selection = RebaseLib.selectDynamicAPY(
            currentSupply, _vaultValue, timeElapsed, sim.mgmtFeeTokens
        );
        
        sim.selectedAPY = selection.selectedRate;
        sim.perfFeeTokens = selection.feeTokens;
        sim.newSupply = selection.newSupply;
        
        // Step 4: Calculate new backing ratio and zone
        sim.newBackingRatio = MathLib.calculateBackingRatio(_vaultValue, sim.newSupply);
        sim.newZone = SpilloverLib.determineZone(sim.newBackingRatio);
        
        // Determine spillover/backstop
        sim.willSpillover = (sim.newZone == SpilloverLib.Zone.SPILLOVER);
        sim.willBackstop = (sim.newZone == SpilloverLib.Zone.BACKSTOP || selection.backstopNeeded);
        
        // Calculate spillover amount if applicable (excess above 110% target)
        if (sim.willSpillover) {
            uint256 targetValue = (sim.newSupply * MathLib.SENIOR_TARGET_BACKING) / MathLib.PRECISION;
            sim.spilloverAmount = _vaultValue > targetValue ? _vaultValue - targetValue : 0;
        }
        
        // Calculate backstop amount if applicable
        if (sim.willBackstop) {
            uint256 targetBacking = (sim.newSupply * MathLib.SENIOR_RESTORE_BACKING) / MathLib.PRECISION;
            sim.backstopNeeded = targetBacking > _vaultValue ? targetBacking - _vaultValue : 0;
        }
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
     * @notice Calculate withdrawal penalty
     * @dev Reference: Fee Calculations - P(w, t_c)
     * @dev Q1 FIX: Delegates to FeeLib which handles all cases including cooldownTime == 0
     */
    function calculateWithdrawalPenalty(
        address user,
        uint256 amount
    ) public view virtual returns (uint256 penalty, uint256 netAmount) {
        // Delegate to FeeLib - it handles all cases including when cooldown not initiated
        return FeeLib.calculateWithdrawalPenalty(amount, _cooldownStart[user], block.timestamp);
    }
    
    // ============================================
    // Rebase Functions
    // ============================================
    
    /**
     * @notice Execute monthly rebase
     * @dev Reference: Rebase Algorithm (all steps) - MATH SPEC PRESERVED
     */
    /**
     * @notice Execute rebase with manual LP price for spillover/backstop transfers
     * @param lpPrice Current LP token price in USD (18 decimals) - must be provided by admin
     */
    function rebase(uint256 lpPrice) public virtual onlyAdmin {
        if (block.timestamp < _lastRebaseTime + _minRebaseInterval) {
            revert RebaseTooSoon();
        }
        
        if (lpPrice == 0) revert InvalidAmount();
        
        uint256 currentSupply = totalSupply();
        if (currentSupply == 0) revert InvalidAmount();
        
        // Step 1: Calculate management fee tokens to mint (TIME-BASED)
        uint256 timeElapsed = block.timestamp - _lastRebaseTime;
        uint256 mgmtFeeTokens = FeeLib.calculateManagementFeeTokens(_vaultValue, timeElapsed);
        
        // Step 2 & 3: Dynamic APY selection (TIME-BASED FIX + MGMT FEE FIX)
        // NOW includes timeElapsed and mgmtFeeTokens for accurate backing ratio calculation
        RebaseLib.APYSelection memory selection = RebaseLib.selectDynamicAPY(
            currentSupply,
            _vaultValue,
            timeElapsed,      // TIME-BASED FIX: Pass actual time elapsed
            mgmtFeeTokens     // MGMT FEE FIX: Include management fee in APY selection
        );
        
        // Step 4: Determine zone and execute spillover/backstop (with LP price)
        // selection.newSupply now ALREADY includes mgmtFeeTokens (no need to add again!)
        uint256 finalBackingRatio = MathLib.calculateBackingRatio(_vaultValue, selection.newSupply);
        SpilloverLib.Zone zone = SpilloverLib.determineZone(finalBackingRatio);
        
        if (zone == SpilloverLib.Zone.SPILLOVER) {
            _executeProfitSpillover(_vaultValue, selection.newSupply, lpPrice);
        } else if (zone == SpilloverLib.Zone.BACKSTOP || selection.backstopNeeded) {
            _executeBackstop(_vaultValue, selection.newSupply, lpPrice);
        }
        
        // Step 5: Update rebase index (TIME-BASED FIX)
        uint256 oldIndex = _rebaseIndex;
        _rebaseIndex = FeeLib.calculateNewRebaseIndex(oldIndex, selection.selectedRate, timeElapsed);
        _epoch++;
        
        // Step 6: Mint ALL fee tokens to treasury (management + performance)
        uint256 totalFeeTokens = mgmtFeeTokens + selection.feeTokens;
        if (totalFeeTokens > 0) {
            _mint(_treasury, totalFeeTokens);
        }
        
        _lastRebaseTime = block.timestamp;
        
        emit Rebase(_epoch, oldIndex, _rebaseIndex, totalSupply());
        emit RebaseExecuted(_epoch, selection.apyTier, oldIndex, _rebaseIndex, selection.newSupply, zone);
        emit FeesCollected(mgmtFeeTokens, selection.feeTokens);  // Now shows both fees
    }
    
    // ============================================
    // Emergency Functions
    // ============================================
    
    /**
     * @notice Set pause state for deposits and withdrawals
     * @dev Consolidates pause/unpause to reduce contract size
     * @param paused True to pause, false to unpause
     */
    function setPaused(bool paused) external onlyAdmin {
        if (paused) {
            _pause();
        } else {
            _unpause();
        }
    }
    
    // ============================================
    // UUPS Upgrade Authorization
    // ============================================
    
    /**
     * @notice Authorize upgrade to new implementation
     * @dev Only admin can upgrade the contract
     * @param newImplementation Address of new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyContractUpdater {
        // Admin authorization check via modifier
    }
    
    /**
     * @notice Emergency withdraw stablecoin tokens to treasury
     * @dev Can only be called by admin when paused, for emergency situations
     * @param amount Amount of stablecoin tokens to withdraw
     */
    function emergencyWithdraw(uint256 amount) external onlyAdmin {
        if (!paused()) revert NotPaused();
        if (amount == 0) revert InvalidAmount();
        
        _stablecoin.safeTransfer(_treasury, amount);
        emit EmergencyWithdraw(_treasury, amount);
    }
    
    // ============================================
    // Internal Functions
    // ============================================
    
    /**
     * @notice Execute profit spillover (Zone 1)
     * @dev Reference: Three-Zone System - Profit Spillover
     * @param lpPrice Current LP token price in USD (18 decimals)
     */
    function _executeProfitSpillover(uint256 netValue, uint256 newSupply, uint256 lpPrice) internal virtual {
        SpilloverLib.ProfitSpillover memory spillover = 
            SpilloverLib.calculateProfitSpillover(netValue, newSupply);
        
        if (spillover.excessAmount == 0) return;
        
        // Update Senior value to exactly 110%
        _vaultValue = spillover.seniorFinalValue;
        
        // Transfer LP tokens to Junior and Reserve (calculated from USD amounts)
        _transferToJunior(spillover.toJunior, lpPrice);
        _transferToReserve(spillover.toReserve, lpPrice);
        
        emit ProfitSpillover(spillover.excessAmount, spillover.toJunior, spillover.toReserve);
    }
    
    /**
     * @notice Execute backstop (Zone 3)
     * @dev Reference: Three-Zone System - Backstop
     * @dev SECURITY FIX: Uses ACTUAL amounts received, not expected amounts
     * @param lpPrice Current LP token price in USD (18 decimals)
     */
    function _executeBackstop(uint256 netValue, uint256 newSupply, uint256 lpPrice) internal virtual {
        uint256 reserveValue = _reserveVault.vaultValue();
        uint256 juniorValue = _juniorVault.vaultValue();
        
        SpilloverLib.BackstopResult memory backstop = 
            SpilloverLib.calculateBackstop(netValue, newSupply, reserveValue, juniorValue);
        
        if (backstop.deficitAmount == 0) return;
        
        // SECURITY FIX: Track ACTUAL amounts received (can differ from expected!)
        uint256 actualFromReserve = 0;
        uint256 actualFromJunior = 0;
        
        // Pull LP tokens from Reserve first (calculated from USD amount)
        if (backstop.fromReserve > 0) {
            actualFromReserve = _pullFromReserve(backstop.fromReserve, lpPrice);
        }
        
        // Then Junior if needed (calculated from USD amount)
        if (backstop.fromJunior > 0) {
            actualFromJunior = _pullFromJunior(backstop.fromJunior, lpPrice);
        }
        
        // SECURITY FIX: Update vault value based on ACTUAL amounts received
        // This prevents accounting mismatch when Reserve/Junior can't provide full amounts
        _vaultValue = netValue + actualFromReserve + actualFromJunior;
        
        // Determine if fully restored based on ACTUAL amounts
        uint256 totalActualReceived = actualFromReserve + actualFromJunior;
        bool actuallyFullyRestored = (netValue + totalActualReceived >= 
            (newSupply * MathLib.SENIOR_RESTORE_BACKING) / MathLib.PRECISION);
        
        emit BackstopTriggered(
            backstop.deficitAmount,
            actualFromReserve,  // Emit ACTUAL amounts, not expected
            actualFromJunior,   // Emit ACTUAL amounts, not expected
            actuallyFullyRestored
        );
    }
    
    // ============================================
    // Abstract Transfer Functions (Must implement in concrete contract)
    // ============================================
    
    /**
     * @notice Transfer LP tokens to Junior vault
     * @dev Must be implemented to handle actual LP token transfers
     * @param amountUSD Amount in USD to transfer
     * @param lpPrice Current LP token price in USD (18 decimals)
     */
    function _transferToJunior(uint256 amountUSD, uint256 lpPrice) internal virtual;
    
    /**
     * @notice Transfer LP tokens to Reserve vault
     * @dev Must be implemented to handle actual LP token transfers
     * @param amountUSD Amount in USD to transfer
     * @param lpPrice Current LP token price in USD (18 decimals)
     */
    function _transferToReserve(uint256 amountUSD, uint256 lpPrice) internal virtual;
    
    /**
     * @notice Pull LP tokens from Reserve vault
     * @dev Must be implemented to handle actual LP token transfers
     * @param amountUSD Amount in USD to receive
     * @param lpPrice Current LP token price in USD (18 decimals)
     * @return actualReceived Actual USD value received (may be less than requested)
     */
    function _pullFromReserve(uint256 amountUSD, uint256 lpPrice) internal virtual returns (uint256 actualReceived);
    
    /**
     * @notice Pull LP tokens from Junior vault
     * @dev Must be implemented to handle actual LP token transfers
     * @param amountUSD Amount in USD to receive
     * @param lpPrice Current LP token price in USD (18 decimals)
     * @return actualReceived Actual USD value received (may be less than requested)
     */
    function _pullFromJunior(uint256 amountUSD, uint256 lpPrice) internal virtual returns (uint256 actualReceived);
}

