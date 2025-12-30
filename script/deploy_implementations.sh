#!/bin/bash
set -e

# ═══════════════════════════════════════════════════════════════════════════════
# DEPLOY NEW VAULT IMPLEMENTATIONS
# ═══════════════════════════════════════════════════════════════════════════════
# This script deploys new implementations for Senior, Junior, and Reserve vaults
# After deployment, use your multisig to upgrade the proxies
# ═══════════════════════════════════════════════════════════════════════════════

# Load environment
source .env

echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    DEPLOY NEW VAULT IMPLEMENTATIONS"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "RPC URL: $RPC_URL"
echo "Deployer: $(cast wallet address --private-key $PRIVATE_KEY 2>/dev/null || echo 'Set PRIVATE_KEY in .env')"
echo ""

# Check private key is set
if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ ERROR: PRIVATE_KEY not set in .env"
    exit 1
fi

echo "═══════════════════════════════════════════════════════════════════════════════"
echo "Step 1: Building contracts..."
echo "═══════════════════════════════════════════════════════════════════════════════"
forge build

echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "Step 2: Deploying implementations..."
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""

# Deploy using forge script
forge script script/DeployNewImplementations.s.sol:DeployNewImplementations \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    -vvv

echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                         DEPLOYMENT COMPLETE!"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "Next steps for MULTISIG:"
echo ""
echo "1. UPGRADE SENIOR VAULT:"
echo "   To:       0x49298F4314eb127041b814A2616c25687Db6b650"
echo "   Function: upgradeToAndCall(address,bytes)"
echo "   Param 1:  <NEW_SENIOR_IMPL from above>"
echo "   Param 2:  0x11c2ee2b"
echo ""
echo "2. MIGRATE TO NON-REBASING (after upgrade):"
echo "   To:       0x49298F4314eb127041b814A2616c25687Db6b650"
echo "   Function: migrateToNonRebasing()"
echo ""
echo "3. UPGRADE JUNIOR VAULT (optional - for swapTokenToStable):"
echo "   To:       0xBaad9F161197A2c26BdC92F8DDFE651c3383CE4E"
echo "   Function: upgradeToAndCall(address,bytes)"
echo "   Param 1:  <NEW_JUNIOR_IMPL from above>"
echo "   Param 2:  0x"
echo ""
echo "4. UPGRADE RESERVE VAULT (optional - for swapTokenToStable):"
echo "   To:       0x7754272c866892CaD4a414C76f060645bDc27203"
echo "   Function: upgradeToAndCall(address,bytes)"
echo "   Param 1:  <NEW_RESERVE_IMPL from above>"
echo "   Param 2:  0x"
echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"

