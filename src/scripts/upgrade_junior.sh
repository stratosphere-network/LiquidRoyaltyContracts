#!/bin/bash

# Script to upgrade Junior Vault implementation
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get the project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Upgrade Junior Vault Implementation     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Check if proxy address is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Proxy address required${NC}"
    echo "Usage: ./upgrade_junior.sh <PROXY_ADDRESS> [NETWORK]"
    echo ""
    echo "Example:"
    echo "  ./upgrade_junior.sh 0x210603159a8f18e820e44c390b7046d507ee7fb5 polygon"
    exit 1
fi

PROXY_ADDRESS=$1
NETWORK=${2:-polygon}

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
echo "  Proxy Address: $PROXY_ADDRESS"
echo "  Network: $NETWORK"
echo "  RPC URL: $RPC_URL"
echo "  Chain ID: $CHAIN_ID"
echo ""

# Confirm before proceeding
read -p "$(echo -e ${YELLOW}Proceed with upgrade? [y/N]: ${NC})" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Upgrade cancelled${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Starting upgrade...${NC}"
echo ""

# Run forge script
forge script script/UpgradeVaults.s.sol:UpgradeVaults \
    --sig "upgradeJunior(address)" $PROXY_ADDRESS \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify \
    -vvv

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Junior Vault Upgrade Complete! ✅       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"

