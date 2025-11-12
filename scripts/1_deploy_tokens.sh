#!/bin/bash

# ====================================
# 🪙 Token Deployment Script
# ====================================
# This script deploys 2 ERC20 tokens with custom parameters
# Configure your tokens in the CONFIGURATION section below

set -e  # Exit on error

echo "======================================"
echo "🪙 TOKEN DEPLOYMENT SCRIPT"
echo "======================================"
echo ""

# ====================================
# INTERACTIVE CONFIGURATION
# ====================================

echo "Let's configure your tokens! 🪙"
echo ""

# Token 1 Configuration
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TOKEN 1 CONFIGURATION:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -p "Token 1 Name (e.g., USDE): " TOKEN1_NAME
read -p "Token 1 Symbol (e.g., USDE): " TOKEN1_SYMBOL
read -p "Token 1 Decimals (6 or 18): " TOKEN1_DECIMALS
read -p "Token 1 Mint Amount (e.g., 10000000): " TOKEN1_MINT_AMOUNT
echo ""

# Token 2 Configuration
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TOKEN 2 CONFIGURATION:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -p "Token 2 Name (e.g., SAIL): " TOKEN2_NAME
read -p "Token 2 Symbol (e.g., SAIL): " TOKEN2_SYMBOL
read -p "Token 2 Decimals (6 or 18): " TOKEN2_DECIMALS
read -p "Token 2 Mint Amount (e.g., 1000000): " TOKEN2_MINT_AMOUNT
echo ""

# Confirm configuration
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 CONFIGURATION SUMMARY:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Token 1: $TOKEN1_NAME ($TOKEN1_SYMBOL)"
echo "   Decimals: $TOKEN1_DECIMALS"
echo "   Mint Amount: $TOKEN1_MINT_AMOUNT $TOKEN1_SYMBOL"
echo ""
echo "Token 2: $TOKEN2_NAME ($TOKEN2_SYMBOL)"
echo "   Decimals: $TOKEN2_DECIMALS"
echo "   Mint Amount: $TOKEN2_MINT_AMOUNT $TOKEN2_SYMBOL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
read -p "Continue with deployment? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi
echo ""

# ====================================
# LOAD ENVIRONMENT
# ====================================

if [ ! -f .env ]; then
    echo "❌ .env file not found!"
    echo ""
    echo "Create a .env file with:"
    echo "PRIVATE_KEY=0xyour_private_key_here"
    echo "RPC_URL=https://artio.rpc.berachain.com"
    exit 1
fi

# Source .env
set -a
source .env
set +a

if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ PRIVATE_KEY not set in .env!"
    exit 1
fi

if [ -z "$RPC_URL" ]; then
    echo "⚠️  RPC_URL not set in .env, using Berachain Artio testnet"
    export RPC_URL="https://artio.rpc.berachain.com"
fi

echo "✅ Loaded configuration from .env"
echo "📡 RPC URL: $RPC_URL"
echo ""

# Get deployer address
DEPLOYER=$(cast wallet address $PRIVATE_KEY 2>/dev/null || echo "Unable to derive address")
echo "👤 Deployer: $DEPLOYER"
echo ""

# ====================================
# CHECK BALANCE
# ====================================

echo "💰 Checking balance..."
BALANCE=$(cast balance $DEPLOYER --rpc-url $RPC_URL 2>/dev/null || echo "0")
BALANCE_ETH=$(echo "scale=4; $BALANCE / 1000000000000000000" | bc 2>/dev/null || echo "0")
echo "   Balance: $BALANCE_ETH BERA"

if [ "$BALANCE" = "0" ]; then
    echo ""
    echo "⚠️  WARNING: Your balance is 0!"
    echo "   Get testnet BERA from: https://artio.faucet.berachain.com"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
echo ""

# ====================================
# BUILD CONTRACTS
# ====================================

echo "🔨 Building contracts..."
forge build
if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi
echo "✅ Build successful!"
echo ""

# ====================================
# DEPLOY TOKEN 1
# ====================================

echo "🚀 Deploying Token 1: $TOKEN1_NAME..."

# Calculate raw amount (amount * 10^decimals)
if [ "$TOKEN1_DECIMALS" -eq 6 ]; then
    TOKEN1_RAW_AMOUNT="${TOKEN1_MINT_AMOUNT}000000"
elif [ "$TOKEN1_DECIMALS" -eq 18 ]; then
    TOKEN1_RAW_AMOUNT="${TOKEN1_MINT_AMOUNT}000000000000000000"
else
    TOKEN1_RAW_AMOUNT=$(echo "$TOKEN1_MINT_AMOUNT * 10^$TOKEN1_DECIMALS" | bc)
fi

# Deploy with broadcast
echo "📡 Broadcasting transaction to $RPC_URL..."
DEPLOY_OUTPUT=$(forge create src/mocks/MockERC20.sol:MockERC20 \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --constructor-args "$TOKEN1_NAME" "$TOKEN1_SYMBOL" $TOKEN1_DECIMALS \
    --broadcast \
    2>&1)

echo "$DEPLOY_OUTPUT"

# Extract address from output (works with or without --json)
TOKEN1_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -i "Deployed to:" | awk '{print $3}')

if [ -z "$TOKEN1_ADDRESS" ]; then
    echo "❌ Token 1 deployment failed!"
    echo "Error output:"
    echo "$DEPLOY_OUTPUT"
    exit 1
fi

echo "✅ Token 1 deployed at: $TOKEN1_ADDRESS"
echo ""

# ====================================
# MINT TOKEN 1
# ====================================

echo "🪙 Minting $TOKEN1_MINT_AMOUNT $TOKEN1_SYMBOL to $DEPLOYER..."

