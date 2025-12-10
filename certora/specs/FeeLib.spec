/**
 * @title FeeLib Formal Verification Specification
 * @notice Certora CVL specification for fee calculation formulas
 * @dev Verifies formulas from Math Spec Section 6 (Fee Structure)
 * 
 * Mathematical Properties Verified:
 * 1. Management Fee (TIME-BASED): S_mgmt = V_s × 1% × (t_elapsed / 365 days)
 * 2. Performance Fee: S_fee = S_users × 2%
 * 3. Withdrawal Penalty: P(w, t_c) = w × 20% if (t - t_c < 7 days)
 * 4. Rebase Supply: S_new = S + S_users + S_fee + S_mgmt
 * 5. Rebase Index: I_new = I_old × (1 + r_selected × timeScaling)
 * 6. Time-based scaling correctness
 */

using FeeLibHarness as feeLib;
using MathLibHarness as mathLib;

methods {
    // Fee calculation functions
    function calculateManagementFee(uint256) external returns (uint256) envfree;
    function calculatePerformanceFee(uint256) external returns (uint256) envfree;
    function calculateWithdrawalPenalty(uint256, uint256, uint256) external returns (uint256, uint256) envfree;
    function calculateManagementFeeTokens(uint256, uint256) external returns (uint256) envfree;
    function calculateRebaseSupply(uint256, uint256, uint256, uint256) external returns (uint256, uint256, uint256) envfree;
    function calculateNewRebaseIndex(uint256, uint256, uint256) external returns (uint256) envfree;
    
    // Helper constants
    function SECONDS_PER_YEAR() external returns (uint256) envfree;
    function SECONDS_PER_MONTH() external returns (uint256) envfree;
    
    // MathLib constants
    function _.PRECISION() external => DISPATCHER(true);
    function _.MGMT_FEE_ANNUAL() external => DISPATCHER(true);
    function _.PERF_FEE() external => DISPATCHER(true);
    function _.EARLY_WITHDRAWAL_PENALTY() external => DISPATCHER(true);
    function _.COOLDOWN_PERIOD() external => DISPATCHER(true);
}

// ============================================
// INVARIANTS - Fee Constants
// ============================================

/**
 * @title INV-FEE-001: Time constants are correct
 * @notice Verifies time period constants
 */
invariant timeConstantsCorrect()
    feeLib.SECONDS_PER_YEAR() == 31536000 &&  // 365 days
    feeLib.SECONDS_PER_MONTH() == 2592000;     // 30 days

// ============================================
// RULES - Management Fee (TIME-BASED)
// ============================================

/**
 * @title RULE-FEE-001: Management fee formula (monthly)
 * @notice Verifies F_mgmt = V × (1% / 12)
 * @dev Reference: Math Spec Section 6.1
 */
rule managementFeeMonthlyFormula(uint256 vaultValue) {
    require vaultValue > 0;
    require vaultValue < max_uint256 / mathLib.MGMT_FEE_ANNUAL();
    
    uint256 fee = feeLib.calculateManagementFee(vaultValue);
    
    // Property: fee = vaultValue × 0.01 / 12
    uint256 expected = (vaultValue * mathLib.MGMT_FEE_ANNUAL()) / (12 * mathLib.PRECISION());
    
    assert fee == expected,
        "Management fee formula violated";
}

/**
 * @title RULE-FEE-002: Management fee tokens (time-based)
 * @notice Verifies S_mgmt = V_s × 1% × (timeElapsed / 365 days)
 * @dev Reference: Math Spec Section 5.1 Step 1
 */
rule managementFeeTokensTimeBased(uint256 vaultValue, uint256 timeElapsed) {
    require vaultValue > 0;
    require timeElapsed > 0;
    require timeElapsed <= feeLib.SECONDS_PER_YEAR();
    require vaultValue < max_uint256 / mathLib.MGMT_FEE_ANNUAL();
    
    uint256 feeTokens = feeLib.calculateManagementFeeTokens(vaultValue, timeElapsed);
    
    // Property: feeTokens = (vaultValue × MGMT_FEE × timeElapsed) / (365 days × PRECISION)
    uint256 expected = (vaultValue * mathLib.MGMT_FEE_ANNUAL() * timeElapsed) / 
                       (feeLib.SECONDS_PER_YEAR() * mathLib.PRECISION());
    
    assert feeTokens == expected,
        "Time-based management fee formula violated";
}

