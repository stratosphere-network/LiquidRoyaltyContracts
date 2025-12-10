/**
 * @title RebaseLib Formal Verification Specification
 * @notice Certora CVL specification for dynamic APY selection mechanism
 * @dev Verifies formulas from Math Spec Section 5.1 Step 2 (Dynamic APY Selection)
 * 
 * Mathematical Properties Verified:
 * 1. Waterfall APY selection: 13% → 12% → 11%
 * 2. Greedy maximization (highest APY that maintains peg)
 * 3. Backing ratio checks for each APY tier
 * 4. Backstop flagging when all APYs fail
 * 5. Consistency of selected rate with backing requirements
 */

using RebaseLibHarness as rebaseLib;
using MathLibHarness as mathLib;
using FeeLibHarness as feeLib;

methods {
    // RebaseLib functions
    function selectDynamicAPY(uint256, uint256, uint256, uint256) external returns (uint256, uint256, uint256, uint256, uint8, bool) envfree;
    function calculateNewIndex(uint256, uint256, uint256) external returns (uint256) envfree;
    function simulateAllAPYs(uint256, uint256, uint256, uint256) external returns (uint256, uint256, uint256) envfree;
    function getAPYInBps(uint8) external returns (uint256) envfree;
    function getMonthlyRate(uint8) external returns (uint256) envfree;
    
    // MathLib functions
    function _.PRECISION() external => DISPATCHER(true);
    function _.MAX_MONTHLY_RATE() external => DISPATCHER(true);
    function _.MID_MONTHLY_RATE() external => DISPATCHER(true);
    function _.MIN_MONTHLY_RATE() external => DISPATCHER(true);
    function _.calculateBackingRatio(uint256, uint256) external => DISPATCHER(true);
}

// ============================================
// INVARIANTS - APY Tiers
// ============================================

/**
 * @title INV-REBASE-001: APY tiers are correctly ordered
 * @notice 13% > 12% > 11%
 */
invariant apyTiersOrdered()
    mathLib.MAX_MONTHLY_RATE() > mathLib.MID_MONTHLY_RATE() &&
    mathLib.MID_MONTHLY_RATE() > mathLib.MIN_MONTHLY_RATE();

/**
 * @title INV-REBASE-002: APY tier mappings are correct
 */
invariant apyTierMappingsCorrect()
    rebaseLib.getAPYInBps(3) == 1300 &&  // 13.00%
    rebaseLib.getAPYInBps(2) == 1200 &&  // 12.00%
    rebaseLib.getAPYInBps(1) == 1100 &&  // 11.00%
    rebaseLib.getMonthlyRate(3) == mathLib.MAX_MONTHLY_RATE() &&
    rebaseLib.getMonthlyRate(2) == mathLib.MID_MONTHLY_RATE() &&
    rebaseLib.getMonthlyRate(1) == mathLib.MIN_MONTHLY_RATE();

// ============================================
// RULES - Dynamic APY Selection (Greedy Maximization)
// ============================================

/**
 * @title RULE-REBASE-001: Waterfall ordering - tries highest APY first
 * @notice System attempts 13% before 12% before 11%
 * @dev Reference: Math Spec Section 5.1 Step 2
 */
rule waterfallOrderingCorrect(uint256 currentSupply, uint256 vaultValue, uint256 timeElapsed, uint256 mgmtFeeTokens) {
    require currentSupply > 0;
    require vaultValue > 0;
    require timeElapsed > 0;
    require timeElapsed <= 30 days;
    require vaultValue < max_uint256 / mathLib.PRECISION();
    require currentSupply < max_uint256 / mathLib.MAX_MONTHLY_RATE();
    
    uint256 selectedRate;
    uint256 newSupply;
    uint256 userTokens;
    uint256 feeTokens;
    uint8 apyTier;
    bool backstopNeeded;
    
    (selectedRate, newSupply, userTokens, feeTokens, apyTier, backstopNeeded) = 
        rebaseLib.selectDynamicAPY(currentSupply, vaultValue, timeElapsed, mgmtFeeTokens);
    
    // Get backing ratios for all tiers
    uint256 backing13;
    uint256 backing12;
    uint256 backing11;
    (backing13, backing12, backing11) = rebaseLib.simulateAllAPYs(
        currentSupply, vaultValue, timeElapsed, mgmtFeeTokens
    );
    
    // Property: If 13% APY works, it's selected
    if (backing13 >= mathLib.PRECISION()) {
        assert apyTier == 3 && selectedRate == mathLib.MAX_MONTHLY_RATE(),
            "Should select 13% APY when it maintains peg";
    }
    // Property: If only 12% works, it's selected
    else if (backing12 >= mathLib.PRECISION()) {
        assert apyTier == 2 && selectedRate == mathLib.MID_MONTHLY_RATE(),
            "Should select 12% APY when 13% fails but 12% works";
    }
    // Property: If only 11% works, it's selected
    else if (backing11 >= mathLib.PRECISION()) {
        assert apyTier == 1 && selectedRate == mathLib.MIN_MONTHLY_RATE(),
            "Should select 11% APY when 13% and 12% fail";
    }
    // Property: If all fail, use 11% with backstop flag
    else {
        assert apyTier == 1 && selectedRate == mathLib.MIN_MONTHLY_RATE() && backstopNeeded,
            "Should use 11% with backstop when all APYs fail";
    }
}

