// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IKodiakVaultHook} from "../../src/integrations/IKodiakVaultHook.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";

/**
 * @title MockKodiakHook
 * @notice Mock Kodiak hook for testing
 */
contract MockKodiakHook is IKodiakVaultHook {
    address public vault;
    address public island;
    IERC20 public lpToken;
    
    constructor(address vault_, address island_, address lpToken_) {
        vault = vault_;
        island = island_;
        lpToken = IERC20(lpToken_);
    }
    
    function getIslandLPBalance() external view returns (uint256) {
        return lpToken.balanceOf(address(this));
    }
    
    function transferIslandLP(address to, uint256 amount) external {
        lpToken.transfer(to, amount);
    }
    
    function harvest() external pure returns (uint256) {
        return 0;
    }
    
    function emergencyWithdrawLP(address to) external {
        uint256 balance = lpToken.balanceOf(address(this));
        if (balance > 0) {
            lpToken.transfer(to, balance);
        }
    }
    
    function onAfterDeposit(uint256) external pure {}
    
    function onAfterDepositWithSwaps(
        uint256 amount,
        address,
        bytes calldata,
        address,
        bytes calldata
    ) external {
        // Mock: Mint LP tokens
        // If amount is in 8 decimals (WBTC), convert to 18 decimals LP
        // 1 WBTC (1e8) = 50,000 LP (50000e18)
        uint256 lpToMint;
        if (amount < 1e12) {
            // Looks like WBTC (8 decimals), convert to LP
            lpToMint = (amount * 50000e18) / 1e8;
        } else {
            // Already in 18 decimals (stablecoin), mint 1:1
            lpToMint = amount;
        }
        MockERC20(address(lpToken)).mint(address(this), lpToMint);
    }
    
    function ensureFundsAvailable(uint256) external pure {}
    
    function liquidateLPForAmount(uint256) external pure {}
    
    function adminSwapAndReturnToVault(
        address,
        uint256,
        bytes calldata,
        address
    ) external pure {}
    
    function adminRescueTokens(
        address token,
        address to,
        uint256 amount
    ) external {
        if (amount > 0 && token != address(0) && to != address(0)) {
            IERC20(token).transfer(to, amount);
        }
    }
    
    function adminLiquidateAll(
        bytes calldata,
        address
    ) external pure {}
}

