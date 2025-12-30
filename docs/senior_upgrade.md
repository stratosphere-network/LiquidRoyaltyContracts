# Senior Vault V4 Upgrade: Rebasing → Non-Rebasing

## TL;DR

```
1. Deploy new implementation (or use script)
2. upgradeToAndCall(newImpl, "initializeV4()")
3. migrateToNonRebasing()
4. migrateUsers([user1, user2, ...])  // optional, in batches
```

---

## Deployment Script

```bash
# Deploy all new implementations at once
forge script script/DeployNewImplementations.s.sol:DeployNewImplementations \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify

# Output will show:
# Senior:   0x...
# Junior:   0x...
# Reserve:  0x...
```

After deployment, use your **multisig** to call `upgradeToAndCall()` on each proxy.

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
| User balances | ✅ Preserved (lazy migration) |
| Cooldowns | ✅ Separate mapping, untouched |
| Deposits | ✅ Work normally |
| Withdrawals | ✅ Work normally |
| Transfers | ✅ Work normally |
| Shares storage | ✅ Still exists for rollback |

---

## Step-by-Step Upgrade

### Prerequisites

- You are the **admin** (or have multisig access)
- You have the list of current token holders (from indexer/events)

---

### Step 1: Deploy New Implementation

**Option A: Using Forge Script (Recommended)**
```bash
forge script script/DeployNewImplementations.s.sol:DeployNewImplementations \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify
```

**Option B: Using forge create**
```bash
forge create src/concrete/UnifiedConcreteSeniorVault.sol:UnifiedConcreteSeniorVault \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --verify
```

Save the deployed address: `NEW_IMPL_ADDRESS`

---

### Step 2: Upgrade Proxy to V4 (via Multisig)

**Function:** `upgradeToAndCall(address newImplementation, bytes memory data)`

**Caller:** Must be `contractUpdater()` (usually the multisig)

**Get the calldata for initializeV4():**
```bash
cast calldata "initializeV4()"
# Returns: 0x54a08606
```

**Multisig transaction:**
- **To:** Senior Vault Proxy (`0x49298F4314eb127041b814A2616c25687Db6b650`)
- **Function:** `upgradeToAndCall(address,bytes)`
- **Params:**
  - `newImplementation`: `NEW_IMPL_ADDRESS`
  - `data`: `0x54a08606`

**Using cast (if not multisig):**
```bash
cast send $SENIOR_PROXY \
  "upgradeToAndCall(address,bytes)" \
  $NEW_IMPL_ADDRESS \
  0x54a08606 \
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
# Should return current rebase index (still dynamic)
cast call $SENIOR_PROXY "rebaseIndex()" --rpc-url $RPC_URL

# Should return current total supply
cast call $SENIOR_PROXY "totalSupply()" --rpc-url $RPC_URL

# Check a user's balance
cast call $SENIOR_PROXY "balanceOf(address)" $USER_ADDRESS --rpc-url $RPC_URL
```

✅ If all values match pre-upgrade, proceed to migration.

---

### Step 4: Execute Migration (IRREVERSIBLE!)

**Function:** `migrateToNonRebasing()`

**Caller:** Must be `admin()`

**Multisig transaction:**
- **To:** Senior Vault Proxy
- **Function:** `migrateToNonRebasing()`
- **Params:** none

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

⚠️ **This is PERMANENT. No undo via contract.**

---

### Step 5: Verify Migration

```bash
# Should return frozen index (never changes again)
cast call $SENIOR_PROXY "rebaseIndex()" --rpc-url $RPC_URL

# Should return same total supply as before
cast call $SENIOR_PROXY "totalSupply()" --rpc-url $RPC_URL

# Check a user's balance (should be same as before)
cast call $SENIOR_PROXY "balanceOf(address)" $USER_ADDRESS --rpc-url $RPC_URL
```

---

### Step 6: Batch Migrate Users (Optional but Recommended)

**Function:** `migrateUsers(address[] calldata users)`

**Caller:** `admin()` OR `liquidityManager()`

Users who aren't batch-migrated still work (lazy migration on first interaction). But batch migration is more gas-efficient.

```bash
# Migrate users in batches of 50-100
cast send $SENIOR_PROXY \
  "migrateUsers(address[])" \
  "[0xUser1,0xUser2,0xUser3]" \
  --private-key $ADMIN_KEY \
  --rpc-url $RPC_URL
```

**What happens per user:**
- If `_userMigrated[user] == true`: Skip (already migrated)
- If `sharesOf(user) == 0`: Sets `_userMigrated[user] = true`, balance = 0
- Otherwise: `_directBalances[user] = shares × frozenIndex`, `_userMigrated[user] = true`

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
| `migrateUsers(address[])` | `admin()` or `liquidityManager()` | Batch converts shares → direct balances |

### Overridden Functions (Behavior Changes Post-Migration)

| Function | Pre-Migration | Post-Migration |
|----------|---------------|----------------|
| `balanceOf(user)` | `shares × index` | `_directBalances[user]` or lazy fallback |
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

- [ ] `rebaseIndex()` returns frozen value (doesn't change after rebase)
- [ ] `totalSupply()` matches pre-migration value
- [ ] User `balanceOf()` returns expected values
- [ ] `deposit()` works → mints to direct balance
- [ ] `withdraw()` works → burns from direct balance
- [ ] `transfer()` works → updates direct balances
- [ ] `rebase()` mints yield to admin (not to users)

---

## Rollback Options

| Scenario | Can Rollback? | How |
|----------|---------------|-----|
| After upgrade, before `migrateToNonRebasing()` | ✅ Full | Upgrade to old implementation |
| After `migrateToNonRebasing()` | ⚠️ Needs recovery | Deploy recovery impl that sets `_migrated = false` |
| User shares | ✅ Always preserved | `_shares` mapping never deleted |

---

## FAQ

### Will I lose my tokens?
**No.** `directBalance = shares × frozenIndex`. Same value, different storage. Shares still exist for potential rollback.

### What if I'm not batch-migrated?
**You still work.** Fallback calculates `shares × frozenIndex`. First interaction auto-migrates you via `_ensureDirectBalance()`.

### Can I still deposit/withdraw?
**Yes.** Both work normally, just using direct balances instead of shares.

### How do I get yield after migration?
**Admin distributes it.** `rebase()` mints yield to admin who distributes manually.

### Can this be reversed?
**Not easily.** Once `migrateToNonRebasing()` is called, `_migrated = true` is permanent. However, a recovery implementation could be deployed that reads from the still-existing `_shares` mapping.

### What about `sharesOf()` and `totalShares()`?
These are NOT overridden. Post-migration they return stale parent values. Use `balanceOf()` and `totalSupply()` instead.

### What about users with shares but no transfer events?
**They're fine.** The `_shares` mapping stores their shares correctly. `balanceOf()` calculates from shares × frozenIndex. They can withdraw normally.

---

## Emergency Contacts

For questions about this upgrade, contact the protocol team.
