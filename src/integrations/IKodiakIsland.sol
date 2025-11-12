// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IKodiakIsland is IERC20 {
    function getUnderlyingBalances() external view returns (uint256 amount0Current, uint256 amount1Current);
    function token0() external view returns (IERC20);
    function token1() external view returns (IERC20);
    function pool() external view returns (address);
    function lowerTick() external view returns (int24);
    function upperTick() external view returns (int24);
    
    // Direct mint/burn (Beefy-style)
    function getMintAmounts(uint256 amount0Max, uint256 amount1Max) external view returns (uint256 amount0, uint256 amount1, uint256 mintAmount);
    function mint(uint256 mintAmount, address receiver) external returns (uint256 amount0, uint256 amount1);
    function burn(uint256 burnAmount, address receiver) external returns (uint256 amount0, uint256 amount1);
}

