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
import {IRewardVault} from "../integrations/IRewardVault.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

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
        
        _stablecoin = IERC20(stablecoin_);
        _seniorVault = seniorVault_; // Can be placeholder initially
        _vaultValue = initialValue_;
        _lastUpdateTime = block.timestamp;
        
        // Initialize management fee minting variables
        _lastMintTime = block.timestamp;
        _mgmtFeeSchedule = 30 days; // Default: 30 days
    }
    

    /// @dev Whitelist actions
    enum WhitelistAction { ADD_LP, REMOVE_LP, ADD_LP_TOKEN, REMOVE_LP_TOKEN }
    
    /// @notice Consolidated whitelist management
    function executeWhitelistAction(WhitelistAction action, address target) external onlyAdmin {
        if (target == address(0)) revert AdminControlled.ZeroAddress();
        if (action == WhitelistAction.ADD_LP) {
            if (_isWhitelistedLP[target]) revert LPAlreadyWhitelisted();
            _whitelistedLPs.push(target); _isWhitelistedLP[target] = true; emit WhitelistedLPAdded(target);
        } else if (action == WhitelistAction.REMOVE_LP) {
            if (!_isWhitelistedLP[target]) revert WhitelistedLPNotFound();
            _removeFromWhitelist(target, false); emit WhitelistedLPRemoved(target);
        } else if (action == WhitelistAction.ADD_LP_TOKEN) {
            if (_isWhitelistedLPToken[target]) revert LPAlreadyWhitelisted();
            _whitelistedLPTokens.push(target); _isWhitelistedLPToken[target] = true; emit WhitelistedLPTokenAdded(target);
        } else if (action == WhitelistAction.REMOVE_LP_TOKEN) {
            if (!_isWhitelistedLPToken[target]) revert WhitelistedLPNotFound();
            _removeFromWhitelist(target, true); emit WhitelistedLPTokenRemoved(target);
        }
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
    
    /**
     * @notice Transfer stablecoins from vault to whitelisted LP
     * @dev Only admin can invest, LP must be whitelisted
     * @param lp Address of the whitelisted LP to transfer to
     * @param amount Amount of stablecoins to transfer
     */
    function investInLP(address lp, uint256 amount) external onlyLiquidityManager nonReentrant {
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
    function withdrawLPTokens(address lpToken, address lp, uint256 amount) external onlyLiquidityManager nonReentrant {
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
                _removeFromWhitelist(address(kodiakHook), false);
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
    
    /// @notice Consolidated deploy to Kodiak (amount=0 means sweep all)
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
        nonReentrant
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
        nonReentrant
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
    
    /// @dev Actions for vault value updates
    enum VaultValueAction { UPDATE_BY_BPS, SET_ABSOLUTE }
    
    /// @notice Consolidated vault value update (by BPS or absolute)
    function executeVaultValueAction(VaultValueAction action, int256 value) public virtual onlyPriceFeedManager {
        uint256 oldValue = _vaultValue;
        int256 bps = 0;
        if (action == VaultValueAction.UPDATE_BY_BPS) {
            if (value < MIN_PROFIT_BPS || value > MAX_PROFIT_BPS) revert InvalidProfitRange();
            _vaultValue = MathLib.applyPercentage(oldValue, value);
            bps = value;
        } else {
            if (value < 0) revert InvalidAmount();
            _vaultValue = uint256(value);
            if (oldValue > 0) bps = int256((_vaultValue * 10000) / oldValue) - 10000;
        }
        _lastUpdateTime = block.timestamp;
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
    ) external onlySeeder nonReentrant {
        // Validation
        if (lpToken == address(0)) revert AdminControlled.ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (lpPrice == 0) revert InvalidLPPrice();
        if (address(kodiakHook) == address(0)) revert KodiakHookNotSet();
          if (lpToken != address(kodiakHook.island())) revert InvalidLPToken();
        
        // Step 1: Transfer LP tokens from caller (seeder) to vault
        IERC20(lpToken).safeTransferFrom(msg.sender, address(kodiakHook), amount);
        
        // Step 3: Calculate value = amount * lpPrice / 1e18
        // Q5 FIX: Account for LP token decimals
        // lpPrice is in 18 decimals, representing how much stablecoin per LP token
        uint8 lpDecimals = IERC20Metadata(lpToken).decimals();
        uint256 normalizedAmount = MathLib.normalizeDecimals(amount, lpDecimals, 18);
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
    
    /// @dev Get LP conversion data for USD amount
    function _getLpConversionData(uint256 usdAmt) internal view returns (uint256 lpTokens, uint256 lpValUsd, uint256 stableInPool, uint256 lpSupply) {
        if (address(kodiakHook) == address(0)) return (0, 0, 0, 0);
        try kodiakHook.island() returns (IKodiakIsland island) {
            if (address(island) == address(0)) return (0, 0, 0, 0);
            (, stableInPool) = island.getUnderlyingBalances();
            lpSupply = island.totalSupply();
            if (lpSupply == 0 || stableInPool == 0) return (0, 0, 0, 0);
            lpValUsd = Math.mulDiv(kodiakHook.getIslandLPBalance(), stableInPool, lpSupply);
            lpTokens = Math.mulDiv(usdAmt, lpSupply, stableInPool) * 102 / 100;
        } catch { return (0, 0, 0, 0); }
    }
    
    /// @notice Ensures liquidity by freeing LP if needed (up to 3 attempts)
    function _ensureLiquidityAvailable(uint256 amountNeeded) internal returns (uint256 totalFreed) {
        for (uint256 i = 0; i < 3; i++) {
            uint256 bal = _stablecoin.balanceOf(address(this));
            if (bal >= amountNeeded) break;
            if (address(kodiakHook) == address(0)) revert KodiakHookNotSet();
            
            uint256 needed = amountNeeded - bal;
            uint256 minExp = _calculateMinExpectedFromLP(needed);
            
            (uint256 lpNeeded, uint256 lpVal, uint256 stablePool, uint256 lpSupply) = _getLpConversionData(needed);
            if (lpVal < needed && lpNeeded > 0 && stablePool > 0 && lpSupply > 0) {
                uint256 lpToGet = Math.mulDiv(needed - lpVal, lpSupply, stablePool) * 102 / 100;
                IRewardVault rv = _getRewardVault();
                if (address(rv) != address(0)) {
                    uint256 staked = rv.getTotalDelegateStaked(admin());
                    uint256 toWithdraw = lpToGet > staked ? staked : lpToGet;
                    if (toWithdraw > 0) { rv.delegateWithdraw(admin(), toWithdraw); IERC20(address(kodiakHook.island())).transfer(address(kodiakHook), toWithdraw); }
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
        
        // Ensure sufficient liquidity (DRY: using extracted helper)
        _ensureLiquidityAvailable(assets);
        
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
    
    function _afterValueUpdate(uint256 oldValue, uint256 newValue) internal virtual { }
}
