import { useState } from 'react';
import { Dashboard } from './components/Dashboard';
import { BotCard } from './components/BotCard';
import { TransactionFeed } from './components/TransactionFeed';
import { HistoricalCharts } from './components/HistoricalCharts';
import type { Bot, Transaction } from './types';
import './App.css';

const ADMIN_ADDRESS = '0xE09883Cb3Fe2d973cEfE4BB28E3A3849E7e5f0A7';
const ADMIN_PRIVATE_KEY = '0x56f68e21f8d5809e1b17414a49b801b0caa1a482db3d4b2f16d2117a53140099';

const BOTS: Bot[] = [
  {
    id: '1',
    name: 'Whale Alpha',
    type: 'whale',
    address: ADMIN_ADDRESS,
    privateKey: ADMIN_PRIVATE_KEY,
    strategy: 'aggressive'
  },
  {
    id: '2',
    name: 'Farmer Bob',
    type: 'farmer',
    address: ADMIN_ADDRESS,
    privateKey: ADMIN_PRIVATE_KEY,
    strategy: 'conservative'
  }
];

function App() {
  const [transactions, setTransactions] = useState<Transaction[]>([]);

  const handleBotAction = (botId: string, action: string, details: string, txHash?: string) => {
    const newTx: Transaction = {
      id: Date.now().toString(),
      botId,
      action,
      details,
      timestamp: new Date().toISOString(),
      status: txHash ? 'success' : 'pending',
      txHash
    };
    setTransactions(prev => [newTx, ...prev].slice(0, 50)); // Keep last 50
  };

  return (
    <div className="app">
      {/* Hero Section */}
      <div className="hero">
        <div className="hero-content">
          <h1 className="gradient-text">Liquid Royalty Protocol</h1>
          <p className="hero-subtitle">Vault Simulation & Testing Dashboard</p>
          <div className="hero-stats">
            <div className="hero-stat">
              <span className="stat-label">Network</span>
              <span className="stat-value">Polygon</span>
            </div>
            <div className="hero-stat">
              <span className="stat-label">Status</span>
              <span className="stat-value active">🟢 Live</span>
            </div>
            <div className="hero-stat">
              <span className="stat-label">Bots Active</span>
              <span className="stat-value">{BOTS.length}</span>
            </div>
          </div>
        </div>
      </div>

      {/* Dashboard */}
      <Dashboard />

      {/* Historical Charts */}
      <HistoricalCharts />

      {/* Bot Simulation Section */}
      <div className="simulation-section">
        <h2 className="section-title">🤖 Bot Simulation</h2>
        <div className="bots-container">
          {BOTS.map(bot => (
            <BotCard key={bot.id} bot={bot} onAction={handleBotAction} />
          ))}
        </div>
      </div>

      {/* Transaction Feed */}
      <TransactionFeed transactions={transactions} />

      {/* Footer */}
      <footer className="footer">
        <p>Built with 🔥 by LiquidRoyalty | Simulation v1.0.0</p>
        <p className="footer-note">🤖 Automated bot testing & 📊 real-time monitoring</p>
      </footer>
    </div>
  );
}

export default App;
