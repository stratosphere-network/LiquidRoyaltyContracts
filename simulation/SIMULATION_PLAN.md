# 🎲 Reserve Depletion Simulation Plan

## 📊 **What We're Simulating**

Your boss wants to know: **"How long can the Reserve vault sustain losses before being depleted?"**

This is a **critical risk management question** that every protocol should answer!

---

## 🎯 **Simulation Objectives**

1. **Time to Depletion**: How many days/months until Reserve = $0?
2. **Coverage Capacity**: How many backstop events can Reserve handle?
3. **Breaking Point**: What loss % triggers immediate depletion?
4. **Safe Buffer Size**: What Reserve size provides 99% confidence of survival?

---

## 🧮 **Key Variables**

### **Initial State**
```typescript
const initialState = {
  seniorVaultValue: 10_000_000,  // $10M HONEY
  juniorVaultValue: 3_000_000,   // $3M HONEY
  reserveVaultValue: 1_000_000,  // $1M WBTC equivalent
  
  targetBackingRatio: 100,        // 100% = fully backed
  healthyZoneMin: 100,            // Below this = spillover needed
  healthyZoneMax: 110,            // Above this = profit
};
```

### **Market Scenarios**
```typescript
const scenarios = {
  // 1. Normal Operations
  normalYield: {
    dailyYieldRate: 0.033,        // 12% APY / 365
    volatility: 0.005,            // ±0.5% daily
    withdrawalRate: 0.01,         // 1% daily withdrawals
  },
  
  // 2. Bear Market
  bearMarket: {
    dailyYieldRate: -0.01,        // -3.65% APY (negative yield)
    volatility: 0.02,             // ±2% daily swings
    withdrawalRate: 0.05,         // 5% daily panic withdrawals
  },
  
  // 3. Black Swan (Market Crash)
  blackSwan: {
    immediateLoss: 0.30,          // 30% LP value crash
    dailyYieldRate: -0.05,        // -18% APY
    volatility: 0.10,             // ±10% daily chaos
    withdrawalRate: 0.20,         // 20% daily bank run
  },
  
  // 4. Protocol Attack
  protocolAttack: {
    immediateLoss: 0.50,          // 50% exploit
    dailyYieldRate: 0,            // Paused
    withdrawalRate: 0,            // Paused
  },
  
  // 5. Gradual Decline
  gradualDecline: {
    dailyYieldRate: -0.001,       // -0.36% APY
    volatility: 0.01,             // ±1% daily
    withdrawalRate: 0.02,         // 2% daily slow bleed
  },
};
```

### **Backstop Triggers**
```typescript
const backstopRules = {
  // When does Reserve kick in?
  triggerBackingRatio: 100,       // When Senior < 100% backing
  
  // How much does Reserve cover?
  coveragePerEvent: (seniorDeficit) => {
    // Reserve covers the full deficit
    return seniorDeficit;
  },
  
  // Reserve depleted when:
  depletionThreshold: 0.01,       // Reserve < 1% of original value
};
```

---

## 📈 **Simulation Types**

### **1. Monte Carlo Simulation** (Recommended)
Run 10,000 simulations with random market conditions:

```typescript
function monteCarloSimulation(iterations = 10_000) {
  const results = [];
  
  for (let i = 0; i < iterations; i++) {
    // Random walk with:
    // - Daily yield: Normal distribution (mean, volatility)
    // - Daily withdrawals: Poisson distribution
    // - Shock events: Rare (1% chance per day)
    
    const daysUntilDepletion = runSingleSimulation({
      randomSeed: i,
      scenario: 'mixed',
    });
    
    results.push(daysUntilDepletion);
  }
  
  return {
    median: percentile(results, 50),
    p95: percentile(results, 95),      // 95% survive at least this long
    p99: percentile(results, 99),      // 99% survive at least this long
    mean: average(results),
    worstCase: min(results),
    bestCase: max(results),
  };
}
```

**Output Example:**
```
📊 Monte Carlo Results (10,000 simulations)

Median survival: 456 days
P95 survival:    89 days   (95% chance Reserve lasts at least 89 days)
P99 survival:    23 days   (99% chance Reserve lasts at least 23 days)
Worst case:      7 days    (0.1% chance of quick depletion)
Best case:       Never     (23% never depleted in 2 years)

Depletion events: 7,689 / 10,000 (77%)
```

---

### **2. Stress Test Scenarios** (Fixed Conditions)

Test specific disaster scenarios:

```typescript
const stressTests = [
  {
    name: "30% Market Crash",
    initialLoss: 0.30,
    dailyYield: -0.01,
    withdrawalRate: 0.05,
    duration: 365,
  },
  {
    name: "Prolonged Bear Market (2 years)",
    initialLoss: 0,
    dailyYield: -0.002,
    withdrawalRate: 0.03,
    duration: 730,
  },
  {
    name: "Black Swan + Bank Run",
    initialLoss: 0.50,
    dailyYield: -0.05,
    withdrawalRate: 0.20,
    duration: 30,
  },
  {
    name: "Slow Bleed (Death by 1000 Cuts)",
    initialLoss: 0,
    dailyYield: 0.01,          // Still profitable!
    withdrawalRate: 0.015,     // But withdrawals > deposits
    duration: 730,
  },
];
```

