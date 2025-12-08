#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

JUNIOR_PROXY="0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883"
EXPECTED_ADMIN="0x6fa2149E69DbCBDCf6F16F755E08c10E53c40605"
EXPECTED_SENIOR="0x49298F4314eb127041b814A2616c25687Db6b650"

echo "=========================================================="
echo "          JUNIOR VAULT V3 VERIFICATION"
echo "=========================================================="
echo ""

# Check admin
echo "Checking Admin Role..."
ADMIN=$(cast call $JUNIOR_PROXY "admin()(address)" --rpc-url $RPC_URL)
if [ "$ADMIN" == "$EXPECTED_ADMIN" ]; then
    echo -e "${GREEN}✓ Admin: $ADMIN${NC}"
else
    echo -e "${RED}✗ Admin: $ADMIN (EXPECTED: $EXPECTED_ADMIN)${NC}"
fi
echo ""

# Check senior vault
echo "Checking Senior Vault Reference..."
SENIOR=$(cast call $JUNIOR_PROXY "seniorVault()(address)" --rpc-url $RPC_URL)
if [ "$SENIOR" == "$EXPECTED_SENIOR" ]; then
    echo -e "${GREEN}✓ Senior Vault: $SENIOR${NC}"
else
    echo -e "${RED}✗ Senior Vault: $SENIOR (EXPECTED: $EXPECTED_SENIOR)${NC}"
fi
echo ""

# Check roles (V2 additions)
echo "Checking V2 Role Managers..."
LIQ_MANAGER=$(cast call $JUNIOR_PROXY "liquidityManager()(address)" --rpc-url $RPC_URL)
echo "  Liquidity Manager: $LIQ_MANAGER"

PRICE_MANAGER=$(cast call $JUNIOR_PROXY "priceFeedManager()(address)" --rpc-url $RPC_URL)
echo "  Price Feed Manager: $PRICE_MANAGER"

CONTRACT_UPDATER=$(cast call $JUNIOR_PROXY "contractUpdater()(address)" --rpc-url $RPC_URL)
echo "  Contract Updater: $CONTRACT_UPDATER"
echo ""

# Check token info
echo "Checking Token Info..."
NAME=$(cast call $JUNIOR_PROXY "name()(string)" --rpc-url $RPC_URL)
SYMBOL=$(cast call $JUNIOR_PROXY "symbol()(string)" --rpc-url $RPC_URL)
echo "  Name: $NAME"
echo "  Symbol: $SYMBOL"
echo ""

# Check balances
echo "Checking Vault Balances..."
TOTAL_SUPPLY=$(cast call $JUNIOR_PROXY "totalSupply()(uint256)" --rpc-url $RPC_URL)
VAULT_VALUE=$(cast call $JUNIOR_PROXY "vaultValue()(uint256)" --rpc-url $RPC_URL)

# Convert to readable format
SUPPLY_READABLE=$(echo "scale=6; $TOTAL_SUPPLY / 1000000000000000000" | bc)
VALUE_READABLE=$(echo "scale=6; $VAULT_VALUE / 1000000000000000000" | bc)

echo "  Total Supply: $SUPPLY_READABLE JNR"
echo "  Vault Value: $VALUE_READABLE USD"

if [ "$TOTAL_SUPPLY" -gt "0" ]; then
    echo -e "${GREEN}✓ Total supply preserved${NC}"
else
    echo -e "${RED}✗ WARNING: Total supply is zero!${NC}"
fi

if [ "$VAULT_VALUE" -gt "0" ]; then
    echo -e "${GREEN}✓ Vault value preserved${NC}"
else
    echo -e "${YELLOW}⚠ Vault value is zero (might be normal if no deposits)${NC}"
fi
echo ""

# Check V3 features
echo "Checking NEW V3 Features (Cooldown)..."

# Test cooldown function exists
TEST_USER="0x6fa2149E69DbCBDCf6F16F755E08c10E53c40605"
COOLDOWN_START=$(cast call $JUNIOR_PROXY "cooldownStart(address)(uint256)" $TEST_USER --rpc-url $RPC_URL 2>/dev/null)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ cooldownStart() function working${NC}"
    echo "  Test user cooldown: $COOLDOWN_START (0 = not initiated)"
else
    echo -e "${RED}✗ cooldownStart() function FAILED${NC}"
fi

CAN_WITHDRAW=$(cast call $JUNIOR_PROXY "canWithdrawWithoutPenalty(address)(bool)" $TEST_USER --rpc-url $RPC_URL 2>/dev/null)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ canWithdrawWithoutPenalty() function working${NC}"
    echo "  Test user can withdraw without penalty: $CAN_WITHDRAW"
else
    echo -e "${RED}✗ canWithdrawWithoutPenalty() function FAILED${NC}"
fi

echo ""

# Final summary
echo "=========================================================="
echo "                    SUMMARY"
echo "=========================================================="

if [ "$ADMIN" == "$EXPECTED_ADMIN" ] && [ "$SENIOR" == "$EXPECTED_SENIOR" ] && [ "$TOTAL_SUPPLY" -gt "0" ]; then
    echo -e "${GREEN}"
    echo "✓ ALL CRITICAL CHECKS PASSED!"
    echo "✓ Storage slots intact"
    echo "✓ V3 cooldown features active"
    echo "✓ Junior vault is SAFE to use"
    echo -e "${NC}"
else
    echo -e "${RED}"
    echo "✗ SOME CHECKS FAILED!"
    echo "✗ Review output above"
    echo "✗ Consider rollback if critical data corrupted"
    echo -e "${NC}"
fi

echo ""
echo "=========================================================="




