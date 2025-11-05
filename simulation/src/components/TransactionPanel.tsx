import { useState } from 'react';
import { apiService } from '../services/api';
import { config } from '../config';
import { ethers } from 'ethers';
import './TransactionPanel.css';

export const TransactionPanel = () => {
  const [privateKey, setPrivateKey] = useState(config.bots.whale.privateKey);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState<{type: 'success' | 'error', text: string} | null>(null);

  // Swap state
  const [swapTokenIn, setSwapTokenIn] = useState<'TUSD' | 'TSAIL'>('TUSD');
  const [swapAmount, setSwapAmount] = useState('1000');
  const [swapSlippage, setSwapSlippage] = useState('0.5');

  // Zap state
  const [zapAmount, setZapAmount] = useState('1000');
  const [zapVault, setZapVault] = useState<'junior' | 'senior' | 'reserve'>('junior');
  const [zapSlippage, setZapSlippage] = useState('0.5');

  const handleSwap = async () => {
    if (!privateKey) {
      setMessage({ type: 'error', text: '❌ Private key required' });
      return;
    }

    try {
      setLoading(true);
      setMessage(null);

      const result = await apiService.swapTokens(
        privateKey,
        swapTokenIn,
        swapAmount,
        parseFloat(swapSlippage)
      );

      if (result.success) {
        setMessage({
          type: 'success',
          text: `✅ Swapped ${swapAmount} ${swapTokenIn} → ${result.swap?.amountOutExpected} ${result.swap?.tokenOut}`
        });
      }
    } catch (error: any) {
      setMessage({ type: 'error', text: `❌ ${error.message}` });
    } finally {
      setLoading(false);
      setTimeout(() => setMessage(null), 8000);
    }
  };

  const handleZapAndStake = async () => {
    if (!privateKey) {
      setMessage({ type: 'error', text: '❌ Private key required' });
      return;
    }

    try {
      setLoading(true);
      setMessage(null);

      const result = await apiService.zapAndStake(
        privateKey,
        zapAmount,
        zapVault,
        parseFloat(zapSlippage)
      );

      if (result.success) {
        // Get user address from private key
        const wallet = new ethers.Wallet(privateKey);
        const userAddress = wallet.address;
        
        setMessage({
          type: 'success',
          text: `✅ Staked ${zapAmount} TUSD in ${zapVault} vault! Shares sent to ${userAddress.slice(0, 6)}...${userAddress.slice(-4)}`
        });
      }
    } catch (error: any) {
      setMessage({ type: 'error', text: `❌ ${error.message}` });
    } finally {
      setLoading(false);
      setTimeout(() => setMessage(null), 8000);
    }
  };

  return (
    <div className="transaction-panel">
      <div className="panel-header">
        <h2 className="gradient-text">🎮 Custom Transactions</h2>
        <p className="subtitle">Manual transaction control panel</p>
      </div>

      {/* Message */}
      {message && (
        <div className={`tx-message ${message.type}`}>
          {message.text}
        </div>
      )}

      {/* Private Key Input */}
      <div className="input-group full-width">
        <label>🔑 Private Key</label>
        <input
          type="password"
          value={privateKey}
          onChange={(e) => setPrivateKey(e.target.value)}
          placeholder="0x..."
          className="key-input"
        />
      </div>

      {/* Info Section */}
      <div className="info-section">
        <div className="info-content">
          <span className="info-icon">ℹ️</span>
          <div>
            <strong>How It Works</strong>
            <p>Anyone can zap & stake! Admin deposits LP tokens, but vault shares go to YOUR address. No whitelist needed!</p>
          </div>
        </div>
      </div>

      {/* Swap Section */}
      <div className="tx-section">
        <h3>🔄 Token Swap</h3>
        <div className="tx-form">
          <div className="form-row">
            <div className="input-group">
              <label>Token In</label>
              <select 
                value={swapTokenIn} 
                onChange={(e) => setSwapTokenIn(e.target.value as 'TUSD' | 'TSAIL')}
                disabled={loading}
              >
                <option value="TUSD">TUSD</option>
                <option value="TSAIL">TSAIL</option>
              </select>
            </div>
            <div className="input-group">
              <label>Amount</label>
              <input
                type="number"
                value={swapAmount}
                onChange={(e) => setSwapAmount(e.target.value)}
                placeholder="1000"
                disabled={loading}
              />
            </div>
            <div className="input-group">
              <label>Slippage %</label>
              <input
                type="number"
                value={swapSlippage}
                onChange={(e) => setSwapSlippage(e.target.value)}
                placeholder="0.5"
                step="0.1"
                disabled={loading}
              />
            </div>
          </div>
          <button 
            onClick={handleSwap} 
            disabled={loading}
            className="tx-btn swap-btn"
          >
            {loading ? '⏳ Swapping...' : `🔄 Swap ${swapTokenIn}`}
          </button>
        </div>
      </div>

      {/* Zap & Stake Section */}
      <div className="tx-section">
        <h3>⚡ Zap & Stake</h3>
        <div className="tx-form">
          <div className="form-row">
            <div className="input-group">
              <label>Vault</label>
              <select 
                value={zapVault} 
                onChange={(e) => setZapVault(e.target.value as 'junior' | 'senior' | 'reserve')}
                disabled={loading}
              >
                <option value="junior">Junior Vault</option>
                <option value="senior">Senior Vault</option>
                <option value="reserve">Reserve Vault</option>
              </select>
            </div>
            <div className="input-group">
              <label>Amount TUSD</label>
              <input
                type="number"
                value={zapAmount}
                onChange={(e) => setZapAmount(e.target.value)}
                placeholder="1000"
                disabled={loading}
              />
            </div>
            <div className="input-group">
              <label>Slippage %</label>
              <input
                type="number"
                value={zapSlippage}
                onChange={(e) => setZapSlippage(e.target.value)}
                placeholder="0.5"
                step="0.1"
                disabled={loading}
              />
            </div>
          </div>
          <button 
            onClick={handleZapAndStake} 
            disabled={loading}
            className="tx-btn zap-btn"
          >
            {loading ? '⏳ Processing...' : `⚡ Zap & Stake to ${zapVault}`}
          </button>
        </div>
      </div>

      {/* Quick Actions */}
      <div className="quick-actions">
        <button 
          onClick={() => {
            setSwapTokenIn('TUSD');
            setSwapAmount('5000');
          }}
          className="quick-btn"
        >
          💰 Swap 5k TUSD
        </button>
        <button 
          onClick={() => {
            setSwapTokenIn('TSAIL');
            setSwapAmount('1000');
          }}
          className="quick-btn"
        >
          🌊 Swap 1k TSAIL
        </button>
        <button 
          onClick={() => {
            setZapVault('senior');
            setZapAmount('10000');
          }}
          className="quick-btn"
        >
          🏦 Stake 10k Senior
        </button>
      </div>
    </div>
  );
};

