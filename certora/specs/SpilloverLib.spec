/**
 * @title SpilloverLib Formal Verification Specification
 * @notice Certora CVL specification for three-zone spillover system
 * @dev Verifies formulas from Math Spec Section 5.1 Steps 4A & 4B (Spillover/Backstop)
 * 
 * Mathematical Properties Verified:
 * 1. Zone 1 (>110%): Profit Spillover - V_target, E, split 80/20
 * 2. Zone 2 (100-110%): Healthy Buffer - No action
 * 3. Zone 3 (<100%): Backstop - V_restore = 100.9%, waterfall Reserve→Junior
 * 4. Zone determination correctness
 * 5. Conservation of value in transfers
 * 6. Spillover share sum = 100%
 */

using SpilloverLibHarness as spilloverLib;
using MathLibHarness as mathLib;

methods {
    // SpilloverLib functions
    function determineZone(uint256) external returns (uint8) envfree;
    function calculateProfitSpillover(uint256, uint256) external returns (uint256, uint256, uint256, uint256) envfree;
    function calculateBackstop(uint256, uint256, uint256, uint256) external returns (uint256, uint256, uint256, uint256, bool) envfree;
    function isHealthyBufferZone(uint256) external returns (bool) envfree;
    function needsProfitSpillover(uint256) external returns (bool) envfree;
    function needsBackstop(uint256) external returns (bool) envfree;
    function calculateZoneThresholds(uint256) external returns (uint256, uint256, uint256) envfree;
    
    // MathLib constants
    function _.PRECISION() external => DISPATCHER(true);
    function _.SENIOR_TARGET_BACKING() external => DISPATCHER(true);
    function _.SENIOR_TRIGGER_BACKING() external => DISPATCHER(true);
    function _.SENIOR_RESTORE_BACKING() external => DISPATCHER(true);
    function _.JUNIOR_SPILLOVER_SHARE() external => DISPATCHER(true);
    function _.RESERVE_SPILLOVER_SHARE() external => DISPATCHER(true);
}

// Zone enum mapping: 0=BACKSTOP, 1=HEALTHY, 2=SPILLOVER

// ============================================
// INVARIANTS - Three-Zone System
// ============================================

/**
 * @title INV-SPILLOVER-001: Zone thresholds are correctly ordered
 * @notice 100% < 100.9% < 110%
 */
invariant zoneThresholdsOrdered()
    mathLib.SENIOR_TRIGGER_BACKING() < mathLib.SENIOR_RESTORE_BACKING() &&
    mathLib.SENIOR_RESTORE_BACKING() < mathLib.SENIOR_TARGET_BACKING();

/**
 * @title INV-SPILLOVER-002: Spillover shares sum to 100%
 * @notice Junior (80%) + Reserve (20%) = 100%
 */
invariant spilloverSharesSum100()
    mathLib.JUNIOR_SPILLOVER_SHARE() + mathLib.RESERVE_SPILLOVER_SHARE() == mathLib.PRECISION();

// ============================================
// RULES - Zone Determination
// ============================================

/**
 * @title RULE-SPILLOVER-001: Zone 1 determination (>110%)
 * @notice Backing > 110% → SPILLOVER zone
 */
rule zone1DeterminationCorrect(uint256 backingRatio) {
    require backingRatio > mathLib.SENIOR_TARGET_BACKING();
    
    uint8 zone = spilloverLib.determineZone(backingRatio);
    
    // Property: zone == 2 (SPILLOVER)
    assert zone == 2,
        "Zone 1 (>110%) not detected as SPILLOVER";
}

/**
 * @title RULE-SPILLOVER-002: Zone 2 determination (100-110%)
 * @notice 100% ≤ Backing ≤ 110% → HEALTHY zone
 */
rule zone2DeterminationCorrect(uint256 backingRatio) {
    require backingRatio >= mathLib.SENIOR_TRIGGER_BACKING();
    require backingRatio <= mathLib.SENIOR_TARGET_BACKING();
    
    uint8 zone = spilloverLib.determineZone(backingRatio);
    
    // Property: zone == 1 (HEALTHY)
    assert zone == 1,
        "Zone 2 (100-110%) not detected as HEALTHY";
}

/**
 * @title RULE-SPILLOVER-003: Zone 3 determination (<100%)
 * @notice Backing < 100% → BACKSTOP zone
 */
rule zone3DeterminationCorrect(uint256 backingRatio) {
    require backingRatio < mathLib.SENIOR_TRIGGER_BACKING();
    
    uint8 zone = spilloverLib.determineZone(backingRatio);
    
    // Property: zone == 0 (BACKSTOP)
    assert zone == 0,
        "Zone 3 (<100%) not detected as BACKSTOP";
}

