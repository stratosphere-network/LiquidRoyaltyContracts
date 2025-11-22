#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}   🚀 LIQUID ROYALTY SIMULATION RUNNER 🚀    ${NC}"
echo -e "${BLUE}=============================================${NC}"

# Create output directories if they don't exist
mkdir -p simulation_output
mkdir -p vault-dashboard/public/simulation_output

echo -e "\n${GREEN}[1/3] Running Market Scenarios...${NC}"
# Run the main scenarios (Bull/Bear) which have detailed user actions
forge test --match-test "test_Scenario1_BullMarket|test_Scenario2_BearMarket" -vv

echo -e "\n${GREEN}[2/3] Running Stress Tests & Real World Scenarios...${NC}"
# Run the whale manipulation and other real world tests
forge test --match-contract RealWorldScenarios -vv

echo -e "\n${GREEN}[3/3] Deploying Data to Dashboard...${NC}"

# Copy ALL generated JSON files to the dashboard public folder
cp simulation_output/*.json vault-dashboard/public/simulation_output/

# Count files copied
COUNT=$(ls simulation_output/*.json | wc -l)
echo -e "✅ Copied ${COUNT} simulation files to dashboard."

echo -e "\n${BLUE}=============================================${NC}"
echo -e "${GREEN}   🎉 SIMULATIONS COMPLETE! 🎉    ${NC}"
echo -e "${BLUE}=============================================${NC}"
echo -e "To view results:"
echo -e "  1. cd vault-dashboard"
echo -e "  2. npm run dev"
echo -e "  3. Open http://localhost:5173"
echo -e "${BLUE}=============================================${NC}"
