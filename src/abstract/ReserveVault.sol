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
     */
    function effectiveMonthlyReturn() public view virtual returns (int256) {
        if (_lastMonthValue == 0) return 0;
        
        // Calculate profit/loss from strategy + spillover - backstop
        int256 strategyReturn = int256(_vaultValue) - int256(_lastMonthValue);
        
        // Return as percentage (in 18 decimals)
        return (strategyReturn * int256(MathLib.PRECISION)) / int256(_lastMonthValue);
    }
    
    /**
     * @notice Get current deposit cap for Senior
     * @dev Reference: Deposit Cap - S_max = γ × V_r = 10 × V_r
     */
    function currentDepositCap() public view virtual returns (uint256) {
        return MathLib.calculateDepositCap(_vaultValue);
    }
    
    /**
     * @notice Check if reserve is depleted
     * @dev Reserve considered depleted if below 1% of initial value
     */
    function isDepleted() public view virtual returns (bool) {
        uint256 initialValue = _lastMonthValue; // Simplified: use last month as reference
        uint256 threshold = (initialValue * DEPLETION_THRESHOLD) / MathLib.PRECISION;
        return _vaultValue < threshold;
    }
    
    /**
     * @notice Get available backstop capacity
     * @dev Reference: Backstop - Reserve provides EVERYTHING (no cap!)
     */
    function backstopCapacity() public view virtual returns (uint256) {
        return _vaultValue;
    }
    
    /**
     * @notice Check if can provide full backstop
     */
    function canProvideFullBackstop(uint256 amount) public view virtual returns (bool) {
        return _vaultValue >= amount;
    }
    
    /**
     * @notice Get utilization rate
     * @dev Percentage of reserve that has been used for backstop
     */
    function utilizationRate() public view virtual returns (uint256) {
        uint256 totalReceived = _totalSpilloverReceived;
        uint256 totalProvided = _totalBackstopProvided;
        
        if (totalReceived == 0 && totalProvided == 0) return 0;
        
        uint256 total = totalReceived + _lastMonthValue;
        if (total == 0) return 0;
        
        return (totalProvided * MathLib.BPS_DENOMINATOR) / total;
    }
    
    // ============================================
    // Senior Vault Functions (Restricted)
    // ============================================
    
    /**
     * @notice Receive profit spillover from Senior
     * @dev Reference: Three-Zone System - Zone 1
     * Formula: E_r = E × 0.20
     */
    function receiveSpillover(uint256 amount) public virtual onlySeniorVault nonReentrant {
        if (amount == 0) return;
        
        // Increase vault value
        _vaultValue += amount;
        _totalSpilloverReceived += amount;
        
        emit SpilloverReceived(amount, msg.sender);
        
        // Emit deposit cap update
        uint256 newCap = currentDepositCap();
        emit DepositCapUpdated(0, newCap);
    }
    
    /**
     * @notice Provide backstop to Senior via LP tokens (primary, no cap!)
     * @dev Reference: Three-Zone System - Zone 3
     * Formula: X_r = min(V_r, D)
     * @param amountUSD Amount requested (in USD)
     * @param lpPrice Current LP token price in USD (18 decimals)
     * @return actualAmount Actual USD amount provided (entire reserve if needed!)
     */
    function provideBackstop(uint256 amountUSD, uint256 lpPrice) public virtual onlySeniorVault nonReentrant returns (uint256 actualAmount) {
        if (amountUSD == 0) return 0;
        if (lpPrice == 0) return 0;
        if (address(kodiakHook) == address(0)) revert ReserveDepleted();
        
        // LP DECIMALS FIX: Get LP token and its decimals
        address lpToken = address(kodiakHook.island());
        uint8 lpDecimals = IERC20Metadata(lpToken).decimals();
        
        // SECURITY FIX: Use Math.mulDiv() to avoid divide-before-multiply precision loss
        // Calculate LP amount needed (accounting for LP decimals)
        // lpPrice is in 18 decimals (USD per LP token)
        uint256 lpAmountNeeded = Math.mulDiv(amountUSD, 10 ** lpDecimals, lpPrice);
        
        // Check Reserve Hook's actual LP token balance
        uint256 lpBalance = kodiakHook.getIslandLPBalance();
        
        // Provide up to available LP tokens
        uint256 actualLPAmount = lpAmountNeeded > lpBalance ? lpBalance : lpAmountNeeded;
        
        if (actualLPAmount == 0) revert ReserveDepleted();
        
        // SECURITY FIX: Use Math.mulDiv() for precise USD conversion
        // Calculate actual USD amount based on LP tokens available (accounting for decimals)
        actualAmount = Math.mulDiv(actualLPAmount, lpPrice, 10 ** lpDecimals);
        
        // Decrease vault value (can go to zero!)
        uint256 oldCap = currentDepositCap();
        _vaultValue -= actualAmount;
        _totalBackstopProvided += actualAmount;
        uint256 newCap = currentDepositCap();
        
        // Get Senior's hook address and transfer LP from Reserve Hook to Senior Hook
        address seniorHook = address(IVault(_seniorVault).kodiakHook());
        require(seniorHook != address(0), "Senior hook not set");
        kodiakHook.transferIslandLP(seniorHook, actualLPAmount);
        
        emit BackstopProvided(actualAmount, msg.sender);
        emit DepositCapUpdated(oldCap, newCap);
        
        // Check if depleted
        if (isDepleted()) {
            emit ReserveBelowThreshold();
        }
        
        return actualAmount;
    }
    
    // ============================================
    // Reserve-Specific Token Management Functions
    // ============================================
    
    /**
     * @notice Seed Reserve vault with non-stablecoin token (e.g., WBTC)
     * @dev ONLY for Reserve vault - token stays in vault, not transferred to hook
     * @dev Caller must have seeder role and approve this vault to transfer tokens first
     * @dev Use investInKodiak() after seeding to convert token to LP
     * @param token Non-stablecoin token address (e.g., WBTC)
     * @param amount Amount of tokens to seed
     * @param tokenPrice Price of token in stablecoin terms (18 decimals)
     */
    function seedReserveWithToken(
        address token,
        uint256 amount,
        uint256 tokenPrice
    ) external onlySeeder nonReentrant {
        // Validation
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (tokenPrice == 0) revert InvalidTokenPrice();
        
        // Step 1: Transfer tokens from caller (seeder) to vault
        // Token STAYS in vault (not transferred to hook like seedVault)
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // Step 2: Calculate value = amount * tokenPrice / 1e18
        // Q5 FIX: Account for token decimals (WBTC=8, USDC=6, etc.)
        // tokenPrice is in 18 decimals, representing stablecoin value per token
        uint8 tokenDecimals = IERC20Metadata(token).decimals();
        uint256 normalizedAmount = _normalizeToDecimals(amount, tokenDecimals, 18);
        uint256 valueAdded = (normalizedAmount * tokenPrice) / 1e18;
        
        // Step 3: Mint shares to caller (seeder)
        // N1-1 FIX: Use previewDeposit() for standardized ERC4626 share calculation
        uint256 sharesToMint = previewDeposit(valueAdded);
        _mint(msg.sender, sharesToMint);
        
        // Step 4: Update vault value to include new token value
        _vaultValue += valueAdded;
        _lastUpdateTime = block.timestamp;
        
        // Step 5: Emit event
        emit ReserveSeededWithToken(token, msg.sender, amount, tokenPrice, valueAdded, sharesToMint);
    }
    
    /**
     * @notice Invest non-stablecoin token into Kodiak Island (Reserve vault only)
     * @dev Takes token from vault, swaps to pool tokens, adds liquidity
     * @dev Same pattern as deployToKodiak() but for non-stablecoin tokens
     * @param island Kodiak Island (pool) address
     * @param token Token to invest (e.g., WBTC)
     * @param amount Amount of tokens to invest
     * @param minLPTokens Minimum LP tokens to receive (slippage protection)
     * @param swapToToken0Aggregator DEX aggregator for token0 swap
     * @param swapToToken0Data Swap calldata for token0
     * @param swapToToken1Aggregator DEX aggregator for token1 swap
     * @param swapToToken1Data Swap calldata for token1
     */
    function investInKodiak(
        address island,
        address token,
        uint256 amount,
        uint256 minLPTokens,
        address swapToToken0Aggregator,
        bytes calldata swapToToken0Data,
        address swapToToken1Aggregator,
        bytes calldata swapToToken1Data
    ) external onlyLiquidityManager nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (address(kodiakHook) == address(0)) revert KodiakHookNotSet();
        
        // Check vault has enough of the token
        uint256 vaultBalance = IERC20(token).balanceOf(address(this));
        if (vaultBalance < amount) revert InsufficientBalance();
        
        // Record LP balance before
        uint256 lpBefore = kodiakHook.getIslandLPBalance();
        
        // Transfer token to hook
        IERC20(token).safeTransfer(address(kodiakHook), amount);
        
        // Call hook to deploy with swap parameters (same as deployToKodiak)
        kodiakHook.onAfterDepositWithSwaps(
            amount,
            swapToToken0Aggregator,
            swapToToken0Data,
            swapToToken1Aggregator,
            swapToToken1Data
        );
        
        // Calculate LP received
        uint256 lpAfter = kodiakHook.getIslandLPBalance();
        uint256 lpReceived = lpAfter - lpBefore;
        
        // Check slippage
        if (lpReceived < minLPTokens) revert SlippageTooHigh();
        
        // Emit event
        emit KodiakInvestment(island, token, amount, lpReceived, block.timestamp);
    }
    
    /**
     * @notice Swap stablecoin (HONEY) to non-stablecoin token (WBTC) in Reserve vault
     * @dev ONLY for Reserve vault - converts HONEY held in vault to WBTC
     * @param amount Amount of stablecoin to swap
     * @param minTokenOut Minimum non-stablecoin to receive (slippage protection)
     * @param tokenOut Non-stablecoin address (e.g., WBTC)
     * @param swapAggregator DEX aggregator address
     * @param swapData Swap calldata from aggregator
     */
    function swapStablecoinToToken(
        uint256 amount,
        uint256 minTokenOut,
        address tokenOut,
        address swapAggregator,
        bytes calldata swapData
    ) external onlyLiquidityManager nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (tokenOut == address(0) || swapAggregator == address(0)) revert ZeroAddress();
        
        // Check vault has enough stablecoin
        uint256 vaultBalance = _stablecoin.balanceOf(address(this));
        if (vaultBalance < amount) revert InsufficientBalance();
        
        // Check token balance before
        uint256 tokenBefore = IERC20(tokenOut).balanceOf(address(this));
        
        // Approve aggregator
        _stablecoin.forceApprove(swapAggregator, amount);
        
        // Execute swap
        (bool success,) = swapAggregator.call(swapData);
        require(success, "Swap failed");
        
        // Check tokens received
        uint256 tokenAfter = IERC20(tokenOut).balanceOf(address(this));
        uint256 tokenReceived = tokenAfter - tokenBefore;
        
        // Slippage check
        if (tokenReceived < minTokenOut) revert SlippageTooHigh();
        
        // Clean up approval
        _stablecoin.forceApprove(swapAggregator, 0);
        
        emit StablecoinSwappedToToken(address(_stablecoin), tokenOut, amount, tokenReceived, block.timestamp);
    }
    
    /**
     * @notice Rescue stablecoin from hook to vault (Reserve only)
     * @dev Swaps non-stablecoin token (e.g., WBTC) in hook to stablecoin and sends to vault
     * @param tokenIn Non-stablecoin token address in hook (e.g., WBTC dust)
     * @param amount Amount of token to swap
     * @param minStablecoinOut Minimum stablecoin to receive
     * @param swapAggregator DEX aggregator address
     * @param swapData Swap calldata from aggregator
     */
    function rescueAndSwapHookTokenToStablecoin(
        address tokenIn,
        uint256 amount,
        uint256 minStablecoinOut,
        address swapAggregator,
        bytes calldata swapData
    ) external onlyLiquidityManager nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (address(kodiakHook) == address(0)) revert KodiakHookNotSet();
        if (tokenIn == address(0) || swapAggregator == address(0)) revert ZeroAddress();
        
        // Check stablecoin balance before
        uint256 stablecoinBefore = _stablecoin.balanceOf(address(this));
        
        // Call hook to swap token to stablecoin and send to vault
        kodiakHook.adminSwapAndReturnToVault(
            tokenIn,
            amount,
            swapData,
            swapAggregator
        );
        
        // Check stablecoin received in vault
        uint256 stablecoinAfter = _stablecoin.balanceOf(address(this));
        uint256 stablecoinReceived = stablecoinAfter - stablecoinBefore;
        
        // Slippage check
        if (stablecoinReceived < minStablecoinOut) revert SlippageTooHigh();
        
        emit HookTokenSwappedToStablecoin(tokenIn, amount, stablecoinReceived, block.timestamp);
    }
    
    /**
     * @notice Rescue non-stablecoin token from hook to vault (Reserve only)
     * @dev Transfers WBTC from Reserve hook back to Reserve vault
     * @param token Non-stablecoin token address (e.g., WBTC)
     * @param amount Amount to rescue (0 = all)
     */
    function rescueTokenFromHook(
        address token,
        uint256 amount
    ) external onlyLiquidityManager nonReentrant {
        if (token == address(0)) revert ZeroAddress();
        if (address(kodiakHook) == address(0)) revert KodiakHookNotSet();
        
        // Get token balance in hook
        uint256 hookBalance = IERC20(token).balanceOf(address(kodiakHook));
        
        // If amount is 0, rescue all
        uint256 rescueAmount = amount == 0 ? hookBalance : amount;
        
        if (rescueAmount == 0) revert InvalidAmount();
        if (hookBalance < rescueAmount) revert InsufficientBalance();
        
        // Use hook's rescue function
        kodiakHook.adminRescueTokens(token, address(this), rescueAmount);
        
        emit TokenRescuedFromHook(token, rescueAmount, block.timestamp);
    }
    
    /**
     * @notice Exit LP position to stablecoin or non-stablecoin (Reserve only)
     * @dev Liquidates LP from hook and swaps to desired token
     * @param lpAmount Amount of LP to exit (0 = all)
     * @param tokenOut Desired output token (HONEY or WBTC)
     * @param minTokenOut Minimum tokens to receive
     * @param swapAggregator DEX aggregator address  
     * @param swapData Swap calldata from aggregator
     */
     
    function exitLPToToken(
        uint256 lpAmount,
        address tokenOut,
        uint256 minTokenOut,
        address swapAggregator,
        bytes calldata swapData
    ) external onlyLiquidityManager nonReentrant {
        if (tokenOut == address(0)) revert ZeroAddress();
        if (address(kodiakHook) == address(0)) revert KodiakHookNotSet();
        
        // Get LP balance if amount is 0
        if (lpAmount == 0) {
            lpAmount = kodiakHook.getIslandLPBalance();
        }
        
        if (lpAmount == 0) revert InvalidAmount();
        
        // Check token balance before
        uint256 tokenBefore = IERC20(tokenOut).balanceOf(address(this));
        
        // Use hook's adminLiquidateAll to exit LP and swap
        kodiakHook.adminLiquidateAll(swapData, swapAggregator);
        
        // Check tokens received
        uint256 tokenAfter = IERC20(tokenOut).balanceOf(address(this));
        uint256 tokenReceived = tokenAfter - tokenBefore;
        
        // Slippage check
        if (tokenReceived < minTokenOut) revert SlippageTooHigh();
        
        emit LPExitedToToken(lpAmount, tokenOut, tokenReceived, block.timestamp);
    }
 

    
    
    /**
     * @notice Hook after value update to track monthly returns
     */
    function _afterValueUpdate(uint256 oldValue, uint256 newValue) internal virtual override {
        _lastMonthValue = oldValue;
        emit ReserveRebaseExecuted(newValue, effectiveMonthlyReturn());
    }
}
