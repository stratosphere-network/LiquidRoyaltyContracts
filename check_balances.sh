#!/bin/bash

# Quick script to check all vault balances

set -e
source .env

GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

LP_TOKEN="0x4975723E9541B907b02d5FfDF9c2457C6B176F2A"
SENIOR="0x9e7753a490628c65219c467a792b708a89209168"
JUNIOR="0xf010119dd90fbbafad10bb335db6054103968a1c"
RESERVE="0x28414d346b6eeb6e7fb2bd73f0105ee32f50e2a9"
DEPLOYER=$(cast wallet address --private-key "$PRIVATE_KEY")

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  VAULT HEALTH CHECK${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Senior Vault
echo -e "${BLUE}Senior Vault (snrUSD):${NC}"
SENIOR_LP=$(cast call $LP_TOKEN "balanceOf(address)(uint256)" $SENIOR --rpc-url $RPC_URL | sed 's/ \[.*\]//')
SENIOR_SUPPLY=$(cast call $SENIOR "totalSupply()(uint256)" --rpc-url $RPC_URL | sed 's/ \[.*\]//')
echo "  LP Balance: $(echo "scale=2; $SENIOR_LP / 1000000000000000000" | bc) LP"
echo "  Total Supply: $(echo "scale=2; $SENIOR_SUPPLY / 1000000000000000000" | bc) snrUSD"
echo "  Backing: $(echo "scale=2; ($SENIOR_LP * 100) / $SENIOR_SUPPLY" | bc)%"
echo ""

# Junior Vault
echo -e "${BLUE}Junior Vault:${NC}"
JUNIOR_LP=$(cast call $LP_TOKEN "balanceOf(address)(uint256)" $JUNIOR --rpc-url $RPC_URL | sed 's/ \[.*\]//')
JUNIOR_SUPPLY=$(cast call $JUNIOR "totalSupply()(uint256)" --rpc-url $RPC_URL | sed 's/ \[.*\]//')
echo "  LP Balance: $(echo "scale=2; $JUNIOR_LP / 1000000000000000000" | bc) LP"
echo "  Total Shares: $(echo "scale=2; $JUNIOR_SUPPLY / 1000000000000000000" | bc) shares"
echo ""

# Reserve Vault
echo -e "${BLUE}Reserve Vault:${NC}"
RESERVE_LP=$(cast call $LP_TOKEN "balanceOf(address)(uint256)" $RESERVE --rpc-url $RPC_URL | sed 's/ \[.*\]//')
RESERVE_SUPPLY=$(cast call $RESERVE "totalSupply()(uint256)" --rpc-url $RPC_URL | sed 's/ \[.*\]//')
echo "  LP Balance: $(echo "scale=2; $RESERVE_LP / 1000000000000000000" | bc) LP"
echo "  Total Shares: $(echo "scale=2; $RESERVE_SUPPLY / 1000000000000000000" | bc) shares"
echo ""

# Your balances
echo -e "${BLUE}Your Balances:${NC}"
YOUR_SNRUSD=$(cast call $SENIOR "balanceOf(address)(uint256)" $DEPLOYER --rpc-url $RPC_URL | sed 's/ \[.*\]//')
YOUR_JUNIOR=$(cast call $JUNIOR "balanceOf(address)(uint256)" $DEPLOYER --rpc-url $RPC_URL | sed 's/ \[.*\]//')
YOUR_RESERVE=$(cast call $RESERVE "balanceOf(address)(uint256)" $DEPLOYER --rpc-url $RPC_URL | sed 's/ \[.*\]//')
echo "  snrUSD: $(echo "scale=2; $YOUR_SNRUSD / 1000000000000000000" | bc)"
echo "  Junior: $(echo "scale=2; $YOUR_JUNIOR / 1000000000000000000" | bc)"
echo "  Reserve: $(echo "scale=2; $YOUR_RESERVE / 1000000000000000000" | bc)"
echo ""

# Total
TOTAL_LP=$(echo "$SENIOR_LP + $JUNIOR_LP + $RESERVE_LP" | bc)
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Total LP in Protocol: $(echo "scale=2; $TOTAL_LP / 1000000000000000000" | bc) LP${NC}"
echo -e "${GREEN}USD Value: \$$(echo "scale=2; ($TOTAL_LP / 1000000000000000000) * 6.32" | bc)${NC}"
echo -e "${GREEN}========================================${NC}"