/**
 * @title RULE-REBASE-002: Selected APY always maintains peg (if possible)
 * @notice Backing ratio >= 100% unless backstop needed
 */
rule selectedAPYMaintainsPeg(uint256 currentSupply, uint256 vaultValue, uint256 timeElapsed, uint256 mgmtFeeTokens) {
    require currentSupply > 0;
    require vaultValue > 0;
    require timeElapsed > 0;
    require timeElapsed <= 30 days;
    require vaultValue < max_uint256 / mathLib.PRECISION();
    require currentSupply < max_uint256 / mathLib.MAX_MONTHLY_RATE();
    
    uint256 selectedRate;
    uint256 newSupply;
    uint256 userTokens;
    uint256 feeTokens;
    uint8 apyTier;
    bool backstopNeeded;
    
    (selectedRate, newSupply, userTokens, feeTokens, apyTier, backstopNeeded) = 
        rebaseLib.selectDynamicAPY(currentSupply, vaultValue, timeElapsed, mgmtFeeTokens);
    
    uint256 backingRatio = mathLib.calculateBackingRatio(vaultValue, newSupply);
    
    // Property: If backstop NOT needed, backing >= 100%
    if (!backstopNeeded) {
        assert backingRatio >= mathLib.PRECISION(),
            "Selected APY should maintain peg when backstop not needed";
    }
    
    // Property: If backstop needed, backing < 100%
    if (backstopNeeded) {
        assert backingRatio < mathLib.PRECISION(),
            "Backstop flag implies backing < 100%";
    }
}

/**
 * @title RULE-REBASE-003: Greedy maximization property
 * @notice System chooses highest APY that works
 */
rule greedyMaximization(uint256 currentSupply, uint256 vaultValue, uint256 timeElapsed, uint256 mgmtFeeTokens) {
    require currentSupply > 0;
    require vaultValue > 0;
    require timeElapsed > 0;
    require timeElapsed <= 30 days;
    require vaultValue < max_uint256 / mathLib.PRECISION();
    require currentSupply < max_uint256 / mathLib.MAX_MONTHLY_RATE();
    
    uint256 selectedRate;
    uint256 newSupply;
    uint256 userTokens;
    uint256 feeTokens;
    uint8 apyTier;
    bool backstopNeeded;
    
    (selectedRate, newSupply, userTokens, feeTokens, apyTier, backstopNeeded) = 
        rebaseLib.selectDynamicAPY(currentSupply, vaultValue, timeElapsed, mgmtFeeTokens);
    
    // Property: Selected tier should be highest possible
    // If tier 2 selected, tier 3 should not work
    if (apyTier == 2) {
        uint256 backing13;
        uint256 backing12;
        uint256 backing11;
        (backing13, backing12, backing11) = rebaseLib.simulateAllAPYs(
            currentSupply, vaultValue, timeElapsed, mgmtFeeTokens
        );
        
        assert backing13 < mathLib.PRECISION(),
            "13% APY shouldn't work if 12% selected";
    }
    
    // If tier 1 selected, tiers 2 and 3 should not work (unless backstop needed)
    if (apyTier == 1 && !backstopNeeded) {
        uint256 backing13;
        uint256 backing12;
        uint256 backing11;
        (backing13, backing12, backing11) = rebaseLib.simulateAllAPYs(
            currentSupply, vaultValue, timeElapsed, mgmtFeeTokens
        );
        
        assert backing13 < mathLib.PRECISION() && backing12 < mathLib.PRECISION(),
            "Higher APYs shouldn't work if 11% selected";
    }
}

