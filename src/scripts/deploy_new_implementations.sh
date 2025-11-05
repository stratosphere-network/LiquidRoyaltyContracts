#!/bin/bash

# Script to deploy new implementations WITHOUT upgrading proxies
# Useful for testing if new implementations compile and deploy successfully
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Deploy New Implementations (No Upgrade) ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

NETWORK=${1:-polygon}

# Set RPC URL based on network
if [ "$NETWORK" = "polygon" ]; then
    RPC_URL="https://polygon-rpc.com"
    CHAIN_ID=137
elif [ "$NETWORK" = "mumbai" ]; then
    RPC_URL="https://rpc-mumbai.maticvigil.com"
    CHAIN_ID=80001
else
    RPC_URL=$NETWORK
    CHAIN_ID=$(cast chain-id --rpc-url $RPC_URL)
fi

echo -e "${YELLOW}Configuration:${NC}"
echo "  Network: $NETWORK"
echo "  RPC URL: $RPC_URL"
echo "  Chain ID: $CHAIN_ID"
echo ""
echo -e "${YELLOW}Note: This will deploy new implementations but NOT upgrade existing proxies${NC}"
echo ""

# Confirm before proceeding
read -p "$(echo -e ${YELLOW}Proceed with deployment? [y/N]: ${NC})" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Deployment cancelled${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Deploying new implementations...${NC}"
echo ""

# Run forge script
forge script script/UpgradeVaults.s.sol:UpgradeVaults \
    --sig "deployNewImplementations()" \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify \
    -vvv

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   New Implementations Deployed! ✅        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}To upgrade proxies to these new implementations, use:${NC}"
echo "  ./upgrade_senior.sh <PROXY_ADDRESS>"
echo "  ./upgrade_junior.sh <PROXY_ADDRESS>"
echo "  ./upgrade_reserve.sh <PROXY_ADDRESS>"

