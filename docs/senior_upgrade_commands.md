# Senior Vault V4 Upgrade: Cast Commands

## Environment Setup

```bash
# Set these environment variables first
export RPC_URL="https://bartio.rpc.berachain.com"
export ADMIN_KEY="your-admin-private-key"
export SENIOR_PROXY="0xYourSeniorVaultProxyAddress"
```

---

## Pre-Upgrade: Capture Current State

```bash
# Get current total supply (save this to verify later)
cast call $SENIOR_PROXY "totalSupply()" --rpc-url $RPC_URL | cast to-dec

# Get current rebase index (save this)
cast call $SENIOR_PROXY "rebaseIndex()" --rpc-url $RPC_URL | cast to-dec

# Get current epoch
cast call $SENIOR_PROXY "epoch()" --rpc-url $RPC_URL | cast to-dec

# Check admin address
cast call $SENIOR_PROXY "admin()" --rpc-url $RPC_URL

# Check a known user's balance (save this)
export TEST_USER="0xKnownUserAddress"
cast call $SENIOR_PROXY "balanceOf(address)" $TEST_USER --rpc-url $RPC_URL | cast to-dec
```

---

## Step 1: Deploy New Implementation

```bash
# Deploy the new implementation contract
forge create src/concrete/UnifiedConcreteSeniorVault.sol:UnifiedConcreteSeniorVault \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_KEY \
  --verify \
  --verifier-url https://api.routescan.io/v2/network/testnet/evm/80084/etherscan/api \
  --etherscan-api-key "routescan"

# Save the deployed address
export NEW_IMPL="0xNewImplementationAddress"
```

---

## Step 2: Upgrade Proxy to V4

```bash
# Upgrade and call initializeV4()
cast send $SENIOR_PROXY \
  "upgradeToAndCall(address,bytes)" \
  $NEW_IMPL \
  $(cast calldata "initializeV4()") \
  --private-key $ADMIN_KEY \
  --rpc-url $RPC_URL

# Wait for confirmation, then verify
echo "Upgrade transaction sent. Verify below:"
```

---

## Step 3: Verify Upgrade (Before Migration)

```bash
# Should return false (not migrated yet)
echo "Is migrated (should be false):"
cast call $SENIOR_PROXY "isMigrated()" --rpc-url $RPC_URL

# Should return same total supply as before
echo "Total supply (should match pre-upgrade):"
cast call $SENIOR_PROXY "totalSupply()" --rpc-url $RPC_URL | cast to-dec

# Should return same rebase index as before
echo "Rebase index (should match pre-upgrade):"
cast call $SENIOR_PROXY "rebaseIndex()" --rpc-url $RPC_URL | cast to-dec

# User balance should be unchanged
echo "Test user balance (should match pre-upgrade):"
cast call $SENIOR_PROXY "balanceOf(address)" $TEST_USER --rpc-url $RPC_URL | cast to-dec
```

---

## Step 4: Execute Migration (IRREVERSIBLE!)

⚠️ **WARNING: This step cannot be undone. Verify everything above first.**

```bash
# Execute migration
cast send $SENIOR_PROXY \
  "migrateToNonRebasing()" \
  --private-key $ADMIN_KEY \
  --rpc-url $RPC_URL

echo "Migration transaction sent."
```

---

## Step 5: Verify Migration

```bash
# Should return true
echo "Is migrated (should be true):"
cast call $SENIOR_PROXY "isMigrated()" --rpc-url $RPC_URL

# Should return frozen index (same as pre-migration)
echo "Rebase index (now frozen forever):"
cast call $SENIOR_PROXY "rebaseIndex()" --rpc-url $RPC_URL | cast to-dec

# Total supply should be same
echo "Total supply (should match):"
cast call $SENIOR_PROXY "totalSupply()" --rpc-url $RPC_URL | cast to-dec

# User balance should be same
echo "Test user balance (should match):"
cast call $SENIOR_PROXY "balanceOf(address)" $TEST_USER --rpc-url $RPC_URL | cast to-dec
```