/**
 * @title RULE-SPILLOVER-004: Zone determination is exhaustive
 * @notice Every backing ratio maps to exactly one zone
 */
rule zoneDeterminationExhaustive(uint256 backingRatio) {
    require backingRatio > 0;
    require backingRatio < max_uint256;
    
    uint8 zone = spilloverLib.determineZone(backingRatio);
    bool needsSpillover = spilloverLib.needsProfitSpillover(backingRatio);
    bool isHealthy = spilloverLib.isHealthyBufferZone(backingRatio);
    bool needsBack = spilloverLib.needsBackstop(backingRatio);
    
    // Property: Exactly one condition is true
    uint8 trueCount = 0;
    if (needsSpillover) trueCount = trueCount + 1;
    if (isHealthy) trueCount = trueCount + 1;
    if (needsBack) trueCount = trueCount + 1;
    
    assert trueCount == 1,
        "Zone determination not exhaustive or overlapping";
}

// ============================================
// RULES - Profit Spillover (Zone 1)
// ============================================

/**
 * @title RULE-SPILLOVER-005: Profit spillover target formula
 * @notice V_target = 1.10 × S_new
 * @dev Reference: Math Spec Section 5.1 Step 4A
 */
rule profitSpilloverTargetFormula(uint256 vaultValue, uint256 newSupply) {
    require vaultValue > 0;
    require newSupply > 0;
    require vaultValue > (newSupply * mathLib.SENIOR_TARGET_BACKING()) / mathLib.PRECISION(); // Excess exists
    require vaultValue < max_uint256 / mathLib.PRECISION();
    
    uint256 excessAmount;
    uint256 toJunior;
    uint256 toReserve;
    uint256 seniorFinalValue;
    
    (excessAmount, toJunior, toReserve, seniorFinalValue) = 
        spilloverLib.calculateProfitSpillover(vaultValue, newSupply);
    
    // Property: seniorFinalValue = 110% × newSupply
    uint256 expectedTarget = (newSupply * mathLib.SENIOR_TARGET_BACKING()) / mathLib.PRECISION();
    
    assert seniorFinalValue == expectedTarget,
        "Senior final value not equal to 110% target";
}

/**
 * @title RULE-SPILLOVER-006: Excess calculation correctness
 * @notice E = V_s - V_target
 */
rule excessCalculationCorrect(uint256 vaultValue, uint256 newSupply) {
    require vaultValue > 0;
    require newSupply > 0;
    require vaultValue > (newSupply * mathLib.SENIOR_TARGET_BACKING()) / mathLib.PRECISION();
    require vaultValue < max_uint256 / mathLib.PRECISION();
    
    uint256 excessAmount;
    uint256 toJunior;
    uint256 toReserve;
    uint256 seniorFinalValue;
    
    (excessAmount, toJunior, toReserve, seniorFinalValue) = 
        spilloverLib.calculateProfitSpillover(vaultValue, newSupply);
    
    // Property: excess = vaultValue - target
    uint256 target = (newSupply * mathLib.SENIOR_TARGET_BACKING()) / mathLib.PRECISION();
    
    assert excessAmount == vaultValue - target,
        "Excess amount calculation incorrect";
}

/**
 * @title RULE-SPILLOVER-007: Spillover 80/20 split
 * @notice E_j = E × 80%, E_r = E × 20%
 */
rule spilloverSplitCorrect(uint256 vaultValue, uint256 newSupply) {
    require vaultValue > 0;
    require newSupply > 0;
    require vaultValue > (newSupply * mathLib.SENIOR_TARGET_BACKING()) / mathLib.PRECISION();
    require vaultValue < max_uint256 / mathLib.PRECISION();
    
    uint256 excessAmount;
    uint256 toJunior;
    uint256 toReserve;
    uint256 seniorFinalValue;
    
    (excessAmount, toJunior, toReserve, seniorFinalValue) = 
        spilloverLib.calculateProfitSpillover(vaultValue, newSupply);
    
    // Property: toJunior = excess × 80%
    uint256 expectedJunior = (excessAmount * mathLib.JUNIOR_SPILLOVER_SHARE()) / mathLib.PRECISION();
    assert toJunior == expectedJunior,
        "Junior spillover not 80% of excess";
    
    // Property: toReserve = excess × 20%
    uint256 expectedReserve = (excessAmount * mathLib.RESERVE_SPILLOVER_SHARE()) / mathLib.PRECISION();
    assert toReserve == expectedReserve,
        "Reserve spillover not 20% of excess";
}

