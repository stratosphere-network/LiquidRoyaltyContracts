#!/bin/bash

# Mint SAIL and USDE tokens

set -e
source .env

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

USDE="0x13f324F02e572f008219A3fa8858e8301b1D1A7A"
SAIL="0xF0Af2b8ED6F59B9D3C1b1C6c63742F5dbc336199"
DEPLOYER=$(cast wallet address --private-key "$PRIVATE_KEY")

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  MINT TOKENS${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get current balances
USDE_BAL=$(cast call $USDE "balanceOf(address)(uint256)" $DEPLOYER --rpc-url $RPC_URL | sed 's/ \[.*\]//')
USDE_BAL_DEC=$(echo "scale=2; $USDE_BAL / 1000000000000000000" | bc)

SAIL_BAL=$(cast call $SAIL "balanceOf(address)(uint256)" $DEPLOYER --rpc-url $RPC_URL | sed 's/ \[.*\]//')
SAIL_BAL_DEC=$(echo "scale=2; $SAIL_BAL / 1000000000000000000" | bc)

echo -e "${YELLOW}Current Balances:${NC}"
echo "  USDE: $USDE_BAL_DEC USDE"
echo "  SAIL: $SAIL_BAL_DEC SAIL"
echo ""

# Ask for amount to mint
read -p "Token to mint (USDE/SAIL): " TOKEN_NAME
TOKEN_NAME=$(echo "$TOKEN_NAME" | tr '[:lower:]' '[:upper:]')

if [ "$TOKEN_NAME" = "USDE" ]; then
    TOKEN_ADDR=$USDE
elif [ "$TOKEN_NAME" = "SAIL" ]; then
    TOKEN_ADDR=$SAIL
else
    echo -e "${RED}Invalid token. Use USDE or SAIL${NC}"
    exit 1
fi

read -p "Amount to mint: " AMOUNT
read -p "Mint to address (press Enter for yourself): " TO_ADDR
TO_ADDR=${TO_ADDR:-$DEPLOYER}

# Convert to wei
AMOUNT_WEI=$(echo "$AMOUNT * 1000000000000000000" | bc | cut -d'.' -f1)

echo ""
echo -e "${YELLOW}Minting...${NC}"
echo "  Token: $TOKEN_NAME"
echo "  Amount: $AMOUNT"
echo "  To: $TO_ADDR"
echo ""

cast send $TOKEN_ADDR \
    "mint(address,uint256)" \
    $TO_ADDR \
    $AMOUNT_WEI \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL

echo ""
echo -e "${GREEN}✓ Minted $AMOUNT $TOKEN_NAME!${NC}"

# Show new balance
NEW_BAL=$(cast call $TOKEN_ADDR "balanceOf(address)(uint256)" $TO_ADDR --rpc-url $RPC_URL | sed 's/ \[.*\]//')
NEW_BAL_DEC=$(echo "scale=2; $NEW_BAL / 1000000000000000000" | bc)
echo -e "${GREEN}New Balance: $NEW_BAL_DEC $TOKEN_NAME${NC}"

