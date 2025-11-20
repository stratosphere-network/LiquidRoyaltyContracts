# 📊 Simulation Results

This directory contains JSON output from vault stress test simulations.

## 📂 Files Generated

Each test scenario generates a JSON file with timestamped snapshots of all vault states:

- **`scenario1_sail_pump.json`** - SAIL price increases from 10 → 12 USDE
- **`scenario2_sail_dump.json`** - SAIL price decreases from 10 → 8 USDE  
- **`scenario3_high_volatility.json`** - SAIL swings wildly between 8-15 USDE over 7 days
- **`scenario4_gradual_decline.json`** - SAIL slowly bleeds from 10 → 5 USDE over 30 days
- **`scenario5_black_swan.json`** - SAIL crashes 80% to 2 USDE instantly
- **`scenario6_extended_bear_market.json`** - 60 days of decline (10 → 6 USDE) with 2% daily withdrawals

## 📋 JSON Structure

Each JSON file contains:

```json
{
  "scenario": "scenario1_sail_pump",
  "snapshots": [
    {
      "day": 0,
      "timestamp": 1234567890,
      "sailPrice": "10000000000000000000",
      "lpPrice": "2000000000000000000",
      "seniorTotalSupply": "1500000000000000000000000",
      "seniorVaultValue": "1500000000000000000000000",
      "seniorBackingRatio": "100000000000000000000",
      "juniorTotalAssets": "1500000000000000000000000",
      "juniorTotalSupply": "1500000000000000000000000",
      "juniorUnstakingRatio": "100000000000000000000",
      "reserveTotalAssets": "750000000000000000000000",
      "reserveTotalSupply": "750000000000000000000000",
      "poolUsdeReserve": "1000000000000000000000000",
      "poolSailReserve": "100000000000000000000000",
      "description": "Initial"
    },
    ...
  ]
}
```

## 📊 Data Fields

| Field | Description | Unit |
|-------|-------------|------|
| `day` | Simulation day (0 = start) | integer |
| `timestamp` | Block timestamp | Unix timestamp |
| `sailPrice` | SAIL token price in USDE | Wei (18 decimals) |
| `lpPrice` | LP token price in USDE | Wei (18 decimals) |
| `seniorTotalSupply` | Total snrUSD in circulation | Wei (18 decimals) |
| `seniorVaultValue` | Total value backing Senior | Wei (18 decimals) |
| `seniorBackingRatio` | Senior collateralization % | Basis points (100e18 = 100%) |
| `juniorTotalAssets` | Junior vault total assets | Wei (18 decimals) |
| `juniorTotalSupply` | Total jnrUSD in circulation | Wei (18 decimals) |
| `juniorUnstakingRatio` | Junior health % | Basis points (100e18 = 100%) |
| `reserveTotalAssets` | Reserve vault total assets | Wei (18 decimals) |
| `reserveTotalSupply` | Total resUSD in circulation | Wei (18 decimals) |
| `poolUsdeReserve` | USDE in AMM pool | Wei (18 decimals) |
| `poolSailReserve` | SAIL in AMM pool | Wei (18 decimals) |
| `description` | Event description | string |

## 🔧 Running Simulations

To generate simulation results:

```bash
# Run all scenarios
forge test --match-path test/simulation/ReserveDepletionSimulation.t.sol -vv

# Run specific scenario
forge test --match-test test_Scenario1_SAILPump -vv
forge test --match-test test_Scenario2_SAILDump -vv
forge test --match-test test_Scenario3_HighVolatility -vv
forge test --match-test test_Scenario4_GradualDecline -vv
forge test --match-test test_Scenario5_BlackSwan -vv
forge test --match-test test_Scenario6_ExtendedBearMarket -vv
```

## 📈 Visualizing Results

### Using Python (Recommended)

```python
import json
import pandas as pd
import matplotlib.pyplot as plt

# Load simulation data
with open('simulation_results/scenario4_gradual_decline.json') as f:
    data = json.load(f)

# Convert to DataFrame
df = pd.DataFrame(data['snapshots'])

# Convert Wei to human-readable (divide by 1e18)
df['sailPrice'] = df['sailPrice'].astype(float) / 1e18
df['seniorBackingRatio'] = df['seniorBackingRatio'].astype(float) / 1e18
df['juniorUnstakingRatio'] = df['juniorUnstakingRatio'].astype(float) / 1e18
df['reserveTotalAssets'] = df['reserveTotalAssets'].astype(float) / 1e18

# Plot
fig, axes = plt.subplots(2, 2, figsize=(15, 10))

axes[0, 0].plot(df['day'], df['sailPrice'])
axes[0, 0].set_title('SAIL Price Over Time')
axes[0, 0].set_ylabel('USDE per SAIL')

axes[0, 1].plot(df['day'], df['seniorBackingRatio'])
axes[0, 1].axhline(y=100, color='r', linestyle='--', label='100% Target')
axes[0, 1].set_title('Senior Backing Ratio')
axes[0, 1].set_ylabel('%')
axes[0, 1].legend()

axes[1, 0].plot(df['day'], df['juniorUnstakingRatio'])
axes[1, 0].axhline(y=100, color='r', linestyle='--', label='100% Target')
axes[1, 0].set_title('Junior Unstaking Ratio')
axes[1, 0].set_ylabel('%')
axes[1, 0].legend()

axes[1, 1].plot(df['day'], df['reserveTotalAssets'])
axes[1, 1].set_title('Reserve Vault Assets')
axes[1, 1].set_ylabel('USDE')

plt.xlabel('Day')
plt.tight_layout()
plt.savefig('simulation_analysis.png', dpi=300)
print("Chart saved to simulation_analysis.png")
```