/**
 * @title RULE-REBASE-004: APY tier corresponds to correct monthly rate
 * @notice Tier 3→13%, Tier 2→12%, Tier 1→11%
 */
rule apyTierCorrespondsToRate(uint256 currentSupply, uint256 vaultValue, uint256 timeElapsed, uint256 mgmtFeeTokens) {
    require currentSupply > 0;
    require vaultValue > 0;
    require timeElapsed > 0;
    require timeElapsed <= 30 days;
    require vaultValue < max_uint256 / mathLib.PRECISION();
    require currentSupply < max_uint256 / mathLib.MAX_MONTHLY_RATE();
    
    uint256 selectedRate;
    uint256 newSupply;
    uint256 userTokens;
    uint256 feeTokens;
    uint8 apyTier;
    bool backstopNeeded;
    
    (selectedRate, newSupply, userTokens, feeTokens, apyTier, backstopNeeded) = 
        rebaseLib.selectDynamicAPY(currentSupply, vaultValue, timeElapsed, mgmtFeeTokens);
    
    // Property: Rate matches tier
    if (apyTier == 3) {
        assert selectedRate == mathLib.MAX_MONTHLY_RATE(),
            "Tier 3 should have 13% APY rate";
    } else if (apyTier == 2) {
        assert selectedRate == mathLib.MID_MONTHLY_RATE(),
            "Tier 2 should have 12% APY rate";
    } else if (apyTier == 1) {
        assert selectedRate == mathLib.MIN_MONTHLY_RATE(),
            "Tier 1 should have 11% APY rate";
    }
}

// ============================================
// RULES - Supply and Fee Calculations
// ============================================

/**
 * @title RULE-REBASE-005: New supply includes all components
 * @notice S_new = S + S_users + S_fee + S_mgmt
 */
rule newSupplyIncludesAllComponents(uint256 currentSupply, uint256 vaultValue, uint256 timeElapsed, uint256 mgmtFeeTokens) {
    require currentSupply > 0;
    require vaultValue > 0;
    require timeElapsed > 0;
    require timeElapsed <= 30 days;
    require vaultValue < max_uint256 / mathLib.PRECISION();
    require currentSupply < max_uint256 / mathLib.MAX_MONTHLY_RATE();
    
    uint256 selectedRate;
    uint256 newSupply;
    uint256 userTokens;
    uint256 feeTokens;
    uint8 apyTier;
    bool backstopNeeded;
    
    (selectedRate, newSupply, userTokens, feeTokens, apyTier, backstopNeeded) = 
        rebaseLib.selectDynamicAPY(currentSupply, vaultValue, timeElapsed, mgmtFeeTokens);
    
    // Property: newSupply = currentSupply + userTokens + feeTokens + mgmtFeeTokens
    assert newSupply == currentSupply + userTokens + feeTokens + mgmtFeeTokens,
        "New supply doesn't include all components";
}

/**
 * @title RULE-REBASE-006: Performance fee is 2% of user tokens
 */
rule performanceFeeIs2PercentInRebase(uint256 currentSupply, uint256 vaultValue, uint256 timeElapsed, uint256 mgmtFeeTokens) {
    require currentSupply > 0;
    require vaultValue > 0;
    require timeElapsed > 0;
    require timeElapsed <= 30 days;
    require vaultValue < max_uint256 / mathLib.PRECISION();
    require currentSupply < max_uint256 / mathLib.MAX_MONTHLY_RATE();
    
    uint256 selectedRate;
    uint256 newSupply;
    uint256 userTokens;
    uint256 feeTokens;
    uint8 apyTier;
    bool backstopNeeded;
    
    (selectedRate, newSupply, userTokens, feeTokens, apyTier, backstopNeeded) = 
        rebaseLib.selectDynamicAPY(currentSupply, vaultValue, timeElapsed, mgmtFeeTokens);
    
    // Property: feeTokens = userTokens × 2%
    uint256 expectedFee = (userTokens * mathLib.PERF_FEE()) / mathLib.PRECISION();
    
    assert feeTokens == expectedFee,
        "Performance fee not 2% of user tokens";
}