---

## Step 6: Batch Migrate Users

```bash
# Migrate single user
cast send $SENIOR_PROXY \
  "migrateUsers(address[])" \
  "[0xUser1Address]" \
  --private-key $ADMIN_KEY \
  --rpc-url $RPC_URL

# Migrate multiple users (batch)
cast send $SENIOR_PROXY \
  "migrateUsers(address[])" \
  "[0xUser1,0xUser2,0xUser3,0xUser4,0xUser5]" \
  --private-key $ADMIN_KEY \
  --rpc-url $RPC_URL
```

**Note:** Keep batches under 100 users to avoid gas limits.

---

## Post-Migration: Calling Rebase

```bash
# Get current LP price (you need to fetch this from your price feed)
export LP_PRICE="1000000000000000000"  # 1e18 = $1.00

# Call rebase (yield goes to admin)
cast send $SENIOR_PROXY \
  "rebase(uint256)" \
  $LP_PRICE \
  --private-key $ADMIN_KEY \
  --rpc-url $RPC_URL

# Check admin balance (should have increased by yield amount)
export ADMIN_ADDRESS=$(cast call $SENIOR_PROXY "admin()" --rpc-url $RPC_URL)
echo "Admin balance after rebase:"
cast call $SENIOR_PROXY "balanceOf(address)" $ADMIN_ADDRESS --rpc-url $RPC_URL | cast to-dec
```

---

## Role Management Commands

```bash
# Check current roles
echo "Admin:"
cast call $SENIOR_PROXY "admin()" --rpc-url $RPC_URL

echo "Liquidity Manager:"
cast call $SENIOR_PROXY "liquidityManager()" --rpc-url $RPC_URL

echo "Price Feed Manager:"
cast call $SENIOR_PROXY "priceFeedManager()" --rpc-url $RPC_URL

echo "Contract Updater:"
cast call $SENIOR_PROXY "contractUpdater()" --rpc-url $RPC_URL

# Set new liquidity manager (RoleType.LIQUIDITY_MANAGER = 0)
cast send $SENIOR_PROXY \
  "setRole(uint8,address)" \
  0 \
  0xNewLiquidityManagerAddress \
  --private-key $ADMIN_KEY \
  --rpc-url $RPC_URL

# Set new price feed manager (RoleType.PRICE_FEED_MANAGER = 1)
cast send $SENIOR_PROXY \
  "setRole(uint8,address)" \
  1 \
  0xNewPriceFeedManagerAddress \
  --private-key $ADMIN_KEY \
  --rpc-url $RPC_URL

# Set new contract updater (RoleType.CONTRACT_UPDATER = 2)
cast send $SENIOR_PROXY \
  "setRole(uint8,address)" \
  2 \
  0xNewContractUpdaterAddress \
  --private-key $ADMIN_KEY \
  --rpc-url $RPC_URL
```

---

## Reward Vault Commands

```bash
# Check current reward vault
cast call $SENIOR_PROXY "rewardVault()" --rpc-url $RPC_URL

# Set reward vault
cast send $SENIOR_PROXY \
  "setRewardVault(address)" \
  0xRewardVaultAddress \
  --private-key $ADMIN_KEY \
  --rpc-url $RPC_URL

# Stake LP tokens into reward vault (Action.STAKE = 0)
cast send $SENIOR_PROXY \
  "executeRewardVaultActions(uint8,uint256)" \
  0 \
  1000000000000000000 \
  --private-key $ADMIN_KEY \
  --rpc-url $RPC_URL

# Withdraw LP tokens from reward vault (Action.WITHDRAW = 1)
cast send $SENIOR_PROXY \
  "executeRewardVaultActions(uint8,uint256)" \
  1 \
  1000000000000000000 \
  --private-key $ADMIN_KEY \
  --rpc-url $RPC_URL
```

