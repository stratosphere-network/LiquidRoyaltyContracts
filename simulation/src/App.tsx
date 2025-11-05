import { useState } from 'react';
import { Dashboard } from './components/Dashboard';
import { BotCard } from './components/BotCard';
import { TransactionFeed } from './components/TransactionFeed';
import { TransactionPanel } from './components/TransactionPanel';
import { apiService } from './services/api';
import type { Bot, Transaction } from './types';
import { config } from './config';
import './App.css';

const BOTS: Bot[] = [
  {
    id: 'whale-conservative',
    name: 'Conservative Whale',
    type: 'whale',
    strategy: 'conservative',
    privateKey: config.bots.whale.privateKey,
    address: config.bots.whale.address,
    isActive: true
  },
  {
    id: 'whale-risky',
    name: 'Risky Whale',
    type: 'whale',
    strategy: 'risky',
    privateKey: config.bots.whale.privateKey,
    address: config.bots.whale.address,
    isActive: true
  },
  {
    id: 'farmer-conservative',
    name: 'Conservative Farmer',
    type: 'farmer',
    strategy: 'conservative',
    privateKey: config.bots.farmer.privateKey,
    address: config.bots.farmer.address,
    isActive: true
  },
  {
    id: 'farmer-risky',
    name: 'Risky Farmer',
    type: 'farmer',
    strategy: 'risky',
    privateKey: config.bots.farmer.privateKey,
    address: config.bots.farmer.address,
    isActive: true
  }
];

function App() {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [simulationActive, setSimulationActive] = useState(false);

  const handleBotAction = (botId: string, action: string, details: string, txHash?: string) => {
    const bot = BOTS.find(b => b.id === botId);
    if (!bot) return;

    const transaction: Transaction = {
      id: `${Date.now()}-${Math.random()}`,
      timestamp: Date.now(),
      botId: bot.id,
      botName: bot.name,
      action: action as any,
      details,
      txHash,
      status: txHash ? 'success' : details.includes('Failed') ? 'failed' : 'pending'
    };

    setTransactions(prev => [...prev, transaction]);
  };

  const executeRandomBotAction = async () => {
    // Pick a random bot
    const randomBot = BOTS[Math.floor(Math.random() * BOTS.length)];
    
    // Pick random action and vault
    const actions = ['swap', 'zap'] as const;
    const vaults: ('junior' | 'senior' | 'reserve')[] = ['junior', 'senior', 'reserve'];
    const randomAction = actions[Math.floor(Math.random() * actions.length)];
    const randomVault = vaults[Math.floor(Math.random() * vaults.length)];
    
    // Get amount based on bot strategy
    const amount = randomBot.strategy === 'conservative' 
      ? (randomBot.type === 'whale' ? '5000' : '1000')
      : (randomBot.type === 'whale' ? '20000' : '5000');
    
    const slippage = randomBot.strategy === 'conservative' ? 0.5 : 2;
    
    try {
      if (randomAction === 'swap') {
        const tokenIn = Math.random() > 0.5 ? 'TUSD' : 'TSAIL';
        handleBotAction(randomBot.id, 'swap', `[AUTO] Swapping ${amount} ${tokenIn}...`);
        
        const result = await apiService.swapTokens(
          randomBot.privateKey,
          tokenIn,
          amount,
          slippage
        );
        
        if (result.success) {
          handleBotAction(
            randomBot.id,
            'swap',
            `[AUTO] Swapped ${amount} ${tokenIn} → ${result.swap?.amountOutExpected} ${result.swap?.tokenOut}`,
            result.transactionHash
          );
        }
      } else {
        handleBotAction(randomBot.id, 'zap_stake', `[AUTO] Zapping ${amount} TUSD to ${randomVault}...`);
        
        const result = await apiService.zapAndStake(
          randomBot.privateKey,
          amount,
          randomVault,
          slippage
        );
        
        if (result.success) {
          handleBotAction(
            randomBot.id,
            'zap_stake',
            `[AUTO] Staked ${amount} TUSD in ${randomVault} vault → ${result.steps?.liquidity.lpTokens} LP`,
            result.finalTransactionHash
          );
        }
      }
    } catch (error: any) {
      handleBotAction(randomBot.id, randomAction, `[AUTO] Failed: ${error.message}`);
    }
  };

  const startSimulation = () => {
    setSimulationActive(true);
    
    // Execute first action immediately
    executeRandomBotAction();
    
    // Auto-execute random actions every 15-45 seconds
    const interval = setInterval(() => {
      executeRandomBotAction();
    }, Math.random() * 30000 + 15000);

    // Store interval ID to clear later
    (window as any).simulationInterval = interval;
  };

  const stopSimulation = () => {
    setSimulationActive(false);
    if ((window as any).simulationInterval) {
      clearInterval((window as any).simulationInterval);
      (window as any).simulationInterval = null;
    }
  };

  const clearTransactions = () => {
    setTransactions([]);
  };

  return (
    <div className="app">
      {/* Hero Section */}
      <div className="hero">
        <div className="hero-content">
          <h1 className="gradient-text">LIQUIDROYALTY</h1>
          <p className="hero-subtitle">Vault Simulation Environment</p>
          <div className="hero-stats">
            <div className="hero-stat">
              <span className="stat-label">Network</span>
              <span className="stat-value">Polygon</span>
            </div>
            <div className="hero-stat">
              <span className="stat-label">Status</span>
              <span className={`stat-value ${simulationActive ? 'active' : ''}`}>
                {simulationActive ? '🟢 Active' : '🔴 Idle'}
              </span>
            </div>
            <div className="hero-stat">
              <span className="stat-label">Bots</span>
              <span className="stat-value">{BOTS.length}</span>
            </div>
          </div>
        </div>
      </div>

      {/* Dashboard */}
      <Dashboard />

      {/* Custom Transaction Panel */}
      <div className="transaction-section">
        <TransactionPanel />
      </div>

      {/* Simulation Section */}
      <div className="simulation-section">
        <div className="section-header">
          <h2 className="gradient-text">🤖 Bot Simulation</h2>
          <div className="controls">
            <button
              onClick={simulationActive ? stopSimulation : startSimulation}
              className={`btn-control ${simulationActive ? 'danger' : 'primary'}`}
            >
              {simulationActive ? '⏸️ Stop Simulation' : '▶️ Start Simulation'}
            </button>
            <button
              onClick={clearTransactions}
              className="btn-control secondary"
              disabled={transactions.length === 0}
            >
              🗑️ Clear Feed
            </button>
          </div>
        </div>

        <div className="simulation-grid">
          {/* Bots */}
          <div className="bots-container">
            <h3 className="subsection-title">
              <span>🤖</span> Active Bots
            </h3>
            <div className="bots-grid">
              {BOTS.map(bot => (
                <BotCard
                  key={bot.id}
                  bot={bot}
                  onAction={handleBotAction}
                />
              ))}
            </div>
          </div>

          {/* Transaction Feed */}
          <div className="feed-container">
            <TransactionFeed transactions={transactions} />
          </div>
        </div>
      </div>

      {/* Footer */}
      <footer className="footer">
        <p>Built with 🔥 by LiquidRoyalty | Simulation Environment v1.0.0</p>
        <p className="footer-note">⚠️ This is a simulation environment. All actions are executed on Polygon mainnet.</p>
      </footer>
    </div>
  );
}

export default App;