**Output Example:**
```
📉 Stress Test Results

1. 30% Market Crash
   - Reserve depleted: Day 67
   - Reason: Junior wiped out on Day 12, Reserve covered Senior deficit
   
2. Prolonged Bear Market
   - Reserve depleted: Day 234
   - Reason: Gradual erosion of all vaults
   
3. Black Swan + Bank Run
   - Reserve depleted: Day 3
   - Reason: Catastrophic loss + mass withdrawals
   
4. Slow Bleed
   - Reserve depleted: Day 456
   - Reason: Net negative flow despite positive yield
```

---

### **3. Sensitivity Analysis**

How does Reserve size affect survival?

```typescript
const reserveSizes = [
  0.5_000_000,   // $500k  (5% of Senior)
  1_000_000,     // $1M    (10% of Senior)
  2_000_000,     // $2M    (20% of Senior)
  5_000_000,     // $5M    (50% of Senior)
];

for (const reserveSize of reserveSizes) {
  const survivalDays = runSimulation({ reserveSize });
  console.log(`Reserve ${reserveSize}: ${survivalDays} days`);
}
```

**Output Example:**
```
💰 Reserve Size Impact

$500k  Reserve (5%):   Median survival = 89 days
$1M    Reserve (10%):  Median survival = 234 days
$2M    Reserve (20%):  Median survival = 567 days
$5M    Reserve (50%):  Median survival = Never (99% confidence)

Recommendation: Maintain Reserve ≥ 20% of Senior for 18-month runway
```

---

## 🛠️ **Implementation Approach**

### **Option 1: TypeScript Simulation** (Fast, Flexible)
Build a standalone TypeScript simulation engine:

```typescript
// simulation/src/reserve-simulation.ts
import { randomNormal, randomPoisson } from './utils/random';

interface VaultState {
  senior: number;
  junior: number;
  reserve: number;
  day: number;
}

function simulateOneDay(state: VaultState, scenario: Scenario): VaultState {
  // 1. Apply daily yield (with volatility)
  const yieldMultiplier = 1 + randomNormal(scenario.dailyYieldRate, scenario.volatility);
  state.senior *= yieldMultiplier;
  state.junior *= yieldMultiplier;
  state.reserve *= yieldMultiplier;
  
  // 2. Process withdrawals
  const withdrawals = state.senior * scenario.withdrawalRate;
  state.senior -= withdrawals;
  
  // 3. Check backing ratio
  const backingRatio = (state.senior / 10_000_000) * 100;
  
  // 4. Trigger backstop if needed
  if (backingRatio < 100) {
    const deficit = 10_000_000 - state.senior;
    
    // Junior covers first
    const juniorCoverage = Math.min(deficit, state.junior);
    state.junior -= juniorCoverage;
    const remainingDeficit = deficit - juniorCoverage;
    
    // Reserve covers remaining
    const reserveCoverage = Math.min(remainingDeficit, state.reserve);
    state.reserve -= reserveCoverage;
    state.senior += juniorCoverage + reserveCoverage;
  }
  
  state.day++;
  return state;
}

function runSimulation(scenario: Scenario, maxDays = 730): number {
  let state: VaultState = {
    senior: 10_000_000,
    junior: 3_000_000,
    reserve: 1_000_000,
    day: 0,
  };
  
  while (state.day < maxDays) {
    state = simulateOneDay(state, scenario);
    
    // Check if Reserve depleted
    if (state.reserve < 10_000) {
      return state.day; // Return day of depletion
    }
  }
  
  return Infinity; // Never depleted
}
```

---

### **Option 2: Python/Jupyter Notebook** (Best for Analysis)
Use Python for statistical analysis and visualization:

```python
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy import stats

def simulate_reserve_depletion(iterations=10000):
    results = []
    
    for i in range(iterations):
        state = {
            'senior': 10_000_000,
            'junior': 3_000_000,
            'reserve': 1_000_000,
        }
        
        day = 0
        while day < 730 and state['reserve'] > 10_000:
            # Random daily yield
            daily_yield = np.random.normal(0.033, 0.005)
            
            # Apply yield
            state['senior'] *= (1 + daily_yield)
            state['junior'] *= (1 + daily_yield)
            state['reserve'] *= (1 + daily_yield)
            
            # Withdrawals
            withdrawals = state['senior'] * 0.01
            state['senior'] -= withdrawals
            
            # Backstop logic
            if state['senior'] < 10_000_000:
                deficit = 10_000_000 - state['senior']
                junior_coverage = min(deficit, state['junior'])
                state['junior'] -= junior_coverage
                remaining = deficit - junior_coverage
                reserve_coverage = min(remaining, state['reserve'])
                state['reserve'] -= reserve_coverage
                state['senior'] += junior_coverage + reserve_coverage
            
            day += 1
        
        results.append(day if state['reserve'] <= 10_000 else np.inf)
    
    return results

# Run simulation
results = simulate_reserve_depletion(10_000)

# Analysis
print(f"Median survival: {np.median(results):.0f} days")
print(f"P95 survival: {np.percentile(results, 5):.0f} days")
print(f"Mean survival: {np.mean([r for r in results if r != np.inf]):.0f} days")
print(f"Never depleted: {sum(r == np.inf for r in results) / len(results) * 100:.1f}%")

# Visualization
plt.figure(figsize=(12, 6))
plt.hist([r for r in results if r != np.inf], bins=50, edgecolor='black')
plt.xlabel('Days Until Reserve Depletion')
plt.ylabel('Frequency')
plt.title('Reserve Depletion Time Distribution (10,000 simulations)')
plt.axvline(np.median(results), color='red', linestyle='--', label=f'Median: {np.median(results):.0f} days')
plt.legend()
plt.savefig('reserve_depletion_simulation.png', dpi=300)
```

