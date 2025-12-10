/**
 * @title MathLib Formal Verification Specification
 * @notice Certora CVL specification for core mathematical formulas
 * @dev Verifies formulas from Math Spec Sections 4.2.1 - 4.2.6
 * 
 * Mathematical Properties Verified:
 * 1. User Balance Formula: b_i = σ_i × I
 * 2. Total Supply Formula: S = I × Σ
 * 3. Backing Ratio Formula: R_senior = V_s / S
 * 4. Deposit Cap Formula: S_max = 10 × V_r
 * 5. Precision and rounding properties
 * 6. Overflow/underflow safety
 */

using MathLibHarness as mathLib;

methods {
    // Constants
    function PRECISION() external returns (uint256) envfree;
    function BPS_DENOMINATOR() external returns (uint256) envfree;
    function MIN_APY() external returns (uint256) envfree;
    function MID_APY() external returns (uint256) envfree;
    function MAX_APY() external returns (uint256) envfree;
    function SENIOR_TARGET_BACKING() external returns (uint256) envfree;
    function SENIOR_TRIGGER_BACKING() external returns (uint256) envfree;
    function SENIOR_RESTORE_BACKING() external returns (uint256) envfree;
    function JUNIOR_SPILLOVER_SHARE() external returns (uint256) envfree;
    function RESERVE_SPILLOVER_SHARE() external returns (uint256) envfree;
    function DEPOSIT_CAP_MULTIPLIER() external returns (uint256) envfree;
    
    // Core functions
    function calculateBackingRatio(uint256, uint256) external returns (uint256) envfree;
    function calculateBalanceFromShares(uint256, uint256) external returns (uint256) envfree;
    function calculateSharesFromBalance(uint256, uint256) external returns (uint256) envfree;
    function calculateSharesFromBalanceCeil(uint256, uint256) external returns (uint256) envfree;
    function calculateTotalSupply(uint256, uint256) external returns (uint256) envfree;
    function calculateDepositCap(uint256) external returns (uint256) envfree;
    function min(uint256, uint256) external returns (uint256) envfree;
    function max(uint256, uint256) external returns (uint256) envfree;
    function mulDiv(uint256, uint256) external returns (uint256) envfree;
}

// ============================================
// INVARIANTS - Protocol Constants
// ============================================

/**
 * @title INV-CONST-001: Protocol constants are correctly set
 * @notice Verifies all protocol constants match math spec Section 4.1
 */
invariant protocolConstantsCorrect()
    mathLib.PRECISION() == 1000000000000000000 &&  // 1e18
    mathLib.SENIOR_TARGET_BACKING() == 1100000000000000000 &&  // 1.10 (110%)
    mathLib.SENIOR_TRIGGER_BACKING() == 1000000000000000000 &&  // 1.00 (100%)
    mathLib.SENIOR_RESTORE_BACKING() == 1009000000000000000 &&  // 1.009 (100.9%)
    mathLib.JUNIOR_SPILLOVER_SHARE() == 800000000000000000 &&  // 0.80 (80%)
    mathLib.RESERVE_SPILLOVER_SHARE() == 200000000000000000 &&  // 0.20 (20%)
    mathLib.DEPOSIT_CAP_MULTIPLIER() == 10;

/**
 * @title INV-CONST-002: Spillover shares sum to 100%
 * @notice Junior (80%) + Reserve (20%) must equal 100%
 * @dev Reference: Math Spec Section 5.1 Step 4A
 */
invariant spilloverSharesSumTo100()
    mathLib.JUNIOR_SPILLOVER_SHARE() + mathLib.RESERVE_SPILLOVER_SHARE() == mathLib.PRECISION();

// ============================================
// RULES - User Balance & Shares
// ============================================

/**
 * @title RULE-MATH-001: User balance formula correctness
 * @notice Verifies b_i = σ_i × I
 * @dev Reference: Math Spec Section 4.2.1
 */
rule userBalanceFormula(uint256 shares, uint256 rebaseIndex) {
    require rebaseIndex > 0;
    require rebaseIndex <= mathLib.PRECISION() * 2; // Reasonable upper bound
    
    uint256 balance = mathLib.calculateBalanceFromShares(shares, rebaseIndex);
    
    // Property: balance = (shares × rebaseIndex) / PRECISION
    assert balance == (shares * rebaseIndex) / mathLib.PRECISION(),
        "User balance formula violated: b_i ≠ σ_i × I";
}

/**
 * @title RULE-MATH-002: Shares calculation correctness
 * @notice Verifies σ_new = d / I
 * @dev Reference: Math Spec Section 9.3 (Deposit)
 */
rule sharesFromBalanceFormula(uint256 balance, uint256 rebaseIndex) {
    require rebaseIndex > 0;
    require balance > 0;
    
    uint256 shares = mathLib.calculateSharesFromBalance(balance, rebaseIndex);
    
    // Property: shares = (balance × PRECISION) / rebaseIndex
    assert shares == (balance * mathLib.PRECISION()) / rebaseIndex,
        "Shares formula violated: σ_new ≠ d / I";
}

