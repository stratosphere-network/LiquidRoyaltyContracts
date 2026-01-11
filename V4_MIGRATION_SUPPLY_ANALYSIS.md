# What Happens to Previous Rebased Tokens After V4 Migration?

## Short Answer

**✅ NO, the supply does NOT reduce.** 

All previous rebases are "frozen" into the total supply at migration time. The supply stays the same, but future yield distribution changes from automatic rebasing to direct minting to admin.

---

## Detailed Explanation

### Before Migration (Rebasing Mode)

**How Total Supply Works:**
```solidity
// Formula: totalSupply = (totalShares × rebaseIndex) / PRECISION
function totalSupply() public view returns (uint256) {
    return (totalShares * rebaseIndex) / PRECISION;
}
```

**Example:**
- User deposits 1000 tokens → gets 1000 shares
- After rebases, `rebaseIndex` = 1.1 (10% growth)
- User's balance = `1000 × 1.1 = 1100 tokens`
- Total supply = `(all shares × 1.1) / PRECISION`

**Key Point:** Total supply **grows** as `rebaseIndex` increases, even though shares stay constant.

---

### During Migration (`migrateToNonRebasing()`)

**What Happens:**
```solidity
function migrateToNonRebasing() external onlyAdmin {
    _frozenRebaseIndex = rebaseIndex();  // Freeze current index (e.g., 1.1)
    _directTotalSupply = MathLib.calculateBalanceFromShares(totalShares(), _frozenRebaseIndex);
    // _directTotalSupply = (totalShares × 1.1) / PRECISION
    _migrated = true;
}
```

**The Math:**
```solidity
// MathLib.calculateBalanceFromShares
function calculateBalanceFromShares(uint256 shares, uint256 rebaseIndex) 
    internal pure returns (uint256 balance) {
    return (shares * rebaseIndex) / PRECISION;
}
```

**Example:**
- Before migration: `totalSupply = (1000 shares × 1.1) = 1100 tokens`
- During migration: `_directTotalSupply = (1000 shares × 1.1) = 1100 tokens`
- **Result: Supply stays the same!** ✅

---

### After Migration (Non-Rebasing Mode)

**How Total Supply Works:**
```solidity
function totalSupply() public view override returns (uint256) {
    return _migrated ? _directTotalSupply : /* rebasing calculation */;
}
```

**Key Changes:**

1. **Total Supply:** 
   - Uses `_directTotalSupply` (frozen value at migration time)
   - Only changes via `_mint()` or `_burn()` operations

2. **Rebase Index:**
   - Frozen forever at migration-time value
   - `rebaseIndex()` always returns `_frozenRebaseIndex`

3. **Future Yield:**
   - Before: Yield distributed via increasing `rebaseIndex` (all holders benefit)
   - After: Yield minted directly to `admin()` via `rebase()` function
   - Supply increases, but only via explicit mints to admin

---

## User Balance Preservation

### During Migration

**Lazy Migration Pattern:**
- Users are NOT migrated immediately
- Balance is calculated on-demand using: `shares × frozenRebaseIndex`

**Example:**
```solidity
function balanceOf(address account) public view override returns (uint256) {
    if (!_migrated) return /* rebasing calculation */;
    if (_userMigrated[account]) return _directBalances[account];
    // Lazy migration: calculate on-the-fly
    return MathLib.calculateBalanceFromShares(super.sharesOf(account), _frozenRebaseIndex);
}
```

**When User Interacts:**
```solidity
function _ensureDirectBalance(address account) internal {
    if (!_userMigrated[account]) {
        uint256 s = super.sharesOf(account);
        // Convert shares → direct balance using frozen index
        if (s > 0) _directBalances[account] = MathLib.calculateBalanceFromShares(s, _frozenRebaseIndex);
        _userMigrated[account] = true;
    }
}
```

**Result:** User balance is preserved:
- Before migration: `balance = shares × currentRebaseIndex`
- After migration (lazy): `balance = shares × frozenRebaseIndex`
- Since `frozenRebaseIndex = currentRebaseIndex` at migration time → **same value!**

