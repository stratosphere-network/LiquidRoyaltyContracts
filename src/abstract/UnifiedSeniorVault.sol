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
    
    modifier nonReentrant() {
        require(_getReentrancyStatus() != _ENTERED, "ReentrancyGuard: reentrant call");
        _setReentrancyStatus(_ENTERED);
        _;
        _setReentrancyStatus(_NOT_ENTERED);
    }
    
    /// @dev Virtual functions for reentrancy guard (implemented in concrete contracts)
    function _getReentrancyStatus() internal view virtual returns (uint256);
    function _setReentrancyStatus(uint256 status) internal virtual;
    
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
    
    /// @dev Pending LP deposits
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
    event WithdrawalFeeCharged(address indexed user, uint256 fee, uint256 netAmount);
    event VaultSeeded(address indexed lpToken, address indexed seedProvider, uint256 amount, uint256 lpPrice, uint256 valueAdded, uint256 sharesMinted);
    event JuniorReserveUpdated(address indexed juniorVault, address indexed reserveVault);
    event KodiakHookUpdated(address indexed newHook);
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

    /// @dev Errors (ZeroAddress inherited from AdminControlled, InsufficientBalance and InvalidAmount from IVault)
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
    error DepositNotFound();
    error DepositNotPending();
    error DepositExpired();
    error NotDepositor();
    error DepositNotExpired();
    error InvalidLPToken();
    error IdleBalanceDeviation();
    error InvalidStablecoinDecimals();
    
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
     * @notice Add LP to whitelist
     * @dev Only admin can whitelist LPs
     * @param lp Address to whitelist
     */
    function addWhitelistedLP(address lp) external onlyAdmin {
        if (lp == address(0)) revert AdminControlled.ZeroAddress();
        if (_isWhitelistedLP[lp]) revert LPAlreadyWhitelisted();
        
        _whitelistedLPs.push(lp);
        _isWhitelistedLP[lp] = true;

        
        emit WhitelistedLPAdded(lp);
    }
    /**
     * @notice Set Kodiak hook and automatically whitelist it
     * @dev Hook must implement IKodiakVaultHook and vault() must return this vault's address
     * @param hook Address of Kodiak hook contract
     */
    function setKodiakHook(address hook) external onlyAdmin {
        // Remove old hook from whitelist if exists
        if (address(kodiakHook) != address(0)) {
            // Remove from whitelist
            if (_isWhitelistedLP[address(kodiakHook)]) {
                _removeWhitelistedLPInternal(address(kodiakHook));
            }
        }
        
        // Validate new hook
        if (hook != address(0)) {
            (bool ok, bytes memory data) = hook.staticcall(abi.encodeWithSignature("vault()"));
            if (!(ok && data.length >= 32 && abi.decode(data, (address)) == address(this))) revert WrongVault();
            
            // Automatically whitelist the new hook so investInLP() can send funds to it
            if (!_isWhitelistedLP[hook]) {
                _whitelistedLPs.push(hook);
                _isWhitelistedLP[hook] = true;
                emit WhitelistedLPAdded(hook);
            }
        }
        
        kodiakHook = IKodiakVaultHook(hook);
        
        emit KodiakHookUpdated(hook);
    }

    /**
     * @notice Remove LP from whitelist
     * @dev Only admin can remove LPs
     * @param lp Address to remove
     */
    function removeWhitelistedLP(address lp) external onlyAdmin {
        if (lp == address(0)) revert AdminControlled.ZeroAddress();
        if (!_isWhitelistedLP[lp]) revert WhitelistedLPNotFound();
        
        _removeWhitelistedLPInternal(lp);
        
        emit WhitelistedLPRemoved(lp);
    }
    
    /**
     * @dev Internal function to remove LP from whitelist (used by setKodiakHook)
     * @param lp Address to remove
     */
    function _removeWhitelistedLPInternal(address lp) internal {
        // Find and remove from array using swap-and-pop
        for (uint256 i = 0; i < _whitelistedLPs.length; i++) {
            if (_whitelistedLPs[i] == lp) {
                _whitelistedLPs[i] = _whitelistedLPs[_whitelistedLPs.length - 1];
                _whitelistedLPs.pop();
                break;
            }
        }
        
        // Remove from mapping
        _isWhitelistedLP[lp] = false;
    }
    
    /**
     * @notice Check if LP is whitelisted
     * @param lp Address to check
     * @return isWhitelisted True if LP is whitelisted
     */
    function isWhitelistedLP(address lp) external view returns (bool) {
        return _isWhitelistedLP[lp];
    }
    
    /**
     * @notice Get all whitelisted LPs
     * @return lps Array of whitelisted LP addresses
     */
    function getWhitelistedLPs() external view returns (address[] memory) {
        return _whitelistedLPs;
    }
    
    // ============================================
    // LP Token Management
    // ============================================

    /**
     * @notice Add LP token to whitelist
     * @dev Only admin can whitelist LP tokens
     * @param lpToken Address of LP token to whitelist
     */
    function addWhitelistedLPToken(address lpToken) external onlyAdmin {
        if (lpToken == address(0)) revert AdminControlled.ZeroAddress();
        if (_isWhitelistedLPToken[lpToken]) revert LPAlreadyWhitelisted();
        
        _whitelistedLPTokens.push(lpToken);
        _isWhitelistedLPToken[lpToken] = true;
        
        emit WhitelistedLPTokenAdded(lpToken);
    }

    /**
     * @notice Remove LP token from whitelist
     * @dev Only admin can remove LP tokens
     * @param lpToken Address of LP token to remove
     */
    function removeWhitelistedLPToken(address lpToken) external onlyAdmin {
        if (lpToken == address(0)) revert AdminControlled.ZeroAddress();
        if (!_isWhitelistedLPToken[lpToken]) revert WhitelistedLPNotFound();
        
        _removeWhitelistedLPTokenInternal(lpToken);
        
        emit WhitelistedLPTokenRemoved(lpToken);
    }
    
    /**
     * @dev Internal helper to remove LP token from whitelist
     * @param lpToken Address to remove
     */
    function _removeWhitelistedLPTokenInternal(address lpToken) internal {
        // Find and remove from array using swap-and-pop
        for (uint256 i = 0; i < _whitelistedLPTokens.length; i++) {
            if (_whitelistedLPTokens[i] == lpToken) {
                _whitelistedLPTokens[i] = _whitelistedLPTokens[_whitelistedLPTokens.length - 1];
                _whitelistedLPTokens.pop();
                break;
            }
        }
        
        // Remove from mapping
        _isWhitelistedLPToken[lpToken] = false;
    }
    
    /**
     * @notice Check if LP token is whitelisted
     * @param lpToken Address to check
     * @return isWhitelisted True if LP token is whitelisted
     */
    function isWhitelistedLPToken(address lpToken) external view returns (bool) {
        return _isWhitelistedLPToken[lpToken];
    }
    
    /**
     * @notice Get all whitelisted LP tokens
     * @return lpTokens Array of whitelisted LP token addresses
     */
    function getWhitelistedLPTokens() external view returns (address[] memory) {
        return _whitelistedLPTokens;
    }
    
    /**
     * @notice Get vault's LP token holdings for all whitelisted LP tokens
     * @dev Returns array of LP tokens and their balances held by this vault
     * @return holdings Array of LPHolding structs containing LP token address and amount
     */
    function getLPTokenHoldings() external view returns (LPHolding[] memory holdings) {
        uint256 lpTokenCount = _whitelistedLPTokens.length;
        holdings = new LPHolding[](lpTokenCount);
        
        for (uint256 i = 0; i < lpTokenCount; i++) {
            address lpToken = _whitelistedLPTokens[i];
            uint256 balance = IERC20(lpToken).balanceOf(address(this));
            
            holdings[i] = LPHolding({
                lpToken: lpToken,
                amount: balance
            });
        }
        
        return holdings;
    }
    
    /**
     * @notice Get vault's balance of a specific LP token
     * @dev Gas-efficient way to check single LP token balance
     * @param lpToken Address of the LP token to check
     * @return balance Amount of LP tokens held by this vault
     */
    function getLPTokenBalance(address lpToken) external view returns (uint256) {
        return IERC20(lpToken).balanceOf(address(this));
    }

    /**
     * @notice Transfer stablecoins from vault to whitelisted LP
     * @dev Only admin can invest, LP must be whitelisted
     * @param lp Address of the whitelisted LP to transfer to
     * @param amount Amount of stablecoins to transfer
     */
    function investInLP(address lp, uint256 amount) external onlyLiquidityManager {
        if (lp == address(0)) revert AdminControlled.ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (!_isWhitelistedLP[lp]) revert WhitelistedLPNotFound();
        
        // Check vault has sufficient stablecoin balance
        uint256 vaultBalance = _stablecoin.balanceOf(address(this));
        if (vaultBalance < amount) revert InsufficientBalance();
        
        // Transfer stablecoins from vault to LP
        _stablecoin.safeTransfer(lp, amount);
        
        emit LPInvestment(lp, amount);
    }

    /**
     * @notice Deploy idle stablecoin funds to Kodiak Island
     * @dev Only callable by admin with off-chain verified swap params
     *      Provides slippage protection via minLPTokens parameter
     * @param amount Amount of stablecoin to deploy to Kodiak
     * @param minLPTokens Minimum Island LP tokens expected (slippage protection)
     * @param swapToToken0Aggregator Aggregator address for token0 swap (verified off-chain)
     * @param swapToToken0Data Swap calldata for token0 (verified off-chain)
     * @param swapToToken1Aggregator Aggregator address for token1 swap (verified off-chain)
     * @param swapToToken1Data Swap calldata for token1 (verified off-chain)
     */
    function deployToKodiak(
        uint256 amount,
        uint256 minLPTokens,
        address swapToToken0Aggregator,
        bytes calldata swapToToken0Data,
        address swapToToken1Aggregator,
        bytes calldata swapToToken1Data
    ) external onlyLiquidityManager {
        if (amount == 0) revert InvalidAmount();
        if (address(kodiakHook) == address(0)) revert KodiakHookNotSet();
        
        // Check vault has enough idle stablecoin
        uint256 vaultBalance = _stablecoin.balanceOf(address(this));
        if (vaultBalance < amount) revert InsufficientBalance();
        
        // Record LP balance before deployment
        uint256 lpBefore = kodiakHook.getIslandLPBalance();
        
        // Transfer stablecoins to hook
        _stablecoin.safeTransfer(address(kodiakHook), amount);
        
        // Deploy to Kodiak with verified swap params
        kodiakHook.onAfterDepositWithSwaps(
            amount,
            swapToToken0Aggregator,
            swapToToken0Data,
            swapToToken1Aggregator,
            swapToToken1Data
        );
        
        // Verify slippage protection
        uint256 lpAfter = kodiakHook.getIslandLPBalance();
        uint256 lpReceived = lpAfter - lpBefore;
        if (lpReceived < minLPTokens) revert SlippageTooHigh();
        
        emit KodiakDeployment(amount, lpReceived, block.timestamp);
    }
    
    /**
     * @notice Deploy all idle stablecoins to Kodiak (sweep dust)
     * @dev Convenience function to deploy entire vault balance without specifying amount
     * @dev N10 FIX: Protects against stale slippage params when deposits happen in same block
     * @param expectedIdle Expected idle balance when tx was prepared (prevents stale minLPTokens)
     * @param maxDeviation Maximum allowed deviation from expectedIdle in basis points (e.g., 100 = 1%)
     * @param minLPTokens Minimum LP tokens to receive (slippage protection)
     * @param swapToToken0Aggregator DEX aggregator for token0 swap
     * @param swapToToken0Data Swap calldata for token0
     * @param swapToToken1Aggregator DEX aggregator for token1 swap
     * @param swapToToken1Data Swap calldata for token1
     */
    function sweepToKodiak(
        uint256 expectedIdle,
        uint256 maxDeviation,
        uint256 minLPTokens,
        address swapToToken0Aggregator,
        bytes calldata swapToToken0Data,
        address swapToToken1Aggregator,
        bytes calldata swapToToken1Data
    ) external onlyLiquidityManager {
        if (address(kodiakHook) == address(0)) revert KodiakHookNotSet();
        
        // Get all idle stablecoin balance
        uint256 idle = _stablecoin.balanceOf(address(this));
        if (idle == 0) revert InvalidAmount();
        
        // N10 FIX: Ensure idle balance hasn't changed significantly since tx preparation
        // This prevents stale minLPTokens from being used when deposits happen in same block
        if (idle != expectedIdle) {
            uint256 deviation = idle > expectedIdle ? idle - expectedIdle : expectedIdle - idle;
            uint256 maxAllowedDeviation = (expectedIdle * maxDeviation) / 10000;
            if (deviation > maxAllowedDeviation) {
                revert IdleBalanceDeviation();
            }
        }
        
        // Deploy all idle funds
        uint256 lpBefore = kodiakHook.getIslandLPBalance();
        
        // Transfer all idle stablecoins to hook
        _stablecoin.safeTransfer(address(kodiakHook), idle);
        
        // Deploy to Kodiak with verified swap params
        kodiakHook.onAfterDepositWithSwaps(
            idle,
            swapToToken0Aggregator,
            swapToToken0Data,
            swapToToken1Aggregator,
            swapToToken1Data
        );
        
        // Verify slippage protection
        uint256 lpAfter = kodiakHook.getIslandLPBalance();
        uint256 lpReceived = lpAfter - lpBefore;
        if (lpReceived < minLPTokens) revert SlippageTooHigh();
        
        emit KodiakDeployment(idle, lpReceived, block.timestamp);
    }

    /**
     * @notice Withdraw LP tokens from vault for liquidation
     * @dev Only admin can withdraw, must be sent to whitelisted LP address
     * @param lpToken Address of the LP token to withdraw
     * @param lp Address of whitelisted LP to send tokens to
     * @param amount Amount of LP tokens to withdraw (0 = withdraw all)
     */
    function withdrawLPTokens(address lpToken, address lp, uint256 amount) external onlyLiquidityManager {
        if (lpToken == address(0)) revert AdminControlled.ZeroAddress();
        if (lp == address(0)) revert AdminControlled.ZeroAddress();
        if (!_isWhitelistedLP[lp]) revert WhitelistedLPNotFound();
        if (!_isWhitelistedLPToken[lpToken]) revert WhitelistedLPNotFound();
        
        // Get LP token balance
        IERC20 lpTokenContract = IERC20(lpToken);
        uint256 balance = lpTokenContract.balanceOf(address(this));
        
        // If amount is 0, withdraw all
        uint256 withdrawAmount = amount == 0 ? balance : amount;
        
        if (withdrawAmount == 0) revert InvalidAmount();
        if (balance < withdrawAmount) revert InsufficientBalance();
        
        // Transfer LP tokens to whitelisted LP address for liquidation
        lpTokenContract.safeTransfer(lp, withdrawAmount);
        
        emit LPTokensWithdrawn(lpToken, lp, withdrawAmount);
    }
    
    /**
     * @notice Update the minimum rebase interval
     * @dev Only admin can update this value
     * @param newInterval New minimum time between rebases (in seconds)
     */
    function setMinRebaseInterval(uint256 newInterval) external onlyAdmin {
        uint256 oldInterval = _minRebaseInterval;
        _minRebaseInterval = newInterval;
        emit MinRebaseIntervalUpdated(oldInterval, newInterval);
    }
    
    /**
     * @notice Set treasury address for fee collection
     * @param treasury_ New treasury address
     */
    function setTreasury(address treasury_) external onlyAdmin {
        if (treasury_ == address(0)) revert AdminControlled.ZeroAddress();
        _treasury = treasury_;
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
    ) external onlySeeder {
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
        uint256 normalizedAmount = _normalizeToDecimals(amount, lpDecimals, 18);
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
    // Pending LP Deposit System
    // ============================================
    
    /**
     * @notice Deposit LP tokens (pending admin approval)
     * @dev LP tokens are transferred to vault's hook immediately
     * @param lpToken Address of LP token to deposit
     * @param amount Amount of LP tokens
     * @return depositId ID of pending deposit
     */
    function depositLP(address lpToken, uint256 amount) external returns (uint256 depositId) {
        if (lpToken == address(0)) revert AdminControlled.ZeroAddress();
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
     * @dev Only admin can approve. For Senior: mints 1:1 snrUSD.
     * @param depositId ID of pending deposit
     * @param lpPrice Price of LP token in USD (18 decimals)
     */
    function approveLPDeposit(uint256 depositId, uint256 lpPrice) external onlyLiquidityManager {
        PendingLPDeposit storage pendingDeposit = _pendingDeposits[depositId];
        
        if (pendingDeposit.depositor == address(0)) revert DepositNotFound();
        if (pendingDeposit.status != DepositStatus.PENDING) revert DepositNotPending();
        if (block.timestamp > pendingDeposit.expiresAt) revert DepositExpired();
        if (lpPrice == 0) revert InvalidLPPrice();
        
        // Calculate value and shares (Senior: 1:1 with USD)
        // Q5 FIX: Account for LP token decimals
        uint8 lpDecimals = IERC20Metadata(pendingDeposit.lpToken).decimals();
        uint256 normalizedAmount = _normalizeToDecimals(pendingDeposit.amount, lpDecimals, 18);
        uint256 valueAdded = (normalizedAmount * lpPrice) / 1e18;
        
        // For Senior: mint 1:1 (snrUSD is rebasing token, not ERC4626)
        // NOTE: UnifiedSeniorVault uses rebasing (balance = shares × index)
        // _mint() will convert the balance amount to internal shares automatically
        if (valueAdded == 0) revert InvalidAmount(); // Safety: prevent 0-value minting
        
        // Update status (Effects - state updates BEFORE external call)
        pendingDeposit.status = DepositStatus.APPROVED;
        
        emit PendingLPDepositApproved(depositId, pendingDeposit.depositor, lpPrice, valueAdded);
        
        // N1-2 FIX: Mint shares BEFORE updating vault value (matches standard deposit flow)
        _mint(pendingDeposit.depositor, valueAdded);
        
        // Update vault value AFTER minting (consistent with deposit() pattern)
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
    
    function depositToken() public view virtual returns (IERC20) {
        return _stablecoin;
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
    function updateVaultValue(int256 profitBps) public virtual onlyPriceFeedManager {
        if (profitBps < MIN_PROFIT_BPS || profitBps > MAX_PROFIT_BPS) {
            revert InvalidProfitRange();
        }
        
        uint256 oldValue = _vaultValue;
        uint256 newValue = MathLib.applyPercentage(oldValue, profitBps);
        
        _vaultValue = newValue;
        _lastUpdateTime = block.timestamp;
        
        emit VaultValueUpdated(oldValue, _vaultValue, profitBps);
    }

    /**
     * @notice Directly set vault value (no BPS calculation)
     * @dev Simple admin function to set exact vault value
     * @param newValue New vault value in wei
     */
    function setVaultValue(uint256 newValue) public virtual onlyPriceFeedManager {
        uint256 oldValue = _vaultValue;
        _vaultValue = newValue;
        _lastUpdateTime = block.timestamp;
        
        // Calculate BPS for event logging
        int256 bps = 0;
        if (oldValue > 0) {
            bps = int256((newValue * 10000 / oldValue)) - 10000;
        }
        
        emit VaultValueUpdated(oldValue, _vaultValue, bps);
    }
    
    /**
     * @notice Deposit stablecoin, receive snrUSD (1:1)
     * @param assets Amount of stablecoin tokens to deposit
     * @param receiver Address to receive snrUSD
     * @return shares Amount of snrUSD minted (approximately equals assets at index ~1.0)
     */
    function deposit(uint256 assets, address receiver) public virtual whenNotPaused returns (uint256 shares) {
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
    function _calculateMinExpectedFromLP(uint256 needed) internal view returns (uint256 minExpected) {
        if (address(kodiakHook) == address(0)) return 0;
        
        try kodiakHook.island() returns (IKodiakIsland island) {
            if (address(island) == address(0)) return 0;
            
            // Query pool reserves
            (, uint256 honeyInPool) = island.getUnderlyingBalances();
            uint256 totalLP = island.totalSupply();
            
            if (totalLP == 0 || honeyInPool == 0) return 0;
            
            // Calculate expected return (conservative: assume 1:1 on needed amount)
            // Note: We could calculate exact amount using honeyPerLP, but conservative is safer
            uint256 expectedReturn = needed;
            
            // Apply 2% slippage tolerance (hardcoded for Senior - 9800/10000)
            minExpected = (expectedReturn * 9800) / 10000;
            
            return minExpected;
        } catch {
            // If query fails, return 0 to disable check
            return 0;
        }
    }
    
    /**
     * @notice Ensures sufficient liquidity by freeing LP tokens if needed
     * @dev DRY Refactor: Extracted from multiple withdraw functions to eliminate code duplication
     * @dev Iteratively liquidates LP tokens up to 3 times with slippage protection
     * @param amountNeeded Amount of stablecoin needed
     * @return totalFreed Total amount of stablecoin freed from LP liquidation
     */
    function _ensureLiquidityAvailable(uint256 amountNeeded) internal returns (uint256 totalFreed) {
        uint256 maxAttempts = 3;
        totalFreed = 0;
        
        for (uint256 i = 0; i < maxAttempts; i++) {
            uint256 vaultBalance = _stablecoin.balanceOf(address(this));
            
            // Check if we have enough liquidity
            if (vaultBalance >= amountNeeded) {
                break;
            }
            
            // Ensure hook is set
            if (address(kodiakHook) == address(0)) {
                revert InsufficientLiquidity();
            }
            
            // Calculate deficit
            uint256 needed = amountNeeded - vaultBalance;
            uint256 balanceBefore = vaultBalance;
            
            // VN003 FIX: Calculate minimum expected amount with slippage tolerance
            uint256 minExpected = _calculateMinExpectedFromLP(needed);
            
            // Attempt to liquidate LP tokens
            try kodiakHook.liquidateLPForAmount(needed) {
                uint256 balanceAfter = _stablecoin.balanceOf(address(this));
                uint256 freedThisRound = balanceAfter > balanceBefore ? balanceAfter - balanceBefore : 0;
                totalFreed += freedThisRound;
                
                // VN003 FIX: Slippage protection
                if (minExpected > 0 && freedThisRound < minExpected) {
                    revert SlippageTooHigh();
                }
                
                emit LPLiquidationExecuted(needed, freedThisRound, minExpected);
                
                // Stop if no progress
                if (freedThisRound == 0) {
                    break;
                }
            } catch {
                // Stop on liquidation failure
                break;
            }
        }
        
        // Final liquidity check
        uint256 finalBalance = _stablecoin.balanceOf(address(this));
        if (finalBalance < amountNeeded) {
            revert InsufficientLiquidity();
        }
        
        // Emit summary event if liquidity was freed
        if (totalFreed > 0) {
            emit LiquidityFreedForWithdrawal(amountNeeded, totalFreed);
        }
    }
    
    /**
     * @notice Withdraw stablecoin by burning snrUSD
     * @dev VN003 FIX: Added slippage protection when liquidating LP tokens
     * @param amount Amount of snrUSD to burn
     * @param receiver Address to receive stablecoin tokens
     * @param owner Owner of snrUSD
     * @return assets Amount of stablecoin tokens withdrawn (after penalty + 1% withdrawal fee)
     */
    function withdraw(uint256 amount, address receiver, address owner) public virtual whenNotPausedOrAdmin nonReentrant returns (uint256 assets) {
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
        
        // Calculate early withdrawal penalty (20% if cooldown not met)
        (uint256 earlyPenalty, uint256 amountAfterEarlyPenalty) = calculateWithdrawalPenalty(owner, amount);
        
        // Calculate 1% withdrawal fee (applied to amount after early penalty)
        uint256 withdrawalFee = (amountAfterEarlyPenalty * MathLib.WITHDRAWAL_FEE) / MathLib.PRECISION;
        uint256 netAssets = amountAfterEarlyPenalty - withdrawalFee;
        
        // Total needed = netAssets + withdrawalFee (we need enough for both receiver and treasury)
        uint256 totalNeeded = amountAfterEarlyPenalty;
        
        // ============================================
        // EFFECTS - All state changes BEFORE external calls (CEI Pattern)
        // ============================================
        
        // Burn snrUSD first
        _burn(owner, amount);
        
        // Update vault value
        _vaultValue -= amountAfterEarlyPenalty;
        
        // Reset cooldown
        if (_cooldownStart[owner] != 0) {
            _cooldownStart[owner] = 0;
        }
        
        // ============================================
        // INTERACTIONS - External calls LAST
        // ============================================
        
        // Ensure sufficient liquidity (may call kodiakHook.liquidateLPForAmount)
        _ensureLiquidityAvailable(totalNeeded);
        
        // Transfer net amount to receiver (after both early penalty and withdrawal fee)
        _stablecoin.safeTransfer(receiver, netAssets);
        
        // Transfer withdrawal fee to treasury
        if (_treasury != address(0) && withdrawalFee > 0) {
            _stablecoin.safeTransfer(_treasury, withdrawalFee);
            emit WithdrawalFeeCharged(owner, withdrawalFee, netAssets);
        }
        
        if (earlyPenalty > 0) {
            emit WithdrawalPenaltyCharged(owner, earlyPenalty);
        }
        
        emit Withdraw(owner, netAssets, amount);
        
        return netAssets;
    }
    
    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        // N6 FIX: Return actual shares that would be minted (accounting for rebase index)
        // Even though snrUSD displays 1:1 balance, internally it's stored as shares
        return MathLib.calculateSharesFromBalance(assets, _rebaseIndex);
    }
    
    function previewWithdraw(uint256 amount) public view virtual returns (uint256) {
        // Calculate early withdrawal penalty first
        (, uint256 amountAfterEarlyPenalty) = calculateWithdrawalPenalty(msg.sender, amount);
        
        // Calculate 1% withdrawal fee on the amount after early penalty
        uint256 withdrawalFee = (amountAfterEarlyPenalty * MathLib.WITHDRAWAL_FEE) / MathLib.PRECISION;
        uint256 netAssets = amountAfterEarlyPenalty - withdrawalFee;
        
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
        return _minRebaseInterval;
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
    
    /**
     * @notice Simulate rebase without executing
     * @dev Reference: Rebase Algorithm - for off-chain analysis
     * TIME-BASED FIX: Now simulates with actual time elapsed and management fees
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
        
        // Calculate time elapsed and management fee (same as real rebase)
        uint256 timeElapsed = block.timestamp - _lastRebaseTime;
        uint256 mgmtFeeTokens = FeeLib.calculateManagementFeeTokens(_vaultValue, timeElapsed);
        
        // TIME-BASED FIX: Pass timeElapsed and mgmtFeeTokens
        selection = RebaseLib.selectDynamicAPY(currentSupply, _vaultValue, timeElapsed, mgmtFeeTokens);
        newBackingRatio = MathLib.calculateBackingRatio(_vaultValue, selection.newSupply);
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
    function _authorizeUpgrade(address newImplementation) internal override onlyContractUpdater {
        // Admin authorization check via modifier
    }
    
    /**
     * @notice Emergency withdraw stablecoin tokens to treasury
     * @dev Can only be called by admin when paused, for emergency situations
     * @param amount Amount of stablecoin tokens to withdraw
     */
    function emergencyWithdraw(uint256 amount) external onlyAdmin {
        if (!paused()) revert("Must be paused");
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
    
    /**
     * @notice Normalize token amount to target decimals (Q5 FIX)
     * @dev Handles tokens with different decimals (WBTC=8, USDC=6, LP=18, etc.)
     * @param amount Amount in source decimals
     * @param fromDecimals Source token decimals
     * @param toDecimals Target decimals
     * @return Normalized amount in target decimals
     */
    function _normalizeToDecimals(
        uint256 amount,
        uint8 fromDecimals,
        uint8 toDecimals
    ) internal pure returns (uint256) {
        if (fromDecimals == toDecimals) {
            return amount;
        } else if (fromDecimals < toDecimals) {
            // Scale up: amount * 10^(toDecimals - fromDecimals)
            return amount * (10 ** (toDecimals - fromDecimals));
        } else {
            // Scale down: amount / 10^(fromDecimals - toDecimals)
            return amount / (10 ** (fromDecimals - toDecimals));
        }
    }
}

