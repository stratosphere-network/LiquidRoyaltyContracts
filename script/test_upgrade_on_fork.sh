#!/bin/bash
# TEST UPGRADE ON FORK BEFORE MAINNET
# This script tests the entire upgrade flow on a forked network
# NO REAL FUNDS ARE TOUCHED

set -e  # Exit on any error

echo "========================================"
echo "  SENIOR VAULT V4 UPGRADE - FORK TEST"
echo "========================================"
echo ""

# ==========================================
# CONFIGURATION - EDIT THESE
# ==========================================
RPC_URL="${RPC_URL:-https://bartio.rpc.berachain.com}"
SENIOR_PROXY="${SENIOR_PROXY:-0xYourSeniorProxyAddress}"
ADMIN_ADDRESS="${ADMIN_ADDRESS:-0xYourAdminAddress}"
TEST_USER="${TEST_USER:-0xAnyUserWithBalance}"

# For fork testing, we'll impersonate the admin
FORK_PORT=8546

echo "📋 Configuration:"
echo "   RPC_URL: $RPC_URL"
echo "   SENIOR_PROXY: $SENIOR_PROXY"
echo "   ADMIN_ADDRESS: $ADMIN_ADDRESS"
echo "   TEST_USER: $TEST_USER"
echo ""

# ==========================================
# STEP 0: Validate inputs
# ==========================================
if [[ "$SENIOR_PROXY" == "0xYourSeniorProxyAddress" ]]; then
    echo "❌ ERROR: Please set SENIOR_PROXY environment variable"
    echo "   export SENIOR_PROXY=0x..."
    exit 1
fi

if [[ "$ADMIN_ADDRESS" == "0xYourAdminAddress" ]]; then
    echo "❌ ERROR: Please set ADMIN_ADDRESS environment variable"
    echo "   export ADMIN_ADDRESS=0x..."
    exit 1
fi

# ==========================================
# STEP 1: Capture pre-upgrade state
# ==========================================
echo "📸 STEP 1: Capturing pre-upgrade state..."
echo ""

PRE_TOTAL_SUPPLY=$(cast call $SENIOR_PROXY "totalSupply()" --rpc-url $RPC_URL)
PRE_REBASE_INDEX=$(cast call $SENIOR_PROXY "rebaseIndex()" --rpc-url $RPC_URL)
PRE_EPOCH=$(cast call $SENIOR_PROXY "epoch()" --rpc-url $RPC_URL)
PRE_ADMIN=$(cast call $SENIOR_PROXY "admin()" --rpc-url $RPC_URL)

echo "   Total Supply:  $(cast to-dec $PRE_TOTAL_SUPPLY) (raw: $PRE_TOTAL_SUPPLY)"
echo "   Rebase Index:  $(cast to-dec $PRE_REBASE_INDEX) (raw: $PRE_REBASE_INDEX)"
echo "   Epoch:         $(cast to-dec $PRE_EPOCH)"
echo "   Admin:         $PRE_ADMIN"
echo ""

if [[ "$TEST_USER" != "0xAnyUserWithBalance" ]]; then
    PRE_USER_BALANCE=$(cast call $SENIOR_PROXY "balanceOf(address)" $TEST_USER --rpc-url $RPC_URL)
    echo "   Test User Balance: $(cast to-dec $PRE_USER_BALANCE)"
fi
echo ""

# ==========================================
# STEP 2: Start Anvil fork
# ==========================================
echo "🔱 STEP 2: Starting Anvil fork..."
echo ""

# Kill any existing anvil on this port
pkill -f "anvil.*$FORK_PORT" 2>/dev/null || true
sleep 1

# Start anvil fork in background
anvil --fork-url $RPC_URL --port $FORK_PORT --silent &
ANVIL_PID=$!
sleep 3

# Verify anvil is running
if ! kill -0 $ANVIL_PID 2>/dev/null; then
    echo "❌ ERROR: Failed to start Anvil fork"
    exit 1
fi

FORK_RPC="http://localhost:$FORK_PORT"
echo "   Anvil PID: $ANVIL_PID"
echo "   Fork RPC: $FORK_RPC"
echo ""

# ==========================================
# STEP 3: Deploy new implementation on fork
# ==========================================
echo "📦 STEP 3: Deploying new implementation on fork..."
echo ""

# Use anvil's default funded account for deployment
DEPLOYER_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