/**
 * @title RULE-SPILLOVER-008: Spillover conserves value
 * @notice toJunior + toReserve = excess
 */
rule spilloverConservesValue(uint256 vaultValue, uint256 newSupply) {
    require vaultValue > 0;
    require newSupply > 0;
    require vaultValue > (newSupply * mathLib.SENIOR_TARGET_BACKING()) / mathLib.PRECISION();
    require vaultValue < max_uint256 / mathLib.PRECISION();
    
    uint256 excessAmount;
    uint256 toJunior;
    uint256 toReserve;
    uint256 seniorFinalValue;
    
    (excessAmount, toJunior, toReserve, seniorFinalValue) = 
        spilloverLib.calculateProfitSpillover(vaultValue, newSupply);
    
    // Property: toJunior + toReserve ≈ excess (within rounding)
    assert toJunior + toReserve >= excessAmount - 1 && 
           toJunior + toReserve <= excessAmount + 1,
        "Spillover doesn't conserve value";
}

/**
 * @title RULE-SPILLOVER-009: Senior value reduction equals distribution
 * @notice V_s - V_s^final = toJunior + toReserve
 */
rule seniorReductionEqualsDistribution(uint256 vaultValue, uint256 newSupply) {
    require vaultValue > 0;
    require newSupply > 0;
    require vaultValue > (newSupply * mathLib.SENIOR_TARGET_BACKING()) / mathLib.PRECISION();
    require vaultValue < max_uint256 / mathLib.PRECISION();
    
    uint256 excessAmount;
    uint256 toJunior;
    uint256 toReserve;
    uint256 seniorFinalValue;
    
    (excessAmount, toJunior, toReserve, seniorFinalValue) = 
        spilloverLib.calculateProfitSpillover(vaultValue, newSupply);
    
    uint256 reduction = vaultValue - seniorFinalValue;
    uint256 distribution = toJunior + toReserve;
    
    // Property: reduction = distribution (within rounding)
    assert reduction >= distribution - 1 && reduction <= distribution + 1,
        "Senior reduction doesn't equal distribution";
}

// ============================================
// RULES - Backstop (Zone 3)
// ============================================

/**
 * @title RULE-SPILLOVER-010: Backstop restoration target formula
 * @notice V_restore = 1.009 × S_new (100.9%)
 * @dev Reference: Math Spec Section 5.1 Step 4B
 */
rule backstopRestorationTargetFormula(uint256 vaultValue, uint256 newSupply, uint256 reserveValue, uint256 juniorValue) {
    require vaultValue > 0;
    require newSupply > 0;
    require vaultValue < (newSupply * mathLib.SENIOR_TRIGGER_BACKING()) / mathLib.PRECISION(); // Depegged
    require reserveValue + juniorValue >= (newSupply * mathLib.SENIOR_RESTORE_BACKING()) / mathLib.PRECISION() - vaultValue; // Can restore
    
    uint256 deficitAmount;
    uint256 fromReserve;
    uint256 fromJunior;
    uint256 seniorFinalValue;
    bool fullyRestored;
    
    (deficitAmount, fromReserve, fromJunior, seniorFinalValue, fullyRestored) = 
        spilloverLib.calculateBackstop(vaultValue, newSupply, reserveValue, juniorValue);
    
    // Property: If fully restored, seniorFinalValue = 100.9% × newSupply
    if (fullyRestored) {
        uint256 expectedRestore = (newSupply * mathLib.SENIOR_RESTORE_BACKING()) / mathLib.PRECISION();
        assert seniorFinalValue == expectedRestore,
            "Senior final value not equal to 100.9% restoration target";
    }
}

/**
 * @title RULE-SPILLOVER-011: Deficit calculation correctness
 * @notice D = V_restore - V_s
 */
rule deficitCalculationCorrect(uint256 vaultValue, uint256 newSupply, uint256 reserveValue, uint256 juniorValue) {
    require vaultValue > 0;
    require newSupply > 0;
    require vaultValue < (newSupply * mathLib.SENIOR_RESTORE_BACKING()) / mathLib.PRECISION(); // Deficit exists
    require reserveValue > 0 || juniorValue > 0;
    
    uint256 deficitAmount;
    uint256 fromReserve;
    uint256 fromJunior;
    uint256 seniorFinalValue;
    bool fullyRestored;
    
    (deficitAmount, fromReserve, fromJunior, seniorFinalValue, fullyRestored) = 
        spilloverLib.calculateBackstop(vaultValue, newSupply, reserveValue, juniorValue);
    
    // Property: deficit = restore - vaultValue
    uint256 restore = (newSupply * mathLib.SENIOR_RESTORE_BACKING()) / mathLib.PRECISION();
    
    assert deficitAmount == restore - vaultValue,
        "Deficit calculation incorrect";
}