/**
 * @title RULE-FEE-003: Management fee grows linearly with time
 * @notice Doubling time doubles the fee
 */
rule managementFeeLinearWithTime(uint256 vaultValue, uint256 time1, uint256 time2) {
    require time1 > 0;
    require time2 == time1 * 2;
    require time2 <= feeLib.SECONDS_PER_YEAR();
    require vaultValue > 0;
    require vaultValue < max_uint256 / mathLib.MGMT_FEE_ANNUAL();
    
    uint256 fee1 = feeLib.calculateManagementFeeTokens(vaultValue, time1);
    uint256 fee2 = feeLib.calculateManagementFeeTokens(vaultValue, time2);
    
    // Property: fee2 ≈ 2 × fee1 (within rounding)
    assert fee2 >= fee1 * 2 - 1 && fee2 <= fee1 * 2 + 1,
        "Management fee not linear with time";
}

/**
 * @title RULE-FEE-004: 30-day fee equals monthly fee
 * @notice Time-based fee for 30 days should equal monthly fee
 */
rule thirtyDayFeeEqualsMonthly(uint256 vaultValue) {
    require vaultValue > 0;
    require vaultValue < max_uint256 / mathLib.MGMT_FEE_ANNUAL();
    
    uint256 monthlyFee = feeLib.calculateManagementFee(vaultValue);
    uint256 thirtyDayFee = feeLib.calculateManagementFeeTokens(vaultValue, feeLib.SECONDS_PER_MONTH());
    
    // Property: fees should be equal (within rounding tolerance)
    assert monthlyFee >= thirtyDayFee - 1 && monthlyFee <= thirtyDayFee + 1,
        "30-day fee doesn't match monthly fee";
}

// ============================================
// RULES - Performance Fee
// ============================================

/**
 * @title RULE-FEE-005: Performance fee formula correctness
 * @notice Verifies S_fee = S_users × 2%
 * @dev Reference: Math Spec Section 6.2
 */
rule performanceFeeFormula(uint256 userTokens) {
    require userTokens > 0;
    require userTokens < max_uint256 / mathLib.PERF_FEE();
    
    uint256 perfFee = feeLib.calculatePerformanceFee(userTokens);
    
    // Property: perfFee = userTokens × 0.02
    uint256 expected = (userTokens * mathLib.PERF_FEE()) / mathLib.PRECISION();
    
    assert perfFee == expected,
        "Performance fee formula violated: S_fee ≠ S_users × 2%";
}

/**
 * @title RULE-FEE-006: Performance fee is 2% of user tokens
 * @notice Performance fee should be exactly 2% (within precision)
 */
rule performanceFeeIs2Percent(uint256 userTokens) {
    require userTokens >= 100; // Need reasonable size for percentage check
    require userTokens < max_uint256 / mathLib.PERF_FEE();
    
    uint256 perfFee = feeLib.calculatePerformanceFee(userTokens);
    
    // Property: perfFee / userTokens ≈ 0.02
    uint256 ratio = (perfFee * mathLib.PRECISION()) / userTokens;
    uint256 expectedRatio = mathLib.PERF_FEE();
    
    assert ratio >= expectedRatio - 1 && ratio <= expectedRatio + 1,
        "Performance fee not exactly 2%";
}

// ============================================
// RULES - Withdrawal Penalty
// ============================================

/**
 * @title RULE-FEE-007: Withdrawal penalty formula (within cooldown)
 * @notice Verifies P = w × 20% when cooldown not met
 * @dev Reference: Math Spec Section 6.4
 */
