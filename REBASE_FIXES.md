# 🔧 Rebase Time-Based Fixes - Summary

## Problems Fixed

### ❌ Problem 1: Time Mismatch (Monthly vs. Time-Based)
**Issue:** Management fees were time-based, but user rewards and rebase index were monthly-based.

**Before:**
```solidity
// Management fee: ✅ Correctly time-based
mgmtFeeTokens = (vaultValue × 1% × timeElapsed) / 365 days

// User rewards: ❌ WRONG - assumes exactly 1 month
userTokens = currentSupply × monthlyRate (fixed ~1%)

// Rebase index: ❌ WRONG - assumes exactly 1 month
_rebaseIndex = oldIndex × (1 + monthlyRate)
```

**After:**
```solidity
// Management fee: ✅ Time-based
mgmtFeeTokens = (vaultValue × 1% × timeElapsed) / 365 days

// User rewards: ✅ NOW time-based!
scaledRate = monthlyRate × (timeElapsed / 30 days)
userTokens = currentSupply × scaledRate

// Rebase index: ✅ NOW time-based!
scaledRate = monthlyRate × (timeElapsed / 30 days)
_rebaseIndex = oldIndex × (1 + scaledRate)
```

**Example:**
```
Scenario: Rebase happens after 45 days instead of 30

BEFORE (WRONG):
- Management fee: 0.123% ✅ (45/365 × 1%)
- User rewards: 1% ❌ (only 1 month's worth)
- Index growth: 1% ❌ (only 1 month's worth)

AFTER (CORRECT):
- Management fee: 0.123% ✅ (45/365 × 1%)
- User rewards: 1.5% ✅ (45/30 × 1% = 1.5 months' worth)
- Index growth: 1.5% ✅ (45/30 × 1% = 1.5 months' worth)
```

---

### ❌ Problem 2: Management Fee Excluded from APY Selection
**Issue:** APY selection calculated backing ratios WITHOUT management fee tokens, leading to incorrect APY tier selection.

**Before:**
```solidity
// Step 1: Calculate management fee
mgmtFeeTokens = calculateManagementFeeTokens(...)

// Step 2: Select APY (WITHOUT management fee!)
selection = selectDynamicAPY(currentSupply, vaultValue)
// Inside: newSupply = currentSupply + userTokens + perfFee
//         ❌ Does NOT include mgmtFeeTokens!

// Step 3: Add management fee AFTER selection
actualNewSupply = selection.newSupply + mgmtFeeTokens
```

**After:**
```solidity
// Step 1: Calculate management fee
mgmtFeeTokens = calculateManagementFeeTokens(...)

// Step 2: Select APY (WITH management fee!)
selection = selectDynamicAPY(currentSupply, vaultValue, timeElapsed, mgmtFeeTokens)
// Inside: newSupply = currentSupply + userTokens + perfFee + mgmtFeeTokens
//         ✅ NOW includes mgmtFeeTokens!

// Step 3: Use selection.newSupply directly (already includes mgmt fee)
finalBackingRatio = calculateBackingRatio(vaultValue, selection.newSupply)
```

**Example:**
```
Vault Value: $100,100
Current Supply: $100,000
Management Fee: $200

BEFORE (WRONG):
- Calculate newSupply WITHOUT mgmt fee: $100,100
- Backing = 100,100 / 100,100 = 100.0% → Select 13% APY ✅
- Add mgmt fee: actualNewSupply = $100,300
- Real backing = 100,100 / 100,300 = 99.8% ❌ (Under 100%! Wrong APY!)

AFTER (CORRECT):
- Calculate newSupply WITH mgmt fee: $100,300
- Backing = 100,100 / 100,300 = 99.8% → Select 12% APY ✅
- No recalculation needed
- Consistent backing ratio throughout
```

---

## Files Changed

### 1. `/src/libraries/FeeLib.sol`

#### `calculateRebaseSupply()` - Added time scaling and management fee
```diff
  function calculateRebaseSupply(
      uint256 currentSupply,
      uint256 monthlyRate,
+     uint256 timeElapsed,
+     uint256 mgmtFeeTokens
  ) internal pure returns (...)

+ // TIME-BASED FIX: Scale monthly rate by actual time elapsed
+ uint256 scaledRate = (monthlyRate * timeElapsed) / 30 days;

- userTokens = (currentSupply * monthlyRate) / PRECISION;
+ userTokens = (currentSupply * scaledRate) / PRECISION;

  feeTokens = calculatePerformanceFee(userTokens);

- newSupply = currentSupply + userTokens + feeTokens;
+ newSupply = currentSupply + userTokens + feeTokens + mgmtFeeTokens;
```

