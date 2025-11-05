#!/bin/bash

# ============================================
# SEED VAULTS WITH LP TOKENS
# ============================================
# This script deposits LP tokens into the vaults
# to match their initial valuations.

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Load environment
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

source .env

if [ -z "$PRIVATE_KEY" ] || [ -z "$RPC_URL" ]; then
    echo -e "${RED}Error: PRIVATE_KEY or RPC_URL not set in .env${NC}"
    exit 1
fi

# Derive deployer address from private key
DEPLOYER=$(cast wallet address --private-key "$PRIVATE_KEY")

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  SEED VAULTS WITH LP TOKENS${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# ============================================
# Get Contract Addresses
# ============================================
echo -e "${BLUE}Enter deployed contract addresses:${NC}"
echo ""

read -p "LP Token Address: " LP_TOKEN
read -p "Senior Vault Address: " SENIOR_VAULT
read -p "Junior Vault Address: " JUNIOR_VAULT
read -p "Reserve Vault Address: " RESERVE_VAULT
echo ""

# ============================================
# Calculate LP Amounts
# ============================================
echo -e "${BLUE}Enter initial values (in USD):${NC}"
read -p "Senior Initial Value [400000]: " SENIOR_USD
SENIOR_USD=${SENIOR_USD:-400000}

read -p "Junior Initial Value [400000]: " JUNIOR_USD
JUNIOR_USD=${JUNIOR_USD:-400000}

read -p "Reserve Initial Value [200000]: " RESERVE_USD
RESERVE_USD=${RESERVE_USD:-200000}

read -p "LP Token Price in USD [6.32]: " LP_PRICE
LP_PRICE=${LP_PRICE:-6.32}
echo ""

# Calculate LP amounts needed (using bc for floating point)
SENIOR_LP_FLOAT=$(echo "scale=6; $SENIOR_USD / $LP_PRICE" | bc)
JUNIOR_LP_FLOAT=$(echo "scale=6; $JUNIOR_USD / $LP_PRICE" | bc)
RESERVE_LP_FLOAT=$(echo "scale=6; $RESERVE_USD / $LP_PRICE" | bc)

# Convert to wei (18 decimals)
SENIOR_LP_WEI=$(echo "$SENIOR_LP_FLOAT * 1000000000000000000" | bc | cut -d'.' -f1)
JUNIOR_LP_WEI=$(echo "$JUNIOR_LP_FLOAT * 1000000000000000000" | bc | cut -d'.' -f1)
RESERVE_LP_WEI=$(echo "$RESERVE_LP_FLOAT * 1000000000000000000" | bc | cut -d'.' -f1)

# ============================================
# Summary
# ============================================
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  SEEDING SUMMARY${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "${BLUE}Deployer:${NC} $DEPLOYER"
echo -e "${BLUE}LP Token:${NC} $LP_TOKEN"
echo ""
echo -e "${BLUE}Senior Vault:${NC} $SENIOR_VAULT"
echo -e "  Amount: $SENIOR_LP_FLOAT LP tokens ($$SENIOR_USD)"
echo ""
echo -e "${BLUE}Junior Vault:${NC} $JUNIOR_VAULT"
echo -e "  Amount: $JUNIOR_LP_FLOAT LP tokens ($$JUNIOR_USD)"
echo ""
echo -e "${BLUE}Reserve Vault:${NC} $RESERVE_VAULT"
echo -e "  Amount: $RESERVE_LP_FLOAT LP tokens ($$RESERVE_USD)"
echo ""
echo -e "${BLUE}Total LP Needed:${NC} $(echo "$SENIOR_LP_FLOAT + $JUNIOR_LP_FLOAT + $RESERVE_LP_FLOAT" | bc) LP tokens"
echo ""

# Check LP balance
echo -e "${YELLOW}Checking your LP token balance...${NC}"
LP_BALANCE=$(cast call $LP_TOKEN "balanceOf(address)(uint256)" $DEPLOYER --rpc-url $RPC_URL)
LP_BALANCE_DECIMAL=$(echo "scale=2; $LP_BALANCE / 1000000000000000000" | bc)
echo -e "${BLUE}Your LP Balance:${NC} $LP_BALANCE_DECIMAL LP tokens"
echo ""

TOTAL_NEEDED=$(echo "$SENIOR_LP_FLOAT + $JUNIOR_LP_FLOAT + $RESERVE_LP_FLOAT" | bc)
if (( $(echo "$LP_BALANCE_DECIMAL < $TOTAL_NEEDED" | bc -l) )); then
    echo -e "${RED}⚠️  WARNING: You don't have enough LP tokens!${NC}"
    echo -e "${RED}   Needed: $TOTAL_NEEDED LP${NC}"
    echo -e "${RED}   You have: $LP_BALANCE_DECIMAL LP${NC}"
    echo ""
fi

read -p "Proceed with seeding? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${RED}Seeding cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}Starting vault seeding...${NC}"
echo ""

# ============================================
# STEP 1: Approve LP Tokens
# ============================================
echo -e "${YELLOW}STEP 1: Approving LP tokens...${NC}"

echo -e "  Approving Senior Vault..."
cast send $LP_TOKEN "approve(address,uint256)" $SENIOR_VAULT $SENIOR_LP_WEI \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 100000 > /dev/null 2>&1
echo -e "  ${GREEN}✓${NC} Senior approved"

echo -e "  Approving Junior Vault..."
cast send $LP_TOKEN "approve(address,uint256)" $JUNIOR_VAULT $JUNIOR_LP_WEI \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 100000 > /dev/null 2>&1
echo -e "  ${GREEN}✓${NC} Junior approved"

echo -e "  Approving Reserve Vault..."
cast send $LP_TOKEN "approve(address,uint256)" $RESERVE_VAULT $RESERVE_LP_WEI \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 100000 > /dev/null 2>&1
echo -e "  ${GREEN}✓${NC} Reserve approved"
echo ""

# ============================================
# STEP 2: Deposit LP Tokens
# ============================================
echo -e "${YELLOW}STEP 2: Depositing LP tokens...${NC}"

echo -e "  Depositing to Senior Vault..."
SENIOR_TX=$(cast send $SENIOR_VAULT "deposit(uint256,address)" $SENIOR_LP_WEI $DEPLOYER \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 500000 2>&1)
if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} Senior seeded with $SENIOR_LP_FLOAT LP"
else
    echo -e "  ${RED}✗${NC} Senior deposit failed"
    echo "$SENIOR_TX"
fi

echo -e "  Depositing to Junior Vault..."
JUNIOR_TX=$(cast send $JUNIOR_VAULT "deposit(uint256,address)" $JUNIOR_LP_WEI $DEPLOYER \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 500000 2>&1)
if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} Junior seeded with $JUNIOR_LP_FLOAT LP"
else
    echo -e "  ${RED}✗${NC} Junior deposit failed"
    echo "$JUNIOR_TX"
