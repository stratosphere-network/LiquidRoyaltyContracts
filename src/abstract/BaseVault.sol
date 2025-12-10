// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IVault} from "../interfaces/IVault.sol";
import {MathLib} from "../libraries/MathLib.sol";
import {AdminControlled} from "./AdminControlled.sol";
import {IKodiakVaultHook} from "../integrations/IKodiakVaultHook.sol";
import {IKodiakIslandRouter} from "../integrations/IKodiakIslandRouter.sol";
import {IKodiakIsland} from "../integrations/IKodiakIsland.sol";

/**
 * @title BaseVault
 * @notice Abstract ERC4626 vault with Stablecoin value tracking
 * @dev Inherited by Junior and Reserve vaults (standard ERC4626)
 * @dev Upgradeable using UUPS proxy pattern
 *
 * References from Mathematical Specification:
 * - Section: Notation & Definitions (State Variables)
 
 */
abstract contract BaseVault is ERC4626Upgradeable, IVault, AdminControlled, UUPSUpgradeable {
    using MathLib for uint256;
    using SafeERC20 for IERC20;
    
    /// @dev Reentrancy guard
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;
    
    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
    
    /// @dev Struct for LP holdings data
    struct LPHolding {
        address lpToken;
        uint256 amount;
    }
    
    /// @dev State Variables
    /// Reference: State Variables (V_s, V_j, V_r)
    uint256 internal _vaultValue;           // Current USD value of vault assets
    uint256 internal _lastUpdateTime;       // Last value update timestamp (T_r)
    
    /// @dev Stablecoin held by vault (the "asset" in ERC4626 terms)
    IERC20 internal _stablecoin;
    
    /// @dev Whitelisted  (Liquidity Pools/Protocols/Kodiak Islands)
    address[] internal _whitelistedLPs;
    mapping(address => bool) internal _isWhitelistedLP;
    
    /// @dev Whitelisted LP Tokens (ERC20 tokens received from LPs/Kodiak Islands)
    address[] internal _whitelistedLPTokens;
    mapping(address => bool) internal _isWhitelistedLPToken;
    
    /// @dev Senior vault address )
    address internal _seniorVault;
    
    /// @dev Kodiak integration
    IKodiakVaultHook public kodiakHook;
    
    /// @dev Treasury address for fees
    address internal _treasury;
    
    /// @dev Management fee minting for Junior/Reserve vaults
    uint256 internal _lastMintTime;        // Last time management fee was minted
    uint256 internal _mgmtFeeSchedule;     // Time interval between mints (e.g., 7 days, 30 days)
    
    /// @dev Constants
    int256 internal constant MIN_PROFIT_BPS = -5000;  // -50% minimum
    int256 internal constant MAX_PROFIT_BPS = 10000;  // +100% maximum
    
    /// @dev Slippage protection (hardcoded to avoid storage changes)
    uint256 internal constant LP_LIQUIDATION_SLIPPAGE_BPS = 200;  // 2% slippage tolerance
    
    /// @dev Events
    event WhitelistedLPAdded(address indexed lp);
    event WhitelistedLPRemoved(address indexed lp);
    event WhitelistedLPTokenAdded(address indexed lpToken);
    event WhitelistedLPTokenRemoved(address indexed lpToken);
    event LPInvestment(address indexed lp, uint256 amount);
    event LPTokensWithdrawn(address indexed lpToken, address indexed lp, uint256 amount);
    event KodiakDeployment(uint256 amount, uint256 lpReceived, uint256 timestamp);
    event LiquidityFreedForWithdrawal(uint256 requested, uint256 freedFromLP);
    event VaultSeeded(
        address indexed lpToken,
        address indexed seedProvider,
        uint256 lpAmount,
        uint256 lpPrice,
        uint256 valueAdded,
        uint256 sharesMinted
    );
    event WithdrawalFeeCharged(address indexed user, uint256 fee, uint256 netAmount);
    event ManagementFeeMinted(address indexed treasury, uint256 amount, uint256 timestamp);
    event MgmtFeeScheduleUpdated(uint256 oldSchedule, uint256 newSchedule);
    event SeniorVaultUpdated(address indexed newSeniorVault);
    event KodiakHookUpdated(address indexed newHook);
    event ReserveSeededWithToken(
        address indexed token,
        address indexed seedProvider,
        uint256 tokenAmount,
        uint256 tokenPrice,
        uint256 valueAdded,
        uint256 sharesMinted
    );
    event KodiakInvestment(
        address indexed island,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 lpMinted,
        uint256 timestamp
    );
    event StablecoinSwappedToToken(
        address indexed stablecoin,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 timestamp
    );
    event HookTokenSwappedToStablecoin(
        address indexed tokenIn,
        uint256 amountIn,
        uint256 stablecoinOut,
        uint256 timestamp
    );
    event TokenRescuedFromHook(
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );
    event LPExitedToToken(
        uint256 lpAmount,
        address indexed tokenOut,
        uint256 tokenReceived,
        uint256 timestamp
    );
    event LPLiquidationExecuted(uint256 requested, uint256 received, uint256 minExpected);
    
    /// @dev Errors (ZeroAddress inherited from AdminControlled, InvalidAmount inherited from IVault)
    error InvalidProfitRange();
    error OnlySeniorVault();
    error WhitelistedLPNotFound();
    error LPAlreadyWhitelisted();
    error KodiakHookNotSet();
    error SlippageTooHigh();
    error WrongVault();
    error InsufficientLiquidity();
    error InvalidLPPrice();
    error FeeScheduleNotMet();
    error InvalidSchedule();
    error ScheduleTooShort();
    error KodiakRouterNotSet();
    error InvalidTokenPrice();
    error IdleBalanceDeviation();
    error InvalidLPToken();
    error InvalidStablecoinDecimals();
    
    /// @dev Modifiers
    modifier onlySeniorVault() {
        if (msg.sender != _seniorVault) revert OnlySeniorVault();
        _;
    }
    
    /**
     * @notice Initialize base vault (replaces constructor for upgradeable)
     * @param stablecoin_ Stablecoin address (the asset)
     * @param vaultName_ ERC20 name for vault shares
     * @param vaultSymbol_ ERC20 symbol for vault shares
     * @param seniorVault_ Senior vault address (can be placeholder)
     * @param initialValue_ Initial vault value
     */
    function __BaseVault_init(
        address stablecoin_,
        string memory vaultName_,
        string memory vaultSymbol_,
        address seniorVault_,
        uint256 initialValue_
    ) internal onlyInitializing {
        if (stablecoin_ == address(0)) revert AdminControlled.ZeroAddress();
        

        if (IERC20Metadata(stablecoin_).decimals() != 18) revert InvalidStablecoinDecimals();
        
        __ERC20_init(vaultName_, vaultSymbol_);
        __ERC4626_init(IERC20(stablecoin_));
        __AdminControlled_init();
        _status = _NOT_ENTERED;
        
        _stablecoin = IERC20(stablecoin_);
        _seniorVault = seniorVault_; // Can be placeholder initially
        _vaultValue = initialValue_;
        _lastUpdateTime = block.timestamp;
        
        // Initialize management fee minting variables
        _lastMintTime = block.timestamp;
        _mgmtFeeSchedule = 30 days; // Default: 30 days
    }
    

    /**
     * @notice Add LP pool/protocol/Kodiak Island to whitelist
     * @dev Only admin can whitelist Liquidity Pools/Protocols/Kodiak Islands
     * @param lp Address of Liquidity Pool/Protocol/Kodiak Island to whitelist
     */
    function addWhitelistedLP(address lp) external onlyAdmin {
        if (lp == address(0)) revert AdminControlled.ZeroAddress();
        if (_isWhitelistedLP[lp]) revert LPAlreadyWhitelisted();
         
        _whitelistedLPs.push(lp);
        _isWhitelistedLP[lp] = true;
        
        emit WhitelistedLPAdded(lp);
    }

    /**
     * @notice Remove LP pool/protocol/Kodiak Island from whitelist
     * @dev Only admin can remove Liquidity Pools/Protocols/Kodiak Islands
     * @param lp Address of Liquidity Pool/Protocol/Kodiak Island to remove
     */
    function removeWhitelistedLP(address lp) external onlyAdmin {
        if (lp == address(0)) revert AdminControlled.ZeroAddress();
        if (!_isWhitelistedLP[lp]) revert WhitelistedLPNotFound();
        
        _removeWhitelistedLPInternal(lp);
        
        emit WhitelistedLPRemoved(lp);
    }
    
    /**
     * @dev Internal helper to remove LP from whitelist
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
     * @notice Check if LP pool/protocol/Kodiak Island is whitelisted
     * @param lp Address to check
     * @return isWhitelisted True if LP pool/protocol/Kodiak Island  is whitelisted
     */
    function isWhitelistedLP(address lp) external view returns (bool) {
        return _isWhitelistedLP[lp];
    }
    
    /**
     * @notice Get all whitelisted LP pools/protocols/Kodiak Islands
     * @return lps Array of whitelisted LP pools/protocols/Kodiak Islands addresses
     */
    function getWhitelistedLPs() external view returns (address[] memory) {
        return _whitelistedLPs;
    }

    /**
     * @notice Add LP token to whitelist
     * @dev Only admin can whitelist LPs
     * @param lpToken Address to whitelist
     */
    function addWhitelistedLPToken(address lpToken) external onlyAdmin {
        if (lpToken == address(0)) revert AdminControlled.ZeroAddress();
        if (_isWhitelistedLPToken[lpToken]) revert LPAlreadyWhitelisted();
        
        _whitelistedLPTokens.push(lpToken);
        _isWhitelistedLPToken[lpToken] = true;
        
        emit WhitelistedLPTokenAdded(lpToken);
    }

    /**
     * @notice Remove LPToken from whitelist
     * @dev Only admin can remove LPs
     * @param lpToken Address to remove
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
     * @notice Check if LP is whitelisted
     * @param lpToken Address to check
     * @return isWhitelisted True if LP is whitelisted
     */
    function isWhitelistedLPToken(address lpToken) external view returns (bool) {
        return _isWhitelistedLPToken[lpToken];
    }
    
    /**
     * @notice Get all whitelisted LPs
     * @return lps Array of whitelisted LP addresses
     */
    function getWhitelistedLPTokens() external view returns (address[] memory) {
        return _whitelistedLPTokens;
    }
    
    /**
     * @notice Get vault's LP holdings for all whitelisted LPs
     * @dev Returns array of LP tokens and their balances held by this vault
     * @return holdings Array of LPHolding structs containing LP address and amount
     */
    function getLPHoldings() external view returns (LPHolding[] memory holdings) {
        uint256 lpCount = _whitelistedLPTokens.length;
        holdings = new LPHolding[](lpCount);
        
        for (uint256 i = 0; i < lpCount; i++) {
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
     * @dev Gas-efficient way to check single LP balance
     * @param lpToken Address of the LP token to check
     * @return balance Amount of LP tokens held by this vault
     */
    function getLPBalance(address lpToken) external view returns (uint256) {
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
     * @notice Withdraw LP tokens and send to whitelisted LP address for liquidation. Can possibly be used for offchain automation.
     * @dev Only admin can withdraw, LP must be whitelisted
     * @param lpToken Address of the LP token to withdraw
     * @param lp Address of the whitelisted LP protocol to send tokens to
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
    
    // ============================================
    // Kodiak Integration
    // ============================================
    
    /**
     * @notice Set Kodiak hook address
     * @dev Automatically whitelists the hook as an LP protocol
     * @param hook Address of KodiakVaultHook contract
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
     * @notice Deploy funds to Kodiak with verified swap parameters
     * @dev Admin-only, secure deployment with slippage protection
     * @param amount Amount of stablecoins to deploy
     * @param minLPTokens Minimum LP tokens to receive (slippage protection)
     * @param swapToToken0Aggregator DEX aggregator for token0 swap
     * @param swapToToken0Data Swap calldata for token0
     * @param swapToToken1Aggregator DEX aggregator for token1 swap
     * @param swapToToken1Data Swap calldata for token1
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
     * @notice Update Senior vault address (admin only)
     * @dev Allows admin to set or update Senior vault address
     * @param seniorVault_ Address of Senior vault
     */
    function updateSeniorVault(address seniorVault_) external onlyAdmin {
        if (seniorVault_ == address(0)) revert AdminControlled.ZeroAddress();
        
        _seniorVault = seniorVault_;
        
        emit SeniorVaultUpdated(seniorVault_);
    }
    
    // ============================================
    // IVault Interface Implementation
    // ============================================
    
    /**
     * @notice Get current vault value
     * @dev Returns admin-updated vault value
     * @return value Current vault value in USD (18 decimals)
     */
    function vaultValue() public view virtual returns (uint256 value) {
        return _vaultValue;
    }
    
    /**
     * @notice Get Stablecoin
     * @dev Reference: Instructions - Vault Architecture
     */
    function stablecoin() public view virtual returns (IERC20) {
        return _stablecoin;
    }
    
    /**
     * @notice Get deposit token (same as Stablecoin for ERC4626)
     */
    function depositToken() public view virtual returns (IERC20) {
        return _stablecoin;
    }
    
    /**
     * @notice Get last update time
     * @dev Reference: State Variables (T_r)
     */
    function lastUpdateTime() public view virtual returns (uint256) {
        return _lastUpdateTime;
    }
    
    /**
     * @notice Get Senior vault address
     */
    function seniorVault() public view virtual returns (address) {
        return _seniorVault;
    }
    
    /**
     * @notice Get treasury address
     */
    function treasury() public view virtual returns (address) {
        return _treasury;
    }
    
    /**
     * @notice Set treasury address
     * @dev Only admin can set treasury
     * @param treasury_ New treasury address
     */
    function setTreasury(address treasury_) external onlyAdmin {
        if (treasury_ == address(0)) revert AdminControlled.ZeroAddress();
        _treasury = treasury_;
    }
    
    // ============================================
    // Management Fee Minting (Junior/Reserve)
    // ============================================
    
    /**
     * @notice Mint management fee to treasury (1% of total supply)
     * @dev Only admin can call this. Can only be called after mgmtFeeSchedule has passed
     * 
     * Flow:
     * 1. Check if enough time has passed since last mint
     * 2. Calculate 1% of current total supply
     * 3. Mint to treasury
     * 4. Update last mint time
     */
    function mintManagementFee() external onlyLiquidityManager {
        if (_treasury == address(0)) revert AdminControlled.ZeroAddress();
        
        // Check if enough time has passed
        if (block.timestamp < _lastMintTime + _mgmtFeeSchedule) {
            revert FeeScheduleNotMet();
        }
        
        uint256 currentSupply = totalSupply();
        if (currentSupply == 0) revert InvalidAmount();
        
        // Calculate 1% of total supply
        uint256 feeAmount = (currentSupply * 1e16) / 1e18; // 1% = 0.01 = 1e16/1e18
        
        // Mint to treasury
        _mint(_treasury, feeAmount);
        
        // Update last mint time
        _lastMintTime = block.timestamp;
        
        emit ManagementFeeMinted(_treasury, feeAmount, block.timestamp);
    }
    
    /**
     * @notice Set management fee schedule (time between management fee mints)
     * @dev Only admin can update the schedule
     * @param newSchedule New schedule in seconds (e.g., 7 days, 30 days)
     */
    function setMgmtFeeSchedule(uint256 newSchedule) external onlyLiquidityManager {
        if (newSchedule == 0) revert InvalidSchedule();
        
        // Prevent too-frequent fee minting (minimum 30 days for monthly fee schedule)
        if (newSchedule < 30 days) revert ScheduleTooShort();
        
        uint256 oldSchedule = _mgmtFeeSchedule;
        _mgmtFeeSchedule = newSchedule;
        
        emit MgmtFeeScheduleUpdated(oldSchedule, newSchedule);
    }
    
    /**
     * @notice Get current management fee schedule
     * @return schedule Time in seconds between management fee mints
     */
    function getMgmtFeeSchedule() external view returns (uint256) {
        return _mgmtFeeSchedule;
    }
    
    /**
     * @notice Get last time management fee was minted
     * @return timestamp Last mint timestamp
     */
    function getLastMintTime() external view returns (uint256) {
        return _lastMintTime;
    }
    
    /**
     * @notice Check if management fee can be minted now
     * @return canMint True if enough time has passed
     */
    function canMintManagementFee() external view returns (bool) {
        return block.timestamp >= _lastMintTime + _mgmtFeeSchedule;
    }
    
    /**
     * @notice Get time remaining until next management fee can be minted
     * @return timeRemaining Seconds until next mint (0 if can mint now)
     */
    function getTimeUntilNextMint() external view returns (uint256) {
        uint256 nextMintTime = _lastMintTime + _mgmtFeeSchedule;
        if (block.timestamp >= nextMintTime) {
            return 0;
        }
        return nextMintTime - block.timestamp;
    }
    
    // ============================================
    // ERC4626 Overrides
    // ============================================
    
    /**
     * @notice Total assets in vault (actual Stablecoin balance)
     * @dev ERC4626 requires actual token balance for share calculations
     * _vaultValue tracks USD value, but shares need Stablecoin balance
     */
    function totalAssets() public view virtual override(ERC4626Upgradeable) returns (uint256) {
        return _vaultValue;  // Use internal accounting, not actual balance
    }
    
    /**
     * @notice Deposit Stablecoins and mint shares
     * @dev Override ERC4626 deposit - open to all users
     * @param assets Amount of Stablecoins to deposit
     * @param receiver Address to receive shares
     * @return shares Amount of shares minted
     */
    function deposit(uint256 assets, address receiver) 
        public 
        virtual 
        override(ERC4626Upgradeable) 
        returns (uint256 shares) 
    {
        shares = super.deposit(assets, receiver);
        
        // Track capital inflow: increase vault value by deposited assets
        _vaultValue += assets;
        
        return shares;
    }
    
    /**
     * @notice Mint shares by depositing Stablecoins
     * @dev Override ERC4626 mint - open to all users
     * @param shares Amount of shares to mint
     * @param receiver Address to receive shares
     * @return assets Amount of Stablecoins deposited
     */
    function mint(uint256 shares, address receiver) 
        public 
        virtual 
        override(ERC4626Upgradeable) 
        returns (uint256 assets) 
    {
        assets = super.mint(shares, receiver);
        
        // Track capital inflow: increase vault value by deposited assets
        _vaultValue += assets;
        
        return assets;
    }
    
    // ============================================
    // Keeper Functions
    // ============================================
    
    /**
     * @notice Update vault value based on off-chain profit calculation
     * @dev Reference: Instructions - Monthly Rebase Flow (Step 2)
     * Formula: V_new = V_old × (1 + profitBps / 10000)
     * @param profitBps Profit/loss in basis points
     */
    function updateVaultValue(int256 profitBps) public virtual onlyPriceFeedManager {
        // Validate reasonable range
        if (profitBps < MIN_PROFIT_BPS || profitBps > MAX_PROFIT_BPS) {
            revert InvalidProfitRange();
        }
        
        uint256 oldValue = _vaultValue;
        
        // Apply profit/loss: V_new = V_old × (1 + profitBps / 10000)
        _vaultValue = MathLib.applyPercentage(oldValue, profitBps);
        _lastUpdateTime = block.timestamp;
        // Hook for derived contracts to execute post-update logic
        _afterValueUpdate(oldValue, _vaultValue);
         emit VaultValueUpdated(oldValue, _vaultValue, profitBps);
    }

    /**
     * @notice Directly set vault value (no BPS calculation)
     * @dev Simple admin function to set exact vault value
     * @param newValue New vault value in wei
     */
    function setVaultValue(uint256 newValue) public virtual onlyPriceFeedManager {
        // Allow 0 to enable truly empty vault state for first deposit
        uint256 oldValue = _vaultValue;
        _vaultValue = newValue;
        _lastUpdateTime = block.timestamp;
        
        // Calculate BPS for event logging
        int256 bps = 0;
        if (oldValue > 0) {
            // PRECISION FIX: Avoid potential overflow/underflow by careful ordering
            bps = int256((newValue * 10000) / oldValue) - 10000;
        }
        
        // Hook for derived contracts to execute post-update logic
        _afterValueUpdate(oldValue, _vaultValue);

          emit VaultValueUpdated(oldValue, _vaultValue, bps);
    }
    
    /**
     * @notice Seed vault with LP tokens from caller
     * @dev Seeder function to bootstrap vault with LP positions (caller must have seeder role)
     * @param lpToken Address of the LP token to seed
     * @param amount Amount of LP tokens to seed
     * @param lpPrice Price of LP token in stablecoin terms (18 decimals)
     * 
     * Flow:
     * 1. Transfer LP tokens from caller to vault (requires approval)
     * 2. Transfer LP tokens from vault to hook
     * 3. Calculate value = amount * lpPrice
     * 4. Mint shares to caller (1:1 for senior, share-price-based for junior/reserve)
     * 5. Update vault value to include new LP value
     * 6. Emit VaultSeeded event
     */

    function seedVault(
        address lpToken,
        uint256 amount,
        uint256 lpPrice
    ) external onlySeeder {
        // Validation
        if (lpToken == address(0)) revert AdminControlled.ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (lpPrice == 0) revert InvalidLPPrice();
        if (address(kodiakHook) == address(0)) revert KodiakHookNotSet();
          if (lpToken != address(kodiakHook.island())) revert InvalidLPToken();
        
        // Step 1: Transfer LP tokens from caller (seeder) to vault
        IERC20(lpToken).safeTransferFrom(msg.sender, address(this), amount);
        
        // Step 2: Transfer LP tokens from vault to hook
        IERC20(lpToken).safeTransfer(address(kodiakHook), amount);
        
        // Step 3: Calculate value = amount * lpPrice / 1e18
        // Q5 FIX: Account for LP token decimals
        // lpPrice is in 18 decimals, representing how much stablecoin per LP token
        uint8 lpDecimals = IERC20Metadata(lpToken).decimals();
        uint256 normalizedAmount = _normalizeToDecimals(amount, lpDecimals, 18);
        uint256 valueAdded = (normalizedAmount * lpPrice) / 1e18;
        
        // Step 4: Mint shares to caller (seeder)
        // N1-1 FIX: Use ERC4626 standard previewDeposit() for share calculation
        // This ensures consistency with normal deposit flow and reduces code duplication
        uint256 sharesToMint = previewDeposit(valueAdded);
        
        // Mint shares directly (bypass normal deposit flow)
        _mint(msg.sender, sharesToMint);
        
        // Step 5: Update vault value to include new LP value
        _vaultValue += valueAdded;
        _lastUpdateTime = block.timestamp;
        
        // Step 6: Emit event
        emit VaultSeeded(lpToken, msg.sender, amount, lpPrice, valueAdded, sharesToMint);
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

    // ============================================
    // Burn Functions
    // ============================================
    
    /**
     * @notice Admin function to burn tokens from any address
     * @param account Account to burn tokens from
     * @param amount Amount of tokens to burn
     * @dev Q2 FIX: Only admin can burn (emergency use only)
     * @dev Removed user burn functions (burn/burnFrom) to prevent accidental value loss
     * @dev Users should use withdraw() or redeem() to get their assets back, not burn
     * @dev Burning tokens increases share price for remaining holders (acts as donation)
     */
    function adminBurn(address account, uint256 amount) public virtual onlyAdmin {
        _burn(account, amount);
    }

    // ============================================
    // ERC4626 Internal Overrides
    // ============================================
    
    /**
     * @notice Calculate minimum expected amount from LP liquidation with slippage tolerance
     * @dev VN003 FIX: Queries Kodiak Island pool to calculate expected return and applies slippage tolerance
     * @param needed Amount of stablecoin needed
     * @return minExpected Minimum acceptable amount after applying slippage tolerance
     */
    function _calculateMinExpectedFromLP(uint256 needed) internal view virtual returns (uint256 minExpected) {
        if (address(kodiakHook) == address(0)) return 0;
        
        try kodiakHook.island() returns (IKodiakIsland island) {
            if (address(island) == address(0)) return 0;
            
            // Query pool reserves
            (, uint256 stablecoinInPool) = island.getUnderlyingBalances();
            uint256 totalLP = island.totalSupply();
            
            if (totalLP == 0 || stablecoinInPool == 0) return 0;
            
            // Calculate expected return (conservative: assume 1:1 on needed amount)
            // Note: We could calculate exact amount using stablecoinPerLP, but conservative is safer
            uint256 expectedReturn = needed;
            
            // Apply hardcoded 2% slippage tolerance (9800/10000)
            // VN003: Hardcoded to avoid storage slot changes in upgradeable contract
            minExpected = (expectedReturn * (10000 - LP_LIQUIDATION_SLIPPAGE_BPS)) / 10000;
            
            return minExpected;
        } catch {
            // If query fails, return 0 to disable check
            return 0;
        }
    }
    
    /**
     * @notice Override ERC4626 internal withdraw to ensure liquidity and charge 1% withdrawal fee
     * @dev Automatically frees up liquidity from Kodiak LP if needed using iterative approach
     * @dev VN003 FIX: Added slippage protection when liquidating LP tokens
     * @dev REENTRANCY FIX: Protected with nonReentrant modifier
     * @param caller Address calling the withdrawal
     * @param receiver Address receiving the assets
     * @param owner Owner of the shares
     * @param assets Amount of assets to withdraw (BEFORE fee)
     * @param shares Amount of shares to burn
     */
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override nonReentrant {
       
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }
        
        // Calculate 1% withdrawal fee
        uint256 withdrawalFee = (assets * MathLib.WITHDRAWAL_FEE) / MathLib.PRECISION;
        uint256 netAssets = assets - withdrawalFee;
        
        // Iterative approach: Try up to 3 times to free up liquidity
        uint256 maxAttempts = 3;
        uint256 totalFreed = 0;
        
        for (uint256 i = 0; i < maxAttempts; i++) {
            uint256 vaultBalance = _stablecoin.balanceOf(address(this));
            
            if (vaultBalance >= assets) {
                break; // We have enough!
            }
            
            if (address(kodiakHook) == address(0)) {
                revert KodiakHookNotSet();
            }
            
            // Calculate how much more we need
            uint256 needed = assets - vaultBalance;
            uint256 balanceBefore = vaultBalance;
            
            // VN003 FIX: Calculate minimum expected amount with slippage tolerance
            uint256 minExpected = _calculateMinExpectedFromLP(needed);
            
            // Call hook to liquidate LP with smart estimation
            try kodiakHook.liquidateLPForAmount(needed) {
                uint256 balanceAfter = _stablecoin.balanceOf(address(this));
                uint256 freedThisRound = balanceAfter > balanceBefore ? balanceAfter - balanceBefore : 0;
                totalFreed += freedThisRound;
                
                // VN003 FIX: Check slippage protection (only if minExpected > 0)
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
        uint256 finalBalance = _stablecoin.balanceOf(address(this));
        if (finalBalance < assets) {
            revert InsufficientLiquidity();
        }
        
        // Emit event if we had to free up liquidity
        if (totalFreed > 0) {
            emit LiquidityFreedForWithdrawal(assets, totalFreed);
        }
        
        // REENTRANCY FIX: Effects before Interactions
        // Burn shares and update state BEFORE external transfers
        _burn(owner, shares);
        _vaultValue -= assets;
        
        // Interactions: Transfer assets (after state changes)
        _stablecoin.safeTransfer(receiver, netAssets);
        
        // Transfer fee to treasury (if treasury is set)
        if (_treasury != address(0) && withdrawalFee > 0) {
            _stablecoin.safeTransfer(_treasury, withdrawalFee);
            emit WithdrawalFeeCharged(owner, withdrawalFee, netAssets);
        }
        
        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    // ============================================
    // Internal Hooks
    // ============================================
    
    /**
     * @notice Hook called after vault value update
     * @dev Override in derived contracts for custom logic
     */
    function _afterValueUpdate(uint256 oldValue, uint256 newValue) internal virtual {
        // Default: do nothing
        // Override in Senior vault to trigger rebase
    }
    
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
    ) internal pure virtual returns (uint256) {
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