#### `calculateNewRebaseIndex()` - Added time scaling
```diff
  function calculateNewRebaseIndex(
      uint256 oldIndex,
      uint256 monthlyRate,
+     uint256 timeElapsed
  ) internal pure returns (uint256 newIndex)

+ // TIME-BASED FIX: Scale monthly rate by actual time elapsed
+ uint256 scaledRate = (monthlyRate * timeElapsed) / 30 days;

- uint256 multiplier = MathLib.PRECISION + monthlyRate;
+ uint256 multiplier = MathLib.PRECISION + scaledRate;
```

### 2. `/src/libraries/RebaseLib.sol`

#### `selectDynamicAPY()` - Added time and management fee parameters
```diff
  function selectDynamicAPY(
      uint256 currentSupply,
      uint256 netVaultValue,
+     uint256 timeElapsed,
+     uint256 mgmtFeeTokens
  ) internal pure returns (APYSelection memory selection)

  // Try each APY tier with NEW parameters
  (newSupply13, userTokens13, feeTokens13) = 
-     FeeLib.calculateRebaseSupply(currentSupply, MAX_MONTHLY_RATE);
+     FeeLib.calculateRebaseSupply(currentSupply, MAX_MONTHLY_RATE, timeElapsed, mgmtFeeTokens);
```

### 3. `/src/abstract/UnifiedSeniorVault.sol`

#### `rebase()` - Pass time and management fee to selection
```diff
  // Step 1: Calculate management fee (same)
  uint256 timeElapsed = block.timestamp - _lastRebaseTime;
  uint256 mgmtFeeTokens = FeeLib.calculateManagementFeeTokens(_vaultValue, timeElapsed);

  // Step 2: Dynamic APY selection
  RebaseLib.APYSelection memory selection = RebaseLib.selectDynamicAPY(
      currentSupply,
      _vaultValue,
+     timeElapsed,      // TIME-BASED FIX
+     mgmtFeeTokens     // MGMT FEE FIX
  );

  // Step 4: Determine zone
- uint256 actualNewSupply = selection.newSupply + mgmtFeeTokens;
- uint256 finalBackingRatio = MathLib.calculateBackingRatio(_vaultValue, actualNewSupply);
+ // selection.newSupply now ALREADY includes mgmtFeeTokens
+ uint256 finalBackingRatio = MathLib.calculateBackingRatio(_vaultValue, selection.newSupply);

  // Step 5: Update rebase index
- _rebaseIndex = FeeLib.calculateNewRebaseIndex(oldIndex, selection.selectedRate);
+ _rebaseIndex = FeeLib.calculateNewRebaseIndex(oldIndex, selection.selectedRate, timeElapsed);
```

---

## Testing Scenarios

### Scenario 1: Normal Monthly Rebase (30 days)
```
Time elapsed: 30 days
Old behavior: 1% growth
New behavior: 1% growth
Result: ✅ Same (backward compatible)
```

### Scenario 2: Late Rebase (45 days)
```
Time elapsed: 45 days
Old behavior: 1% growth (WRONG - users underpaid!)
New behavior: 1.5% growth (CORRECT - 1.5 months)
Result: ✅ Fixed!
```

### Scenario 3: Early Rebase (15 days)
```
Time elapsed: 15 days
Old behavior: 1% growth (WRONG - users overpaid!)
New behavior: 0.5% growth (CORRECT - 0.5 months)
Result: ✅ Fixed!
```

### Scenario 4: Edge Case - High Management Fee
```
Vault: $100,100
Supply: $100,000
Mgmt fee: $300

Old behavior:
- APY selection: backing = 100,100 / 100,100 = 100.0% → 13% APY
- After mgmt fee: backing = 100,100 / 100,400 = 99.7% ❌ (Wrong tier!)

New behavior:
- APY selection: backing = 100,100 / 100,400 = 99.7% → 12% APY ✅
Result: ✅ Fixed!
```

---

## Migration Notes

### For Existing Deployments
- These fixes are **backward compatible** for monthly rebases
- If rebases have always been exactly 30 days apart, results will be identical
- If rebases were irregular, users will now get **correct** rewards

### For Testing
- Test with various `timeElapsed` values:
  - 15 days (half month)
  - 30 days (normal)
  - 45 days (1.5 months)
  - 60 days (2 months)
- Verify user rewards scale linearly with time
- Verify APY selection uses correct backing ratio

---

## Summary

✅ **Problem 1 Fixed:** All calculations (user rewards, performance fee, rebase index) now scale with actual time elapsed
✅ **Problem 2 Fixed:** APY selection now includes management fee tokens in backing ratio calculations
✅ **Zero linter errors**
✅ **Backward compatible** for 30-day rebases
✅ **More accurate** for irregular rebase intervals

Users now get exactly what they're promised, regardless of rebase timing! 🎉

