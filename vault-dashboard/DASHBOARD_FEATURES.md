# Enhanced Simulation Dashboard Features

## New Features 🎉

Your dashboard now shows **complete financial analytics** including:
- ✅ **Protocol Fee Revenue** (management + performance fees)
- ✅ **User Wallet Activity** (deposits, withdrawals, trades)
- ✅ **Transaction Timeline** with reasons
- ✅ **Whale vs Retail Analytics**

## How to View

### 1. Start the Dashboard
```bash
cd vault-dashboard
npm run dev
```

### 2. Open in Browser
Visit: http://localhost:5173

### 3. Select a Scenario
Click on **"📈 Bull Market"** or **"📉 Bear Market"** to see the enhanced data

## What You'll See

### 📊 Fee Revenue Section

**Protocol Fee Revenue** panel shows:
- **Total Fees**: All fees collected over 12 months
- **Management Fees**: From 1% annual fee
- **Performance Fees**: From APY spread (11-13%)
- **Average Yield**: Fee yield as % of AUM (in BPS)
- **Annual Rate**: Total fees as % of final AUM

**Charts:**
1. **Monthly Fee Collection** - Stacked bar chart showing management + performance fees each epoch
2. **Cumulative Fee Revenue** - Area chart showing running total

### 👥 User Wallet Activity Section

**Activity Summary** shows:
- **Deposits**: Count and total USD
- **Withdrawals**: Count and total USD  
- **Trades**: SAIL swap count
- **Whales**: Number of whale wallets (Whale 1, Whale 2)
- **Retail**: Number of retail investors (Retail 1, 2, 3)
- **Total Actions**: All transactions

**Action Timeline** shows every transaction:
- 💰 Deposits with amounts and reasons
- 📤 Withdrawals with shares and reasons
- 🔄 Trades with direction and reasons

Each action shows:
- User type (Whale vs Retail)
- Action type (DEPOSIT/WITHDRAW/TRADE)
- Vault (SENIOR/JUNIOR/RESERVE/POOL)
- Amount and shares
- **Reason** (e.g., "Whale 1 buying the dip", "Retail panic selling")

**Activity by Vault Chart** - Bar chart showing deposits/withdrawals/trades per vault

## Enhanced Monthly Metrics Table

The detailed table now includes:
- **Mgmt Fee**: Management fee collected this epoch
- **Perf Fee**: Performance fee collected this epoch
- **Fee Yield**: Fee yield in basis points

## Example Insights

### Bull Market Scenario
- **Total Fees**: ~$22,771 over 12 months
- **Management**: $18,533 (81%)
- **Performance**: $4,237 (19%)
- **User Actions**: 25 transactions
  - Whales accumulate early
  - Retail FOMO at top
  - Whale 2 takes profit at peak

### Bear Market Scenario
- **Total Fees**: ~$19,942 over 12 months
- **Management**: $16,068 (80%)
- **Performance**: $3,874 (20%)
- **User Actions**: 23 transactions
  - Retail panic sells first
  - Whales capitulate later
  - Whale 1 buys the bottom

## Understanding User Behavior

### Whale Wallets
- **Whale 1** (0x1111): Smart money
  - Buys dips
  - Holds through volatility
  - Contrarian plays
  
- **Whale 2** (0x2222): Aggressive trader
  - High conviction buys
  - FOMO near tops
  - Sometimes panics

### Retail Wallets
- **Retail 1** (0x3333): Conservative
  - Gets scared easily
  - Sells on bad news
  
- **Retail 2** (0x4444): Moderate
  - Balanced behavior
  - Partial exits for safety
  
- **Retail 3** (0x5555): FOMO investor
  - Buys tops
  - Sells bottoms
  - Emotional trading

## Data Files

Each scenario has **2 JSON files**:

1. **`scenario1_bull_market.json`**
   - Vault snapshots with fee data
   - Pool state, TVL, backing ratios
   - Spillover/backstop events
   
2. **`scenario1_user_actions.json`**
   - Complete transaction history
   - Every deposit, withdrawal, trade
   - User addresses and reasons

## Developer Notes

### TypeScript Interfaces

```typescript
interface FeeData {
  managementFeeTokens: number;
  performanceFeeTokens: number;
  totalFeesThisEpoch: number;
  cumulativeFees: number;
  feeYieldBps: number;
}

interface UserAction {
  timestamp: number;
  epoch: number;
  user: string;
  actionType: 'DEPOSIT' | 'WITHDRAW' | 'TRADE';
  vault: string;
  amount: number;
  shares: number;
  reason: string;
}
```

### Adding New Scenarios

1. Run simulation:
   ```bash
   forge test --match-test test_YourScenario -vv
   ```

2. Copy output files:
   ```bash
   cp simulation_output/your_scenario*.json vault-dashboard/public/simulation_output/
   ```

3. Add to scenario list in `SimulationDashboard.tsx`:
   ```typescript
   { id: 'your_scenario', name: '🎯 Your Scenario', color: '#yourcolor' }
   ```

## Troubleshooting

### No Fee Data Showing
- Old scenarios don't have fee data (backward compatible)
- Run the new enhanced simulations to generate fee data

### No User Actions
- Only Bull Market and Bear Market scenarios have user actions
- User actions file must match scenario name with `_user_actions.json` suffix

### Dashboard Not Updating
```bash
# Clear cache and restart
rm -rf node_modules/.vite
npm run dev
```

## Future Enhancements

Potential additions:
- 📈 Fee APY projections
- 🎯 Whale wallet profitability
- 📊 Retail vs whale performance comparison
- 🔍 Transaction search and filter
- 💹 Real-time fee calculator
- 📱 Mobile-responsive improvements

