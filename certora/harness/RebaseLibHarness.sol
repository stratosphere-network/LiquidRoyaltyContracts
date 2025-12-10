// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/libraries/RebaseLib.sol";
import "../../src/libraries/MathLib.sol";
import "../../src/libraries/FeeLib.sol";

/**
 * @title RebaseLibHarness
 * @notice Harness contract to expose RebaseLib internal functions for Certora verification
 * @dev Wraps all RebaseLib functions for formal verification
 */
contract RebaseLibHarness {
    using RebaseLib for uint256;
    
    /**
     * @notice Dynamically select highest APY that maintains peg
     * @dev Reference: Math Spec Section 5.1 Step 2 (Dynamic APY Selection)
     * Algorithm: 13% → 12% → 11% waterfall
     */
    function selectDynamicAPY(
        uint256 currentSupply,
        uint256 netVaultValue,
        uint256 timeElapsed,
        uint256 mgmtFeeTokens
    ) external pure returns (
        uint256 selectedRate,
        uint256 newSupply,
        uint256 userTokens,
        uint256 feeTokens,
        uint8 apyTier,
        bool backstopNeeded
    ) {
        RebaseLib.APYSelection memory selection = RebaseLib.selectDynamicAPY(
            currentSupply,
            netVaultValue,
            timeElapsed,
            mgmtFeeTokens
        );
        
        return (
            selection.selectedRate,
            selection.newSupply,
            selection.userTokens,
            selection.feeTokens,
            selection.apyTier,
            selection.backstopNeeded
        );
    }
    
    /**
     * @notice Calculate new rebase index
     * @dev Reference: Math Spec Section 5.1 Step 5
     * Formula: I_new = I_old × (1 + r_selected × timeScaling)
     */
    function calculateNewIndex(
        uint256 oldIndex,
        uint256 selectedRate,
        uint256 timeElapsed
    ) external pure returns (uint256) {
        return RebaseLib.calculateNewIndex(
            oldIndex,
            selectedRate,
            timeElapsed
        );
    }
    
    /**
     * @notice Simulate all three APY tiers
     * @dev Useful for verification - returns backing ratios for all APYs
     */
    function simulateAllAPYs(
        uint256 currentSupply,
        uint256 netVaultValue,
        uint256 timeElapsed,
        uint256 mgmtFeeTokens
    ) external pure returns (
        uint256 backing13,
        uint256 backing12,
        uint256 backing11
    ) {
        return RebaseLib.simulateAllAPYs(
            currentSupply,
            netVaultValue,
            timeElapsed,
            mgmtFeeTokens
        );
    }
    
    /**
     * @notice Get APY in basis points from tier
     */
    function getAPYInBps(uint8 apyTier) external pure returns (uint256) {
        return RebaseLib.getAPYInBps(apyTier);
    }
    
    /**
     * @notice Get monthly rate from APY tier
     */
    function getMonthlyRate(uint8 apyTier) external pure returns (uint256) {
        return RebaseLib.getMonthlyRate(apyTier);
    }
}