/**
 * @title RULE-SPILLOVER-012: Backstop waterfall (Reserve first)
 * @notice X_r = min(V_r, D), then X_j = min(V_j, D - X_r)
 */
rule backstopWaterfallCorrect(uint256 vaultValue, uint256 newSupply, uint256 reserveValue, uint256 juniorValue) {
    require vaultValue > 0;
    require newSupply > 0;
    require vaultValue < (newSupply * mathLib.SENIOR_RESTORE_BACKING()) / mathLib.PRECISION();
    require reserveValue > 0 || juniorValue > 0;
    
    uint256 deficitAmount;
    uint256 fromReserve;
    uint256 fromJunior;
    uint256 seniorFinalValue;
    bool fullyRestored;
    
    (deficitAmount, fromReserve, fromJunior, seniorFinalValue, fullyRestored) = 
        spilloverLib.calculateBackstop(vaultValue, newSupply, reserveValue, juniorValue);
    
    // Property: fromReserve = min(reserveValue, deficit)
    assert fromReserve == mathLib.min(reserveValue, deficitAmount),
        "Reserve contribution not min(V_r, D)";
    
    // Property: fromJunior = min(juniorValue, deficit - fromReserve)
    uint256 remainingDeficit = deficitAmount - fromReserve;
    assert fromJunior == mathLib.min(juniorValue, remainingDeficit),
        "Junior contribution not min(V_j, D - X_r)";
}

/**
 * @title RULE-SPILLOVER-013: Reserve provides first (priority)
 * @notice Junior only contributes if Reserve insufficient
 */
rule reserveProvidesFirst(uint256 vaultValue, uint256 newSupply, uint256 reserveValue, uint256 juniorValue) {
    require vaultValue > 0;
    require newSupply > 0;
    require vaultValue < (newSupply * mathLib.SENIOR_RESTORE_BACKING()) / mathLib.PRECISION();
    require reserveValue > 0;
    
    uint256 deficitAmount;
    uint256 fromReserve;
    uint256 fromJunior;
    uint256 seniorFinalValue;
    bool fullyRestored;
    
    (deficitAmount, fromReserve, fromJunior, seniorFinalValue, fullyRestored) = 
        spilloverLib.calculateBackstop(vaultValue, newSupply, reserveValue, juniorValue);
    
    // Property: If Reserve sufficient, Junior contributes nothing
    if (reserveValue >= deficitAmount) {
        assert fromJunior == 0,
            "Junior contributed when Reserve was sufficient";
        assert fromReserve == deficitAmount,
            "Reserve didn't provide full deficit when able";
    }
}

/**
 * @title RULE-SPILLOVER-014: Backstop conserves value
 * @notice fromReserve + fromJunior = deficit (if fully restored)
 */
rule backstopConservesValue(uint256 vaultValue, uint256 newSupply, uint256 reserveValue, uint256 juniorValue) {
    require vaultValue > 0;
    require newSupply > 0;
    require vaultValue < (newSupply * mathLib.SENIOR_RESTORE_BACKING()) / mathLib.PRECISION();
    require reserveValue + juniorValue >= (newSupply * mathLib.SENIOR_RESTORE_BACKING()) / mathLib.PRECISION() - vaultValue;
    
    uint256 deficitAmount;
    uint256 fromReserve;
    uint256 fromJunior;
    uint256 seniorFinalValue;
    bool fullyRestored;
    
    (deficitAmount, fromReserve, fromJunior, seniorFinalValue, fullyRestored) = 
        spilloverLib.calculateBackstop(vaultValue, newSupply, reserveValue, juniorValue);
    
    // Property: If fully restored, fromReserve + fromJunior = deficit
    if (fullyRestored) {
        assert fromReserve + fromJunior == deficitAmount,
            "Backstop contributions don't equal deficit";
    }
}

/**
 * @title RULE-SPILLOVER-015: Full restoration flag correctness
 * @notice fullyRestored ⟺ Reserve + Junior sufficient
 */
