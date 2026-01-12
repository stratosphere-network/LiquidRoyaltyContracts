# DEX Composability & Balance Scanners: What They Track

## Quick Answer

**All DEXes, AMMs, and balance scanners track `balanceOf()` - NOT `sharesOf()`**

- ✅ **ERC20 Standard**: `balanceOf()` is the standard function
- ✅ **DEXes/AMMs**: Use `balanceOf()` for liquidity pool accounting
- ✅ **Balance Scanners**: Track `balanceOf()` (Etherscan, block explorers, wallets)
- ❌ **Shares**: Internal only, not part of ERC20 standard

---

## Why This Matters

### Before Migration (Rebasing Mode) - ❌ BREAKS DEXes

**The Problem:**
```
1. User adds liquidity to DEX pool
   - DEX records: poolBalance = balanceOf(pool) = 1000 tokens
   
2. Rebase happens (balanceOf increases automatically)
   - User's balance: 1000 → 1010 (automatic growth)
   - Pool's balance: 1000 → 1010 (automatic growth)
   
3. DEX accounting is STALE
   - DEX still thinks pool has 1000 tokens
   - Actual pool has 1010 tokens
   - Accounting mismatch!
   
4. Arbitrageurs exploit the mismatch
   - Buy at stale price
   - Extract value from LPs
   - LPs lose money
```

