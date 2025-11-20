// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IKodiakVaultHook} from "../../src/integrations/IKodiakVaultHook.sol";

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
        uint256,
        address,
        bytes calldata,
        address,
        bytes calldata
    ) external pure {}
    
    function ensureFundsAvailable(uint256) external pure {}
    
    function liquidateLPForAmount(uint256) external pure {}
}