rule withdrawalPenaltyWithinCooldown(uint256 amount, uint256 cooldownStart, uint256 currentTime) {
    require amount > 0;
    require cooldownStart > 0;
    require currentTime > cooldownStart;
    require currentTime - cooldownStart < mathLib.COOLDOWN_PERIOD();
    require amount < max_uint256 / mathLib.EARLY_WITHDRAWAL_PENALTY();
    
    uint256 penalty;
    uint256 netAmount;
    (penalty, netAmount) = feeLib.calculateWithdrawalPenalty(amount, cooldownStart, currentTime);
    
    // Property: penalty = amount × 0.20
    uint256 expectedPenalty = (amount * mathLib.EARLY_WITHDRAWAL_PENALTY()) / mathLib.PRECISION();
    
    assert penalty == expectedPenalty,
        "Withdrawal penalty formula violated";
    
    // Property: netAmount = amount - penalty
    assert netAmount == amount - penalty,
        "Net amount calculation incorrect";
}

/**
 * @title RULE-FEE-008: No penalty after cooldown
 * @notice Verifies P = 0 when cooldown met
 */
rule noPenaltyAfterCooldown(uint256 amount, uint256 cooldownStart, uint256 currentTime) {
    require amount > 0;
    require cooldownStart > 0;
    require currentTime >= cooldownStart + mathLib.COOLDOWN_PERIOD();
    
    uint256 penalty;
    uint256 netAmount;
    (penalty, netAmount) = feeLib.calculateWithdrawalPenalty(amount, cooldownStart, currentTime);
    
    // Property: penalty == 0
    assert penalty == 0,
        "Penalty should be 0 after cooldown";
    
    // Property: netAmount == amount
    assert netAmount == amount,
        "Net amount should equal full amount after cooldown";
}

/**
 * @title RULE-FEE-009: Penalty applies if cooldown never initiated
 * @notice Verifies penalty when cooldownStart = 0
 */
rule penaltyWhenNoCooldown(uint256 amount, uint256 currentTime) {
    require amount > 0;
    require currentTime > 0;
    require amount < max_uint256 / mathLib.EARLY_WITHDRAWAL_PENALTY();
    
    uint256 penalty;
    uint256 netAmount;
    (penalty, netAmount) = feeLib.calculateWithdrawalPenalty(amount, 0, currentTime);
    
    // Property: penalty > 0
    assert penalty > 0,
        "Penalty should apply when cooldown never initiated";
    
    // Property: penalty = amount × 20%
    uint256 expectedPenalty = (amount * mathLib.EARLY_WITHDRAWAL_PENALTY()) / mathLib.PRECISION();
    assert penalty == expectedPenalty,
        "Incorrect penalty when cooldown not initiated";
}

// ============================================
// RULES - Rebase Supply Calculation
// ============================================

/**
 * @title RULE-FEE-010: Rebase supply formula correctness
 * @notice Verifies S_new = S + S_users + S_fee + S_mgmt
 * @dev Reference: Math Spec Section 5.1 Step 2
 */
rule rebaseSupplyFormula(uint256 currentSupply, uint256 monthlyRate, uint256 timeElapsed, uint256 mgmtFeeTokens) {
    require currentSupply > 0;
    require monthlyRate > 0;
    require monthlyRate <= mathLib.MAX_MONTHLY_RATE();
    require timeElapsed > 0;
    require timeElapsed <= feeLib.SECONDS_PER_MONTH();
    require currentSupply < max_uint256 / monthlyRate;
    
    uint256 newSupply;
    uint256 userTokens;
    uint256 feeTokens;
    (newSupply, userTokens, feeTokens) = feeLib.calculateRebaseSupply(
        currentSupply,
        monthlyRate,
        timeElapsed,
        mgmtFeeTokens
    );
    
    // Property: newSupply = currentSupply + userTokens + feeTokens + mgmtFeeTokens
    assert newSupply == currentSupply + userTokens + feeTokens + mgmtFeeTokens,
        "Rebase supply formula violated: S_new ≠ S + S_users + S_fee + S_mgmt";
}

/**
 * @title RULE-FEE-011: User tokens scale with time
 * @notice S_users = S × r_month × (timeElapsed / 30 days)
 */
