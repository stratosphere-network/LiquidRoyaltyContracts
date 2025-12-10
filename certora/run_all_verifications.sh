#!/bin/bash

# Certora Formal Verification Script
# Runs all verification jobs for the Senior Tranche Protocol

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Senior Tranche Protocol - Certora Formal Verification    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if certora is installed
if ! command -v certoraRun &> /dev/null; then
    echo -e "${RED}Error: Certora CLI not found. Please install:${NC}"
    echo "  pip install certora-cli"
    exit 1
fi

# Array of verification targets
declare -a TARGETS=(
    "MathLib:Core Mathematical Formulas"
    "FeeLib:Fee Calculations & Time-Based Logic"
    "RebaseLib:Dynamic APY Selection (13%→12%→11%)"
    "SpilloverLib:Three-Zone Spillover System"
)

# Results tracking
declare -a RESULTS=()

# Run each verification
for TARGET in "${TARGETS[@]}"; do
    IFS=':' read -r -a PARTS <<< "$TARGET"
    NAME="${PARTS[0]}"
    DESC="${PARTS[1]}"
    
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Verifying: ${NAME}${NC}"
    echo -e "${YELLOW}Description: ${DESC}${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Run verification
    CONFIG_FILE="certora/conf/${NAME}.conf"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Error: Configuration file not found: ${CONFIG_FILE}${NC}"
        RESULTS+=("${NAME}:FAILED (config not found)")
        continue
    fi
    
    echo -e "${BLUE}Running: certoraRun ${CONFIG_FILE}${NC}"
    echo ""
    
    if certoraRun "$CONFIG_FILE"; then
        echo -e "${GREEN}✓ ${NAME} verification completed successfully${NC}"
        RESULTS+=("${NAME}:SUCCESS")
    else
        echo -e "${RED}✗ ${NAME} verification failed${NC}"
        RESULTS+=("${NAME}:FAILED")
    fi
    
    echo ""
    echo ""
done

# Print summary
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    VERIFICATION SUMMARY                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

SUCCESS_COUNT=0
FAILED_COUNT=0

for RESULT in "${RESULTS[@]}"; do
    IFS=':' read -r -a PARTS <<< "$RESULT"
    NAME="${PARTS[0]}"
    STATUS="${PARTS[1]}"
    
    if [[ "$STATUS" == "SUCCESS" ]]; then
        echo -e "${GREEN}✓ ${NAME}: ${STATUS}${NC}"
        ((SUCCESS_COUNT++))
    else
        echo -e "${RED}✗ ${NAME}: ${STATUS}${NC}"
        ((FAILED_COUNT++))
    fi
done

echo ""
echo -e "${BLUE}Total: ${SUCCESS_COUNT} succeeded, ${FAILED_COUNT} failed${NC}"
echo ""

if [ $FAILED_COUNT -eq 0 ]; then
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}   ALL VERIFICATIONS PASSED! Protocol math is correct! 🎉${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    exit 0
else
    echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}   Some verifications failed. Please review the results.   ${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
    exit 1
fi

