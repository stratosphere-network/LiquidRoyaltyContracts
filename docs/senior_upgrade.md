# Senior Vault V4 Upgrade: Rebasing → Non-Rebasing

## TL;DR

```
1. Deploy new implementation
2. upgradeToAndCall(newImpl, "initializeV4()")
3. migrateToNonRebasing()
4. migrateUsers([user1, user2, ...])  // optional, in batches
```

---

## Why This Migration?

Rebasing tokens break DEXes/AMMs:
- AMMs track balances directly, not shares
- When rebase happens, AMM accounting goes stale
- Arbitrageurs extract value, LPs lose

**After migration:** Balance is static. Yield minted to admin for manual distribution.

---

## What Changes?

| Aspect | Before | After |
|--------|--------|-------|
| Balance calculation | `shares × rebaseIndex` | Fixed `_directBalances[user]` |
| Yield distribution | Automatic via rebase | Minted to admin |
| DEX compatible | ❌ | ✅ |
| `rebaseIndex()` | Changes each rebase | Frozen forever |

---

## Nothing Breaks

| Component | Status |
|-----------|--------|
| User balances | ✅ Preserved (same math) |
| Cooldowns | ✅ Separate mapping, untouched |
| Deposits | ✅ Work normally |
| Withdrawals | ✅ Work normally |
| Transfers | ✅ Work normally |

---

## Step-by-Step Upgrade

### Prerequisites

- You are the **admin** of the Senior Vault proxy
- You have the list of current token holders (from indexer/events)

---

### Step 1: Deploy New Implementation

```bash
forge create src/concrete/UnifiedConcreteSeniorVault.sol:UnifiedConcreteSeniorVault \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --verify
```

Save the deployed address: `NEW_IMPL_ADDRESS`

---

### Step 2: Upgrade Proxy to V4

**Function:** `upgradeToAndCall(address newImplementation, bytes memory data)`

**Caller:** Must be `admin()`

```solidity
// Encode the initializeV4() call
bytes memory initData = abi.encodeWithSignature("initializeV4()");

// Call upgrade on the proxy
seniorVaultProxy.upgradeToAndCall(NEW_IMPL_ADDRESS, initData);
```

**Using cast:**
```bash
cast send $SENIOR_PROXY \
  "upgradeToAndCall(address,bytes)" \
  $NEW_IMPL_ADDRESS \
  $(cast calldata "initializeV4()") \
  --private-key $ADMIN_KEY \
  --rpc-url $RPC_URL
```

**What happens:**
- Proxy points to new implementation
- `initializeV4()` is called (sets reinitializer to 4)
- Token still rebasing (migration not triggered yet)

---

### Step 3: Verify Upgrade (Before Migration)

```bash
# Should return false - not migrated yet
cast call $SENIOR_PROXY "isMigrated()" --rpc-url $RPC_URL
# Expected: false

# Should return current rebase index (still dynamic)
cast call $SENIOR_PROXY "rebaseIndex()" --rpc-url $RPC_URL

# Should return current total supply
cast call $SENIOR_PROXY "totalSupply()" --rpc-url $RPC_URL
```

✅ If all good, proceed to migration.

---

### Step 4: Execute Migration (IRREVERSIBLE!)

**Function:** `migrateToNonRebasing()`

**Caller:** Must be `admin()`

```bash
cast send $SENIOR_PROXY \
  "migrateToNonRebasing()" \
  --private-key $ADMIN_KEY \
  --rpc-url $RPC_URL
```

**What happens:**
1. `_frozenRebaseIndex` = current `rebaseIndex()`
2. `_epochAtMigration` = current `epoch()`
3. `_directTotalSupply` = `totalShares × frozenIndex`
4. `_migrated` = `true`

⚠️ **This is PERMANENT. No undo.**

---

### Step 5: Verify Migration

```bash
# Should return true
cast call $SENIOR_PROXY "isMigrated()" --rpc-url $RPC_URL
# Expected: true

# Should return frozen index (never changes again)
cast call $SENIOR_PROXY "rebaseIndex()" --rpc-url $RPC_URL

# Check a user's balance (should be same as before)
cast call $SENIOR_PROXY "balanceOf(address)" $USER_ADDRESS --rpc-url $RPC_URL
```

---

### Step 6: Batch Migrate Users (Recommended)

**Function:** `migrateUsers(address[] calldata users)`

**Caller:** Must be `admin()`

Users who aren't batch-migrated still work (lazy migration on first interaction). But batch migration is more gas-efficient.

