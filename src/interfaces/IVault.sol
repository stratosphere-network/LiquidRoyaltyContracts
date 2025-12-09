// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IKodiakVaultHook} from "../integrations/IKodiakVaultHook.sol";

/**
 * @title IVault
 * @notice Base vault interface for Senior, Junior, and Reserve vaults
 * @dev Common functionality across all three vault types
 * 
 * References from Mathematical Specification:
 * - Section: Notation & Definitions (State Variables)
 * - Instructions: Vault Architecture (stablecoin Holdings)
 */
interface IVault {
    /// @dev Events
    event VaultValueUpdated(uint256 oldValue, uint256 newValue, int256 profitBps);
    event Deposit(address indexed user, uint256 assets, uint256 shares);
    event Withdraw(address indexed user, uint256 assets, uint256 shares);
    event FeesCollected(uint256 managementFee, uint256 performanceFee);
    
    /// @dev Errors
    error InvalidAmount();
    error InsufficientBalance();
    error InsufficientShares();  // N8 FIX: Slippage protection for LP deposits
    error DepositCapExceeded();
    error Unauthorized();
    
    /**
     * @notice Get current vault value in USD
     * @dev Reference: State Variables (V_s, V_j, V_r)
     * Updated monthly by keeper based on stablecoin prices
     * @return value Current USD value of vault assets
     */
    function vaultValue() external view returns (uint256 value);
    
    /**
     * @notice Get stablecoin held by vault
     * @dev Reference: Instructions - Vault Architecture
     * Vaults hold stablecoins (e.g., USDe-SAIL), not pure stablecoins
     * @return stablecoin Address of stablecoin
     */
    function stablecoin() external view returns (IERC20 stablecoin);
    
    /**
     * @notice Get deposit token (typically USDE)
     * @return depositToken Address of deposit token
     */
    function depositToken() external view returns (IERC20 depositToken);
    
    /**
     * @notice Update vault value based on off-chain profit calculation
     * @dev Reference: Instructions - Monthly Rebase Flow (Step 1-3)
     * Called by admin with stablecoin profit/loss percentage
     * @param profitBps Profit/loss in basis points (250 = 2.5%, -1000 = -10%)
     */
    function updateVaultValue(int256 profitBps) external;
    
    /**
     * @notice Get last value update timestamp
     * @dev Reference: State Variables (T_r - last rebase timestamp)
     * @return timestamp Last time vault value was updated
     */
    function lastUpdateTime() external view returns (uint256 timestamp);
    
    /**
     * @notice Get Senior vault address (for Junior/Reserve)
     * @return seniorVault Address of Senior vault
     */
    function seniorVault() external view returns (address seniorVault);
    
    /**
     * @notice Get Kodiak vault hook address
     * @return hook Address of Kodiak vault hook
     */
    function kodiakHook() external view returns (IKodiakVaultHook hook);
    
    // Note: deposit, withdraw, previewDeposit, previewWithdraw, totalAssets
    // are defined in ERC4626 standard for Junior/Reserve vaults
    // Senior vault implements custom deposit/withdraw with snrUSD
}