fi

echo -e "  Depositing to Reserve Vault..."
RESERVE_TX=$(cast send $RESERVE_VAULT "deposit(uint256,address)" $RESERVE_LP_WEI $DEPLOYER \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 500000 2>&1)
if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} Reserve seeded with $RESERVE_LP_FLOAT LP"
else
    echo -e "  ${RED}✗${NC} Reserve deposit failed"
    echo "$RESERVE_TX"
fi

echo ""

# ============================================
# STEP 3: Verify Balances
# ============================================
echo -e "${YELLOW}STEP 3: Verifying balances...${NC}"

# Senior (snrUSD balance)
SNRUSD_BALANCE=$(cast call $SENIOR_VAULT "balanceOf(address)(uint256)" $DEPLOYER --rpc-url $RPC_URL)
SNRUSD_BALANCE_DECIMAL=$(echo "scale=2; $SNRUSD_BALANCE / 1000000000000000000" | bc)
echo -e "  ${BLUE}Your snrUSD:${NC} $SNRUSD_BALANCE_DECIMAL snrUSD"

# Junior (shares)
JUNIOR_SHARES=$(cast call $JUNIOR_VAULT "balanceOf(address)(uint256)" $DEPLOYER --rpc-url $RPC_URL)
JUNIOR_SHARES_DECIMAL=$(echo "scale=2; $JUNIOR_SHARES / 1000000000000000000" | bc)
echo -e "  ${BLUE}Your Junior Shares:${NC} $JUNIOR_SHARES_DECIMAL shares"

# Reserve (shares)
RESERVE_SHARES=$(cast call $RESERVE_VAULT "balanceOf(address)(uint256)" $DEPLOYER --rpc-url $RPC_URL)
RESERVE_SHARES_DECIMAL=$(echo "scale=2; $RESERVE_SHARES / 1000000000000000000" | bc)
echo -e "  ${BLUE}Your Reserve Shares:${NC} $RESERVE_SHARES_DECIMAL shares"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  SEEDING COMPLETE! 🎉${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "1. Admin can now call updateVaultValue() monthly"
echo -e "2. Admin can call rebase() after 30 days"
echo -e "3. Users can deposit into Senior vault for snrUSD"
echo ""