```bash
# Migrate users in batches of 50-100
cast send $SENIOR_PROXY \
  "migrateUsers(address[])" \
  "[0xUser1,0xUser2,0xUser3,...]" \
  --private-key $ADMIN_KEY \
  --rpc-url $RPC_URL
```

**What happens per user:**
- If `_directBalances[user] > 0`: Skip (already migrated)
- If `sharesOf(user) == 0`: Skip (no balance)
- Otherwise: `_directBalances[user] = shares × frozenIndex`

---

## Post-Migration: Yield Distribution

After migration, `rebase()` no longer increases user balances. Instead:

**Function:** `rebase(uint256 lpPrice)`

**Caller:** Must be `admin()`

```bash
cast send $SENIOR_PROXY \
  "rebase(uint256)" \
  $LP_PRICE_18_DECIMALS \
  --private-key $ADMIN_KEY \
  --rpc-url $RPC_URL
```

**What happens:**
1. Yield calculated using same APY logic (11-13%)
2. All yield tokens minted to `admin()` address
3. Admin distributes manually (airdrop, claim contract, etc.)

---

## Role Management Summary

| Role | How to Get | How to Check |
|------|------------|--------------|
| `admin()` | Set during deploy, transferable via `transferAdmin()` | `cast call $PROXY "admin()"` |
| `liquidityManager()` | `setRole(0, address)` | `cast call $PROXY "liquidityManager()"` |
| `priceFeedManager()` | `setRole(1, address)` | `cast call $PROXY "priceFeedManager()"` |
| `contractUpdater()` | `setRole(2, address)` | `cast call $PROXY "contractUpdater()"` |

**Setting roles:**
```bash
# RoleType enum: 0 = LIQUIDITY_MANAGER, 1 = PRICE_FEED_MANAGER, 2 = CONTRACT_UPDATER
cast send $SENIOR_PROXY \
  "setRole(uint8,address)" \
  0 \
  $NEW_LIQUIDITY_MANAGER \
  --private-key $ADMIN_KEY \
  --rpc-url $RPC_URL
```

---

## All V4 Functions

### Migration Functions

| Function | Caller | Description |
|----------|--------|-------------|
| `initializeV4()` | Called via upgradeToAndCall | Prepares V4, does NOT migrate |
| `migrateToNonRebasing()` | `admin()` | Freezes index, enables non-rebasing mode |
| `migrateUsers(address[])` | `admin()` | Batch converts shares → direct balances |
| `isMigrated()` | Anyone (view) | Returns `true` if migrated |

### Overridden Functions (Behavior Changes Post-Migration)

| Function | Pre-Migration | Post-Migration |
|----------|---------------|----------------|
| `balanceOf(user)` | `shares × index` | `_directBalances[user]` or fallback |
| `totalSupply()` | `totalShares × index` | `_directTotalSupply` |
| `rebaseIndex()` | Current index | Frozen index |
| `epoch()` | Current epoch | `epochAtMigration + offset` |
| `rebase(lpPrice)` | Increases index | Mints yield to admin |

### Internal Behavior (Automatic)

| Function | What Happens |
|----------|--------------|
| `_transfer()` | Lazy-migrates sender/receiver, then transfers direct balances |
| `_mint()` | Lazy-migrates receiver, then adds to direct balance |
| `_burn()` | Lazy-migrates sender, then subtracts from direct balance |
| `_ensureDirectBalance()` | Converts shares → direct balance on first interaction |

---

## Verification Checklist

After upgrade:

- [ ] `isMigrated()` returns `true`
- [ ] `rebaseIndex()` returns frozen value (doesn't change)
- [ ] `totalSupply()` matches pre-migration value
- [ ] User `balanceOf()` returns expected values
- [ ] `deposit()` works → mints to direct balance
- [ ] `withdraw()` works → burns from direct balance
- [ ] `transfer()` works → updates direct balances
- [ ] `rebase()` mints yield to admin (not to users)

---

## FAQ

### Will I lose my tokens?
**No.** `directBalance = shares × frozenIndex`. Same value, different storage.

### What if I'm not batch-migrated?
**You still work.** Fallback calculates `shares × frozenIndex`. First interaction auto-migrates you.

### Can I still deposit/withdraw?
**Yes.** Both work normally, just using direct balances instead of shares.

### How do I get yield after migration?
**Admin distributes it.** `rebase()` mints yield to admin who distributes manually.

### Can this be reversed?
**No.** Once `migrateToNonRebasing()` is called, it's permanent.

### What about `sharesOf()` and `totalShares()`?
These are NOT overridden. Post-migration they return stale parent values. Use `balanceOf()` and `totalSupply()` instead.

---

## Emergency Contacts

For questions about this upgrade, contact the protocol team.
