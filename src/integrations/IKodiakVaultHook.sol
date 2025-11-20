// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title IKodiakVaultHook
 * @notice Minimal hook interface the vaults call to integrate with Kodiak Islands/Router.
 *         Implementations should handle adding liquidity after deposits and freeing
 *         stablecoins before withdrawals (e.g., by removing liquidity via Island Router).
 */
interface IKodiakVaultHook {
    /**
     * @notice Called by the vault immediately after assets are deposited into the vault.
     * @dev Implementations may pull `assets` from the vault (requires prior approval)
     *      and deposit them to Kodiak (single-sided via Island Router or double-sided).
     * @param assets Amount of stablecoin assets newly deposited into the vault (asset decimals)
     */
    function onAfterDeposit(uint256 assets) external;

    /**
     * @notice Deposit with pre-computed swaps from Kodiak backend (Beefy-style double-sided).
     * @param assets Amount to deposit
     * @param swapToToken0Aggregator Aggregator address for asset→token0 swap
     * @param swapToToken0Data Calldata for asset→token0 swap
     * @param swapToToken1Aggregator Aggregator address for asset→token1 swap (can be same)
     * @param swapToToken1Data Calldata for asset→token1 swap
     */
    function onAfterDepositWithSwaps(
        uint256 assets,
        address swapToToken0Aggregator,
        bytes calldata swapToToken0Data,
        address swapToToken1Aggregator,
        bytes calldata swapToToken1Data
    ) external;

    /**
     * @notice Called by the vault before transferring out assets to the user.
     * @dev Implementations must ensure at least `amount` stablecoins are available
     *      in the vault by the end of the call (e.g., remove liquidity and send
     *      assets back to the vault).
     * @param amount Amount of stablecoin assets the vault needs available (asset decimals)
     */
    function ensureFundsAvailable(uint256 amount) external;

    /**
     * @notice Smart LP liquidation using statistical estimation and safety buffer
     * @dev Called by vault during withdrawal. Uses configurable buffer to handle slippage efficiently.
     * @param unstake_usd USD value user wants to withdraw
     */
    function liquidateLPForAmount(uint256 unstake_usd) external;

    /**
     * @notice Transfer Island LP tokens from the hook to a recipient vault (for yield transfers).
     */
    function transferIslandLP(address recipient, uint256 amount) external;

    /**
     * @notice Get Island LP balance held by this hook.
     */
    function getIslandLPBalance() external view returns (uint256);
    
    /**
     * @notice Admin function to swap tokens in hook and return stablecoin to vault
     * @dev Used for converting tokens to stablecoin in hook
     */
    function adminSwapAndReturnToVault(
        address tokenIn,
        uint256 amountIn,
        bytes calldata swapData,
        address aggregator
    ) external;
    
    /**
     * @notice Admin function to rescue tokens from hook to specified address
     * @dev Used for recovering WBTC or other tokens
     */
    function adminRescueTokens(
        address token,
        address to,
        uint256 amount
    ) external;
    
    /**
     * @notice Admin function to liquidate all LP and swap to desired token
     * @dev Used for exiting LP positions completely
     */
    function adminLiquidateAll(
        bytes calldata swapData,
        address aggregator
    ) external;
}