---

## Supply Comparison

### Scenario: Migration at Current State

**Before Migration:**
```
totalShares = 1,000,000
rebaseIndex = 1.15 (15% growth from rebases)
totalSupply = 1,000,000 × 1.15 = 1,150,000 tokens
```

**After Migration:**
```
_directTotalSupply = 1,000,000 × 1.15 = 1,150,000 tokens
_frozenRebaseIndex = 1.15 (never changes)
totalSupply() = 1,150,000 tokens (same!)
```

**Result:** ✅ Supply is identical

---

## What Changes After Migration?

### 1. Future Yield Distribution

**Before (Rebasing):**
- `rebase()` increases `rebaseIndex` (e.g., 1.15 → 1.16)
- All holders automatically see balance increase
- No new tokens minted, existing tokens "grow"

**After (Non-Rebasing):**
- `rebase()` mints new tokens to `admin()`
- Existing user balances stay constant
- Supply increases via minting (not index growth)

**Example:**
```
Before Migration:
- User has 1000 tokens
- Rebase happens: rebaseIndex 1.15 → 1.16
- User's balance: 1000 → ~1008.7 (automatic)

After Migration:
- User has 1000 tokens (fixed)
- Rebase happens: mints yield to admin
- User's balance: 1000 (unchanged)
- Total supply increases via mint
```

### 2. Supply Growth Mechanism

**Before:**
```
Total Supply Growth = Index Growth
- Supply increases via rebaseIndex multiplier
- Shares stay constant, balances grow
```

**After:**
```
Total Supply Growth = Direct Minting
- Supply increases via _mint() calls
- Admin receives all yield as new tokens
- Existing balances stay fixed
```

---

## Key Points

### ✅ Supply Does NOT Reduce

1. **Migration preserves supply:**
   - `_directTotalSupply = (totalShares × frozenRebaseIndex)`
   - This equals the current `totalSupply` at migration time

2. **All previous rebases are preserved:**
   - Frozen index includes all historical growth
   - User balances reflect all previous rebases

3. **Shares are preserved:**
   - `_shares` mapping is never deleted
   - Can be used for rollback if needed

### ⚠️ What Changes

1. **Future yield distribution:**
   - Goes to admin (not automatically to users)

2. **Balance growth:**
   - User balances stop growing automatically
   - Only grows via deposits or admin distribution

3. **Supply tracking:**
   - Switches from index-based to direct balance tracking

---

## Verification

**To verify supply is preserved:**

```bash
# Before migration
BEFORE_SUPPLY=$(cast call $SENIOR_PROXY "totalSupply()(uint256)" --rpc-url $RPC_URL)

# After migration
AFTER_SUPPLY=$(cast call $SENIOR_PROXY "totalSupply()(uint256)" --rpc-url $RPC_URL)

# They should be equal
echo "Before: $BEFORE_SUPPLY"
echo "After:  $AFTER_SUPPLY"
```

**Expected:** `BEFORE_SUPPLY == AFTER_SUPPLY`

---

## Summary

| Aspect | Before Migration | After Migration | Change |
|--------|-----------------|-----------------|--------|
| **Total Supply** | `shares × rebaseIndex` | `_directTotalSupply` | ✅ **Same value** |
| **Rebase Index** | Increases with rebases | Frozen forever | 🔒 **Frozen** |
| **User Balances** | `shares × rebaseIndex` | `shares × frozenIndex` | ✅ **Same value** |
| **Future Yield** | Increases index (all benefit) | Mints to admin | 🔄 **Distribution changes** |
| **Supply Growth** | Via index multiplier | Via direct minting | 🔄 **Mechanism changes** |

**Conclusion:**
- ✅ Supply does NOT reduce
- ✅ All previous rebases are preserved
- ✅ User balances are preserved
- ⚠️ Only future yield distribution changes (goes to admin instead of automatic rebasing)

The migration is **supply-preserving** - it just changes how future yield is distributed and tracked.