rule userTokensScaleWithTime(uint256 currentSupply, uint256 monthlyRate, uint256 timeElapsed) {
    require currentSupply > 0;
    require monthlyRate > 0;
    require monthlyRate <= mathLib.MAX_MONTHLY_RATE();
    require timeElapsed > 0;
    require timeElapsed <= feeLib.SECONDS_PER_MONTH();
    require currentSupply < max_uint256 / monthlyRate;
    
    uint256 newSupply;
    uint256 userTokens;
    uint256 feeTokens;
    (newSupply, userTokens, feeTokens) = feeLib.calculateRebaseSupply(
        currentSupply,
        monthlyRate,
        timeElapsed,
        0  // no mgmt fee for this test
    );
    
    // Property: userTokens = (currentSupply × monthlyRate × timeElapsed) / (30 days × PRECISION)
    uint256 expected = (currentSupply * monthlyRate * timeElapsed) / 
                       (feeLib.SECONDS_PER_MONTH() * mathLib.PRECISION());
    
    assert userTokens == expected,
        "User tokens time-scaling violated";
}

/**
 * @title RULE-FEE-012: Performance fee is 2% of user tokens
 * @notice Verifies relationship between user tokens and performance fee
 */
rule performanceFeeIn Rebase(uint256 currentSupply, uint256 monthlyRate, uint256 timeElapsed) {
    require currentSupply > 0;
    require monthlyRate > 0;
    require monthlyRate <= mathLib.MAX_MONTHLY_RATE();
    require timeElapsed > 0;
    require timeElapsed <= feeLib.SECONDS_PER_MONTH();
    require currentSupply < max_uint256 / monthlyRate;
    
    uint256 newSupply;
    uint256 userTokens;
    uint256 feeTokens;
    (newSupply, userTokens, feeTokens) = feeLib.calculateRebaseSupply(
        currentSupply,
        monthlyRate,
        timeElapsed,
        0
    );
    
    // Property: feeTokens = userTokens × 0.02
    uint256 expectedFee = (userTokens * mathLib.PERF_FEE()) / mathLib.PRECISION();
    
    assert feeTokens == expectedFee,
        "Performance fee not 2% of user tokens in rebase";
}

// ============================================
// RULES - Rebase Index Calculation
// ============================================

/**
 * @title RULE-FEE-013: Rebase index formula correctness
 * @notice Verifies I_new = I_old × (1 + r_selected × timeScaling)
 * @dev Reference: Math Spec Section 5.1 Step 5
 */
rule rebaseIndexFormula(uint256 oldIndex, uint256 monthlyRate, uint256 timeElapsed) {
    require oldIndex > 0;
    require oldIndex <= mathLib.PRECISION() * 2; // Reasonable upper bound
    require monthlyRate > 0;
    require monthlyRate <= mathLib.MAX_MONTHLY_RATE();
    require timeElapsed > 0;
    require timeElapsed <= feeLib.SECONDS_PER_MONTH();
    
    uint256 newIndex = feeLib.calculateNewRebaseIndex(oldIndex, monthlyRate, timeElapsed);
    
    // Property: newIndex > oldIndex (always increases)
    assert newIndex >= oldIndex,
        "Rebase index didn't increase";
    
    // Calculate expected value
    uint256 scaledRate = (monthlyRate * timeElapsed) / feeLib.SECONDS_PER_MONTH();
    uint256 expected = (oldIndex * (mathLib.PRECISION() + scaledRate)) / mathLib.PRECISION();
    
    assert newIndex == expected,
        "Rebase index formula violated";
}

/**
 * @title RULE-FEE-014: Rebase index grows monotonically
 * @notice Index always increases after rebase
 */
rule rebaseIndexMonotonicGrowth(uint256 oldIndex, uint256 monthlyRate, uint256 timeElapsed) {
    require oldIndex > 0;
    require monthlyRate > 0;
    require monthlyRate <= mathLib.MAX_MONTHLY_RATE();
    require timeElapsed > 0;
    require timeElapsed <= feeLib.SECONDS_PER_MONTH();
    
    uint256 newIndex = feeLib.calculateNewRebaseIndex(oldIndex, monthlyRate, timeElapsed);
    
    // Property: newIndex > oldIndex (strict inequality for positive rate and time)
    assert newIndex > oldIndex,
        "Rebase index not strictly increasing";
}

