// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IKodiakIsland} from "../integrations/IKodiakIsland.sol";
import {IKodiakVaultHook} from "../integrations/IKodiakVaultHook.sol";

/**
 * @title LPPriceOracle
 * @notice Calculate LP token price using ONLY pool data - zero external dependencies!
 * @dev Works for any pool with one stablecoin (uses pool ratio as price oracle)
 */
library LPPriceOracle {
    
    /**
     * @notice Calculate LP token price using pool ratio
     * @dev Assumes one token is a stablecoin ($1). Pool ratio determines other token's price.
     * @param island Kodiak Island address
     * @param stablecoinIsToken0 True if token0 is the stablecoin
     * @return lpPrice LP token price in USD (18 decimals)
     */
    function calculateLPPrice(
        address island,
        bool stablecoinIsToken0
    ) internal view returns (uint256 lpPrice) {
        IKodiakIsland islandContract = IKodiakIsland(island);
        
        // Get pool state
        (uint256 amt0, uint256 amt1) = islandContract.getUnderlyingBalances();
        uint256 totalLP = islandContract.totalSupply();
        
        if (totalLP == 0) return 0;
        
        // Get token info
        IERC20 token0 = islandContract.token0();
        IERC20 token1 = islandContract.token1();
        
        uint8 decimals0 = _getDecimals(address(token0));
        uint8 decimals1 = _getDecimals(address(token1));
        
        // Normalize to 18 decimals
        uint256 amt0In18 = _normalize(amt0, decimals0);
        uint256 amt1In18 = _normalize(amt1, decimals1);
        
        // Calculate total value
        // KEY INSIGHT: In AMMs (Uniswap V2, Kodiak), the value of both sides is ALWAYS equal
        // due to the constant product formula (x * y = k). Arbitrage keeps it balanced.
        // Therefore: stablecoin_value = other_token_value
        // So: total_value = 2 * stablecoin_value
        //
        // This is MORE accurate and gas-efficient than calculating price ratios!
        uint256 totalValue;
        
        if (stablecoinIsToken0) {
            // Token0 = stablecoin, so total value = 2 * token0 value
            totalValue = amt0In18 * 2;
        } else {
            // Token1 = stablecoin, so total value = 2 * token1 value
            totalValue = amt1In18 * 2;
        }
        
        // LP price = total value / total LP supply
        // Both totalValue and totalLP are in 18 decimals
        // Division would give us a base value, so we multiply by 1e18 to maintain precision
        // Formula: (value_in_18_decimals * 1e18) / lp_in_18_decimals = price_in_18_decimals
        lpPrice = (totalValue * 1e18) / totalLP;
    }
    
    /**
     * @notice Calculate vault value from hook's LP holdings
     * @param hook Kodiak vault hook address
     * @param island Kodiak Island address
     * @param stablecoinIsToken0 True if token0 is the stablecoin
     * @return vaultValue Total vault value in USD (18 decimals)
     */
    function calculateVaultValue(
        address hook,
        address island,
        bool stablecoinIsToken0
    ) internal view returns (uint256 vaultValue) {
        // Get LP balance from hook
        uint256 lpBalance = IKodiakVaultHook(hook).getIslandLPBalance();
        
        if (lpBalance == 0) return 0;
        
        // Calculate LP price
        uint256 lpPrice = calculateLPPrice(island, stablecoinIsToken0);
        
        // Vault value = LP balance × LP price
        vaultValue = (lpBalance * lpPrice) / 1e18;
    }
    
    /**
     * @notice Calculate vault value including idle stablecoin
     * @param hook Kodiak vault hook address
     * @param island Kodiak Island address
     * @param stablecoinIsToken0 True if token0 is the stablecoin
     * @param vaultAddress Vault address (for idle balance check)
     * @param stablecoin Stablecoin token address
     * @return totalValue Total vault value (LP + idle) in USD (18 decimals)
     */
    function calculateTotalVaultValue(
        address hook,
        address island,
        bool stablecoinIsToken0,
        address vaultAddress,
        address stablecoin
    ) internal view returns (uint256 totalValue) {
        // LP value
        uint256 lpValue = calculateVaultValue(hook, island, stablecoinIsToken0);
        
        // Idle stablecoin in vault
        uint256 idleBalance = IERC20(stablecoin).balanceOf(vaultAddress);
        uint8 stablecoinDecimals = _getDecimals(stablecoin);
        uint256 idleValue = _normalize(idleBalance, stablecoinDecimals);
        
        // Total value
        totalValue = lpValue + idleValue;
    }
    
    /**
     * @notice Normalize token amount to 18 decimals
     */
    function _normalize(uint256 amount, uint8 decimals) 
        private 
        pure 
        returns (uint256) 
    {
        if (decimals == 18) return amount;
        if (decimals < 18) return amount * 10**(18 - decimals);
        return amount / 10**(decimals - 18);
    }
    
    /**
     * @notice Get token decimals safely
     */
    function _getDecimals(address token) private view returns (uint8) {
        // Try to get decimals, default to 18 if call fails
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSignature("decimals()")
        );
        
        if (success && data.length >= 32) {
            return abi.decode(data, (uint8));
        }
        
        return 18;  // Default to 18 decimals
    }
}

