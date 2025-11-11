import React from 'react';
import {
  LineChart,
  Line,
  BarChart,
  Bar,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
  ReferenceLine,
  Cell
} from 'recharts';
import { 
  vaultSnapshots, 
  getRebaseHistory, 
  getBackingRatioHistory,
  getPriceHistory,
  getVaultHistory,
} from '../data/vaultSnapshots';
import './HistoricalCharts.css';

export const HistoricalCharts: React.FC = () => {
  // Prepare data for charts
  const chartData = vaultSnapshots.map((snapshot, idx) => ({
    name: `#${idx + 1}`,
    fullName: snapshot.event,
    sailPrice: snapshot.sailPrice,
    lpPrice: snapshot.lpPrice,
    seniorBacking: snapshot.senior.backingRatio,
    seniorOffChainBacking: snapshot.senior.offChainBackingRatio,
    seniorTVL: snapshot.senior.offChainValue,
    juniorTVL: snapshot.junior.offChainValue,
    reserveTVL: snapshot.reserve.offChainValue,
    juniorUnstaking: snapshot.junior.unstakingRatio,
    reserveUnstaking: snapshot.reserve.unstakingRatio,
    isRebase: snapshot.rebase?.occurred || false,
    isBackstop: snapshot.rebase?.backstopTriggered || false,
    tokensP: snapshot.rebase?.tokensPrinted || 0,
    rebasePercent: snapshot.rebase?.percentageIncrease || 0,
  }));

  const rebaseData = vaultSnapshots
    .filter(s => s.rebase?.occurred)
    .map((snapshot, idx) => ({
      name: `Rebase ${idx + 1}`,
      tokens: snapshot.rebase?.tokensPrinted || 0,
      percent: snapshot.rebase?.percentageIncrease || 0,
      type: snapshot.rebase?.backstopTriggered ? 'Backstop' : 'Spillover',
      apy: snapshot.rebase?.apyType || '11%',
    }));

  // Custom tooltip
  const CustomTooltip = ({ active, payload, label }: any) => {
    if (active && payload && payload.length) {
      const data = payload[0].payload;
      return (
        <div className="custom-tooltip">
          <p className="tooltip-title">{data.fullName}</p>
          {payload.map((entry: any, index: number) => (
            <p key={index} style={{ color: entry.color }}>
              {entry.name}: {typeof entry.value === 'number' ? entry.value.toFixed(2) : entry.value}
            </p>
          ))}
        </div>
      );
    }
    return null;
  };

  // Get backing ratio colors
  const getBackingColor = (value: number) => {
    if (value < 100) return '#ef4444'; // Red - backstop zone
    if (value <= 110) return '#3b82f6'; // Blue - healthy zone
    return '#10b981'; // Green - spillover zone
  };

  return (
    <div className="historical-charts">
      <div className="charts-header">
        <h2>📊 System Performance Analysis</h2>
        <p className="subtitle">Complete journey through {vaultSnapshots.length} snapshots • 2 rebases executed</p>
      </div>

      {/* Price Journey Chart */}
      <div className="chart-card">
        <h3>💰 Token Price Impact</h3>
        <p className="chart-description">SAIL crashed -41% on dump, recovered +51% on pumps</p>
        <ResponsiveContainer width="100%" height={300}>
          <LineChart data={chartData} margin={{ top: 5, right: 30, left: 20, bottom: 5 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.1)" />
            <XAxis dataKey="name" stroke="#888" />
            <YAxis stroke="#888" />
            <Tooltip content={<CustomTooltip />} />
            <Legend />
            <Line 
              type="monotone" 
              dataKey="sailPrice" 
              stroke="#8b5cf6" 
              strokeWidth={3}
              name="SAIL Price ($)"
              dot={{ fill: '#8b5cf6', r: 5 }}
            />
            <Line 
              type="monotone" 
              dataKey="lpPrice" 
              stroke="#3b82f6" 
              strokeWidth={3}
              name="LP Price ($)"
              dot={{ fill: '#3b82f6', r: 5 }}
            />
          </LineChart>
        </ResponsiveContainer>
      </div>

      {/* Backing Ratio Chart */}
      <div className="chart-card">
        <h3>🎯 Senior Backing Ratio Journey (On-Chain)</h3>
        <p className="chart-description">Zone transitions: Healthy → Backstop (95%) → Recovered (101%) → Spillover (110%)</p>
        <ResponsiveContainer width="100%" height={350}>
          <BarChart data={chartData} margin={{ top: 20, right: 30, left: 20, bottom: 5 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.1)" />
            <XAxis dataKey="name" stroke="#888" />
            <YAxis stroke="#888" domain={[90, 115]} />
            <Tooltip content={<CustomTooltip />} />
            <Legend />
            <ReferenceLine y={100} stroke="#ef4444" strokeDasharray="3 3" label="100% (Peg)" />
            <ReferenceLine y={110} stroke="#10b981" strokeDasharray="3 3" label="110% (Target)" />
            <Bar dataKey="seniorBacking" name="On-Chain Backing (%)" radius={[8, 8, 0, 0]}>
              {chartData.map((entry, index) => (
                <Cell key={`cell-${index}`} fill={getBackingColor(entry.seniorBacking)} />
              ))}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
        <div className="zone-legend">
          <div className="zone-item">
            <div className="zone-color" style={{ background: '#ef4444' }}></div>
            <span>&lt; 100% - Backstop Zone</span>
          </div>
          <div className="zone-item">
            <div className="zone-color" style={{ background: '#3b82f6' }}></div>
            <span>100-110% - Healthy Zone</span>
          </div>
          <div className="zone-item">
            <div className="zone-color" style={{ background: '#10b981' }}></div>
            <span>&gt; 110% - Spillover Zone</span>
          </div>
        </div>
      </div>

      {/* TVL Changes Chart */}
      <div className="chart-card">
        <h3>💎 Vault TVL Evolution</h3>
        <p className="chart-description">Junior gained +274%, Reserve recovered from -67% loss</p>
        <ResponsiveContainer width="100%" height={300}>
          <AreaChart data={chartData} margin={{ top: 5, right: 30, left: 20, bottom: 5 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.1)" />
            <XAxis dataKey="name" stroke="#888" />
            <YAxis stroke="#888" />
            <Tooltip content={<CustomTooltip />} />
            <Legend />
            <Area 
              type="monotone" 
              dataKey="seniorTVL" 
              stackId="1"
              stroke="#8b5cf6" 
              fill="#8b5cf6"
              fillOpacity={0.6}
              name="Senior TVL ($)"
            />
            <Area 
              type="monotone" 
              dataKey="juniorTVL" 
              stackId="1"
              stroke="#10b981" 
              fill="#10b981"
              fillOpacity={0.6}
              name="Junior TVL ($)"
            />
            <Area 
              type="monotone" 
              dataKey="reserveTVL" 
              stackId="1"
              stroke="#f59e0b" 
              fill="#f59e0b"
              fillOpacity={0.6}
              name="Reserve TVL ($)"
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>

      {/* Rebase Comparison Chart */}
      <div className="chart-card">
        <h3>🔄 Rebase Events Comparison</h3>
        <p className="chart-description">First rebase: 11% APY + Backstop | Second rebase: 13% APY + Spillover</p>
        <ResponsiveContainer width="100%" height={300}>
          <BarChart data={rebaseData} margin={{ top: 20, right: 30, left: 20, bottom: 5 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.1)" />
            <XAxis dataKey="name" stroke="#888" />
            <YAxis stroke="#888" />
            <Tooltip content={<CustomTooltip />} />
            <Legend />
            <Bar dataKey="tokens" name="Tokens Printed" fill="#8b5cf6" radius={[8, 8, 0, 0]} />
            <Bar dataKey="percent" name="% Increase" fill="#3b82f6" radius={[8, 8, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </div>

      {/* Unstaking Ratios Chart */}
      <div className="chart-card">
        <h3>📊 Unstaking Ratios (Price per Token)</h3>
        <p className="chart-description">Junior: $0.77 → $1.87 (+143%) | Reserve: $0.31 → $0.43 (+39%)</p>
        <ResponsiveContainer width="100%" height={300}>
          <LineChart data={chartData} margin={{ top: 5, right: 30, left: 20, bottom: 5 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.1)" />
            <XAxis dataKey="name" stroke="#888" />
            <YAxis stroke="#888" />
            <Tooltip content={<CustomTooltip />} />
            <Legend />
            <Line 
              type="monotone" 
              dataKey="juniorUnstaking" 
              stroke="#10b981" 
              strokeWidth={3}
              name="Junior Unstaking Ratio"
              dot={{ fill: '#10b981', r: 6 }}
            />
            <Line 
              type="monotone" 
              dataKey="reserveUnstaking" 
              stroke="#f59e0b" 
              strokeWidth={3}
              name="Reserve Unstaking Ratio"
              dot={{ fill: '#f59e0b', r: 6 }}
            />
            <ReferenceLine y={1.0} stroke="#888" strokeDasharray="3 3" label="1:1 Peg" />
          </LineChart>
        </ResponsiveContainer>
      </div>

      {/* Summary Stats */}
      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-icon">💰</div>
          <div className="stat-content">
            <div className="stat-label">SAIL Price Journey</div>
            <div className="stat-value">${chartData[0].sailPrice.toFixed(2)} → ${chartData[chartData.length - 1].sailPrice.toFixed(2)}</div>
            <div className="stat-change negative">-10% overall (-41% → +51%)</div>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon">🎯</div>
          <div className="stat-content">
            <div className="stat-label">Senior Stability (On-Chain)</div>
            <div className="stat-value">{chartData[chartData.length - 1].seniorBacking.toFixed(2)}% Backing</div>
            <div className="stat-change positive">Target achieved</div>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon">🚀</div>
          <div className="stat-content">
            <div className="stat-label">Junior Performance</div>
            <div className="stat-value">+$273.84 TVL</div>
            <div className="stat-change positive">+274% ROI</div>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon">🛡️</div>
          <div className="stat-content">
            <div className="stat-label">Reserve Protection</div>
            <div className="stat-value">$417 Backstop</div>
            <div className="stat-change">System saved from depeg</div>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon">🔄</div>
          <div className="stat-content">
            <div className="stat-label">Rebases Executed</div>
            <div className="stat-value">2 Total</div>
            <div className="stat-change">1 Backstop • 1 Spillover</div>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon">📈</div>
          <div className="stat-content">
            <div className="stat-label">Senior Tokens Printed</div>
            <div className="stat-value">36.16 snrUSD</div>
            <div className="stat-change positive">+2.07% total</div>
          </div>
        </div>
      </div>
    </div>
  );
};
