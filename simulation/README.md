# 🚀 LiquidRoyalty Vault Simulator

A real-time simulation environment for testing bot interactions with LiquidRoyalty vaults on Polygon.

## 🎮 Features

- **Real-time Dashboard**: Live vault analytics, pool data, and profit tracking
- **Bot Simulation**: 4 configurable bots (2 whales, 2 farmers) with different strategies
- **Transaction Feed**: Real-time transaction monitoring with Polygonscan links
- **Interactive Controls**: Manual and automated bot execution
- **Responsive Design**: Works on desktop, tablet, and mobile
- **Degen Aesthetic**: Dark mode with neon accents and smooth animations

## 🤖 Bots

### Conservative Whale
- Type: Large capital player
- Strategy: Low risk, smaller amounts
- Default: 5,000 TUSD per action

### Risky Whale
- Type: Large capital player
- Strategy: High risk, larger amounts
- Default: 20,000 TUSD per action

### Conservative Farmer
- Type: Small yield farmer
- Strategy: Low risk, smaller amounts
- Default: 1,000 TUSD per action

### Risky Farmer
- Type: Aggressive yield farmer
- Strategy: High risk, larger amounts
- Default: 5,000 TUSD per action

## 🚀 Getting Started

### Prerequisites

- Node.js 18+ installed
- API server running on port 3000
- Bot wallet private keys configured

### Installation

```bash
# Install dependencies
npm install
```

### Configuration

**Configure your bot wallet private keys** in `src/config.ts`:

```typescript
export const config = {
  apiUrl: 'http://localhost:3000',
  chainId: 137,
  networkName: 'Polygon',
  
  bots: {
    whale: {
      privateKey: '0xYOUR_WHALE_PRIVATE_KEY',
      address: '0xYOUR_WHALE_ADDRESS'
    },
    farmer: {
      privateKey: '0xYOUR_FARMER_PRIVATE_KEY', 
      address: '0xYOUR_FARMER_ADDRESS'
    }
  }
};
```

⚠️ **Never commit your private keys to git!** Add `src/config.ts` to `.gitignore` if using real keys.

### Start the Simulation

```bash
# Start API server (in ../wrapper directory)
cd ../wrapper
npm run dev

# In a new terminal, start the simulation UI
cd ../simulation
npm run dev
```

The app will open at `http://localhost:5173`
The API runs on `http://localhost:3000`

## 🎯 How to Use

1. **View Dashboard**: See real-time vault and pool data
2. **Expand Bot Cards**: Click on any bot to see controls
3. **Execute Actions**:
   - Choose "Swap" or "Zap & Stake"
   - Select vault (for zap)
   - Enter amount or use default
   - Click "Execute" or "Random"
4. **Start Simulation**: Click "Start Simulation" for automated bot activity
5. **Monitor Transactions**: Watch the transaction feed for real-time updates

## 📊 Bot Actions

### Swap
- Swaps between TUSD and TSAIL tokens
- Random direction (TUSD→TSAIL or TSAIL→TUSD)
- Slippage: 0.5% (conservative) or 2% (risky)

### Zap & Stake
- Converts TUSD to LP tokens
- Stakes in selected vault (Junior/Senior/Reserve)
- All-in-one transaction
- Slippage: 0.5% (conservative) or 2% (risky)

## 🎨 Tech Stack

- **React 18** with TypeScript
- **Vite** for blazing fast dev experience
- **Framer Motion** for smooth animations
- **Axios** for API calls
- **Custom CSS** with degen aesthetic

## 🔗 Related

- API Documentation: `../wrapper/api.json`
- Smart Contracts: `../src/`
- Deployment Scripts: `../script/`

## ⚠️ Important Notes

- This simulator executes **real transactions** on Polygon mainnet
- Ensure you have enough MATIC for gas fees
- Bot private keys are configured in the code (change before production)
- All transactions are visible on Polygonscan

## 🛠️ Development

```bash
# Run dev server
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview

# Type check
npm run type-check
```

## 📝 License

MIT