// ============================================
// RULES - Rebase Index Updates
// ============================================

/**
 * @title RULE-REBASE-007: Index always increases
 * @notice I_new > I_old for positive rate and time
 */
rule indexAlwaysIncreases(uint256 oldIndex, uint256 selectedRate, uint256 timeElapsed) {
    require oldIndex > 0;
    require oldIndex <= mathLib.PRECISION() * 2;
    require selectedRate > 0;
    require selectedRate <= mathLib.MAX_MONTHLY_RATE();
    require timeElapsed > 0;
    require timeElapsed <= 30 days;
    
    uint256 newIndex = rebaseLib.calculateNewIndex(oldIndex, selectedRate, timeElapsed);
    
    // Property: newIndex > oldIndex
    assert newIndex > oldIndex,
        "Rebase index should always increase";
}

/**
 * @title RULE-REBASE-008: Higher APY produces higher index
 * @notice 13% APY → bigger index growth than 11% APY
 */
rule higherAPYHigherIndex(uint256 oldIndex, uint256 timeElapsed) {
    require oldIndex > 0;
    require oldIndex <= mathLib.PRECISION();
    require timeElapsed > 0;
    require timeElapsed <= 30 days;
    
    uint256 index13 = rebaseLib.calculateNewIndex(oldIndex, mathLib.MAX_MONTHLY_RATE(), timeElapsed);
    uint256 index12 = rebaseLib.calculateNewIndex(oldIndex, mathLib.MID_MONTHLY_RATE(), timeElapsed);
    uint256 index11 = rebaseLib.calculateNewIndex(oldIndex, mathLib.MIN_MONTHLY_RATE(), timeElapsed);
    
    // Property: index13 > index12 > index11
    assert index13 > index12 && index12 > index11,
        "Higher APY should produce higher index";
}

/**
 * @title RULE-REBASE-009: Index growth proportional to time
 * @notice Doubling time approximately doubles index growth
 */
rule indexGrowthProportionalToTime(uint256 oldIndex, uint256 selectedRate, uint256 time1, uint256 time2) {
    require oldIndex > 0;
    require oldIndex <= mathLib.PRECISION();
    require selectedRate > 0;
    require selectedRate <= mathLib.MAX_MONTHLY_RATE();
    require time1 > 0;
    require time2 == time1 * 2;
    require time2 <= 30 days;
    
    uint256 index1 = rebaseLib.calculateNewIndex(oldIndex, selectedRate, time1);
    uint256 index2 = rebaseLib.calculateNewIndex(oldIndex, selectedRate, time2);
    
    uint256 growth1 = index1 - oldIndex;
    uint256 growth2 = index2 - oldIndex;
    
    // Property: growth2 ≈ 2 × growth1 (within rounding)
    assert growth2 >= growth1 * 2 - 2 && growth2 <= growth1 * 2 + 2,
        "Index growth not proportional to time";
}

// ============================================
// RULES - Backstop Flag Logic
// ============================================

/**
 * @title RULE-REBASE-010: Backstop flag correctness
 * @notice Backstop needed ⟺ all APYs fail to maintain peg
 */
rule backstopFlagCorrect(uint256 currentSupply, uint256 vaultValue, uint256 timeElapsed, uint256 mgmtFeeTokens) {
    require currentSupply > 0;
    require vaultValue > 0;
    require timeElapsed > 0;
    require timeElapsed <= 30 days;
    require vaultValue < max_uint256 / mathLib.PRECISION();
    require currentSupply < max_uint256 / mathLib.MAX_MONTHLY_RATE();
    
    uint256 selectedRate;
    uint256 newSupply;
    uint256 userTokens;
    uint256 feeTokens;
    uint8 apyTier;
    bool backstopNeeded;
    
    (selectedRate, newSupply, userTokens, feeTokens, apyTier, backstopNeeded) = 
        rebaseLib.selectDynamicAPY(currentSupply, vaultValue, timeElapsed, mgmtFeeTokens);
    
    uint256 backing13;
    uint256 backing12;
    uint256 backing11;
    (backing13, backing12, backing11) = rebaseLib.simulateAllAPYs(
        currentSupply, vaultValue, timeElapsed, mgmtFeeTokens
    );
    
    // Property: Backstop needed ⟺ even 11% APY fails
    if (backstopNeeded) {
        assert backing11 < mathLib.PRECISION(),
            "Backstop flag set but 11% APY works";
    } else {
        assert backing11 >= mathLib.PRECISION(),
            "Backstop flag not set but 11% APY fails";
    }
}