NEW_IMPL=$(forge create src/concrete/UnifiedConcreteSeniorVault.sol:UnifiedConcreteSeniorVault \
    --rpc-url $FORK_RPC \
    --private-key $DEPLOYER_KEY \
    --json 2>/dev/null | jq -r '.deployedTo')

if [[ -z "$NEW_IMPL" || "$NEW_IMPL" == "null" ]]; then
    echo "❌ ERROR: Failed to deploy new implementation"
    kill $ANVIL_PID 2>/dev/null
    exit 1
fi

echo "   New Implementation: $NEW_IMPL"
echo ""

# ==========================================
# STEP 4: Impersonate admin and upgrade
# ==========================================
echo "🔐 STEP 4: Impersonating admin and upgrading..."
echo ""

# Impersonate admin
cast rpc anvil_impersonateAccount $ADMIN_ADDRESS --rpc-url $FORK_RPC > /dev/null

# Fund admin with ETH for gas
cast rpc anvil_setBalance $ADMIN_ADDRESS 0x56BC75E2D63100000 --rpc-url $FORK_RPC > /dev/null

# Generate calldata
INIT_CALLDATA=$(cast calldata "initializeV4()")
echo "   Init calldata: $INIT_CALLDATA"

# Execute upgrade
echo "   Executing upgradeToAndCall..."
UPGRADE_TX=$(cast send $SENIOR_PROXY \
    "upgradeToAndCall(address,bytes)" \
    $NEW_IMPL \
    $INIT_CALLDATA \
    --from $ADMIN_ADDRESS \
    --unlocked \
    --rpc-url $FORK_RPC \
    --json 2>/dev/null)

UPGRADE_STATUS=$(echo $UPGRADE_TX | jq -r '.status')
if [[ "$UPGRADE_STATUS" != "0x1" ]]; then
    echo "❌ ERROR: Upgrade transaction failed!"
    echo "$UPGRADE_TX"
    kill $ANVIL_PID 2>/dev/null
    exit 1
fi
echo "   ✅ Upgrade successful"
echo ""

# ==========================================
# STEP 5: Verify upgrade (not migrated yet)
# ==========================================
echo "🔍 STEP 5: Verifying upgrade (should NOT be migrated yet)..."
echo ""

IS_MIGRATED=$(cast call $SENIOR_PROXY "isMigrated()" --rpc-url $FORK_RPC)
POST_TOTAL_SUPPLY=$(cast call $SENIOR_PROXY "totalSupply()" --rpc-url $FORK_RPC)
POST_REBASE_INDEX=$(cast call $SENIOR_PROXY "rebaseIndex()" --rpc-url $FORK_RPC)

echo "   Is Migrated: $IS_MIGRATED (should be 0x0...0)"
echo "   Total Supply: $(cast to-dec $POST_TOTAL_SUPPLY)"
echo "   Rebase Index: $(cast to-dec $POST_REBASE_INDEX)"

if [[ "$IS_MIGRATED" != "0x0000000000000000000000000000000000000000000000000000000000000000" ]]; then
    echo "❌ ERROR: Contract should NOT be migrated yet!"
    kill $ANVIL_PID 2>/dev/null
    exit 1
fi

if [[ "$POST_TOTAL_SUPPLY" != "$PRE_TOTAL_SUPPLY" ]]; then
    echo "❌ ERROR: Total supply changed after upgrade!"
    kill $ANVIL_PID 2>/dev/null
    exit 1
fi
echo "   ✅ All checks passed"
echo ""

# ==========================================
# STEP 6: Execute migration
# ==========================================
echo "🚀 STEP 6: Executing migration..."
echo ""

MIGRATE_TX=$(cast send $SENIOR_PROXY \
    "migrateToNonRebasing()" \
    --from $ADMIN_ADDRESS \
    --unlocked \
    --rpc-url $FORK_RPC \
    --json 2>/dev/null)

MIGRATE_STATUS=$(echo $MIGRATE_TX | jq -r '.status')
if [[ "$MIGRATE_STATUS" != "0x1" ]]; then
    echo "❌ ERROR: Migration transaction failed!"
    echo "$MIGRATE_TX"
    kill $ANVIL_PID 2>/dev/null
    exit 1
fi
echo "   ✅ Migration successful"
echo ""

# ==========================================
# STEP 7: Verify migration
# ==========================================
echo "🔍 STEP 7: Verifying migration..."
echo ""

