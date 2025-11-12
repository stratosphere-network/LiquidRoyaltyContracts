// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./IKodiakIsland.sol";

/**
 * @title IKodiakIslandRouter
 * @notice Interface per Kodiak docs for Island Router operations.
 * @dev See: https://documentation.kodiak.finance/developers/kodiak-islands/technical-integration-guide
 */
interface IKodiakIslandRouter {
    struct RouterSwapParams {
        bool zeroForOne;
        uint256 amountIn;
        uint256 minAmountOut;
        bytes routeData;
    }

    function addLiquidity(
        IKodiakIsland island,
        uint256 amount0Max,
        uint256 amount1Max,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 amountSharesMin,
        address receiver
    ) external returns (uint256 amount0, uint256 amount1, uint256 mintAmount);

    function addLiquiditySingle(
        IKodiakIsland island,
        uint256 totalAmountIn,
        uint256 amountSharesMin,
        uint256 maxStakingSlippageBPS,
        RouterSwapParams calldata swapData,
        address receiver
    ) external returns (uint256 amount0, uint256 amount1, uint256 mintAmount);

    function removeLiquidity(
        IKodiakIsland island,
        uint256 burnAmount,
        uint256 amount0Min,
        uint256 amount1Min,
        address receiver
    ) external returns (uint256 amount0, uint256 amount1, uint128 liquidityBurned);

    // Common Kodiak router entrypoints observed on Berachain Mainnet
    function depositSingleToken(
        address island,
        address tokenIn,
        uint256 amountIn,
        uint256 minShares,
        address receiver
    ) external returns (uint256 sharesMinted);

    function depositSingleToken(
        address island,
        address tokenIn,
        uint256 amountIn,
        uint256 minShares,
        address receiver,
        bytes calldata data
    ) external returns (uint256 sharesMinted);
}