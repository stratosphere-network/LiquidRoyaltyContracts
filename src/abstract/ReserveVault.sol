// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseVault} from "./BaseVault.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IReserveVault} from "../interfaces/IReserveVault.sol";
import {MathLib} from "../libraries/MathLib.sol";
import {FeeLib} from "../libraries/FeeLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IKodiakIsland} from "../integrations/IKodiakIsland.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IRewardVault} from "../integrations/IRewardVault.sol";

/**
 * @title ReserveVault
 * @notice Abstract Reserve vault (Standard ERC4626)
 * @dev Receives profit spillover (20%), provides primary backstop (no cap - can be wiped out!)
 * @dev Upgradeable using UUPS proxy pattern
 * 
 * Users deposit Stablecoins, receive standard ERC4626 shares (NOT rebasing)
 * 
 * References from Mathematical Specification:
 * - Section: Three-Zone Spillover System
 * - Section: Backstop Mechanics (Primary layer)
 * - Section: Deposit Cap (S_max = 10 × V_r)
 */
abstract contract ReserveVault is BaseVault, IReserveVault {
    using MathLib for uint256;
    using SafeERC20 for IERC20;
    
    /// @dev State Variables
    uint256 internal _totalSpilloverReceived;    // Cumulative spillover
    uint256 internal _totalBackstopProvided;     // Cumulative backstop
    uint256 internal _lastMonthValue;            // For return calculation
    address internal _kodiakRouter;              // Kodiak Island Router for token swaps
    
    /// @dev Minimum reserve threshold (1% of initial value)
    uint256 internal constant DEPLETION_THRESHOLD = 1e16; // 1%
    
    /// @dev Reserve-specific events
    event KodiakRouterSet(address indexed router);
    
    /// @dev Errors (defined in interface or BaseVault, no need to redeclare)
    
    /**
     * @notice Initialize Reserve vault (replaces constructor for upgradeable)
     * @param stablecoin_ Stablecoin address
     * @param vaultName_ ERC20 name for shares (e.g., "Reserve Tranche Shares")
     * @param vaultSymbol_ ERC20 symbol for shares (e.g., "rTRN")
     * @param seniorVault_ Senior vault address (can be placeholder)
     * @param initialValue_ Initial vault value
     */
    function __ReserveVault_init(
        address stablecoin_,
        string memory vaultName_,
        string memory vaultSymbol_,
        address seniorVault_,
        uint256 initialValue_
    ) internal onlyInitializing {
        __BaseVault_init(stablecoin_, vaultName_, vaultSymbol_, seniorVault_, initialValue_);
        _lastMonthValue = initialValue_;
    }
    
    // View functions (condensed single-line)
    function seniorVault() public view virtual override returns (address) { return _seniorVault; }
    function totalSpilloverReceived() public view virtual returns (uint256) { return _totalSpilloverReceived; }
    function totalBackstopProvided() public view virtual returns (uint256) { return _totalBackstopProvided; }
    function currentDepositCap() public view virtual returns (uint256) { return MathLib.calculateDepositCap(_vaultValue); }
    function backstopCapacity() public view virtual returns (uint256) { return _vaultValue; }
    function canProvideFullBackstop(uint256 amount) public view virtual returns (bool) { return _vaultValue >= amount; }
    function isDepleted() public view virtual returns (bool) { return _vaultValue < (_lastMonthValue * DEPLETION_THRESHOLD) / MathLib.PRECISION; }
    function utilizationRate() public view virtual returns (uint256) { uint256 t = _totalSpilloverReceived + _lastMonthValue; return t == 0 ? 0 : (_totalBackstopProvided * MathLib.BPS_DENOMINATOR) / t; }
    
    // ============================================
    // Senior Vault Functions (Restricted)
    // ============================================
    
    /// @notice Receive profit spillover from Senior
    function receiveSpillover(uint256 amount) public virtual onlySeniorVault nonReentrant {
        if (amount == 0) return;
        _vaultValue += amount;
        _totalSpilloverReceived += amount;
        emit SpilloverReceived(amount, msg.sender);
        emit DepositCapUpdated(0, currentDepositCap());
    }
    
    /// @notice Provide backstop to Senior via LP tokens (no cap - can use entire reserve)
    function provideBackstop(uint256 amountUSD, uint256 lpPrice) public virtual onlySeniorVault nonReentrant returns (uint256 actualAmount) {
        if (amountUSD == 0 || lpPrice == 0) return 0;
        if (address(kodiakHook) == address(0)) revert ReserveDepleted();
        
        address lpToken = address(kodiakHook.island());
        uint8 lpDec = IERC20Metadata(lpToken).decimals();
        uint256 lpNeeded = Math.mulDiv(amountUSD, 10 ** lpDec, lpPrice);
        uint256 lpBal = kodiakHook.getIslandLPBalance();
        
        // Withdraw from reward vault if needed
        IRewardVault rv = _getRewardVault();
        if (lpBal < lpNeeded && address(rv) != address(0)) {
            uint256 deficit = lpNeeded - lpBal;
            uint256 staked = rv.getTotalDelegateStaked(admin());
            uint256 toWithdraw = deficit > staked ? staked : deficit;
            if (toWithdraw > 0) { rv.delegateWithdraw(admin(), toWithdraw); IERC20(lpToken).transfer(address(kodiakHook), toWithdraw); lpBal = kodiakHook.getIslandLPBalance(); }
        }
        
        uint256 actualLP = lpNeeded > lpBal ? lpBal : lpNeeded;
        if (actualLP == 0) revert ReserveDepleted();
        
        actualAmount = Math.mulDiv(actualLP, lpPrice, 10 ** lpDec);
        uint256 oldCap = currentDepositCap();
        _vaultValue -= actualAmount;
        _totalBackstopProvided += actualAmount;
        
        address seniorHook = address(IVault(_seniorVault).kodiakHook());
        if (seniorHook == address(0)) revert KodiakHookNotSet();
        kodiakHook.transferIslandLP(seniorHook, actualLP);
        
        emit BackstopProvided(actualAmount, msg.sender);
        emit DepositCapUpdated(oldCap, currentDepositCap());
        if (isDepleted()) emit ReserveBelowThreshold();
    }
    
    // ============================================
    // Reserve-Specific Token Management Functions
    // ============================================
    
    /// @notice Seed Reserve with non-stablecoin token (e.g., WBTC)
    /// @dev Large seeds (> LARGE_SEED_BPS of vault value) require timelock if set
    function seedReserveWithToken(address token, uint256 amount, uint256 tokenPrice) external nonReentrant {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (tokenPrice == 0) revert InvalidTokenPrice();
        
        // Calculate seed value to check if it's a "large" seed
        uint256 valueToAdd = (MathLib.normalizeDecimals(amount, IERC20Metadata(token).decimals(), 18) * tokenPrice) / 1e18;
        
        // Check authorization based on seed size relative to vault value
        bool isLargeSeed = _vaultValue > 0 && (valueToAdd * 10000) / _vaultValue > LARGE_SEED_BPS;
        if (isLargeSeed && timelock() != address(0)) {
            // Large seed with timelock set - must come from timelock
            _requireTimelock();
        } else {
            // Small seed or no timelock - seeder can execute directly
            if (!isSeeder(msg.sender)) revert OnlySeeder();
        }
        
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint256 shares = previewDeposit(valueToAdd);
        _mint(msg.sender, shares);
        _vaultValue += valueToAdd;
        _lastUpdateTime = block.timestamp;
        emit ReserveSeededWithToken(token, msg.sender, amount, tokenPrice, valueToAdd, shares);
    }
    
    /// @notice Consolidated Reserve actions - use enum to select action, logic 100% same
    /// @param action: 0=InvestKodiak, 1=SwapStable, 2=RescueAndSwap, 3=RescueToken, 4=ExitLP
    /// @param tokenA: island(0) or tokenOut(1,4) or tokenIn(2,3)
    /// @param tokenB: token to invest(0) - unused for others
    /// @param amount: amount to use
    /// @param minOut: minimum output (LP or tokens)
    /// @param agg0: aggregator 0
    /// @param data0: swap data 0
    /// @param agg1: aggregator 1 (only for InvestKodiak)
    /// @param data1: swap data 1 (only for InvestKodiak)
    enum ReserveAction { InvestKodiak, SwapStable, RescueAndSwap, RescueToken, ExitLP }
    
    function executeReserveAction(ReserveAction action, address tokenA, address tokenB, uint256 amount, uint256 minOut, address agg0, bytes calldata data0, address agg1, bytes calldata data1) external onlyLiquidityManager nonReentrant {
        if (action == ReserveAction.InvestKodiak) {
            // investInKodiak: tokenA=island, tokenB=token
            if (amount == 0) revert InvalidAmount();
            if (address(kodiakHook) == address(0)) revert KodiakHookNotSet();
            if (IERC20(tokenB).balanceOf(address(this)) < amount) revert InsufficientBalance();
            uint256 lpBefore = kodiakHook.getIslandLPBalance();
            IERC20(tokenB).safeTransfer(address(kodiakHook), amount);
            kodiakHook.onAfterDepositWithSwaps(amount, agg0, data0, agg1, data1);
            uint256 lpReceived = kodiakHook.getIslandLPBalance() - lpBefore;
            if (lpReceived < minOut) revert SlippageTooHigh();
            emit KodiakInvestment(tokenA, tokenB, amount, lpReceived, block.timestamp);
        } else if (action == ReserveAction.SwapStable) {
            // swapStablecoinToToken: tokenA=tokenOut
            if (amount == 0) revert InvalidAmount();
            if (tokenA == address(0) || agg0 == address(0)) revert ZeroAddress();
            if (_stablecoin.balanceOf(address(this)) < amount) revert InsufficientBalance();
            uint256 before = IERC20(tokenA).balanceOf(address(this));
            _stablecoin.forceApprove(agg0, amount);
            (bool ok,) = agg0.call(data0);
            if (!ok) revert SlippageTooHigh();
            uint256 received = IERC20(tokenA).balanceOf(address(this)) - before;
            if (received < minOut) revert SlippageTooHigh();
            _stablecoin.forceApprove(agg0, 0);
            emit StablecoinSwappedToToken(address(_stablecoin), tokenA, amount, received, block.timestamp);
        } else if (action == ReserveAction.RescueAndSwap) {
            // rescueAndSwapHookTokenToStablecoin: tokenA=tokenIn
            if (amount == 0) revert InvalidAmount();
            if (address(kodiakHook) == address(0)) revert KodiakHookNotSet();
            if (tokenA == address(0) || agg0 == address(0)) revert ZeroAddress();
            uint256 before = _stablecoin.balanceOf(address(this));
            kodiakHook.adminSwapAndReturnToVault(tokenA, amount, data0, agg0);
            uint256 received = _stablecoin.balanceOf(address(this)) - before;
            if (received < minOut) revert SlippageTooHigh();
            emit HookTokenSwappedToStablecoin(tokenA, amount, received, block.timestamp);
        } else if (action == ReserveAction.RescueToken) {
            // rescueTokenFromHook: tokenA=token, amount=0 means all
            if (tokenA == address(0)) revert ZeroAddress();
            if (address(kodiakHook) == address(0)) revert KodiakHookNotSet();
            uint256 hookBal = IERC20(tokenA).balanceOf(address(kodiakHook));
            uint256 amt = amount == 0 ? hookBal : amount;
            if (amt == 0 || hookBal < amt) revert InsufficientBalance();
            kodiakHook.adminRescueTokens(tokenA, address(this), amt);
            emit TokenRescuedFromHook(tokenA, amt, block.timestamp);
        } else if (action == ReserveAction.ExitLP) {
            // exitLPToToken: tokenA=tokenOut, amount=lpAmount (0 means all)
            if (tokenA == address(0)) revert ZeroAddress();
            if (address(kodiakHook) == address(0)) revert KodiakHookNotSet();
            uint256 lp = amount == 0 ? kodiakHook.getIslandLPBalance() : amount;
            if (lp == 0) revert InvalidAmount();
            uint256 before = IERC20(tokenA).balanceOf(address(this));
            kodiakHook.adminLiquidateAll(data0, agg0);
            uint256 received = IERC20(tokenA).balanceOf(address(this)) - before;
            if (received < minOut) revert SlippageTooHigh();
            emit LPExitedToToken(lp, tokenA, received, block.timestamp);
        }
    }
 

    
    
    function _afterValueUpdate(uint256 oldValue, uint256 newValue) internal virtual override {
        _lastMonthValue = oldValue;
        int256 ret = oldValue == 0 ? int256(0) : (int256(newValue) - int256(oldValue)) * int256(MathLib.PRECISION) / int256(oldValue);
        emit ReserveRebaseExecuted(newValue, ret);
    }
}