---

## Emergency: Check Everything

```bash
echo "=== SENIOR VAULT STATUS ==="

echo -n "Is Migrated: "
cast call $SENIOR_PROXY "isMigrated()" --rpc-url $RPC_URL

echo -n "Total Supply: "
cast call $SENIOR_PROXY "totalSupply()" --rpc-url $RPC_URL | cast to-dec

echo -n "Rebase Index: "
cast call $SENIOR_PROXY "rebaseIndex()" --rpc-url $RPC_URL | cast to-dec

echo -n "Current Epoch: "
cast call $SENIOR_PROXY "epoch()" --rpc-url $RPC_URL | cast to-dec

echo -n "Admin: "
cast call $SENIOR_PROXY "admin()" --rpc-url $RPC_URL

echo -n "Liquidity Manager: "
cast call $SENIOR_PROXY "liquidityManager()" --rpc-url $RPC_URL

echo -n "Reward Vault: "
cast call $SENIOR_PROXY "rewardVault()" --rpc-url $RPC_URL

echo "==========================="
```

---

## Full Upgrade Script (Copy-Paste)

```bash
#!/bin/bash
set -e

# Configuration
export RPC_URL="https://bartio.rpc.berachain.com"
export ADMIN_KEY="your-private-key"
export SENIOR_PROXY="0xYourProxyAddress"

echo "=== PRE-UPGRADE STATE ==="
PRE_SUPPLY=$(cast call $SENIOR_PROXY "totalSupply()" --rpc-url $RPC_URL | cast to-dec)
PRE_INDEX=$(cast call $SENIOR_PROXY "rebaseIndex()" --rpc-url $RPC_URL | cast to-dec)
echo "Total Supply: $PRE_SUPPLY"
echo "Rebase Index: $PRE_INDEX"

echo ""
echo "=== DEPLOYING NEW IMPLEMENTATION ==="
# Uncomment and run this, then set NEW_IMPL
# forge create src/concrete/UnifiedConcreteSeniorVault.sol:UnifiedConcreteSeniorVault \
#   --rpc-url $RPC_URL --private-key $ADMIN_KEY

export NEW_IMPL="0xPasteNewImplAddressHere"

echo ""
echo "=== UPGRADING PROXY ==="
cast send $SENIOR_PROXY \
  "upgradeToAndCall(address,bytes)" \
  $NEW_IMPL \
  $(cast calldata "initializeV4()") \
  --private-key $ADMIN_KEY \
  --rpc-url $RPC_URL

echo ""
echo "=== VERIFYING UPGRADE (not migrated yet) ==="
IS_MIGRATED=$(cast call $SENIOR_PROXY "isMigrated()" --rpc-url $RPC_URL)
echo "Is Migrated: $IS_MIGRATED (should be false)"

echo ""
read -p "Press Enter to execute migration (IRREVERSIBLE!) or Ctrl+C to abort..."

echo ""
echo "=== EXECUTING MIGRATION ==="
cast send $SENIOR_PROXY \
  "migrateToNonRebasing()" \
  --private-key $ADMIN_KEY \
  --rpc-url $RPC_URL

echo ""
echo "=== POST-MIGRATION VERIFICATION ==="
IS_MIGRATED=$(cast call $SENIOR_PROXY "isMigrated()" --rpc-url $RPC_URL)
POST_SUPPLY=$(cast call $SENIOR_PROXY "totalSupply()" --rpc-url $RPC_URL | cast to-dec)
POST_INDEX=$(cast call $SENIOR_PROXY "rebaseIndex()" --rpc-url $RPC_URL | cast to-dec)

echo "Is Migrated: $IS_MIGRATED (should be true)"
echo "Total Supply: $POST_SUPPLY (should match $PRE_SUPPLY)"
echo "Rebase Index: $POST_INDEX (should match $PRE_INDEX, now frozen)"

echo ""
echo "=== UPGRADE COMPLETE ==="
```

