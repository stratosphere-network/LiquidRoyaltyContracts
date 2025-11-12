#!/bin/bash

echo "======================================"
echo "🚀 DEPLOYING TEST SETUP"
echo "======================================"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ .env file not found!"
    echo ""
    echo "Create a .env file with:"
    echo "PRIVATE_KEY=0xyour_private_key_here"
    exit 1
fi

# Source .env
set -a
source .env
set +a

# Check if PRIVATE_KEY is set
if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ PRIVATE_KEY not set in .env!"
    exit 1
fi

echo "✅ Found PRIVATE_KEY in .env"
echo ""

# Set RPC URL (default to local Anvil)
if [ -z "$RPC_URL" ]; then
    export RPC_URL="http://localhost:8545"
    echo "📡 Using default RPC: $RPC_URL"
else
    echo "📡 Using RPC: $RPC_URL"
fi
echo ""

echo "🔨 Building contracts..."
forge build
if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi
echo "✅ Build successful!"
echo ""

echo "🚀 Deploying..."
echo ""

forge script script/DeployTestSetup.s.sol \
  --rpc-url $RPC_URL \
  --broadcast \
  -vvv

if [ $? -eq 0 ]; then
    echo ""
    echo "======================================"
    echo "✅ DEPLOYMENT SUCCESSFUL!"
    echo "======================================"
    echo ""
    echo "📋 Next steps:"
    echo "1. Copy the contract addresses from above"
    echo "2. Create USDE-SAIL pool on your DEX"
    echo "3. Add liquidity (e.g., 100K USDE + 10K SAIL)"
    echo "4. Share the pool address to configure the vaults!"
    echo ""
else
    echo ""
    echo "❌ Deployment failed!"
    exit 1
fi