rule fullRestorationFlagCorrect(uint256 vaultValue, uint256 newSupply, uint256 reserveValue, uint256 juniorValue) {
    require vaultValue > 0;
    require newSupply > 0;
    require vaultValue < (newSupply * mathLib.SENIOR_RESTORE_BACKING()) / mathLib.PRECISION();
    
    uint256 deficitAmount;
    uint256 fromReserve;
    uint256 fromJunior;
    uint256 seniorFinalValue;
    bool fullyRestored;
    
    (deficitAmount, fromReserve, fromJunior, seniorFinalValue, fullyRestored) = 
        spilloverLib.calculateBackstop(vaultValue, newSupply, reserveValue, juniorValue);
    
    // Property: fullyRestored ⟺ (reserveValue + juniorValue) >= deficit
    if (reserveValue + juniorValue >= deficitAmount) {
        assert fullyRestored,
            "Should be fully restored when funds sufficient";
    } else {
        assert !fullyRestored,
            "Can't be fully restored when funds insufficient";
    }
}

/**
 * @title RULE-SPILLOVER-016: Senior value increase equals contributions
 * @notice V_s^final - V_s = fromReserve + fromJunior
 */
rule seniorIncreaseEqualsContributions(uint256 vaultValue, uint256 newSupply, uint256 reserveValue, uint256 juniorValue) {
    require vaultValue > 0;
    require newSupply > 0;
    require vaultValue < (newSupply * mathLib.SENIOR_RESTORE_BACKING()) / mathLib.PRECISION();
    require reserveValue > 0 || juniorValue > 0;
    
    uint256 deficitAmount;
    uint256 fromReserve;
    uint256 fromJunior;
    uint256 seniorFinalValue;
    bool fullyRestored;
    
    (deficitAmount, fromReserve, fromJunior, seniorFinalValue, fullyRestored) = 
        spilloverLib.calculateBackstop(vaultValue, newSupply, reserveValue, juniorValue);
    
    uint256 increase = seniorFinalValue - vaultValue;
    uint256 contributions = fromReserve + fromJunior;
    
    // Property: increase = contributions
    assert increase == contributions,
        "Senior increase doesn't equal contributions";
}

// ============================================
// RULES - Zone Thresholds
// ============================================

/**
 * @title RULE-SPILLOVER-017: Zone thresholds calculation correctness
 */
rule zoneThresholdsCorrect(uint256 newSupply) {
    require newSupply > 0;
    require newSupply < max_uint256 / mathLib.SENIOR_TARGET_BACKING();
    
    uint256 targetValue;
    uint256 triggerValue;
    uint256 restoreValue;
    
    (targetValue, triggerValue, restoreValue) = spilloverLib.calculateZoneThresholds(newSupply);
    
    // Property: targetValue = 110% × newSupply
    assert targetValue == (newSupply * mathLib.SENIOR_TARGET_BACKING()) / mathLib.PRECISION(),
        "Target value not 110% of supply";
    
    // Property: triggerValue = 100% × newSupply
    assert triggerValue == (newSupply * mathLib.SENIOR_TRIGGER_BACKING()) / mathLib.PRECISION(),
        "Trigger value not 100% of supply";
    
    // Property: restoreValue = 100.9% × newSupply
    assert restoreValue == (newSupply * mathLib.SENIOR_RESTORE_BACKING()) / mathLib.PRECISION(),
        "Restore value not 100.9% of supply";
}

/**
 * @title RULE-SPILLOVER-018: Restoration buffer enables next rebase
 * @notice 100.9% - 0.9167% (11% monthly) ≈ 100%
 */
rule restorationBufferEnablesRebase(uint256 newSupply) {
    require newSupply > 0;
    require newSupply < max_uint256 / mathLib.SENIOR_RESTORE_BACKING();
    
    uint256 restoreValue = (newSupply * mathLib.SENIOR_RESTORE_BACKING()) / mathLib.PRECISION();
    
    // After 11% monthly rebase (0.9167%), backing should be ≈100%
    // New supply after rebase: newSupply × 1.009167
    uint256 supplyAfterRebase = (newSupply * (mathLib.PRECISION() + mathLib.MIN_MONTHLY_RATE())) / mathLib.PRECISION();
    uint256 backingAfterRebase = (restoreValue * mathLib.PRECISION()) / supplyAfterRebase;
    
    // Property: Backing after rebase should be ≈100% (within 1%)
    assert backingAfterRebase >= mathLib.PRECISION() - (mathLib.PRECISION() / 100) &&
           backingAfterRebase <= mathLib.PRECISION() + (mathLib.PRECISION() / 100),
        "Restoration buffer doesn't enable next rebase";
}




