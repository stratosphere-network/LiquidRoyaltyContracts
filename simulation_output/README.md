# 📊 Rebase Simulation Framework

A comprehensive Solidity-based simulation that models the Senior Tranche Protocol's behavior under various market conditions.

## 🎯 Overview

This simulation framework:
- ✅ Models a Constant Product AMM pool (USDE/SAIL)
- ✅ Simulates price changes and their effects on LP token prices
- ✅ Executes monthly rebases following the math spec exactly
- ✅ Tracks all vault states (Senior, Junior, Reserve)
- ✅ Handles three-zone spillover system (Spillover/Healthy/Backstop)
- ✅ Outputs comprehensive time-series JSON data
- ✅ Generates visual charts and statistics

## 🏗️ Initial Setup

### Pool
- **USDE Reserve**: 1,000,000 tokens
- **SAIL Reserve**: 100,000 tokens
- **Initial SAIL Price**: $10 (1M USDE / 100K SAIL)
- **LP Token Price**: ~$6.32

### Vaults
- **Senior**: $1.5M in LP tokens (~237,342 LP tokens)
- **Junior**: $1.5M in LP tokens (~237,342 LP tokens)
- **Reserve**: $750K in SAIL tokens (75,000 SAIL @ $10)

## 🚀 Running Simulations

### Prerequisites

```bash
# Install Foundry (if not already installed)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Node.js/TypeScript for analysis (optional)
# Install from https://nodejs.org if not already installed
```

### Run All Scenarios

```bash
# From project root
forge test --match-test test_RunAllScenarios -vv

# Or run individual scenarios
forge test --match-test test_Scenario1_BullMarket -vv
forge test --match-test test_Scenario2_BearMarket -vv
forge test --match-test test_Scenario3_VolatileMarket -vv
# ... etc
```

### Analyze Results

```bash
cd simulation_output

# Using ts-node (recommended)
ts-node analyze.ts

# Or compile and run
npx tsc analyze.ts && node analyze.js
```

## 📈 Scenarios

### Scenario 1: Bull Market
- **Duration**: 12 months
- **SAIL Price**: $10 → $30
- **Pattern**: Steady growth with acceleration
- **Expected**: Frequent spillovers, high Senior backing ratio

### Scenario 2: Bear Market
- **Duration**: 12 months
- **SAIL Price**: $10 → $3
- **Pattern**: Consistent decline
- **Expected**: Backstops triggered, declining vault values

### Scenario 3: Volatile Market
- **Duration**: 12 months
- **SAIL Price**: Swings between $7-$15
- **Pattern**: Wild reversals
- **Expected**: Mixed zones, frequent spillover/backstop switches

### Scenario 4: Stable Market
- **Duration**: 12 months
- **SAIL Price**: $9-$11 range
- **Pattern**: Low volatility
- **Expected**: Mostly healthy zone, minimal spillovers

### Scenario 5: Flash Crash & Recovery
- **Duration**: 12 months
- **SAIL Price**: Crashes to $4, recovers to $12
- **Pattern**: Sudden crash followed by gradual recovery
- **Expected**: Severe backstops, then spillovers during recovery

### Scenario 6: Slow Bleed (24 Months)
- **Duration**: 24 months
- **SAIL Price**: $10 → $2
- **Pattern**: Gradual, persistent decline
- **Expected**: Sustained backstops, reserve depletion risk

### Scenario 7: Parabolic Bull Run
- **Duration**: 12 months
- **SAIL Price**: $10 → $100
- **Pattern**: Exponential growth
- **Expected**: Maximum spillovers, Senior hits target frequently

## 📊 Output Files

### JSON Files (`scenario*.json`)
Complete time-series data including:
- Pool state (reserves, prices)
- Vault states (values, shares, backing ratios)
- Operating zones
- Spillover/backstop amounts
- Rebase details

### CSV Files (`scenario*.csv`)
Tabular format for easy analysis in Excel/Google Sheets/Pandas

**Columns include:**
- Epoch, timestamp, zone
- Pool state (SAIL/USDE reserves, prices)
- Senior vault (value, supply, backing ratio, index, APY)
- Junior vault (value, LP amount)
- Reserve vault (value, SAIL amount)
- Transfers (spillovers and backstops)

**Use for:**
- Creating custom charts in Excel/Google Sheets
- Statistical analysis
- Importing into Grafana/Tableau
- Further processing with pandas/R

## 📊 Analysis Output

