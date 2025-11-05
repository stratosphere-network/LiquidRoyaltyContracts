import { useEffect, useRef } from 'react';
import type { Transaction } from '../types';
import './TransactionFeed.css';

interface TransactionFeedProps {
  transactions: Transaction[];
}

export const TransactionFeed = ({ transactions }: TransactionFeedProps) => {
  const feedRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (feedRef.current) {
      feedRef.current.scrollTop = feedRef.current.scrollHeight;
    }
  }, [transactions]);

  const getActionIcon = (action: string) => {
    switch (action) {
      case 'swap':
        return '🔄';
      case 'zap_stake':
        return '⚡';
      case 'add_liquidity':
        return '💧';
      case 'withdraw':
        return '💸';
      default:
        return '📝';
    }
  };

  const getActionLabel = (action: string) => {
    switch (action) {
      case 'swap':
        return 'Swap';
      case 'zap_stake':
        return 'Zap & Stake';
      case 'add_liquidity':
        return 'Add Liquidity';
      case 'withdraw':
        return 'Withdraw';
      default:
        return 'Action';
    }
  };

  const formatTime = (timestamp: number) => {
    const date = new Date(timestamp);
    return date.toLocaleTimeString('en-US', {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    });
  };

  return (
    <div className="transaction-feed">
      <div className="feed-header">
        <h2>
          <span className="pulse">📡</span> Transaction Feed
        </h2>
        <span className="tx-count">{transactions.length} transactions</span>
      </div>

      <div className="feed-content" ref={feedRef}>
        {transactions.length === 0 ? (
          <div className="empty-state">
            <div className="empty-icon">🤖</div>
            <p>No transactions yet</p>
            <span>Execute bot actions to see transactions here</span>
          </div>
        ) : (
          <div className="transactions">
            {transactions.map((tx) => (
              <div
                key={tx.id}
                className={`transaction-item glass ${tx.status}`}
              >
                <div className="tx-header">
                  <div className="tx-action">
                    <span className="action-icon">{getActionIcon(tx.action)}</span>
                    <span className="action-label">{getActionLabel(tx.action)}</span>
                  </div>
                  <span className="tx-time">{formatTime(tx.timestamp)}</span>
                </div>

                <div className="tx-bot">
                  <span className="bot-label">Bot:</span>
                  <span className="bot-name">{tx.botName}</span>
                </div>

                <div className="tx-details">{tx.details}</div>

                {tx.txHash && (
                  <div className="tx-hash">
                    <span className="hash-label">TX:</span>
                    <a
                      href={`https://polygonscan.com/tx/${tx.txHash}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="hash-link"
                    >
                      {tx.txHash.slice(0, 10)}...{tx.txHash.slice(-8)}
                    </a>
                  </div>
                )}

                <div className={`tx-status status-${tx.status}`}>
                  {tx.status === 'pending' && '⏳ Pending'}
                  {tx.status === 'success' && '✅ Success'}
                  {tx.status === 'failed' && '❌ Failed'}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

