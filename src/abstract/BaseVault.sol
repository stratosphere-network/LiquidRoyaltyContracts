// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IVault} from "../interfaces/IVault.sol";
import {MathLib} from "../libraries/MathLib.sol";
import {AdminControlled} from "./AdminControlled.sol";

/**
 * @title BaseVault
 * @notice Abstract ERC4626 vault with Stablecoin value tracking
 * @dev Inherited by Junior and Reserve vaults (standard ERC4626)
 * @dev Upgradeable using UUPS proxy pattern
 *
 * References from Mathematical Specification:
 * - Section: Notation & Definitions (State Variables)
 * - Instructions: Vault Architecture (Stablecoin Holdings)
 */
abstract contract BaseVault is ERC4626Upgradeable, IVault, AdminControlled, UUPSUpgradeable {
    using MathLib for uint256;
    
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
    
    /// @dev Whitelisted LPs (Liquidity Providers/Protocols)
    address[] internal _whitelistedLPs;
    mapping(address => bool) internal _isWhitelistedLP;
    
    /// @dev Whitelisted LP Tokens (ERC20 tokens received from LPs)
    address[] internal _whitelistedLPTokens;
    mapping(address => bool) internal _isWhitelistedLPToken;
    
    /// @dev Senior vault address (for circular dependency fix)
    address internal _seniorVault;
    
    /// @dev Whitelisted depositors
    mapping(address => bool) internal _whitelistedDepositors;
    
    /// @dev Constants
    int256 internal constant MIN_PROFIT_BPS = -5000;  // -50% minimum
    int256 internal constant MAX_PROFIT_BPS = 10000;  // +100% maximum
    
    /// @dev Events
    event DepositorWhitelisted(address indexed depositor);
    event DepositorRemoved(address indexed depositor);
    event WhitelistedLPAdded(address indexed lp);
    event WhitelistedLPRemoved(address indexed lp);
    event WhitelistedLPTokenAdded(address indexed lpToken);
    event WhitelistedLPTokenRemoved(address indexed lpToken);
    event LPInvestment(address indexed lp, uint256 amount);
    event LPTokensWithdrawn(address indexed lpToken, address indexed lp, uint256 amount);
    
    /// @dev Errors (ZeroAddress inherited from AdminControlled)
    error InvalidProfitRange();
    error SeniorVaultAlreadySet();
    error OnlySeniorVault();
    error OnlyWhitelistedDepositor();
    error WhitelistedLPNotFound();
    error LPAlreadyWhitelisted();
    
    /// @dev Modifiers
    modifier onlySeniorVault() {
        if (msg.sender != _seniorVault) revert OnlySeniorVault();
        _;
    }
    
    modifier onlyWhitelisted() {
        if (!_whitelistedDepositors[msg.sender]) revert OnlyWhitelistedDepositor();
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
        
        __ERC20_init(vaultName_, vaultSymbol_);
        __ERC4626_init(IERC20(stablecoin_));
        __AdminControlled_init();
        
        _stablecoin = IERC20(stablecoin_);
        _seniorVault = seniorVault_; // Can be placeholder initially
        _vaultValue = initialValue_;
        _lastUpdateTime = block.timestamp;
    }
    

    /**
     * @notice Add LP protocol to whitelist
     * @dev Only admin can whitelist LP protocols
     * @param lp Address of LP protocol to whitelist
     */
    function addWhitelistedLP(address lp) external onlyAdmin {
        if (lp == address(0)) revert AdminControlled.ZeroAddress();
        if (_isWhitelistedLP[lp]) revert LPAlreadyWhitelisted();
        
        _whitelistedLPs.push(lp);
        _isWhitelistedLP[lp] = true;
        
        emit WhitelistedLPAdded(lp);
    }

    /**
     * @notice Remove LP protocol from whitelist
     * @dev Only admin can remove LP protocols
     * @param lp Address of LP protocol to remove
     */
    function removeWhitelistedLP(address lp) external onlyAdmin {
        if (lp == address(0)) revert AdminControlled.ZeroAddress();
        if (!_isWhitelistedLP[lp]) revert WhitelistedLPNotFound();
        
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
        
        emit WhitelistedLPRemoved(lp);
    }
    
    /**
     * @notice Check if LP protocol is whitelisted
     * @param lp Address to check
     * @return isWhitelisted True if LP protocol is whitelisted
     */
    function isWhitelistedLP(address lp) external view returns (bool) {
        return _isWhitelistedLP[lp];
    }
    
    /**
     * @notice Get all whitelisted LP protocols
     * @return lps Array of whitelisted LP protocol addresses
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
        
        emit WhitelistedLPTokenRemoved(lpToken);
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
    function investInLP(address lp, uint256 amount) external onlyAdmin {
        if (lp == address(0)) revert AdminControlled.ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (!_isWhitelistedLP[lp]) revert WhitelistedLPNotFound();
        
        // Check vault has sufficient stablecoin balance
        uint256 vaultBalance = _stablecoin.balanceOf(address(this));
        if (vaultBalance < amount) revert InsufficientBalance();
        
        // Transfer stablecoins from vault to LP
        _stablecoin.transfer(lp, amount);
        
        emit LPInvestment(lp, amount);
    }

    /**
     * @notice Withdraw LP tokens and send to whitelisted LP address for liquidation
     * @dev Only admin can withdraw, LP must be whitelisted
     * @param lpToken Address of the LP token to withdraw
     * @param lp Address of the whitelisted LP protocol to send tokens to
     * @param amount Amount of LP tokens to withdraw (0 = withdraw all)
     */
    function withdrawLPTokens(address lpToken, address lp, uint256 amount) external onlyAdmin {
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
        lpTokenContract.transfer(lp, withdrawAmount);
        
        emit LPTokensWithdrawn(lpToken, lp, withdrawAmount);
    }

    /**
     * @notice Set Senior vault address (fixes circular dependency)
     * @dev Can only be called once by admin after deployment
     * @param seniorVault_ Address of Senior vault
     */
    function setSeniorVault(address seniorVault_) external onlyAdmin {
        if (_seniorVault != address(0) && _seniorVault != address(0x1)) {
            revert SeniorVaultAlreadySet();
        }
        if (seniorVault_ == address(0)) revert AdminControlled.ZeroAddress();
        
        _seniorVault = seniorVault_;
    }
    
    /**
     * @notice Update Senior vault address (admin only)
     * @dev Allows admin to update Senior vault address after initial setup
     * @param seniorVault_ Address of Senior vault
     */
    function updateSeniorVault(address seniorVault_) external onlyAdmin {
        if (seniorVault_ == address(0)) revert AdminControlled.ZeroAddress();
        
        _seniorVault = seniorVault_;
    }
    
    /**
     * @notice Add address to whitelist for deposits
     * @dev Only admin can whitelist depositors
     * @param depositor Address to whitelist
     */
    function addWhitelistedDepositor(address depositor) external onlyAdmin {
        if (depositor == address(0)) revert AdminControlled.ZeroAddress();
        _whitelistedDepositors[depositor] = true;
        emit DepositorWhitelisted(depositor);
    }
    
    /**
     * @notice Remove address from whitelist
     * @dev Only admin can remove depositors
     * @param depositor Address to remove
     */
    function removeWhitelistedDepositor(address depositor) external onlyAdmin {
        _whitelistedDepositors[depositor] = false;
        emit DepositorRemoved(depositor);
    }
    
    /**
     * @notice Check if address is whitelisted
     * @param depositor Address to check
     * @return isWhitelisted True if address can deposit
     */
    function isWhitelistedDepositor(address depositor) external view returns (bool) {
        return _whitelistedDepositors[depositor];
    }
    
    // ============================================
    // IVault Interface Implementation
    // ============================================
    
    /**
     * @notice Get current vault value
     * @dev Reference: State Variables (V_s, V_j, V_r)
     */
    function vaultValue() public view virtual returns (uint256) {
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
        return super.deposit(assets, receiver);
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
        return super.mint(shares, receiver);
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
    function updateVaultValue(int256 profitBps) public virtual onlyAdmin {
        // Validate reasonable range
        if (profitBps < MIN_PROFIT_BPS || profitBps > MAX_PROFIT_BPS) {
            revert InvalidProfitRange();
        }
        
        uint256 oldValue = _vaultValue;
        
        // Apply profit/loss: V_new = V_old × (1 + profitBps / 10000)
        _vaultValue = MathLib.applyPercentage(oldValue, profitBps);
        _lastUpdateTime = block.timestamp;
        
        emit VaultValueUpdated(oldValue, _vaultValue, profitBps);
        
        // Hook for derived contracts to execute post-update logic
        _afterValueUpdate(oldValue, _vaultValue);
    }

    /**
     * @notice Directly set vault value (no BPS calculation)
     * @dev Simple admin function to set exact vault value
     * @param newValue New vault value in wei
     */
    function setVaultValue(uint256 newValue) public virtual onlyAdmin {
        // Allow 0 to enable truly empty vault state for first deposit
        
        uint256 oldValue = _vaultValue;
        _vaultValue = newValue;
        _lastUpdateTime = block.timestamp;
        
        // Calculate BPS for event logging
        int256 bps = 0;
        if (oldValue > 0) {
            bps = int256((newValue * 10000 / oldValue)) - 10000;
        }
        
        emit VaultValueUpdated(oldValue, _vaultValue, bps);
        
        // Hook for derived contracts to execute post-update logic
        _afterValueUpdate(oldValue, _vaultValue);
    }
    
    /**
     * @notice Transfer Stablecoins to Senior vault (fixes asset transfer issue)
     * @dev Called by Senior vault during backstop
     * @param amount Amount of Stablecoins to transfer
     */
    function transferToSenior(uint256 amount) external virtual onlySeniorVault {
        if (amount == 0) return;
        _stablecoin.transfer(_seniorVault, amount);
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

    // ============================================
    // Burn Functions
    // ============================================
    
    /**
     * @notice Burns tokens from the caller's account
     * @param amount Amount of tokens to burn
     * @dev Uses ERC20Burnable functionality
     */
    function burn(uint256 amount) public virtual {
        _burn(msg.sender, amount);
    }
    
    /**
     * @notice Burns tokens from a specified account (requires allowance)
     * @param account Account to burn tokens from
     * @param amount Amount of tokens to burn
     * @dev Requires caller to have allowance for `account`
     */
    function burnFrom(address account, uint256 amount) public virtual {
        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
    }
    
    /**
     * @notice Admin function to burn tokens from any address
     * @param account Account to burn tokens from
     * @param amount Amount of tokens to burn
     * @dev Only callable by admin - used for emergency situations
     */
    function adminBurn(address account, uint256 amount) public virtual onlyAdmin {
        _burn(account, amount);
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
}
