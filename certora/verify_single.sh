#!/bin/bash

# Run a single Certora verification
# Usage: ./verify_single.sh <library_name>
# Example: ./verify_single.sh MathLib

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

if [ $# -eq 0 ]; then
    echo -e "${RED}Error: Please specify a library name${NC}"
    echo ""
    echo "Usage: $0 <library_name>"
    echo ""
    echo "Available libraries:"
    echo "  - MathLib      (Core mathematical formulas)"
    echo "  - FeeLib       (Fee calculations & time-based logic)"
    echo "  - RebaseLib    (Dynamic APY selection)"
    echo "  - SpilloverLib (Three-zone spillover system)"
    exit 1
fi

LIBRARY=$1
CONFIG_FILE="certora/conf/${LIBRARY}.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Configuration file not found: ${CONFIG_FILE}${NC}"
    exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       Running Certora Verification for ${LIBRARY}${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

certoraRun "$CONFIG_FILE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Verification completed successfully${NC}"
else
    echo -e "${RED}✗ Verification failed${NC}"
    exit 1
fi