### Using JavaScript/TypeScript

```typescript
import fs from 'fs';

// Load simulation data
const data = JSON.parse(
  fs.readFileSync('simulation_results/scenario4_gradual_decline.json', 'utf8')
);

// Calculate statistics
const snapshots = data.snapshots;
const initialReserve = BigInt(snapshots[0].reserveTotalAssets);
const finalReserve = BigInt(snapshots[snapshots.length - 1].reserveTotalAssets);
const reserveDepletion = Number(initialReserve - finalReserve) / 1e18;

console.log(`Scenario: ${data.scenario}`);
console.log(`Duration: ${snapshots.length - 1} days`);
console.log(`Reserve depletion: $${reserveDepletion.toLocaleString()}`);
console.log(`Reserve remaining: ${(Number(finalReserve) / 1e18).toLocaleString()}`);

// Check if Senior ever went under-collateralized
const underCollatEvents = snapshots.filter(s => 
  BigInt(s.seniorBackingRatio) < BigInt(100e18)
);

if (underCollatEvents.length > 0) {
  console.log(`⚠️  Senior was under-collateralized ${underCollatEvents.length} times`);
  console.log(`   Worst backing: ${Number(underCollatEvents[0].seniorBackingRatio) / 1e18}%`);
}
```

### Using Excel/Google Sheets

1. Open the JSON file
2. Use a JSON-to-CSV converter (or Python script above with `.to_csv()`)
3. Import CSV into Excel/Sheets
4. Create charts for:
   - SAIL price over time
   - Senior backing ratio over time
   - Junior unstaking ratio over time
   - Reserve assets over time

## 🎯 Key Metrics to Track

### Reserve Depletion Analysis
- **Time to Depletion**: How many days until Reserve < $1,000?
- **Depletion Rate**: Average daily Reserve loss
- **Survival Probability**: % of scenarios where Reserve survives

### Senior Vault Health
- **Backing Ratio Min**: Lowest backing ratio reached
- **Under-Collat Events**: Number of times backing < 100%
- **Max Deficit**: Largest shortfall covered by backstop

### Junior Vault Impact
- **Total Losses**: Junior assets lost
- **Wipeout Risk**: Did Junior get fully depleted?
- **Loss Absorption**: How much loss did Junior absorb before Reserve?

### Protocol Sustainability
- **Safe SAIL Price**: Minimum SAIL price before insolvency
- **Buffer Size**: Ideal Reserve size for 99% survival
- **Max Withdrawals**: Maximum daily withdrawal rate sustainable

## 📝 Example Analysis Workflow

```bash
# 1. Run all simulations
forge test --match-path test/simulation/ReserveDepletionSimulation.t.sol -vv

# 2. Analyze results with Python
python analyze_simulations.py

# 3. Generate report
./generate_report.sh

# 4. Share with boss 🎉
```

## 🚨 Warning Signs in Results

Look for these patterns:

- ⚠️  **Reserve depletion in < 30 days** → Increase Reserve size or reduce Senior exposure
- ⚠️  **Senior backing < 95%** → Backstop triggered, system stressed
- ⚠️  **Junior wiped out** → First line of defense failed, Reserve next
- ⚠️  **Rapid depletion rate (>$50k/day)** → System unsustainable

## 📧 Reporting to Boss

Key points to include:

1. **Executive Summary**: "Reserve survives X days in Y% of scenarios"
2. **Worst Case**: "In black swan (80% crash), Reserve lasts Z days"
3. **Recommendation**: "Increase Reserve to $XM for 6-month runway"
4. **Charts**: Visual proof of stress test results
5. **Confidence**: "99% probability of surviving normal market conditions"

---

**Last Updated**: November 20, 2025  
**Test Suite**: `ReserveDepletionSimulation.t.sol`  
**Documentation**: See `SIMULATION_PLAN.md` for methodology