/**
 * @title RULE-MATH-003: Balance-shares roundtrip consistency
 * @notice deposit → shares → balance should preserve value
 * @dev Critical for maintaining 1:1 deposit conversion
 */
rule balanceSharesRoundtrip(uint256 depositAmount, uint256 rebaseIndex) {
    require rebaseIndex > 0;
    require depositAmount > 0;
    require depositAmount < max_uint256 / mathLib.PRECISION(); // Prevent overflow
    
    uint256 shares = mathLib.calculateSharesFromBalance(depositAmount, rebaseIndex);
    uint256 reconstructedBalance = mathLib.calculateBalanceFromShares(shares, rebaseIndex);
    
    // Property: reconstructed balance should equal original (allowing for rounding)
    assert reconstructedBalance >= depositAmount - 1 && 
           reconstructedBalance <= depositAmount,
        "Balance-shares roundtrip failed";
}

/**
 * @title RULE-MATH-004: Ceiling shares calculation is conservative
 * @notice Ceiling division should always give >= floor division
 * @dev Used in burns to favor protocol
 */
rule sharesFromBalanceCeilIsConservative(uint256 balance, uint256 rebaseIndex) {
    require rebaseIndex > 0;
    require balance > 0;
    
    uint256 sharesFloor = mathLib.calculateSharesFromBalance(balance, rebaseIndex);
    uint256 sharesCeil = mathLib.calculateSharesFromBalanceCeil(balance, rebaseIndex);
    
    // Property: ceiling >= floor
    assert sharesCeil >= sharesFloor,
        "Ceiling shares not >= floor shares";
    
    // Property: difference is at most 1
    assert sharesCeil - sharesFloor <= 1,
        "Ceiling-floor difference too large";
}

// ============================================
// RULES - Total Supply
// ============================================

/**
 * @title RULE-MATH-005: Total supply formula correctness
 * @notice Verifies S = I × Σ
 * @dev Reference: Math Spec Section 4.2.2
 */
rule totalSupplyFormula(uint256 totalShares, uint256 rebaseIndex) {
    require rebaseIndex > 0;
    require totalShares < max_uint256 / rebaseIndex; // Prevent overflow
    
    uint256 supply = mathLib.calculateTotalSupply(totalShares, rebaseIndex);
    
    // Property: supply = (totalShares × rebaseIndex) / PRECISION
    assert supply == (totalShares * rebaseIndex) / mathLib.PRECISION(),
        "Total supply formula violated: S ≠ I × Σ";
}

/**
 * @title RULE-MATH-006: Supply grows proportionally with index
 * @notice When index increases, supply increases proportionally
 */
rule supplyGrowsWithIndex(uint256 totalShares, uint256 oldIndex, uint256 newIndex) {
    require oldIndex > 0;
    require newIndex > oldIndex;
    require totalShares > 0;
    require totalShares < max_uint256 / newIndex;
    
    uint256 oldSupply = mathLib.calculateTotalSupply(totalShares, oldIndex);
    uint256 newSupply = mathLib.calculateTotalSupply(totalShares, newIndex);
    
    // Property: new supply > old supply
    assert newSupply > oldSupply,
        "Supply didn't grow with index";
    
    // Property: growth ratio matches index ratio (within rounding)
    mathint supplyRatio = (newSupply * mathLib.PRECISION()) / oldSupply;
    mathint indexRatio = (newIndex * mathLib.PRECISION()) / oldIndex;
    
    assert supplyRatio >= indexRatio - 1 && supplyRatio <= indexRatio + 1,
        "Supply growth doesn't match index growth";
}

// ============================================
// RULES - Backing Ratio
// ============================================

/**
 * @title RULE-MATH-007: Backing ratio formula correctness
 * @notice Verifies R_senior = V_s / S
 * @dev Reference: Math Spec Section 4.2.4
 */
rule backingRatioFormula(uint256 vaultValue, uint256 totalSupply) {
    require totalSupply > 0;
    require vaultValue < max_uint256 / mathLib.PRECISION();
    
    uint256 backingRatio = mathLib.calculateBackingRatio(vaultValue, totalSupply);
    
    // Property: backingRatio = (vaultValue × PRECISION) / totalSupply
    assert backingRatio == (vaultValue * mathLib.PRECISION()) / totalSupply,
        "Backing ratio formula violated: R ≠ V_s / S";
}

/**
 * @title RULE-MATH-008: Backing ratio monotonicity with vault value
 * @notice Increasing vault value increases backing ratio
 */
rule backingRatioIncreasesWithVault(uint256 supply, uint256 value1, uint256 value2) {
    require supply > 0;
    require value2 > value1;
    require value1 > 0;
    require value2 < max_uint256 / mathLib.PRECISION();
    
    uint256 ratio1 = mathLib.calculateBackingRatio(value1, supply);
    uint256 ratio2 = mathLib.calculateBackingRatio(value2, supply);
    
    // Property: higher vault value → higher backing ratio
    assert ratio2 > ratio1,
        "Backing ratio didn't increase with vault value";
}