**Why It Breaks:**
- DEXes track `balanceOf()` at specific points in time
- When rebase happens, `balanceOf()` changes WITHOUT a transfer event
- DEX accounting becomes stale (doesn't match actual balances)
- Creates arbitrage opportunities at LP expense

### After Migration (Non-Rebasing Mode) - ✅ WORKS WITH DEXes

**The Solution:**
```
1. User adds liquidity to DEX pool
   - DEX records: poolBalance = balanceOf(pool) = 1000 tokens
   
2. Rebase happens (mints to admin, NOT to pool)
   - User's balance: 1000 (unchanged)
   - Pool's balance: 1000 (unchanged)
   - Admin's balance: 0 → 10 (new tokens minted)
   
3. DEX accounting stays ACCURATE
   - DEX thinks pool has 1000 tokens
   - Actual pool has 1000 tokens
   - ✅ Perfect match!
   
4. No arbitrage opportunity
   - No stale accounting
   - LPs protected
```

**Why It Works:**
- `balanceOf()` is now fixed (doesn't change with rebases)
- DEX accounting stays accurate
- No automatic balance changes
- Standard ERC20 behavior

---

## What Balance Scanners Track

### All Scanners Use `balanceOf()`

**Examples:**
- ✅ **Etherscan**: Shows `balanceOf()` in token view
- ✅ **Block Explorers**: Track `balanceOf()` for all addresses
- ✅ **Wallets** (MetaMask, etc.): Display `balanceOf()`
- ✅ **Indexers** (The Graph, etc.): Index `balanceOf()` from Transfer events
- ✅ **Analytics Tools**: Track `balanceOf()` for portfolio tracking

**They DON'T Track:**
- ❌ `sharesOf()` - Not part of ERC20 standard
- ❌ Internal share calculations
- ❌ Rebase index values

### How Scanners Work

**Standard ERC20 Tracking:**
```solidity
// Scanners track these events:
event Transfer(address indexed from, address indexed to, uint256 value);

// They calculate balance by:
// balance = sum of all Transfer(to, user) - sum of all Transfer(from, user)
```

**For Rebasing Tokens (Before Migration):**
```
Problem:
- Transfer events only fire on actual transfers
- Rebase changes balanceOf() WITHOUT Transfer events
- Scanners miss the balance changes
- Displayed balance becomes stale
```

**For Non-Rebasing Tokens (After Migration):**
```
Solution:
- All balance changes happen via Transfer events
- Scanners track accurately
- Displayed balance matches actual balance
```

---

## DEX Integration Details

### How AMMs Track Balances

**Uniswap V2/V3 Example:**
```solidity
// AMM tracks pool reserves
uint256 reserve0;  // Token A balance
uint256 reserve1;  // Token B balance

// Updated via:
function _update(uint balance0, uint balance1) {
    reserve0 = balance0;  // Uses token.balanceOf(pool)
    reserve1 = balance1;  // Uses token.balanceOf(pool)
}
```

**The Problem with Rebasing:**
```
1. Pool initialized: reserve0 = 1000, reserve1 = 1000
2. Rebase happens: balanceOf(pool) = 1000 → 1010
3. AMM still thinks: reserve0 = 1000 (stale!)
4. Actual balance: 1010
5. Mismatch = arbitrage opportunity
```

**The Solution (Non-Rebasing):**
```
1. Pool initialized: reserve0 = 1000, reserve1 = 1000
2. Rebase happens: balanceOf(pool) = 1000 (unchanged)
3. AMM thinks: reserve0 = 1000
4. Actual balance: 1000
5. ✅ Perfect match!
```

### Transfer Events Matter

**ERC20 Standard:**
```solidity
// Every balance change should emit Transfer event
event Transfer(address indexed from, address indexed to, uint256 value);
```

**Rebasing Tokens (Before Migration):**
```
Rebase increases balanceOf():
- balanceOf(user) = 1000 → 1010
- ❌ NO Transfer event emitted
- Scanners/DEXes don't see the change
- Accounting breaks
```

**Non-Rebasing Tokens (After Migration):**
```
Rebase mints to admin:
- balanceOf(admin) = 0 → 10
- ✅ Transfer(address(0), admin, 10) event emitted
- Scanners/DEXes see the change
- Accounting stays accurate
```

---

## Composability Impact

### What "Composability" Means

**Definition:** Ability to integrate with other DeFi protocols seamlessly

**Requirements:**
1. ✅ Standard ERC20 interface
2. ✅ Predictable `balanceOf()` behavior
3. ✅ Transfer events for all balance changes
4. ✅ No unexpected balance changes

### Before Migration: ❌ Poor Composability

**Issues:**
- ❌ Breaks AMM/DEX integrations
- ❌ Confuses balance scanners
- ❌ Arbitrage opportunities hurt LPs
- ❌ Unpredictable balance changes
- ❌ Missing Transfer events

**Result:** Limited composability, risky integrations

### After Migration: ✅ Good Composability

**Benefits:**
- ✅ Works with all AMMs/DEXes
- ✅ Accurate balance tracking
- ✅ No arbitrage opportunities
- ✅ Predictable balance behavior
- ✅ Proper Transfer events

**Result:** Full composability, safe integrations

---

## Specific Integrations

### 1. Uniswap/Sushiswap/Other AMMs

**Before Migration:**
```
❌ Pool accounting breaks
❌ LPs lose value to arbitrageurs
❌ Price discovery breaks
```

**After Migration:**
```
✅ Pool accounting accurate
✅ LPs protected
✅ Price discovery works
```

### 2. Lending Protocols (Aave, Compound)

**Before Migration:**
```
❌ Collateral value changes unexpectedly
❌ Liquidations can be triggered incorrectly
❌ Interest calculations break
```

**After Migration:**
```
✅ Collateral value stable
✅ Liquidations work correctly
✅ Interest calculations accurate
```

### 3. Yield Aggregators

**Before Migration:**
```
❌ Balance tracking breaks
❌ Yield calculations incorrect
❌ User confusion
```

**After Migration:**
```
✅ Balance tracking accurate
✅ Yield calculations correct
✅ Clear user experience
```

### 4. Wallets & Block Explorers

**Before Migration:**
```
❌ Displayed balance becomes stale
❌ Users see wrong balances
❌ Confusion and trust issues
```

**After Migration:**
```
✅ Displayed balance accurate
✅ Users see correct balances
✅ Trust maintained
```

---

## Balance Scanner Implementation

### How They Work

**Standard Approach:**
```javascript
// Pseudo-code for balance scanner
function getBalance(address user, address token) {
    // Option 1: Direct call (real-time)
    return token.balanceOf(user);
    
    // Option 2: Event-based (indexed)
    // Sum all Transfer(to, user) events
    // Subtract all Transfer(from, user) events
    let balance = 0;
    for (event of TransferEvents) {
        if (event.to === user) balance += event.value;
        if (event.from === user) balance -= event.value;
    }
    return balance;
}
```

**For Rebasing Tokens:**
```
Problem:
- balanceOf() changes without Transfer events
- Event-based tracking misses changes
- Direct calls work, but cached data becomes stale
```

**For Non-Rebasing Tokens:**
```
Solution:
- All changes emit Transfer events
- Event-based tracking works perfectly
- Cached data stays accurate
```

---

## Summary Table

| Aspect | Before Migration (Rebasing) | After Migration (Non-Rebasing) |
|--------|----------------------------|-------------------------------|
| **DEX Compatibility** | ❌ Breaks (stale accounting) | ✅ Works (accurate accounting) |
| **Balance Scanners** | ❌ Stale balances | ✅ Accurate balances |
| **Transfer Events** | ❌ Missing for rebases | ✅ All changes emit events |
| **Composability** | ❌ Limited (risky) | ✅ Full (safe) |
| **LP Protection** | ❌ Vulnerable to arbitrage | ✅ Protected |
| **What They Track** | `balanceOf()` (but it changes unexpectedly) | `balanceOf()` (stable) |
| **What They DON'T Track** | `sharesOf()` (not ERC20) | `sharesOf()` (not ERC20) |

---

## Key Takeaways

1. **All integrations use `balanceOf()`**
   - DEXes, AMMs, scanners, wallets all track `balanceOf()`
   - `sharesOf()` is internal only, not used by integrations

2. **Rebasing breaks composability**
   - Balance changes without Transfer events
   - Accounting becomes stale
   - Arbitrage opportunities hurt LPs

3. **Non-rebasing enables composability**
   - Fixed balances work with all integrations
   - Proper Transfer events for all changes
   - Accurate accounting everywhere

4. **Migration was necessary**
   - Enables DEX integration
   - Fixes balance scanner issues
   - Restores full composability

**Bottom Line:** The migration from rebasing to non-rebasing was specifically done to fix DEX integration issues. All external systems track `balanceOf()`, and after migration, it behaves like a standard ERC20 token with fixed balances.
