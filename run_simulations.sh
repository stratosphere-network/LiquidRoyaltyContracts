#!/bin/bash
# Quick-start script for running rebase simulations

set -e

echo "🚀 Rebase Simulation Runner"
echo "=========================="
echo ""

# Check if foundry is installed
if ! command -v forge &> /dev/null; then
    echo "❌ Foundry not found. Installing..."
    curl -L https://foundry.paradigm.xyz | bash
    foundryup
fi

# Create output directory
echo "📁 Creating output directory..."
mkdir -p simulation_output

# Run simulations
echo ""
echo "🧪 Running all simulation scenarios..."
echo "This will take a few minutes..."
echo ""

# Run each scenario individually to avoid memory issues
echo "Running Scenario 1: Bull Market..."
forge test --match-test test_Scenario1_BullMarket -vv

echo "Running Scenario 2: Bear Market..."
forge test --match-test test_Scenario2_BearMarket -vv

echo "Running Scenario 3: Volatile Market..."
forge test --match-test test_Scenario3_VolatileMarket -vv

echo "Running Scenario 4: Stable Market..."
forge test --match-test test_Scenario4_StableMarket -vv

echo "Running Scenario 5: Flash Crash & Recovery..."
forge test --match-test test_Scenario5_FlashCrashRecovery -vv

echo "Running Scenario 6: Slow Bleed (24 Months)..."
forge test --match-test test_Scenario6_SlowBleed_24Months -vv

echo "Running Scenario 7: Parabolic Bull Run..."
forge test --match-test test_Scenario7_ParabolicBullRun -vv

echo ""
echo "========================================="
echo "🌍 Running REAL WORLD Scenarios..."
echo "========================================="

echo "Running Real World: Complete 12-Month Lifecycle..."
forge test --match-test test_Scenario_CompleteLifecycle -vv

echo "Running Real World: Bear Market Stress Test..."
forge test --match-test test_Scenario_BearMarketStress -vv

echo "Running Real World: Stable Yield Market..."
forge test --match-test test_Scenario_StableYield -vv

echo "Running Real World: Flash Crash Event..."
forge test --match-test test_Scenario_FlashCrash -vv

# Check if Node.js/TypeScript is available for analysis
if command -v ts-node &> /dev/null; then
    echo ""
    echo "📊 Running analysis..."
    cd simulation_output
    ts-node analyze.ts
    cd ..
elif command -v node &> /dev/null; then
    echo ""
    echo "📊 Compiling and running analysis..."
    cd simulation_output
    npx tsc analyze.ts && node analyze.js
    cd ..
else
    echo "⚠️  Node.js not found. Skipping analysis."
    echo "   Install Node.js and run: cd simulation_output && ts-node analyze.ts"
fi

echo ""
echo "✅ All simulations complete!"
echo ""
echo "📁 Output files in: ./simulation_output/"
echo "   - JSON files: Complete time-series data"
echo "   - CSV files: Tabular format for analysis"
echo ""
echo "📖 See simulation_output/README.md for details"
echo "💡 Tip: Import CSV files into Excel/Google Sheets for visualization"
echo ""