/**
 * @title RULE-REBASE-011: Backstop always uses 11% APY
 * @notice When backstop needed, use minimum APY
 */
rule backstopUsesMinAPY(uint256 currentSupply, uint256 vaultValue, uint256 timeElapsed, uint256 mgmtFeeTokens) {
    require currentSupply > 0;
    require vaultValue > 0;
    require timeElapsed > 0;
    require timeElapsed <= 30 days;
    require vaultValue < max_uint256 / mathLib.PRECISION();
    require currentSupply < max_uint256 / mathLib.MAX_MONTHLY_RATE();
    
    uint256 selectedRate;
    uint256 newSupply;
    uint256 userTokens;
    uint256 feeTokens;
    uint8 apyTier;
    bool backstopNeeded;
    
    (selectedRate, newSupply, userTokens, feeTokens, apyTier, backstopNeeded) = 
        rebaseLib.selectDynamicAPY(currentSupply, vaultValue, timeElapsed, mgmtFeeTokens);
    
    // Property: If backstop needed, use tier 1 (11% APY)
    if (backstopNeeded) {
        assert apyTier == 1 && selectedRate == mathLib.MIN_MONTHLY_RATE(),
            "Backstop should use minimum APY (11%)";
    }
}

// ============================================
// RULES - Simulation Consistency
// ============================================

/**
 * @title RULE-REBASE-012: Simulation backing ratios are ordered
 * @notice Higher APY → lower backing ratio
 */
rule simulationBackingOrderedByAPY(uint256 currentSupply, uint256 vaultValue, uint256 timeElapsed, uint256 mgmtFeeTokens) {
    require currentSupply > 0;
    require vaultValue > 0;
    require timeElapsed > 0;
    require timeElapsed <= 30 days;
    require vaultValue < max_uint256 / mathLib.PRECISION();
    require currentSupply < max_uint256 / mathLib.MAX_MONTHLY_RATE();
    
    uint256 backing13;
    uint256 backing12;
    uint256 backing11;
    (backing13, backing12, backing11) = rebaseLib.simulateAllAPYs(
        currentSupply, vaultValue, timeElapsed, mgmtFeeTokens
    );
    
    // Property: backing13 <= backing12 <= backing11
    // Higher APY creates more supply, thus lower backing
    assert backing13 <= backing12 && backing12 <= backing11,
        "Simulation backing ratios not correctly ordered";
}

/**
 * @title RULE-REBASE-013: Selected APY matches simulation
 * @notice Backing from selection == backing from simulation
 */
rule selectedAPYMatchesSimulation(uint256 currentSupply, uint256 vaultValue, uint256 timeElapsed, uint256 mgmtFeeTokens) {
    require currentSupply > 0;
    require vaultValue > 0;
    require timeElapsed > 0;
    require timeElapsed <= 30 days;
    require vaultValue < max_uint256 / mathLib.PRECISION();
    require currentSupply < max_uint256 / mathLib.MAX_MONTHLY_RATE();
    
    uint256 selectedRate;
    uint256 newSupply;
    uint256 userTokens;
    uint256 feeTokens;
    uint8 apyTier;
    bool backstopNeeded;
    
    (selectedRate, newSupply, userTokens, feeTokens, apyTier, backstopNeeded) = 
        rebaseLib.selectDynamicAPY(currentSupply, vaultValue, timeElapsed, mgmtFeeTokens);
    
    uint256 backing13;
    uint256 backing12;
    uint256 backing11;
    (backing13, backing12, backing11) = rebaseLib.simulateAllAPYs(
        currentSupply, vaultValue, timeElapsed, mgmtFeeTokens
    );
    
    uint256 selectedBacking = mathLib.calculateBackingRatio(vaultValue, newSupply);
    
    // Property: Selected backing matches corresponding simulation
    if (apyTier == 3) {
        assert selectedBacking == backing13,
            "Selected 13% backing doesn't match simulation";
    } else if (apyTier == 2) {
        assert selectedBacking == backing12,
            "Selected 12% backing doesn't match simulation";
    } else if (apyTier == 1) {
        assert selectedBacking == backing11,
            "Selected 11% backing doesn't match simulation";
    }
}