---

### **Option 3: Smart Contract Testing** (Most Accurate)
Use Foundry to simulate on-chain:

```solidity
// test/simulation/ReserveDepletionSimulation.t.sol
contract ReserveDepletionSimulation is Test {
    function testMonteCarloSimulation() public {
        uint256 iterations = 1000;
        uint256[] memory depletionDays = new uint256[](iterations);
        
        for (uint256 i = 0; i < iterations; i++) {
            // Random seed
            vm.warp(block.timestamp + i * 1 days);
            
            // Reset vaults
            setUp();
            
            // Run simulation
            depletionDays[i] = simulateUntilDepletion();
        }
        
        // Calculate statistics
        uint256 median = _median(depletionDays);
        uint256 p95 = _percentile(depletionDays, 5);
        
        console.log("Median survival:", median, "days");
        console.log("P95 survival:", p95, "days");
    }
    
    function simulateUntilDepletion() internal returns (uint256) {
        uint256 day = 0;
        
        while (day < 730 && reserveVault.totalAssets() > 10_000e18) {
            // Advance 1 day
            vm.warp(block.timestamp + 1 days);
            
            // Simulate random yield
            int256 dailyYield = _randomYield();
            _applyYield(dailyYield);
            
            // Simulate withdrawals
            _simulateWithdrawals();
            
            // Trigger rebase (backstop)
            seniorVault.rebase(1e18);
            
            day++;
        }
        
        return day;
    }
}
```

---

## 📊 **Expected Outputs**

### **1. Executive Summary Report**
```markdown
# Reserve Vault Stress Test Results

## Current Configuration
- Senior Vault: $10M
- Junior Vault: $3M (30% of Senior)
- Reserve Vault: $1M (10% of Senior)

## Key Findings
✅ Under normal conditions: Reserve NEVER depletes (99.8% confidence)
⚠️  30% market crash: Reserve lasts 67 days median
🚨 Black swan event: Reserve depletes in 3 days

## Recommendations
1. Increase Reserve to $2M (20% of Senior) for 6-month runway
2. Implement circuit breakers for >20% daily losses
3. Monitor Junior depletion as early warning signal
```

### **2. Interactive Dashboard**
Build a React dashboard (you already have the simulation folder!):
- Sliders to adjust vault sizes, yield rates, withdrawal rates
- Real-time chart showing depletion timeline
- Scenario comparison (normal vs bear vs crash)

### **3. Risk Metrics**
```typescript
interface RiskMetrics {
  // Survival probability
  probabilityOfSurvival30Days: number;    // e.g., 99.2%
  probabilityOfSurvival90Days: number;    // e.g., 94.1%
  probabilityOfSurvival365Days: number;   // e.g., 67.3%
  
  // Value at Risk
  valueAtRisk95: number;                   // 95% chance Reserve > this value
  expectedShortfall: number;               // Average loss in worst 5% cases
  
  // Depletion triggers
  maxTolerableLoss: number;                // Single loss that wipes Reserve
  maxDailyWithdrawals: number;             // Max daily outflow before danger
  
  // Coverage ratios
  backstopCapacity: number;                // How many $1M deficits can Reserve cover?
  daysOfCoverage: number;                  // At current burn rate
}
```

---

## 🚀 **Quick Start: Let's Build It!**

I can help you build any of these:

1. **Quick & Dirty** (1 hour): TypeScript simulation with basic scenarios
2. **Professional** (3 hours): Full Monte Carlo with React dashboard
3. **Academic** (1 day): Python Jupyter notebook with statistical analysis
4. **Production** (2 days): Foundry-based on-chain simulation + frontend

**Which approach do you want to start with?**

---

## 💡 **Why This Matters**

- ✅ **Risk Management**: Know your protocol's limits
- ✅ **Investor Confidence**: Show you've stress-tested the system
- ✅ **Parameter Tuning**: Determine optimal Reserve size
- ✅ **Circuit Breakers**: Know when to trigger emergency mechanisms
- ✅ **Insurance Pricing**: Data for coverage premiums

Your boss is asking the RIGHT questions! 🎯


