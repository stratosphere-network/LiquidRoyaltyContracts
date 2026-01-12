# balanceOf vs sharesOf: Key Differences and Implications

## Quick Summary

**Shares (`sharesOf`):**
- Represents the "base units" - constant, doesn't change with rebases
- Like owning "shares" in a company

**Balance (`balanceOf`):**
- Represents the "token amount" - changes with rebases (before migration)
- Like the dollar value of your shares
- Formula: `balance = shares × rebaseIndex`

---

## The Fundamental Concept

### Shares: The Base Unit (Constant)

**What it is:**
```solidity
function sharesOf(address account) public view returns (uint256) {
    return _shares[account];  // Direct storage mapping
}
```

**Characteristics:**
- ✅ **Constant** - Doesn't change with rebases
- ✅ **Only changes with deposits/withdrawals/transfers**
- ✅ **Like "ownership units" in the vault**

### Balance: The Token Amount (Variable)

**What it is:**
```solidity
// Before migration (rebasing mode)
function balanceOf(address account) public view returns (uint256) {
    return (shares × rebaseIndex) / PRECISION;
}

// After migration (non-rebasing mode)
function balanceOf(address account) public view returns (uint256) {
    if (_userMigrated[account]) return _directBalances[account];
    return (shares × frozenRebaseIndex) / PRECISION;
}
```

**Characteristics:**
- ⚠️ **Variable** - Changes with rebases (before migration)
- ✅ **Fixed** - Stays constant (after migration)
- ✅ **Like "token units" users can transfer/trade**

---

## Example Timeline

### Scenario: User Deposits 1000 Tokens

**Initial Deposit:**
```
User deposits: 1000 tokens
rebaseIndex: 1.0
sharesOf(user): 1000 shares
balanceOf(user): 1000 tokens (1000 × 1.0)
```

**After Rebase #1 (1% growth):**
```
rebaseIndex: 1.0 → 1.01
sharesOf(user): 1000 shares (UNCHANGED)
balanceOf(user): 1010 tokens (1000 × 1.01) ← INCREASED!
```

**After Rebase #2 (another 1%):**
```
rebaseIndex: 1.01 → 1.0201
sharesOf(user): 1000 shares (UNCHANGED)
balanceOf(user): 1020.1 tokens (1000 × 1.0201) ← INCREASED MORE!
```

**After Migration (frozen at 1.0201):**
```
frozenRebaseIndex: 1.0201 (frozen forever)
sharesOf(user): 1000 shares (UNCHANGED)
balanceOf(user): 1020.1 tokens (1000 × 1.0201) ← NOW FIXED
```

**After Future Rebase (post-migration):**
```
frozenRebaseIndex: 1.0201 (still frozen)
sharesOf(user): 1000 shares (UNCHANGED)
balanceOf(user): 1020.1 tokens (UNCHANGED - no automatic growth)
// Yield mints to admin instead
```

---

## Key Implications

### 1. Shares Represent "Ownership Units"

**Think of it like:**
- Shares = "Shares of stock" in the vault
- Balance = "Dollar value" of those shares

**Example:**
- You own 1000 shares (constant)
- When vault performs well (rebases), your balance grows
- But you still own the same 1000 shares

### 2. Balance is What Users Transfer/Trade

**ERC20 Standard:**
- `balanceOf()` is what ERC20 contracts use
- Users transfer based on `balanceOf()`
- DEXes/AMMs track `balanceOf()`, not `sharesOf()`

**Example:**
```solidity
// User can transfer based on balance
user.transfer(recipient, 1000);  // Uses balanceOf(user)

// NOT based on shares
// There's no transferShares() function
```

### 3. Deposits/Withdrawals Affect Shares

**When User Deposits:**
```solidity
function deposit(uint256 assets) {
    // Assets = tokens to deposit (e.g., 1000)
    // Shares to mint = assets / rebaseIndex
    uint256 shares = assets / rebaseIndex;
    _shares[user] += shares;  // Shares increase
    // balanceOf automatically increases due to shares increase
}
```

**When User Withdraws:**
```solidity
function withdraw(uint256 assets) {
    // Assets = tokens to withdraw (e.g., 1000)
    // Shares to burn = assets / rebaseIndex
    uint256 shares = assets / rebaseIndex;
    _shares[user] -= shares;  // Shares decrease
    // balanceOf automatically decreases due to shares decrease
}
```

---

## Before Migration (Rebasing Mode)

### Shares Behavior

```solidity
sharesOf(user) = _shares[user]
```

- **Stays constant** between rebases
- **Only changes** with deposits/withdrawals/transfers
- Example: 1000 shares → (rebase happens) → still 1000 shares

### Balance Behavior

```solidity
balanceOf(user) = (shares × rebaseIndex) / PRECISION
```