The TypeScript analyzer (`analyze.ts`) generates:

1. **Console Statistics**
   - Price analysis (SAIL, LP tokens)
   - Backing ratio statistics (min, max, avg, std dev)
   - Vault value changes
   - Zone distribution
   - APY selection frequency
   - Cumulative spillovers/backstops
   - Rebase index growth & annualized returns

2. **CSV Export**
   - All time-series data in tabular format
   - Ready for Excel/Google Sheets visualization
   - Easy to import into other tools

## 🔍 Understanding the Data

### Key Metrics

**SAIL Price**
- Shows volatility of the non-stablecoin asset
- Directly impacts LP token prices
- Drives backing ratio changes

**Senior Backing Ratio**
- **> 110%**: Profit spillover triggered
- **100-110%**: Healthy buffer zone (most common)
- **< 100%**: Backstop triggered

**Operating Zones**
- **GREEN (Spillover)**: System profitable, sharing excess
- **YELLOW (Healthy)**: Optimal operation, no transfers
- **RED (Backstop)**: Emergency support needed

**APY Selection**
- **3 (13%)**: Highest APY, system very healthy
- **2 (12%)**: Middle APY, good health
- **1 (11%)**: Minimum APY, stressed conditions

### Vault Interactions

**Spillover (>110%)**
```
Senior (excess) → Junior (80%) + Reserve (20%)
```

**Backstop (<100%)**
```
Reserve → Senior (primary, no cap)
Junior → Senior (secondary, no cap)
```

## 🧪 Customizing Simulations

### Create Your Own Scenario

```solidity
function test_MyCustomScenario() public {
    // Month 1: Your custom trade
    simulateTrade(SAIL_AMOUNT, PRICE_IMPACT_BPS);
    executeRebase();
    
    // Month 2: Another trade
    simulateTrade(SAIL_AMOUNT, PRICE_IMPACT_BPS);
    executeRebase();
    
    // ... repeat
    
    // Export
    string memory json = exportToJSON();
    vm.writeFile("./simulation_output/my_custom_scenario.json", json);
}
```

### Parameters

**`simulateTrade(sailAmountIn, priceImpactBps)`**
- `sailAmountIn`: Positive = sell SAIL (price down), Negative = buy SAIL (price up)
- `priceImpactBps`: Expected price impact in basis points (for validation)

**`executeRebase()`**
- Executes full rebase following math spec
- Automatically handles spillover/backstop
- Updates all vault states
- Takes snapshot for time-series

## 📐 Math Spec Compliance

This simulation implements:

✅ **Three-Zone Spillover System**
- Zone 1 (>110%): Profit spillover calculation
- Zone 2 (100-110%): No action
- Zone 3 (<100%): Backstop with 100.9% restoration

✅ **Dynamic APY Selection (11-13%)**
- Waterfall algorithm: 13% → 12% → 11%
- Selects highest APY that maintains peg

✅ **Rebase Algorithm (6 Steps)**
1. Management fee calculation
2-3. Dynamic APY selection + performance fee
4. Zone determination
5A/5B. Execute spillover or backstop
6. Update rebase index

✅ **Fee Calculations**
- Management: 1% annual (0.0833% monthly)
- Performance: 2% of user tokens
- Minted as tokens (dilution model)

✅ **Constant Product AMM**
- x * y = k formula
- Realistic price impact
- LP token pricing based on TVL

## 🎯 Use Cases

### Risk Analysis
- Identify conditions that trigger backstops
- Measure reserve depletion risk
- Assess Junior downside exposure

### APY Optimization
- See when system selects 13% vs 11%
- Understand backing ratio requirements
- Optimize target thresholds

### Stress Testing
- Extreme market scenarios
- Prolonged bear markets
- Flash crashes

### Parameter Tuning
- Test different spillover ratios
- Adjust zone thresholds
- Modify fee structures

## 📞 Support

For questions or issues:
1. Check the math spec (`../math_spec.md`)
2. Review contract architecture (`../CONTRACT_ARCHITECTURE.md`)
3. Examine the simulation code (`../test/simulation/`)

## 🔧 Technical Details

### AMM Formula
```
k = x * y (constant product)
price = x / y
LP_value = (x + y * price) / LP_supply
```

### Rebase Index
```
I_new = I_old × (1 + r_selected × 1.02)
balance = shares × index
```

### Backing Ratio
```
R = V_senior / S_snrUSD
```

---

**Happy Simulating!** 🚀

