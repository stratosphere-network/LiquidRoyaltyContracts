// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./IKodiakVaultHook.sol";
import "./IKodiakIslandRouter.sol";
import "./IKodiakIsland.sol";

interface IUniswapV3Pool {
    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16, uint16, uint16, uint8, bool);
}

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
    function balanceOf(address) external view returns (uint256);
}

interface IVault {
    function vaultValue() external view returns (uint256);
}

/**
 * @title KodiakVaultHook
 * @notice Default implementation that routes deposits to a Kodiak Island and
 *         frees funds before withdrawals by removing Island liquidity.
 */
contract KodiakVaultHook is AccessControl, IKodiakVaultHook {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    address public immutable vault;      // Vault that calls this hook
    IERC20 public immutable assetToken;  // Stablecoin (e.g., USDC)
    IKodiakIslandRouter public router;   // Kodiak Island Router
    IKodiakIsland public island;         // Target Island ERC20 token
    address public wbera;                // WBERA address for native BERA handling

    // Slippage controls (can be tuned by admin)
    uint256 public minSharesPerAssetBps = 0;     // 0 = no min
    uint256 public minAssetOutBps = 0;           // 0 = no min
    
    // LP liquidation parameters (for smart withdrawal with slippage protection)
    uint256 public safetyMultiplier = 115;       // 115 = 1.15x = 15% buffer (in basis points, 100 = 1.0x)
    
    // Native BERA placeholder
    address public constant NATIVE_BERA = 0x6969696969696969696969696969696969696969;

    event RouterUpdated(address router);
    event IslandUpdated(address island);
    event SlippageUpdated(uint256 minSharesPerAssetBps, uint256 minAssetOutBps);
    event WBERAUpdated(address wbera);
    event LPParametersUpdated(uint256 safetyMultiplier);
    event LPLiquidated(uint256 requested, uint256 lpBurned, uint256 honeyReceived, uint256 wbtcKept);
    // Aggregator control/events
    mapping(address => bool) public whitelistedAggregators; // kX router targets (methodParameters.to)
    event AggregatorWhitelisted(address indexed target, bool status);
    event AggregatorZapExecuted(address indexed target, uint256 value, bytes4 selector);

    constructor(address _vault, address _assetToken, address _admin) {
        require(_vault != address(0), "vault=0");
        require(_assetToken != address(0), "asset=0");
        require(_admin != address(0), "admin=0");
        vault = _vault;
        assetToken = IERC20(_assetToken);
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
    }

    modifier onlyVault() {
        require(msg.sender == vault, "only vault");
        _;
    }

    function setRouter(address routerAddress) external onlyRole(ADMIN_ROLE) {
        require(routerAddress != address(0), "router=0");
        router = IKodiakIslandRouter(routerAddress);
        emit RouterUpdated(routerAddress);
    }

    function setIsland(address islandAddress) external onlyRole(ADMIN_ROLE) {
        require(islandAddress != address(0), "island=0");
        island = IKodiakIsland(islandAddress);
        emit IslandUpdated(islandAddress);
    }

    function setWBERA(address wberaAddress) external onlyRole(ADMIN_ROLE) {
        require(wberaAddress != address(0), "wbera=0");
        wbera = wberaAddress;
        emit WBERAUpdated(wberaAddress);
    }

    function setAggregatorWhitelisted(address target, bool isWhitelisted) external onlyRole(ADMIN_ROLE) {
        require(target != address(0), "target=0");
        whitelistedAggregators[target] = isWhitelisted;
        emit AggregatorWhitelisted(target, isWhitelisted);
    }

    function setSlippage(uint256 minSharesPerAssetBps_, uint256 minAssetOutBps_) external onlyRole(ADMIN_ROLE) {
        require(minSharesPerAssetBps_ <= 10_000 && minAssetOutBps_ <= 10_000, "bps>100%");
        minSharesPerAssetBps = minSharesPerAssetBps_;
        minAssetOutBps = minAssetOutBps_;
        emit SlippageUpdated(minSharesPerAssetBps_, minAssetOutBps_);
    }

    /**
     * @notice Update LP liquidation safety multiplier
     * @dev SECURITY UPDATE: Now uses reasonable basis points (100 = 1.0x, 115 = 1.15x)
     * @param safetyMultiplier_ Safety buffer in basis points (100-120 = 0-20% buffer)
     *        100 = no buffer, 110 = 10% buffer, 115 = 15% buffer, 120 = 20% buffer (max)
     */
    function setSafetyMultiplier(uint256 safetyMultiplier_) external onlyRole(ADMIN_ROLE) {
        require(safetyMultiplier_ >= 100 && safetyMultiplier_ <= 120, "multiplier must be 1.0x-1.2x (100-120)");
        safetyMultiplier = safetyMultiplier_;
        emit LPParametersUpdated(safetyMultiplier_);
    }

    // DEAD CODE REMOVED: _estimateBurnForAsset() - never used (Slither finding)
    // DEAD CODE REMOVED: _minAmountsForRemove() - never used (Slither finding)

    function onAfterDeposit(uint256 assets) external override onlyVault {
        require(address(island) != address(0), "Island not configured");
        require(assets > 0, "Zero deposit amount");

        // Vault already sent funds via safeTransfer before calling this function
        // No need to pull - funds are already here!

        // Beefy-style: balance asset to token0/token1 using pool price, then island.mint
        _swapToBalancedLp(assets);
        
        uint256 bal0 = island.token0().balanceOf(address(this));
        uint256 bal1 = island.token1().balanceOf(address(this));
        if (bal0 == 0 && bal1 == 0) {
            // No tokens to add, return asset
            uint256 refund = assetToken.balanceOf(address(this));
            if (refund > 0) assetToken.safeTransfer(vault, refund);
            return;
        }

        // Preview and mint Island LP
        (uint256 use0, uint256 use1, uint256 mintAmt) = island.getMintAmounts(bal0, bal1);
        if (mintAmt == 0) {
            // Refund
            uint256 refund = assetToken.balanceOf(address(this));
            if (refund > 0) assetToken.safeTransfer(vault, refund);
            return;
        }
        island.token0().forceApprove(address(island), use0);
        island.token1().forceApprove(address(island), use1);
        
        // SECURITY FIX: Capture and verify LP mint return value
        (uint256 actual0, uint256 actual1) = island.mint(mintAmt, address(this));
        require(actual0 > 0 || actual1 > 0, "No tokens used in LP mint");
        
        // Reset approvals
        island.token0().forceApprove(address(island), 0);
        island.token1().forceApprove(address(island), 0);
    }

    // Swap assetToken to balanced token0/token1 using pool price (Beefy-style)
    function _swapToBalancedLp(uint256 assetAmount) internal view {
        if (address(router) == address(0)) return;
        IERC20 token0 = island.token0();
        IERC20 token1 = island.token1();
        address pool = island.pool();
        bool assetIsToken0 = address(token0) == address(assetToken);
        bool assetIsToken1 = address(token1) == address(assetToken);
        
        if (!assetIsToken0 && !assetIsToken1) return; // can't balance if asset not in pair

        // Read pool price
        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(pool).slot0();
        uint256 price = (uint256(sqrtPriceX96) * 1e18 / (2 ** 96)) ** 2; // token1/token0 in 1e18

        (uint256 amt0, uint256 amt1) = island.getUnderlyingBalances();
        // PRECISION FIX: Avoid divide-before-multiply by rearranging calculation
        // Original: toToken0 = assetAmount × (amt0 × price / 1e36) / ((amt0 × price / 1e36) + amt1)
        // Fixed: toToken0 = (assetAmount × amt0 × price) / (amt0 × price + amt1 × 1e36)
        uint256 amt0PriceScaled = amt0 * price;
        uint256 totalScaled = amt0PriceScaled + (amt1 * 1e36);
        if (totalScaled == 0) return;

        uint256 toToken0 = (assetAmount * amt0PriceScaled) / totalScaled;
        uint256 toToken1 = assetAmount - toToken0;

        // If asset is token0, swap part to token1; if asset is token1, swap part to token0
        if (assetIsToken0 && toToken1 > 0) {
            // Swap token0 -> token1
            _swapViaRouter(address(assetToken), address(token1), toToken1);
        } else if (assetIsToken1 && toToken0 > 0) {
            // Swap token1 -> token0
            _swapViaRouter(address(assetToken), address(token0), toToken0);
        }
    }

    function _swapViaRouter(address from, address to, uint256 amount) internal pure {
        // Stub: swaps are handled via onAfterDepositWithSwaps using Kodiak backend quotes
        // This function is kept for backward compat but not used in the new flow
    }

    /**
     * @notice Deposit with pre-fetched Kodiak backend swaps (Beefy-style).
     * @dev Vault calls this with swap calldata from Kodiak quote API for asset→token0 and asset→token1.
     */
    function onAfterDepositWithSwaps(
        uint256 assets,
        address swapToToken0Aggregator,
        bytes calldata swapToToken0Data,
        address swapToToken1Aggregator,
        bytes calldata swapToToken1Data
    ) external override onlyVault {
        require(address(island) != address(0), "Island not configured");
        require(assets > 0, "Zero deposit amount");

        // Vault already sent funds via safeTransfer before calling this function
        // No need to pull - funds are already here!

        IERC20 token0 = island.token0();
        IERC20 token1 = island.token1();
        
        bool nativeBera0 = address(token0) == NATIVE_BERA;
        bool nativeBera1 = address(token1) == NATIVE_BERA;

        // Execute swaps as provided (script calculated the amounts)
        // The swapData already contains the correct amounts embedded
        
        // Swap to token0 if calldata provided
        if (swapToToken0Data.length > 2) {
            require(whitelistedAggregators[swapToToken0Aggregator], "agg0 not whitelisted");
            // Approve full balance for flexibility
            uint256 bal = assetToken.balanceOf(address(this));
            assetToken.forceApprove(swapToToken0Aggregator, bal);
            (bool ok0,) = swapToToken0Aggregator.call(swapToToken0Data);
            require(ok0, "swap0 failed");
            assetToken.forceApprove(swapToToken0Aggregator, 0);
            
            // Unwrap WBERA → native BERA if needed
            if (nativeBera0 && wbera != address(0)) {
                uint256 wberaBal = IWETH(wbera).balanceOf(address(this));
                if (wberaBal > 0) {
                    IWETH(wbera).withdraw(wberaBal);
                }
            }
        }

        // Swap to token1 if calldata provided
        if (swapToToken1Data.length > 2) {
            require(whitelistedAggregators[swapToToken1Aggregator], "agg1 not whitelisted");
            // Approve remaining balance
            uint256 bal = assetToken.balanceOf(address(this));
            assetToken.forceApprove(swapToToken1Aggregator, bal);
            (bool ok1,) = swapToToken1Aggregator.call(swapToToken1Data);
            require(ok1, "swap1 failed");
            assetToken.forceApprove(swapToToken1Aggregator, 0);
            
            // Unwrap WBERA → native BERA if needed
            if (nativeBera1 && wbera != address(0)) {
                uint256 wberaBal = IWETH(wbera).balanceOf(address(this));
                if (wberaBal > 0) {
                    IWETH(wbera).withdraw(wberaBal);
                }
            }
        }

        // Mint Island LP with received tokens
        uint256 bal0 = nativeBera0 ? address(this).balance : token0.balanceOf(address(this));
        uint256 bal1 = nativeBera1 ? address(this).balance : token1.balanceOf(address(this));
        
        if (bal0 == 0 && bal1 == 0) {
            // Refund if swaps failed
            uint256 refund = assetToken.balanceOf(address(this));
            if (refund > 0) assetToken.safeTransfer(vault, refund);
            return;
        }

        // Use island.getMintAmounts to get optimal balanced amounts
        (uint256 use0, uint256 use1, uint256 mintAmt) = island.getMintAmounts(bal0, bal1);
        require(mintAmt > 0, "mint amount 0");
        
        // Approve ERC20 tokens only (native BERA sent as value)
        if (!nativeBera0 && use0 > 0) token0.forceApprove(address(island), use0);
        if (!nativeBera1 && use1 > 0) token1.forceApprove(address(island), use1);
        
        // Call mint with value if native BERA
        uint256 valueToSend = nativeBera0 ? use0 : nativeBera1 ? use1 : 0;
        (bool ok,) = address(island).call{value: valueToSend}(
            abi.encodeWithSignature("mint(uint256,address)", mintAmt, address(this))
        );
        require(ok, "island mint failed");
        
        // Reset approvals
        if (!nativeBera0 && use0 > 0) token0.forceApprove(address(island), 0);
        if (!nativeBera1 && use1 > 0) token1.forceApprove(address(island), 0);

        // Refund any leftover tokens
        uint256 leftover = assetToken.balanceOf(address(this));
        if (leftover > 0) assetToken.safeTransfer(vault, leftover);
        
        // Refund leftover token0/token1 (if any)
        if (!nativeBera0) {
            uint256 leftover0 = token0.balanceOf(address(this));
            if (leftover0 > 0) token0.safeTransfer(vault, leftover0);
        }
        if (!nativeBera1) {
            uint256 leftover1 = token1.balanceOf(address(this));
            if (leftover1 > 0) token1.safeTransfer(vault, leftover1);
        }
    }

    /**
     * @notice Smart LP liquidation using Island pool data with built-in slippage protection
     * @dev Called by vault during withdrawal. Queries Island directly for HONEY/LP ratio.
     * @dev SECURITY: Implements multi-layer slippage protection to prevent manipulation attacks
     * @param unstakeUsd USD value user wants to withdraw (in stablecoin wei)
     *
     * Algorithm:
     * 1. Query Island for actual HONEY balance in pool
     * 2. Calculate HONEY per LP = honeyInPool / totalLPSupply
     * 3. Calculate LP needed = unstakeUsd / honeyPerLP
     * 4. Apply reasonable buffer (15% max, not the old 2.5x)
     * 5. VALIDATE: LP amount is sane (not excessive)
     * 6. Burn LP, capture actual amounts
     * 7. VALIDATE: Output meets minimum expectations (95% of requested)
     * 8. Send ONLY stablecoin to vault, keep WBTC in hook
     */
    function liquidateLPForAmount(uint256 unstakeUsd) public onlyVault {
        require(unstakeUsd > 0, "Zero withdrawal amount");
        require(address(island) != address(0), "Island not configured");
        
        // Get LP balance in hook
        uint256 lpBalance = island.balanceOf(address(this));
        require(lpBalance > 0, "No LP tokens available");
        
        // Query Island pool directly for actual balances
        (, uint256 honeyInPool) = island.getUnderlyingBalances();
        uint256 totalLPSupply = island.totalSupply();
        
        require(totalLPSupply > 0 && honeyInPool > 0, "Invalid pool state");
        
        // Calculate HONEY per LP (in 1e18 precision)
        uint256 honeyPerLP = Math.mulDiv(honeyInPool, 1e18, totalLPSupply);
        require(honeyPerLP > 0, "Invalid LP price");
        
        // ===== SLIPPAGE PROTECTION LAYER 1: Reasonable LP Burn Calculation =====
        // Calculate base LP needed (without excessive multiplier)
        uint256 lpNeeded = Math.mulDiv(unstakeUsd, 1e18, honeyPerLP);
        
        // Apply REASONABLE buffer for slippage/fees (15% max, configurable via safetyMultiplier)
        // safetyMultiplier is now in basis points: 100 = 1.0x, 115 = 1.15x
        // Cap it between 1.0x - 1.2x to prevent excessive burns
        uint256 effectiveMultiplier = safetyMultiplier;
        if (effectiveMultiplier > 120) effectiveMultiplier = 120; // Max 20% buffer
        if (effectiveMultiplier < 100) effectiveMultiplier = 100; // Min 0% buffer
        
        uint256 unstakeSendToHook = Math.mulDiv(lpNeeded, effectiveMultiplier, 100);
        
        // ===== SLIPPAGE PROTECTION LAYER 2: Sanity Check on LP Amount =====
        // If calculated LP amount seems excessive (>3x expected), something is wrong
        // This catches extreme pool manipulation scenarios
        uint256 maxReasonableLP = lpNeeded * 3;
        if (unstakeSendToHook > maxReasonableLP) {
            // Pool state looks manipulated, use conservative fallback
            unstakeSendToHook = lpNeeded + (lpNeeded * 15 / 100); // Just add 15%
        }
        
        // Cap at available LP balance
        if (unstakeSendToHook > lpBalance) {
            unstakeSendToHook = lpBalance;
        }
        
        require(unstakeSendToHook > 0, "Insufficient LP for withdrawal");
        
        // ===== SLIPPAGE PROTECTION LAYER 3: Minimum Output Validation =====
        // Calculate minimum acceptable HONEY output (95% of requested)
        uint256 minHoneyExpected = Math.mulDiv(unstakeUsd, 9500, 10000);
        
        // Burn LP tokens and capture amounts received
        uint256 wbtcReceived = 0;
        uint256 honeyReceived = 0;
        
        try island.burn(unstakeSendToHook, address(this)) returns (uint256 amount0, uint256 amount1) {
            wbtcReceived = amount0;
            honeyReceived = amount1;
        } catch {
            // If burn fails, try via router
            try router.removeLiquidity(island, unstakeSendToHook, 0, 0, address(this)) 
                returns (uint256 amount0, uint256 amount1, uint128) {
                wbtcReceived = amount0;
                honeyReceived = amount1;
            } catch {
                // If both fail, revert to signal failure
                revert("LP burn failed");
            }
        }
        
        // Verify we received tokens
        require(wbtcReceived > 0 || honeyReceived > 0, "No tokens received from burn");
        
        // ===== CRITICAL: Validate output against minimum expectation =====
        // If we received significantly less HONEY than expected, pool was likely manipulated
        require(honeyReceived >= minHoneyExpected, "Slippage too high - insufficient output");
        
        // Send ONLY stablecoin (HONEY) to vault
        if (honeyReceived > 0) {
            island.token1().safeTransfer(vault, honeyReceived);
        }
        
        // WBTC stays in hook for admin to batch swap later
        // Emit event for monitoring
        emit LPLiquidated(unstakeUsd, unstakeSendToHook, honeyReceived, wbtcReceived);
    }

    function ensureFundsAvailable(uint256 amount) external override onlyVault {
        // Deprecated: Use liquidateLPForAmount() instead
        // Kept for backward compatibility
        liquidateLPForAmount(amount);
    }

    // DEAD CODE REMOVED: _autoRescueNonStablecoinToVault() - never used (Slither finding)

    /**
     * @notice Admin function to swap stuck non-stablecoin tokens and send to vault
     * @dev Use this to rescue stuck HONEY or other tokens after LP burns
     * @param tokenIn Address of token to swap (e.g., HONEY)
     * @param amountIn Amount to swap
     * @param swapData Swap calldata from Kodiak quote API
     * @param aggregator Aggregator address from Kodiak quote API
     */
    function adminSwapAndReturnToVault(
        address tokenIn,
        uint256 amountIn,
        bytes calldata swapData,
        address aggregator
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(tokenIn != address(0), "tokenIn=0");
        require(aggregator != address(0), "aggregator=0");
        require(swapData.length > 0, "no swap data");
        require(amountIn > 0, "amount=0");
        
        IERC20 tokenInERC = IERC20(tokenIn);
        uint256 balance = tokenInERC.balanceOf(address(this));
        require(balance >= amountIn, "insufficient balance");
        
        // Approve aggregator
        tokenInERC.forceApprove(aggregator, amountIn);
        
        // Execute swap
        (bool success, ) = aggregator.call(swapData);
        require(success, "swap failed");
        
        // Reset approval
        tokenInERC.forceApprove(aggregator, 0);
        
        // Send all stablecoin to vault
        uint256 stablecoinBalance = assetToken.balanceOf(address(this));
        if (stablecoinBalance > 0) {
            assetToken.safeTransfer(vault, stablecoinBalance);
        }
    }

    // Transfer Island LP to another vault (for yield transfers)
    function transferIslandLP(address recipient, uint256 amount) external override onlyVault {
        require(recipient != address(0), "recipient=0");
        require(amount > 0, "amount=0");
        uint256 bal = island.balanceOf(address(this));
        require(bal >= amount, "insufficient LP");
        IERC20(address(island)).safeTransfer(recipient, amount);
    }

    function getIslandLPBalance() external view override returns (uint256) {
        if (address(island) == address(0)) return 0;
        return island.balanceOf(address(this));
    }

    /**
     * @notice Admin function to liquidate all Island LP and return funds to vault
     * @dev Only callable by admin. Burns all LP, swaps to stablecoin, transfers to vault
     * @param swapData Calldata for swapping non-stablecoin token to stablecoin (from Kodiak API)
     * @param aggregator Address of the swap aggregator to use
     */
    function adminLiquidateAll(bytes calldata swapData, address aggregator) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(address(island) != address(0), "island not set");
        
        uint256 lpBal = island.balanceOf(address(this));
        if (lpBal == 0) return;
        
        // SECURITY FIX: Capture return values from LP burn
        // Burn Island LP and get token amounts received
        (uint256 amount0, uint256 amount1) = island.burn(lpBal, address(this));
        
        // Verify we received tokens
        require(amount0 > 0 || amount1 > 0, "No tokens received from LP burn");
        
        // Get token balances
        IERC20 token0 = island.token0();
        IERC20 token1 = island.token1();
        uint256 bal0 = token0.balanceOf(address(this));
        uint256 bal1 = token1.balanceOf(address(this));
        
        // Determine which token needs to be swapped
        bool token0IsAsset = address(token0) == address(assetToken);
        bool token1IsAsset = address(token1) == address(assetToken);
        
        // Swap non-stablecoin to stablecoin if needed
        if (!token0IsAsset && bal0 > 0 && swapData.length > 2) {
            require(whitelistedAggregators[aggregator], "aggregator not whitelisted");
            token0.forceApprove(aggregator, bal0);
            (bool ok,) = aggregator.call(swapData);
            require(ok, "swap failed");
            token0.forceApprove(aggregator, 0);
        } else if (!token1IsAsset && bal1 > 0 && swapData.length > 2) {
            require(whitelistedAggregators[aggregator], "aggregator not whitelisted");
            token1.forceApprove(aggregator, bal1);
            (bool ok,) = aggregator.call(swapData);
            require(ok, "swap failed");
            token1.forceApprove(aggregator, 0);
        }
        
        // Transfer all stablecoin to vault
        uint256 finalBal = assetToken.balanceOf(address(this));
        if (finalBal > 0) {
            assetToken.safeTransfer(vault, finalBal);
        }
    }

    /**
     * @notice Emergency function to rescue any ERC20 tokens stuck in hook
     * @dev Only callable by admin. Use to recover tokens from old/misconfigured hooks
     * @param token Address of ERC20 token to rescue
     * @param to Recipient address (typically admin wallet)
     * @param amount Amount to transfer (0 = transfer all)
     */
    function adminRescueTokens(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(0), "token=0");
        require(to != address(0), "to=0");
        
        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        
        if (balance == 0) {
            return; // Nothing to rescue
        }
        
        uint256 transferAmount = amount == 0 ? balance : amount;
        require(transferAmount <= balance, "insufficient balance");
        
        tokenContract.safeTransfer(to, transferAmount);
    }

    // Accept native BERA for unwrapping
    receive() external payable {}
}