- **Increases automatically** with each rebase
- **Grows** as `rebaseIndex` increases
- Example: 1000 tokens → (rebase: 1.0 → 1.01) → 1010 tokens

### Relationship

```
balanceOf = sharesOf × rebaseIndex / PRECISION

If rebaseIndex > 1.0:
- balanceOf > sharesOf  ✅ NORMAL
- This represents accumulated yield

If rebaseIndex = 1.0:
- balanceOf = sharesOf  (no yield yet)
```

---

## After Migration (Non-Rebasing Mode)

### Shares Behavior

```solidity
sharesOf(user) = _shares[user]  // Still same storage
```

- **Still constant** (same as before)
- **Preserved** from before migration
- Example: 1000 shares → (migration) → still 1000 shares

### Balance Behavior

**For Migrated Users:**
```solidity
balanceOf(user) = _directBalances[user]
```

- **Fixed value** stored directly
- Set during migration: `_directBalances[user] = shares × frozenRebaseIndex`
- Never changes automatically (only via transfers/deposits/withdrawals)

**For Non-Migrated Users (Lazy):**
```solidity
balanceOf(user) = (shares × frozenRebaseIndex) / PRECISION
```

- **Calculated on-demand** using frozen index
- Same value as migrated users
- Auto-migrates on first interaction

### Relationship

```
balanceOf = sharesOf × frozenRebaseIndex / PRECISION

Since frozenRebaseIndex > 1.0:
- balanceOf > sharesOf  ✅ NORMAL
- This preserves pre-migration yield
```

---

## Practical Implications

### 1. For Users

**What They See:**
- ✅ `balanceOf()` - Their token balance (what they can transfer)
- ❌ `sharesOf()` - Hidden/internal (not visible in wallets)

**What They Experience:**
- Before migration: Balance grows automatically with rebases
- After migration: Balance stays fixed (no automatic growth)

### 2. For Integrations (DEXes/AMMs)

**What Integrations Use:**
- ✅ `balanceOf()` - Used by all ERC20 integrations
- ❌ `sharesOf()` - Internal, not part of ERC20 standard

**Why Migration Was Needed:**
- Before: Rebasing balances confused AMMs (accounting breaks)
- After: Fixed balances work normally with AMMs

### 3. For Protocol Operations

**Deposits:**
```
User deposits 1000 tokens
→ Shares calculated: shares = 1000 / rebaseIndex
→ Shares increase: _shares[user] += shares
→ Balance increases: balanceOf = shares × rebaseIndex = 1000 ✅
```

**Rebases (Before Migration):**
```
Rebase increases rebaseIndex: 1.0 → 1.01
→ Shares unchanged: _shares[user] stays same
→ Balance increases: balanceOf = shares × 1.01 ✅
```

**Rebases (After Migration):**
```
Rebase mints yield to admin
→ Shares unchanged: _shares[user] stays same
→ User balance unchanged: _directBalances[user] stays same
→ Admin balance increases: _directBalances[admin] += yield
```

---

## Common Misconceptions

### ❌ Misconception 1: "Balance should equal shares"

**Wrong:** In a rebasing token, `balanceOf > sharesOf` is normal and expected.

**Why:** The difference represents accumulated yield from rebases.

### ❌ Misconception 2: "Resetting rebase index to 1.0 is fine"

**Wrong:** This would make `balanceOf = sharesOf`, destroying all rebase rewards.

**Why:** Users would lose all accumulated growth.

### ✅ Correct Understanding

**In Rebasing Mode (before migration):**
- `balanceOf = sharesOf × rebaseIndex` where `rebaseIndex > 1.0`
- This is **correct** - represents yield accumulation

**In Non-Rebasing Mode (after migration):**
- `balanceOf = sharesOf × frozenRebaseIndex` where `frozenRebaseIndex > 1.0`
- This is **correct** - preserves pre-migration yield

---

## Summary Table

| Aspect | sharesOf | balanceOf |
|--------|----------|-----------|
| **What it represents** | Base ownership units | Token amount (transferable) |
| **Changes with rebases?** | ❌ No (before/after migration) | ✅ Yes (before), ❌ No (after) |
| **Changes with deposits?** | ✅ Yes | ✅ Yes |
| **ERC20 standard?** | ❌ No (internal) | ✅ Yes (required) |
| **Used by DEXes?** | ❌ No | ✅ Yes |
| **Formula (rebasing)** | Direct storage | `shares × rebaseIndex` |
| **Formula (non-rebasing)** | Direct storage | `_directBalances[user]` or `shares × frozenIndex` |

---

## Key Takeaway

**Shares = Base Units (constant)**
**Balance = Token Amount (variable before migration, fixed after)**

The relationship `balanceOf > sharesOf` when `rebaseIndex > 1.0` is **correct and expected** - it represents accumulated yield. This is NOT a bug, it's how rebasing tokens work!
