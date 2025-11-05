// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IVault} from "../interfaces/IVault.sol";
import {MathLib} from "../libraries/MathLib.sol";
import {AdminControlled} from "./AdminControlled.sol";

/**
 * @title BaseVault
 * @notice Abstract ERC4626 vault with LP token value tracking
 * @dev Inherited by Junior and Reserve vaults (standard ERC4626)
 * @dev Upgradeable using UUPS proxy pattern
 *
 * References from Mathematical Specification:
 * - Section: Notation & Definitions (State Variables)
 * - Instructions: Vault Architecture (LP Token Holdings)
 */
abstract contract BaseVault is ERC4626Upgradeable, IVault, AdminControlled, UUPSUpgradeable {
    using MathLib for uint256;
    
    /// @dev State Variables
    /// Reference: State Variables (V_s, V_j, V_r)
    uint256 internal _vaultValue;           // Current USD value of vault assets
    uint256 internal _lastUpdateTime;       // Last value update timestamp (T_r)
    
    /// @dev LP token held by vault (the "asset" in ERC4626 terms)
    IERC20 internal _lpToken;
    
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
    
    /// @dev Errors (ZeroAddress inherited from AdminControlled)
    error InvalidProfitRange();
    error SeniorVaultAlreadySet();
    error OnlySeniorVault();
    error OnlyWhitelistedDepositor();
    
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
     * @param lpToken_ LP token address (the asset)
     * @param vaultName_ ERC20 name for vault shares
     * @param vaultSymbol_ ERC20 symbol for vault shares
     * @param seniorVault_ Senior vault address (can be placeholder)
     * @param initialValue_ Initial vault value
     */
    function __BaseVault_init(
        address lpToken_,
        string memory vaultName_,
        string memory vaultSymbol_,
        address seniorVault_,
        uint256 initialValue_
    ) internal onlyInitializing {
        if (lpToken_ == address(0)) revert AdminControlled.ZeroAddress();
        
        __ERC20_init(vaultName_, vaultSymbol_);
        __ERC4626_init(IERC20(lpToken_));
        __AdminControlled_init();
        
        _lpToken = IERC20(lpToken_);
        _seniorVault = seniorVault_; // Can be placeholder initially
        _vaultValue = initialValue_;
        _lastUpdateTime = block.timestamp;
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
     * @notice Get LP token
     * @dev Reference: Instructions - Vault Architecture
     */
    function lpToken() public view virtual returns (IERC20) {
        return _lpToken;
    }
    
    /**
     * @notice Get deposit token (same as LP token for ERC4626)
     */
    function depositToken() public view virtual returns (IERC20) {
        return _lpToken;
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
     * @notice Total assets in vault (actual LP token balance)
     * @dev ERC4626 requires actual token balance for share calculations
     * _vaultValue tracks USD value, but shares need LP token balance
     */
    function totalAssets() public view virtual override(ERC4626Upgradeable) returns (uint256) {
        return _lpToken.balanceOf(address(this));
    }
    
    /**
     * @notice Deposit LP tokens and mint shares
     * @dev Override ERC4626 deposit to add whitelist check
     * @param assets Amount of LP tokens to deposit
     * @param receiver Address to receive shares
     * @return shares Amount of shares minted
     */
    function deposit(uint256 assets, address receiver) 
        public 
        virtual 
        override(ERC4626Upgradeable) 
        onlyWhitelisted 
        returns (uint256 shares) 
    {
        return super.deposit(assets, receiver);
    }
    
    /**
     * @notice Mint shares by depositing LP tokens
     * @dev Override ERC4626 mint to add whitelist check
     * @param shares Amount of shares to mint
     * @param receiver Address to receive shares
     * @return assets Amount of LP tokens deposited
     */
    function mint(uint256 shares, address receiver) 
        public 
        virtual 
        override(ERC4626Upgradeable) 
        onlyWhitelisted 
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
     * @notice Transfer LP tokens to Senior vault (fixes asset transfer issue)
     * @dev Called by Senior vault during backstop
     * @param amount Amount of LP tokens to transfer
     */
    function transferToSenior(uint256 amount) external virtual onlySeniorVault {
        if (amount == 0) return;
        _lpToken.transfer(_seniorVault, amount);
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
