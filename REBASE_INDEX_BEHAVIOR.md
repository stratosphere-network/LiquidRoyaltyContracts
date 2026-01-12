# How Does Rebase Index Work? Does It Keep Getting New Values?

## Short Answer

**Before Migration (Rebasing Mode):**
- ✅ **YES** - `rebaseIndex` keeps increasing with each rebase
- It's cumulative - each rebase multiplies the previous index
- Formula: `I_new = I_old × (1 + rate × timeScaling)`

**After Migration (Non-Rebasing Mode):**
- ❌ **NO** - `rebaseIndex` is frozen forever
- Set once during migration, never changes again

---

## Before Migration: Rebase Index Keeps Growing

### How It Works

**Each time `rebase()` is called:**

```solidity
// Step 5: Update rebase index
uint256 oldIndex = _rebaseIndex;  // Save current index (e.g., 1.15)
_rebaseIndex = FeeLib.calculateNewRebaseIndex(oldIndex, selection.selectedRate, timeElapsed);
// Calculate new index (e.g., 1.15 → 1.1605)
```

**The Formula:**
```solidity
function calculateNewRebaseIndex(
    uint256 oldIndex,      // Current index (e.g., 1.15)
    uint256 monthlyRate,   // Selected APY rate (11-13% annual, scaled to monthly)
    uint256 timeElapsed    // Time since last rebase
) internal pure returns (uint256 newIndex) {
    // Scale monthly rate by actual time elapsed
    uint256 scaledRate = (monthlyRate * timeElapsed) / 30 days;
    
    // I_new = I_old × (1 + scaledRate)
    uint256 multiplier = MathLib.PRECISION + scaledRate;
    return (oldIndex * multiplier) / MathLib.PRECISION;
}
```

### Example Timeline

**Initial State:**
```
rebaseIndex = 1.0 (PRECISION = 1e18, so 1.0 = 1e18)
totalShares = 1,000,000
totalSupply = 1,000,000 × 1.0 = 1,000,000 tokens
```

**Rebase #1 (After 1 month, 12% APY):**
```
oldIndex = 1.0
monthlyRate = 0.01 (12% / 12 = 1% per month)
timeElapsed = 30 days
scaledRate = 0.01 × (30/30) = 0.01
newIndex = 1.0 × (1 + 0.01) = 1.01

Result:
- rebaseIndex: 1.0 → 1.01
- User balance: 1000 → 1010 (10 tokens growth)
- Total supply: 1,000,000 → 1,010,000
```

**Rebase #2 (After another month):**
```
oldIndex = 1.01  // ← Uses previous rebase's index!
monthlyRate = 0.01
timeElapsed = 30 days
newIndex = 1.01 × (1 + 0.01) = 1.0201

Result:
- rebaseIndex: 1.01 → 1.0201
- User balance: 1010 → 1020.1
- Total supply: 1,010,000 → 1,020,100
```

**Rebase #3 (After another month):**
```
oldIndex = 1.0201  // ← Cumulative!
newIndex = 1.0201 × (1 + 0.01) = 1.030301

Result:
- rebaseIndex: 1.0201 → 1.030301
- User balance: 1020.1 → 1030.301
- Total supply: 1,020,100 → 1,030,301
```

### Key Points

1. **Cumulative Growth:**
   - Each rebase multiplies the previous index
   - `I_new = I_old × (1 + rate)`
   - Compounding effect over time

2. **Continuous Updates:**
   - `_rebaseIndex` is updated every time `rebase()` is called
   - It's a state variable that keeps growing
   - Never resets, always accumulates

3. **All Users Benefit:**
   - As index increases, all user balances increase
   - `balance = shares × rebaseIndex`
   - No new tokens minted, existing tokens "grow" via index

---

## After Migration: Rebase Index is Frozen

### During Migration

```solidity
function migrateToNonRebasing() external onlyAdmin {
    _frozenRebaseIndex = rebaseIndex();  // ← Freeze current value (e.g., 1.15)
    _directTotalSupply = MathLib.calculateBalanceFromShares(totalShares(), _frozenRebaseIndex);
    _migrated = true;
}
```

**What Happens:**
- Current `rebaseIndex()` value is captured (e.g., 1.15)
- Stored in `_frozenRebaseIndex`
- Never changes again

### After Migration

```solidity
function rebaseIndex() public view override returns (uint256) {
    return _migrated ? _frozenRebaseIndex : super.rebaseIndex();
    //     ↑ Always returns frozen value if migrated
}
```

**Key Changes:**

1. **Frozen Forever:**
   - `_frozenRebaseIndex` never changes
   - `rebaseIndex()` always returns the same value
   - No more index updates

2. **Rebase() Behavior Changes:**
   ```solidity
   function rebase(uint256 lpPrice) public override onlyAdmin {
       if (!_migrated) { super.rebase(lpPrice); return; }
       // ↑ Above: old rebasing logic (updates index)
       
       // ↓ Below: new non-rebasing logic (mints to admin)
       // No index update!
       uint256 yield = sel.userTokens + sel.feeTokens + mgmtFee;
       if (yield > 0) { 
           _directBalances[admin()] += yield; 
           _directTotalSupply += yield; 
       }
   }
   ```

3. **No More Index Growth:**
   - `rebase()` no longer updates `_rebaseIndex`
   - Index stays at frozen value (e.g., 1.15)
   - Yield distribution switches to direct minting

---

## Comparison Table

| Aspect | Before Migration (Rebasing) | After Migration (Non-Rebasing) |
|--------|----------------------------|-------------------------------|
| **Index Updates** | ✅ Yes, every rebase | ❌ No, frozen forever |
| **Index Formula** | `I_new = I_old × (1 + rate)` | `I = _frozenRebaseIndex` (constant) |
| **Index Growth** | ✅ Cumulative, keeps growing | ❌ Fixed at migration value |
| **User Balance Growth** | ✅ Automatic via index | ❌ Fixed (only grows via deposits) |
| **Yield Distribution** | ✅ All users via index | ❌ Admin receives minted tokens |
| **Total Supply Growth** | ✅ Via index multiplier | ✅ Via direct minting |

---

## Visual Timeline

### Before Migration (Rebasing Mode)

```
Time:     Rebase 0    Rebase 1      Rebase 2      Rebase 3
Index:    1.0    →    1.01    →     1.0201   →    1.030301
Supply:   1M     →    1.01M   →     1.0201M  →    1.030301M
           ↑           ↑              ↑              ↑
        Always growing, cumulative
```

### After Migration (Non-Rebasing Mode)

```
Migration happens at Rebase 3:
_frozenRebaseIndex = 1.030301 (frozen forever)

Time:     Migration    Rebase 4      Rebase 5      Rebase 6
Index:    1.030301  →  1.030301  →  1.030301  →  1.030301
Supply:   1.030301M →  1.040301M →  1.050301M →  1.060301M
           ↑            ↑            ↑            ↑
        Frozen     Mint to admin  Mint to admin  Mint to admin
```

---

## Summary

### Before Migration
- ✅ **YES** - `rebaseIndex` gets a new value with each rebase
- Cumulative growth: `I_new = I_old × (1 + rate)`
- Never resets, keeps compounding
- All users benefit automatically

### After Migration
- ❌ **NO** - `rebaseIndex` is frozen forever
- Set once during migration: `_frozenRebaseIndex = rebaseIndex()`
- Never changes after that
- Yield switches to direct minting to admin

**Key Takeaway:** The rebase index is like a counter that keeps incrementing before migration, but after migration it's frozen at the migration-time value forever. The mechanism changes from "growing the index" to "minting new tokens to admin."