/**
 * @title RULE-MATH-009: Backing ratio monotonicity with supply
 * @notice Increasing supply decreases backing ratio
 */
rule backingRatioDecreasesWithSupply(uint256 vaultValue, uint256 supply1, uint256 supply2) {
    require supply1 > 0;
    require supply2 > supply1;
    require vaultValue > 0;
    require vaultValue < max_uint256 / mathLib.PRECISION();
    
    uint256 ratio1 = mathLib.calculateBackingRatio(vaultValue, supply1);
    uint256 ratio2 = mathLib.calculateBackingRatio(vaultValue, supply2);
    
    // Property: higher supply → lower backing ratio
    assert ratio2 < ratio1,
        "Backing ratio didn't decrease with supply";
}

/**
 * @title RULE-MATH-010: 100% backing definition
 * @notice Backing ratio equals PRECISION when vault = supply
 */
rule hundred_percent_backing(uint256 amount) {
    require amount > 0;
    require amount < max_uint256 / mathLib.PRECISION();
    
    uint256 backingRatio = mathLib.calculateBackingRatio(amount, amount);
    
    // Property: V_s == S → R == 100% (PRECISION)
    assert backingRatio == mathLib.PRECISION(),
        "100% backing not equal to PRECISION";
}

// ============================================
// RULES - Deposit Cap
// ============================================

/**
 * @title RULE-MATH-011: Deposit cap formula correctness
 * @notice Verifies S_max = γ × V_r = 10 × V_r
 * @dev Reference: Math Spec Section 4.2.6
 */
rule depositCapFormula(uint256 reserveValue) {
    require reserveValue > 0;
    require reserveValue < max_uint256 / mathLib.DEPOSIT_CAP_MULTIPLIER();
    
    uint256 cap = mathLib.calculateDepositCap(reserveValue);
    
    // Property: cap = reserveValue × 10
    assert cap == reserveValue * mathLib.DEPOSIT_CAP_MULTIPLIER(),
        "Deposit cap formula violated: S_max ≠ 10 × V_r";
}

/**
 * @title RULE-MATH-012: Deposit cap grows linearly with reserve
 * @notice Doubling reserve doubles the cap
 */
rule depositCapLinearGrowth(uint256 reserve1, uint256 reserve2) {
    require reserve1 > 0;
    require reserve2 == reserve1 * 2;
    require reserve2 < max_uint256 / mathLib.DEPOSIT_CAP_MULTIPLIER();
    
    uint256 cap1 = mathLib.calculateDepositCap(reserve1);
    uint256 cap2 = mathLib.calculateDepositCap(reserve2);
    
    // Property: cap2 == 2 × cap1
    assert cap2 == cap1 * 2,
        "Deposit cap doesn't grow linearly";
}

// ============================================
// RULES - Helper Functions
// ============================================

/**
 * @title RULE-MATH-013: Min function correctness
 */
rule minFunctionCorrect(uint256 a, uint256 b) {
    uint256 result = mathLib.min(a, b);
    
    // Property: result <= a AND result <= b
    assert result <= a && result <= b,
        "Min not <= both inputs";
    
    // Property: result == a OR result == b
    assert result == a || result == b,
        "Min not equal to one of inputs";
}

/**
 * @title RULE-MATH-014: Max function correctness
 */
rule maxFunctionCorrect(uint256 a, uint256 b) {
    uint256 result = mathLib.max(a, b);
    
    // Property: result >= a AND result >= b
    assert result >= a && result >= b,
        "Max not >= both inputs";
    
    // Property: result == a OR result == b
    assert result == a || result == b,
        "Max not equal to one of inputs";
}

/**
 * @title RULE-MATH-015: MulDiv maintains precision
 * @notice (a × b) / PRECISION should preserve precision
 */
rule mulDivPreservesPrecision(uint256 a, uint256 b) {
    require a > 0 && b > 0;
    require a < max_uint256 / b; // Prevent overflow
    
    uint256 result = mathLib.mulDiv(a, b);
    
    // Property: result = (a × b) / PRECISION
    assert result == (a * b) / mathLib.PRECISION(),
        "MulDiv doesn't preserve precision";
}

// ============================================
// RULES - No Division by Zero
// ============================================

/**
 * @title RULE-MATH-016: Backing ratio reverts on zero supply
 */
rule backingRatioRevertsOnZeroSupply(uint256 vaultValue) {
    // Property: Should revert when supply == 0
    mathLib.calculateBackingRatio@withrevert(vaultValue, 0);
    
    assert lastReverted,
        "Backing ratio didn't revert on zero supply";
}

/**
 * @title RULE-MATH-017: Shares calculation reverts on zero index
 */
rule sharesCalculationRevertsOnZeroIndex(uint256 balance) {
    // Property: Should revert when rebaseIndex == 0
    mathLib.calculateSharesFromBalance@withrevert(balance, 0);
    
    assert lastReverted,
        "Shares calculation didn't revert on zero index";
}