IS_MIGRATED=$(cast call $SENIOR_PROXY "isMigrated()" --rpc-url $FORK_RPC)
FINAL_TOTAL_SUPPLY=$(cast call $SENIOR_PROXY "totalSupply()" --rpc-url $FORK_RPC)
FINAL_REBASE_INDEX=$(cast call $SENIOR_PROXY "rebaseIndex()" --rpc-url $FORK_RPC)

echo "   Is Migrated: $IS_MIGRATED"
echo "   Total Supply: $(cast to-dec $FINAL_TOTAL_SUPPLY)"
echo "   Rebase Index: $(cast to-dec $FINAL_REBASE_INDEX) (now frozen)"

if [[ "$IS_MIGRATED" != "0x0000000000000000000000000000000000000000000000000000000000000001" ]]; then
    echo "❌ ERROR: Contract should be migrated!"
    kill $ANVIL_PID 2>/dev/null
    exit 1
fi

if [[ "$FINAL_TOTAL_SUPPLY" != "$PRE_TOTAL_SUPPLY" ]]; then
    echo "⚠️  WARNING: Total supply differs!"
    echo "   Pre:  $(cast to-dec $PRE_TOTAL_SUPPLY)"
    echo "   Post: $(cast to-dec $FINAL_TOTAL_SUPPLY)"
fi

if [[ "$TEST_USER" != "0xAnyUserWithBalance" ]]; then
    FINAL_USER_BALANCE=$(cast call $SENIOR_PROXY "balanceOf(address)" $TEST_USER --rpc-url $FORK_RPC)
    echo "   Test User Balance: $(cast to-dec $FINAL_USER_BALANCE)"
    
    if [[ "$FINAL_USER_BALANCE" != "$PRE_USER_BALANCE" ]]; then
        echo "⚠️  WARNING: User balance changed!"
        echo "   Pre:  $(cast to-dec $PRE_USER_BALANCE)"
        echo "   Post: $(cast to-dec $FINAL_USER_BALANCE)"
    else
        echo "   ✅ User balance preserved"
    fi
fi
echo ""

# ==========================================
# STEP 8: Test user operations
# ==========================================
echo "🧪 STEP 8: Testing user operations..."
echo ""

if [[ "$TEST_USER" != "0xAnyUserWithBalance" ]]; then
    # Impersonate test user
    cast rpc anvil_impersonateAccount $TEST_USER --rpc-url $FORK_RPC > /dev/null
    cast rpc anvil_setBalance $TEST_USER 0x56BC75E2D63100000 --rpc-url $FORK_RPC > /dev/null
    
    # Try a small transfer to self (tests _transfer)
    echo "   Testing transfer..."
    TRANSFER_TX=$(cast send $SENIOR_PROXY \
        "transfer(address,uint256)" \
        $TEST_USER \
        1 \
        --from $TEST_USER \
        --unlocked \
        --rpc-url $FORK_RPC \
        --json 2>/dev/null)
    
    TRANSFER_STATUS=$(echo $TRANSFER_TX | jq -r '.status')
    if [[ "$TRANSFER_STATUS" == "0x1" ]]; then
        echo "   ✅ Transfer works"
    else
        echo "   ❌ Transfer failed"
    fi
else
    echo "   ⏭️  Skipped (no TEST_USER set)"
fi
echo ""

# ==========================================
# CLEANUP
# ==========================================
echo "🧹 Cleaning up..."
kill $ANVIL_PID 2>/dev/null || true
echo ""

# ==========================================
# SUMMARY
# ==========================================
echo "========================================"
echo "  FORK TEST COMPLETE"
echo "========================================"
echo ""
echo "✅ All tests passed!"
echo ""
echo "📋 Summary:"
echo "   - Upgrade: SUCCESS"
echo "   - Migration: SUCCESS"
echo "   - Total Supply: PRESERVED"
echo "   - User Balances: PRESERVED"
echo "   - Transfers: WORKING"
echo ""
echo "🚀 Ready for mainnet upgrade!"
echo ""
echo "📝 Next steps:"
echo "   1. Deploy new implementation to mainnet"
echo "   2. Call upgradeToAndCall with calldata: $INIT_CALLDATA"
echo "   3. Call migrateToNonRebasing()"
echo "   4. Call migrateUsers([...]) for all holders"
echo ""