/**
 * @title RULE-FEE-015: Rebase index proportional to time
 * @notice Doubling time approximately doubles the index growth
 */
rule rebaseIndexProportionalToTime(uint256 oldIndex, uint256 monthlyRate, uint256 time1, uint256 time2) {
    require oldIndex > 0;
    require oldIndex <= mathLib.PRECISION();
    require monthlyRate > 0;
    require monthlyRate <= mathLib.MAX_MONTHLY_RATE();
    require time1 > 0;
    require time2 == time1 * 2;
    require time2 <= feeLib.SECONDS_PER_MONTH();
    
    uint256 index1 = feeLib.calculateNewRebaseIndex(oldIndex, monthlyRate, time1);
    uint256 index2 = feeLib.calculateNewRebaseIndex(oldIndex, monthlyRate, time2);
    
    uint256 growth1 = index1 - oldIndex;
    uint256 growth2 = index2 - oldIndex;
    
    // Property: growth2 ≈ 2 × growth1 (within rounding)
    assert growth2 >= growth1 * 2 - 2 && growth2 <= growth1 * 2 + 2,
        "Rebase index growth not proportional to time";
}

// ============================================
// RULES - Combined Fee Properties
// ============================================

/**
 * @title RULE-FEE-016: Total fee burden is bounded
 * @notice Management + Performance fees should not exceed reasonable limits
 */
rule totalFeesBounded(uint256 vaultValue, uint256 currentSupply, uint256 monthlyRate, uint256 timeElapsed) {
    require vaultValue > 0;
    require currentSupply > 0;
    require monthlyRate > 0;
    require monthlyRate <= mathLib.MAX_MONTHLY_RATE();
    require timeElapsed > 0;
    require timeElapsed <= feeLib.SECONDS_PER_MONTH();
    require vaultValue < max_uint256 / mathLib.MGMT_FEE_ANNUAL();
    require currentSupply < max_uint256 / monthlyRate;
    
    uint256 mgmtFee = feeLib.calculateManagementFeeTokens(vaultValue, timeElapsed);
    
    uint256 newSupply;
    uint256 userTokens;
    uint256 perfFee;
    (newSupply, userTokens, perfFee) = feeLib.calculateRebaseSupply(
        currentSupply,
        monthlyRate,
        timeElapsed,
        mgmtFee
    );
    
    uint256 totalFees = mgmtFee + perfFee;
    
    // Property: Total fees < 5% of current supply (sanity check)
    // Management: max 1%/12 ≈ 0.083%
    // Performance: max 2% of ~1% ≈ 0.02%
    // Total should be well under 1%
    assert totalFees < currentSupply / 20,
        "Total fees exceed 5% threshold";
}

/**
 * @title RULE-FEE-017: Fees don't cause supply overflow
 * @notice Adding fees to supply maintains arithmetic safety
 */
rule feesNoOverflow(uint256 currentSupply, uint256 monthlyRate, uint256 timeElapsed, uint256 mgmtFeeTokens) {
    require currentSupply > 0;
    require monthlyRate > 0;
    require monthlyRate <= mathLib.MAX_MONTHLY_RATE();
    require timeElapsed > 0;
    require timeElapsed <= feeLib.SECONDS_PER_MONTH();
    require currentSupply < max_uint256 / 2; // Reasonable bound
    
    uint256 newSupply;
    uint256 userTokens;
    uint256 feeTokens;
    (newSupply, userTokens, feeTokens) = feeLib.calculateRebaseSupply(
        currentSupply,
        monthlyRate,
        timeElapsed,
        mgmtFeeTokens
    );
    
    // Property: newSupply > currentSupply (sanity)
    assert newSupply > currentSupply,
        "New supply not greater than current supply";
    
    // Property: growth is reasonable (< 2% for monthly rebase)
    uint256 maxGrowth = currentSupply * 2 / 100; // 2%
    assert newSupply - currentSupply <= maxGrowth + mgmtFeeTokens,
        "Supply growth exceeds reasonable bounds";
}

