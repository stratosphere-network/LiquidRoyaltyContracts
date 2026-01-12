// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReserveVault} from "../abstract/ReserveVault.sol";
import {MathLib} from "../libraries/MathLib.sol";
import {FeeLib} from "../libraries/FeeLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRewardVault} from "../integrations/IRewardVault.sol";

/**
 * @title ConcreteReserveVault
 * @notice Concrete implementation of Reserve vault (ERC4626)
 * @dev No additional logic needed - receives spillover, provides primary backstop
 * @dev Upgradeable using UUPS proxy pattern
 */
contract ConcreteReserveVault is ReserveVault {
    using SafeERC20 for IERC20;
    /// @dev NEW role management (V2 upgrade)
    address private _liquidityManager;
    address private _priceFeedManager;
    address private _contractUpdater;

    /// @dev Cooldown mechanism (V3 upgrade - moved from ReserveVault for storage safety)
    mapping(address => uint256) private _cooldownStart;
    
    /// @dev Reentrancy guard state (V3 upgrade - MUST be in concrete contract)
    uint256 private _status;
   
    address private _liquidityManagerVault;
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
    
    function liquidityManager() public view override returns (address) { return _liquidityManager; }
    function priceFeedManager() public view override returns (address) { return _priceFeedManager; }
    function contractUpdater() public view override returns (address) { return _contractUpdater; }
    
    function setLiquidityManager(address m) external onlyAdmin { if (m == address(0)) revert ZeroAddress(); _liquidityManager = m; }
    function setPriceFeedManager(address m) external onlyAdmin { if (m == address(0)) revert ZeroAddress(); _priceFeedManager = m; }
    function setContractUpdater(address m) external onlyAdmin { if (m == address(0)) revert ZeroAddress(); _contractUpdater = m; }
    function liquidityManagerVault() public view override returns (address) { return _liquidityManagerVault; }
    function setLiquidityManagerVault(address m) external onlyAdmin { if (m == address(0)) revert ZeroAddress(); _liquidityManagerVault = m; emit AdminControlled.LiquidityManagerVaultSet(m); }
    
    // ============================================
    // V3 Initialization
    // ============================================
    
    function initializeV3() external reinitializer(3) onlyAdmin { _status = 1; }
    
    // Cooldown mechanism
    function initiateCooldown() external { _cooldownStart[msg.sender] = block.timestamp; emit CooldownInitiated(msg.sender, block.timestamp); }
    function cooldownStart(address user) external view returns (uint256) { return _cooldownStart[user]; }
    function canWithdrawWithoutPenalty(address user) external view returns (bool) { return _cooldownStart[user] > 0 && (block.timestamp - _cooldownStart[user]) >= MathLib.COOLDOWN_PERIOD; }
    function calculateWithdrawalPenalty(address user, uint256 amount) external view returns (uint256 penalty, uint256 netAmount) { return FeeLib.calculateWithdrawalPenalty(amount, _cooldownStart[user], block.timestamp); }
    
    /// @notice Override withdraw to add cooldown penalty (CEI pattern)
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares) internal override nonReentrant {
        if (caller != owner) _spendAllowance(owner, caller, shares);
        
        (uint256 earlyPenalty, uint256 afterPenalty) = FeeLib.calculateWithdrawalPenalty(assets, _cooldownStart[owner], block.timestamp);
        uint256 fee = (afterPenalty * MathLib.WITHDRAWAL_FEE) / MathLib.PRECISION;
        uint256 net = afterPenalty - fee;
        
        _burn(owner, shares);
        _vaultValue -= afterPenalty;
        if (_cooldownStart[owner] != 0) _cooldownStart[owner] = 0;
        
        _ensureLiquidityAvailable(afterPenalty);
        _stablecoin.safeTransfer(receiver, net);
        if (_treasury != address(0) && fee > 0) { _stablecoin.safeTransfer(_treasury, fee); emit WithdrawalFeeCharged(owner, fee, net); }
        if (earlyPenalty > 0) emit WithdrawalPenaltyCharged(owner, earlyPenalty);
        emit Withdraw(caller, receiver, owner, afterPenalty, shares);
    }
    
    function _update(address from, address to, uint256 value) internal override { super._update(from, to, value); if (to != address(0) && _cooldownStart[to] != 0) _cooldownStart[to] = 0; }
    
    // Reentrancy guard
    function _getReentrancyStatus() internal view override returns (uint256) { return _status; }
    function _setReentrancyStatus(uint256 status) internal override { _status = status; }
    function _getRewardVault() internal pure override returns (IRewardVault) { return IRewardVault(address(0)); }
    
    error RewardVaultNotSet();
    event WithdrawalPenaltyCharged(address indexed user, uint256 penalty);
    
    /**
     * @notice Invest tokens into Kodiak (transfer from vault to LiquidityManagerVault), LMV needs to transfer tokens back to vault within 30 mins
     * @dev Only callable by LiquidityManagerVault role
     * @param token Token address to invest (USDe, SAIL.r, etc.)
     * @param amount Amount of tokens to transfer
     */
    function investInKodiak(address token, uint256 amount) external onlyLiquidityManagerVault {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (liquidityManagerVault() == address(0)) revert ZeroAddress();
        IERC20(token).safeTransfer(liquidityManagerVault(), amount);
    }
}

