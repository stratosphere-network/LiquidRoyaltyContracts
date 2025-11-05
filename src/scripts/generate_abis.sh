#!/bin/bash

# Script to generate ABIs for the three concrete vault contracts
set -e

# Define colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the project root (assuming script is in src/scripts/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

# Create abi directory if it doesn't exist
ABI_DIR="$PROJECT_ROOT/abi"
mkdir -p "$ABI_DIR"

echo -e "${BLUE}Generating ABIs for vault contracts...${NC}"

# Build contracts first
echo "Building contracts..."
forge build

# Extract ABI from compiled artifacts using jq
echo -e "${GREEN}Extracting UnifiedConcreteSeniorVault ABI...${NC}"
jq '.abi' out/UnifiedConcreteSeniorVault.sol/UnifiedConcreteSeniorVault.json > "$ABI_DIR/UnifiedConcreteSeniorVault.json"

echo -e "${GREEN}Extracting ConcreteJuniorVault ABI...${NC}"
jq '.abi' out/ConcreteJuniorVault.sol/ConcreteJuniorVault.json > "$ABI_DIR/ConcreteJuniorVault.json"

echo -e "${GREEN}Extracting ConcreteReserveVault ABI...${NC}"
jq '.abi' out/ConcreteReserveVault.sol/ConcreteReserveVault.json > "$ABI_DIR/ConcreteReserveVault.json"

echo -e "${BLUE}✅ ABIs generated successfully in $ABI_DIR${NC}"
echo ""
echo "Generated files:"
ls -lh "$ABI_DIR"/*.json

