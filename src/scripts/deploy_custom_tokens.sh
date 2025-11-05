#!/bin/bash

# ==============================================
# Interactive Token Deployment Script
# ==============================================
# Deploys 2 customizable ERC20 tokens

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Load .env
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo -e "${RED}ERROR: .env file not found${NC}"
    exit 1
fi

source "$SCRIPT_DIR/.env"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  CUSTOM TOKEN DEPLOYMENT${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Interactive prompts
read -p "$(echo -e ${BLUE}Token 1 Name${NC} [SAIL Token]: )" TOKEN1_NAME
TOKEN1_NAME=${TOKEN1_NAME:-"SAIL Token"}

read -p "$(echo -e ${BLUE}Token 1 Symbol${NC} [SAIL]: )" TOKEN1_SYMBOL
TOKEN1_SYMBOL=${TOKEN1_SYMBOL:-"SAIL"}

read -p "$(echo -e ${BLUE}Token 1 Supply${NC} [1000000]: )" TOKEN1_SUPPLY_INPUT
TOKEN1_SUPPLY_INPUT=${TOKEN1_SUPPLY_INPUT:-"1000000"}
TOKEN1_SUPPLY="${TOKEN1_SUPPLY_INPUT}000000000000000000" # Convert to wei

echo ""

read -p "$(echo -e ${BLUE}Token 2 Name${NC} [USD Ethena]: )" TOKEN2_NAME
TOKEN2_NAME=${TOKEN2_NAME:-"USD Ethena"}

read -p "$(echo -e ${BLUE}Token 2 Symbol${NC} [USDe]: )" TOKEN2_SYMBOL
TOKEN2_SYMBOL=${TOKEN2_SYMBOL:-"USDe"}

read -p "$(echo -e ${BLUE}Token 2 Supply${NC} [1000000]: )" TOKEN2_SUPPLY_INPUT
TOKEN2_SUPPLY_INPUT=${TOKEN2_SUPPLY_INPUT:-"1000000"}
TOKEN2_SUPPLY="${TOKEN2_SUPPLY_INPUT}000000000000000000" # Convert to wei

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  DEPLOYMENT SUMMARY${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "${BLUE}Token 1:${NC} $TOKEN1_NAME ($TOKEN1_SYMBOL)"
echo -e "${BLUE}Supply:${NC} $TOKEN1_SUPPLY_INPUT"
echo ""
echo -e "${BLUE}Token 2:${NC} $TOKEN2_NAME ($TOKEN2_SYMBOL)"
echo -e "${BLUE}Supply:${NC} $TOKEN2_SUPPLY_INPUT"
echo ""
echo -e "${BLUE}Network:${NC} ${RPC_URL}"
echo ""

read -p "$(echo -e ${YELLOW}Proceed with deployment? [y/N]:${NC} )" CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${RED}Deployment cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}Deploying tokens...${NC}"
echo ""

# Export variables for forge script
export TOKEN1_NAME
export TOKEN1_SYMBOL
export TOKEN1_SUPPLY
export TOKEN2_NAME
export TOKEN2_SYMBOL
export TOKEN2_SUPPLY

# Run forge script
forge script script/DeployTokens.s.sol:DeployTokens \
    --rpc-url "$RPC_URL" \
    --broadcast \
    -vvv

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  DEPLOYMENT COMPLETE!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Extract addresses from broadcast file
BROADCAST_FILE="$SCRIPT_DIR/broadcast/DeployTokens.s.sol/137/run-latest.json"

if [ -f "$BROADCAST_FILE" ]; then
    TOKEN1_ADDR=$(jq -r '.transactions[0].contractAddress' "$BROADCAST_FILE")
    TOKEN2_ADDR=$(jq -r '.transactions[2].contractAddress' "$BROADCAST_FILE")
    
    echo -e "${CYAN}Token Addresses:${NC}"
    echo -e "  $TOKEN1_SYMBOL: ${YELLOW}$TOKEN1_ADDR${NC}"
    echo -e "  $TOKEN2_SYMBOL: ${YELLOW}$TOKEN2_ADDR${NC}"
    echo ""
    
    # Save to file
    cat > "$SCRIPT_DIR/.deployed-tokens.json" << EOF
{
  "network": "Polygon",
  "rpc_url": "$RPC_URL",
  "deployer": "$(cast wallet address --private-key $PRIVATE_KEY)",
  "tokens": {
    "$TOKEN1_SYMBOL": "$TOKEN1_ADDR",
    "$TOKEN2_SYMBOL": "$TOKEN2_ADDR"
  },
  "supplies": {
    "$TOKEN1_SYMBOL": "$TOKEN1_SUPPLY_INPUT",
    "$TOKEN2_SYMBOL": "$TOKEN2_SUPPLY_INPUT"
  },
  "deployed_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
    
    echo -e "${GREEN}✓ Addresses saved to .deployed-tokens.json${NC}"
fi

echo ""
echo -e "${CYAN}Next steps:${NC}"
echo "  1. Add liquidity to a DEX (Uniswap, QuickSwap)"
echo "  2. Get LP tokens"
echo "  3. Deploy vaults: ./deploy.sh deploy --lp <LP_ADDRESS>"
echo ""

