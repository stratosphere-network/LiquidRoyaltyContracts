import { useState } from 'react';
import type { Bot, VaultType } from '../types';
import { apiService } from '../services/api';
import './BotCard.css';

interface BotCardProps {
  bot: Bot;
  onAction: (botId: string, action: string, details: string, txHash?: string) => void;
}

export const BotCard = ({ bot, onAction }: BotCardProps) => {
  const [isExpanded, setIsExpanded] = useState(false);
  const [isExecuting, setIsExecuting] = useState(false);
  const [actionType, setActionType] = useState<'swap' | 'zap'>('zap');
  const [vaultType, setVaultType] = useState<VaultType>('junior');
  const [amount, setAmount] = useState('');

  const getStrategyAmount = () => {
    if (bot.strategy === 'conservative') {
      return bot.type === 'whale' ? '5000' : '1000';
    } else {
      return bot.type === 'whale' ? '20000' : '5000';
    }
  };

  const executeAction = async () => {
    if (!amount && !getStrategyAmount()) return;

    setIsExecuting(true);
    const actualAmount = amount || getStrategyAmount();

    try {
      if (actionType === 'swap') {
        // Random swap direction
        const tokenIn = Math.random() > 0.5 ? 'TUSD' : 'TSAIL';
        const slippage = bot.strategy === 'conservative' ? 0.5 : 2;
        
        onAction(bot.id, 'swap', `Swapping ${actualAmount} ${tokenIn}...`);
        
        const result = await apiService.swapTokens(
          bot.privateKey,
          tokenIn,
          actualAmount,
          slippage
        );

        if (result.success) {
          onAction(
            bot.id,
            'swap',
            `Swapped ${actualAmount} ${tokenIn} → ${result.swap?.amountOutExpected} ${result.swap?.tokenOut}`,
            result.transactionHash
          );
        }
      } else {
        // Zap and stake
        const slippage = bot.strategy === 'conservative' ? 0.5 : 2;
        
        onAction(bot.id, 'zap_stake', `Zapping ${actualAmount} TUSD to ${vaultType}...`);
        
        const result = await apiService.zapAndStake(
          bot.privateKey,
          actualAmount,
          vaultType,
          slippage
        );

        if (result.success) {
          onAction(
            bot.id,
            'zap_stake',
            `Staked ${actualAmount} TUSD in ${vaultType} vault → ${result.steps?.liquidity.lpTokens} LP`,
            result.finalTransactionHash
          );
        }
      }
    } catch (error: any) {
      onAction(bot.id, actionType, `Failed: ${error.message}`);
    } finally {
      setIsExecuting(false);
      setAmount('');
    }
  };

  const executeRandomAction = async () => {
    const actions = ['swap', 'zap'] as const;
    const randomAction = actions[Math.floor(Math.random() * actions.length)];
    const vaults: VaultType[] = ['junior', 'senior', 'reserve'];
    const randomVault = vaults[Math.floor(Math.random() * vaults.length)];
    
    setActionType(randomAction);
    setVaultType(randomVault);
    
    setTimeout(() => executeAction(), 500);
  };

  return (
    <div className={`bot-card glass ${bot.type} ${isExecuting ? 'executing' : ''}`}>
      {/* Header */}
      <div className="bot-header" onClick={() => setIsExpanded(!isExpanded)}>
        <div className="bot-info">
          <div className="bot-icon">
            {bot.type === 'whale' ? '🐋' : '🌾'}
          </div>
          <div>
            <h3>{bot.name}</h3>
            <span className="bot-strategy">{bot.strategy}</span>
          </div>
        </div>
        <button className="expand-btn">
          {isExpanded ? '▼' : '▶'}
        </button>
      </div>

      {/* Address */}
      <div className="bot-address">
        <span className="label">Address:</span>
        <code className="address">{bot.address.slice(0, 6)}...{bot.address.slice(-4)}</code>
      </div>

      {/* Expanded Controls */}
      {isExpanded && (
        <div className="bot-controls">
          <div className="control-group">
            <label>Action Type</label>
            <div className="btn-group">
              <button
                className={`btn-small ${actionType === 'swap' ? 'active' : ''}`}
                onClick={() => setActionType('swap')}
                disabled={isExecuting}
              >
                Swap
              </button>
              <button
                className={`btn-small ${actionType === 'zap' ? 'active' : ''}`}
                onClick={() => setActionType('zap')}
                disabled={isExecuting}
              >
                Zap & Stake
              </button>
            </div>
          </div>

          {actionType === 'zap' && (
            <div className="control-group">
              <label>Vault</label>
              <select
                value={vaultType}
                onChange={(e) => setVaultType(e.target.value as VaultType)}
                disabled={isExecuting}
                className="select"
              >
                <option value="junior">Junior</option>
                <option value="senior">Senior</option>
                <option value="reserve">Reserve</option>
              </select>
            </div>
          )}

          <div className="control-group">
            <label>Amount (TUSD)</label>
            <input
              type="number"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder={`Default: ${getStrategyAmount()}`}
              disabled={isExecuting}
              className="input"
            />
          </div>

          <div className="actions">
            <button
              onClick={executeAction}
              disabled={isExecuting}
              className="btn-action primary"
            >
              {isExecuting ? '⏳ Executing...' : '🚀 Execute'}
            </button>
            <button
              onClick={executeRandomAction}
              disabled={isExecuting}
              className="btn-action secondary"
            >
              🎲 Random
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

