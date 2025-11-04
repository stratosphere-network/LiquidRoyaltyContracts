#!/bin/bash

# ==============================================
# Deploy Vaults Only (Use Your Own LP Token)
# ==============================================

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
echo -e "${CYAN}  DEPLOY VAULTS WITH YOUR LP TOKEN${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Prompt for LP token if not set
if [ -z "$LP_TOKEN" ]; then
    read -p "$(echo -e ${BLUE}LP Token Address:${NC} )" LP_TOKEN
    
    if [ -z "$LP_TOKEN" ]; then
        echo -e "${RED}ERROR: LP Token address is required${NC}"
        exit 1
    fi
fi

# Prompt for optional parameters
read -p "$(echo -e ${BLUE}Senior Initial Value in USD${NC} [833000]: )" SENIOR_VAL
SENIOR_VAL=${SENIOR_VAL:-"833000"}
SENIOR_INITIAL_VALUE="${SENIOR_VAL}000000000000000000"

read -p "$(echo -e ${BLUE}Junior Initial Value in USD${NC} [833000]: )" JUNIOR_VAL
JUNIOR_VAL=${JUNIOR_VAL:-"833000"}
JUNIOR_INITIAL_VALUE="${JUNIOR_VAL}000000000000000000"

read -p "$(echo -e ${BLUE}Reserve Initial Value in USD${NC} [625000]: )" RESERVE_VAL
RESERVE_VAL=${RESERVE_VAL:-"625000"}
RESERVE_INITIAL_VALUE="${RESERVE_VAL}000000000000000000"

read -p "$(echo -e ${BLUE}Treasury Address${NC} [deployer]: )" TREASURY
if [ -z "$TREASURY" ]; then
    TREASURY=$(cast wallet address --private-key "$PRIVATE_KEY")
fi

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  DEPLOYMENT SUMMARY${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "${BLUE}LP Token:${NC} $LP_TOKEN"
echo -e "${BLUE}Senior Initial:${NC} \$$SENIOR_VAL"
echo -e "${BLUE}Junior Initial:${NC} \$$JUNIOR_VAL"
echo -e "${BLUE}Reserve Initial:${NC} \$$RESERVE_VAL"
echo -e "${BLUE}Treasury:${NC} $TREASURY"
echo -e "${BLUE}Network:${NC} ${RPC_URL}"
echo ""

read -p "$(echo -e ${YELLOW}Proceed with deployment? [y/N]:${NC} )" CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${RED}Deployment cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}Deploying vaults...${NC}"
echo ""

# Export variables for forge script
export LP_TOKEN
export SENIOR_INITIAL_VALUE
export JUNIOR_INITIAL_VALUE
export RESERVE_INITIAL_VALUE
export TREASURY

# Run forge script with IR optimization (fixes "stack too deep")
forge script script/DeployVaults.s.sol:DeployVaults \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --via-ir \
    -vvv

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  DEPLOYMENT COMPLETE!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Extract addresses from broadcast file
CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL")
BROADCAST_FILE="$SCRIPT_DIR/broadcast/DeployVaults.s.sol/$CHAIN_ID/run-latest.json"

if [ -f "$BROADCAST_FILE" ]; then
    JUNIOR_ADDR=$(jq -r '.transactions[] | select(.contractName == "ERC1967Proxy") | .contractAddress' "$BROADCAST_FILE" | sed -n '1p')
    RESERVE_ADDR=$(jq -r '.transactions[] | select(.contractName == "ERC1967Proxy") | .contractAddress' "$BROADCAST_FILE" | sed -n '2p')
    SENIOR_ADDR=$(jq -r '.transactions[] | select(.contractName == "ERC1967Proxy") | .contractAddress' "$BROADCAST_FILE" | sed -n '3p')
    
    echo -e "${CYAN}Deployed Addresses:${NC}"
    echo -e "  Junior:  ${YELLOW}$JUNIOR_ADDR${NC}"
    echo -e "  Reserve: ${YELLOW}$RESERVE_ADDR${NC}"
    echo -e "  Senior:  ${YELLOW}$SENIOR_ADDR${NC}"
    echo ""
    
    # Save to file
    cat > "$SCRIPT_DIR/.deployed-vaults.json" << EOF
{
  "network": "Polygon",
  "rpc_url": "$RPC_URL",
  "deployer": "$(cast wallet address --private-key $PRIVATE_KEY)",
  "lp_token": "$LP_TOKEN",
  "vaults": {
    "junior": "$JUNIOR_ADDR",
    "reserve": "$RESERVE_ADDR",
    "senior": "$SENIOR_ADDR"
  },
  "initial_values": {
    "senior": "$SENIOR_VAL",
    "junior": "$JUNIOR_VAL",
    "reserve": "$RESERVE_VAL"
  },
  "treasury": "$TREASURY",
  "deployed_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
    
    echo -e "${GREEN}✓ Addresses saved to .deployed-vaults.json${NC}"
fi

echo ""
echo -e "${CYAN}Next steps:${NC}"
echo "  1. Set admin: cast send $SENIOR_ADDR 'setAdmin(address)' YOUR_ADMIN --private-key \$PRIVATE_KEY --rpc-url \$RPC_URL"
echo "  2. Approve LP tokens: cast send $LP_TOKEN 'approve(address,uint256)' $SENIOR_ADDR AMOUNT --private-key \$PRIVATE_KEY --rpc-url \$RPC_URL"
echo "  3. Deposit LP tokens: cast send $SENIOR_ADDR 'deposit(uint256,address)' AMOUNT YOUR_ADDRESS --private-key \$PRIVATE_KEY --rpc-url \$RPC_URL"
echo ""

