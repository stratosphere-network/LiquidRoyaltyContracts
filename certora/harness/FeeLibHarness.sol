// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/libraries/FeeLib.sol";
import "../../src/libraries/MathLib.sol";

/**
 * @title FeeLibHarness
 * @notice Harness contract to expose FeeLib internal functions for Certora verification
 * @dev Wraps all FeeLib functions for formal verification
 */
contract FeeLibHarness {
    using FeeLib for uint256;
    
    /**
     * @notice Calculate monthly management fee
     * @dev Reference: Math Spec Section 6.1
     * Formula: F_mgmt = V(t) × (f_mgmt / 12)
     */
    function calculateManagementFee(
        uint256 vaultValue
    ) external pure returns (uint256) {
        return FeeLib.calculateManagementFee(vaultValue);
    }
    
    /**
     * @notice Calculate performance fee tokens
     * @dev Reference: Math Spec Section 6.2
     * Formula: S_fee = S_users × 0.02
     */
    function calculatePerformanceFee(
        uint256 userTokensMinted
    ) external pure returns (uint256) {
        return FeeLib.calculatePerformanceFee(userTokensMinted);
    }
    
    /**
     * @notice Calculate early withdrawal penalty
     * @dev Reference: Math Spec Section 6.4
     * Formula: P(w, t_c) = w × f_penalty if (t - t_c < τ)
     */
    function calculateWithdrawalPenalty(
        uint256 withdrawalAmount,
        uint256 cooldownStartTime,
        uint256 currentTime
    ) external pure returns (uint256 penalty, uint256 netAmount) {
        return FeeLib.calculateWithdrawalPenalty(
            withdrawalAmount,
            cooldownStartTime,
            currentTime
        );
    }
    
    /**
     * @notice Calculate management fee tokens (TIME-BASED)
     * @dev Reference: Math Spec Section 5.1 Step 1
     * Formula: S_mgmt = V_s × 1% × (timeElapsed / 365 days)
     */
    function calculateManagementFeeTokens(
        uint256 vaultValue,
        uint256 timeElapsed
    ) external pure returns (uint256) {
        return FeeLib.calculateManagementFeeTokens(vaultValue, timeElapsed);
    }
    
    /**
     * @notice Calculate total supply after rebase
     * @dev Reference: Math Spec Section 5.1 Step 2
     * Formula: S_new = S + S_users + S_fee + S_mgmt
     */
    function calculateRebaseSupply(
        uint256 currentSupply,
        uint256 monthlyRate,
        uint256 timeElapsed,
        uint256 mgmtFeeTokens
    ) external pure returns (
        uint256 newSupply,
        uint256 userTokens,
        uint256 feeTokens
    ) {
        return FeeLib.calculateRebaseSupply(
            currentSupply,
            monthlyRate,
            timeElapsed,
            mgmtFeeTokens
        );
    }
    
    /**
     * @notice Calculate new rebase index
     * @dev Reference: Math Spec Section 5.1 Step 5
     * Formula: I_new = I_old × (1 + r_selected × timeScaling)
     */
    function calculateNewRebaseIndex(
        uint256 oldIndex,
        uint256 monthlyRate,
        uint256 timeElapsed
    ) external pure returns (uint256) {
        return FeeLib.calculateNewRebaseIndex(
            oldIndex,
            monthlyRate,
            timeElapsed
        );
    }
    
    // Helper functions for verification
    
    /**
     * @notice Get seconds per year constant
     */
    function SECONDS_PER_YEAR() external pure returns (uint256) {
        return 365 days;
    }
    
    /**
     * @notice Get seconds per month constant
     */
    function SECONDS_PER_MONTH() external pure returns (uint256) {
        return 30 days;
    }
}