cast send $TOKEN1_ADDRESS \
    "mint(address,uint256)" \
    $DEPLOYER \
    $TOKEN1_RAW_AMOUNT \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY

echo "✅ Minted $TOKEN1_MINT_AMOUNT $TOKEN1_SYMBOL"
echo ""

# ====================================
# DEPLOY TOKEN 2
# ====================================

echo "🚀 Deploying Token 2: $TOKEN2_NAME..."

# Calculate raw amount (amount * 10^decimals)
if [ "$TOKEN2_DECIMALS" -eq 6 ]; then
    TOKEN2_RAW_AMOUNT="${TOKEN2_MINT_AMOUNT}000000"
elif [ "$TOKEN2_DECIMALS" -eq 18 ]; then
    TOKEN2_RAW_AMOUNT="${TOKEN2_MINT_AMOUNT}000000000000000000"
else
    TOKEN2_RAW_AMOUNT=$(echo "$TOKEN2_MINT_AMOUNT * 10^$TOKEN2_DECIMALS" | bc)
fi

# Deploy with broadcast
echo "📡 Broadcasting transaction to $RPC_URL..."
DEPLOY_OUTPUT=$(forge create src/mocks/MockERC20.sol:MockERC20 \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --constructor-args "$TOKEN2_NAME" "$TOKEN2_SYMBOL" $TOKEN2_DECIMALS \
    --broadcast \
    2>&1)

echo "$DEPLOY_OUTPUT"

# Extract address from output (works with or without --json)
TOKEN2_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -i "Deployed to:" | awk '{print $3}')

if [ -z "$TOKEN2_ADDRESS" ]; then
    echo "❌ Token 2 deployment failed!"
    echo "Error output:"
    echo "$DEPLOY_OUTPUT"
    exit 1
fi

echo "✅ Token 2 deployed at: $TOKEN2_ADDRESS"
echo ""

# ====================================
# MINT TOKEN 2
# ====================================

echo "🪙 Minting $TOKEN2_MINT_AMOUNT $TOKEN2_SYMBOL to $DEPLOYER..."

cast send $TOKEN2_ADDRESS \
    "mint(address,uint256)" \
    $DEPLOYER \
    $TOKEN2_RAW_AMOUNT \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY

echo "✅ Minted $TOKEN2_MINT_AMOUNT $TOKEN2_SYMBOL"
echo ""

# ====================================
# VERIFY BALANCES
# ====================================

echo "🔍 Verifying balances..."

TOKEN1_BALANCE=$(cast call $TOKEN1_ADDRESS "balanceOf(address)(uint256)" $DEPLOYER --rpc-url $RPC_URL)
TOKEN2_BALANCE=$(cast call $TOKEN2_ADDRESS "balanceOf(address)(uint256)" $DEPLOYER --rpc-url $RPC_URL)

echo "   $TOKEN1_SYMBOL Balance: $TOKEN1_BALANCE (raw)"
echo "   $TOKEN2_SYMBOL Balance: $TOKEN2_BALANCE (raw)"
echo ""

# ====================================
# SAVE ADDRESSES
# ====================================

echo "💾 Saving deployment addresses..."

# Get the project root directory (parent of scripts/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cat > "$PROJECT_ROOT/deployed_tokens.txt" << EOF
# Token Deployment Addresses
# Deployed on: $(date)
# Network: $RPC_URL
# Deployer: $DEPLOYER

TOKEN1_NAME=$TOKEN1_NAME
TOKEN1_SYMBOL=$TOKEN1_SYMBOL
TOKEN1_ADDRESS=$TOKEN1_ADDRESS
TOKEN1_DECIMALS=$TOKEN1_DECIMALS

TOKEN2_NAME=$TOKEN2_NAME
TOKEN2_SYMBOL=$TOKEN2_SYMBOL
TOKEN2_ADDRESS=$TOKEN2_ADDRESS
TOKEN2_DECIMALS=$TOKEN2_DECIMALS

# For easy sourcing in other scripts:
export TOKEN1_ADDRESS=$TOKEN1_ADDRESS
export TOKEN2_ADDRESS=$TOKEN2_ADDRESS
EOF

echo "✅ Addresses saved to: $PROJECT_ROOT/deployed_tokens.txt"
echo ""

# Also print the absolute path for clarity
echo "📁 File location: $PROJECT_ROOT/deployed_tokens.txt"
echo ""

# ====================================
# SUMMARY
# ====================================

echo "======================================"
echo "✅ DEPLOYMENT COMPLETE!"
echo "======================================"
echo ""
echo "📋 DEPLOYED ADDRESSES:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$TOKEN1_NAME ($TOKEN1_SYMBOL): $TOKEN1_ADDRESS"
echo "$TOKEN2_NAME ($TOKEN2_SYMBOL): $TOKEN2_ADDRESS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💰 YOUR BALANCES:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$TOKEN1_MINT_AMOUNT $TOKEN1_SYMBOL"
echo "$TOKEN2_MINT_AMOUNT $TOKEN2_SYMBOL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 NEXT STEPS:"
echo "1. Create a pool on Kodiak/Uniswap with these tokens"
echo "2. Add liquidity (e.g., 100K $TOKEN1_SYMBOL + 10K $TOKEN2_SYMBOL)"
echo "3. Run the vault deployment script next!"
echo ""
echo "💡 TIP: Source the addresses file to use in other scripts:"
echo "   source deployed_tokens.txt"
echo ""
echo "📄 File Contents Preview:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat "$PROJECT_ROOT/deployed_tokens.txt" | grep -E "TOKEN[12]_(NAME|SYMBOL|ADDRESS|DECIMALS)="
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

