import { useState, useEffect } from 'react';
import {
  LineChart,
  Line,
  AreaChart,
  Area,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
  ReferenceLine,
} from 'recharts';
import { TrendingUp, TrendingDown, DollarSign, Activity } from 'lucide-react';

interface PoolData {
  usdeReserve: number;
  sailReserve: number;
  sailPrice: number;
  lpTokenPrice: number;
  totalLPSupply: number;
}

interface VaultData {
  lpAmount?: number;
  value: number;
  supply?: number;
  backingRatio?: number;
  rebaseIndex?: number;
  apy?: number;
  shares?: number;
  sailAmount?: number;
}

interface TransferData {
  spilloverToJunior: number;
  spilloverToReserve: number;
  backstopFromReserve: number;
  backstopFromJunior: number;
}

interface Snapshot {
  epoch: number;
  timestamp: number;
  zone: string;
  pool: PoolData;
  senior: VaultData;
  junior: VaultData;
  reserve: VaultData;
  transfers: TransferData;
}

interface SimulationData {
  simulation: string;
  snapshots: Snapshot[];
}

const scenarios = [
  { id: 'scenario1_bull_market', name: '📈 Bull Market', color: '#10b981' },
  { id: 'scenario2_bear_market', name: '📉 Bear Market', color: '#ef4444' },
  { id: 'scenario3_volatile_market', name: '⚡ Volatile Market', color: '#f59e0b' },
  { id: 'scenario4_stable_market', name: '➡️ Stable Market', color: '#3b82f6' },
  { id: 'scenario5_flash_crash_recovery', name: '💥 Flash Crash', color: '#ec4899' },
  { id: 'scenario6_slow_bleed_24m', name: '🩸 Slow Bleed', color: '#8b5cf6' },
  { id: 'scenario7_parabolic_bull', name: '🚀 Strong Bull', color: '#14b8a6' },
  { id: 'scenario_complete_lifecycle', name: '🌍 Complete Lifecycle', color: '#06b6d4' },
  { id: 'scenario_bear_stress_test', name: '🔴 Bear Stress Test', color: '#dc2626' },
  { id: 'scenario_stable_yield', name: '💰 Stable Yield', color: '#8b5cf6' },
  { id: 'scenario_flash_crash', name: '⚡ Flash Crash', color: '#f97316' },
];

export function SimulationDashboard() {
  const [selectedScenario, setSelectedScenario] = useState(scenarios[0].id);
  const [simulationData, setSimulationData] = useState<SimulationData | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    loadScenario(selectedScenario);
  }, [selectedScenario]);

  const loadScenario = async (scenarioId: string) => {
    setLoading(true);
    try {
      const response = await fetch(`../simulation_output/${scenarioId}.json`);
      const data = await response.json();
      setSimulationData(data);
    } catch (error) {
      console.error('Error loading scenario:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading || !simulationData) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-purple-500 mx-auto mb-4"></div>
          <p className="text-gray-400">Loading simulation data...</p>
        </div>
      </div>
    );
  }

  const chartData = simulationData.snapshots.map((s) => ({
    epoch: s.epoch,
    sailPrice: s.pool.sailPrice / 1000, // Convert to dollars (stored with 3 decimals precision)
    lpPrice: s.pool.lpTokenPrice / 1000,
    seniorValue: s.senior.value / 1000000, // Convert to millions
    juniorValue: s.junior.value / 1000000,
    reserveValue: s.reserve.value / 1000000,
    backingRatio: s.senior.backingRatio,
    seniorAPY: s.senior.apy || 0,
    // Calculate unstaking ratios (value per share)
    juniorUnstakingRatio: s.junior.shares > 0 ? (s.junior.value / s.junior.shares) : 1,
    reserveUnstakingRatio: s.reserve.shares > 0 ? (s.reserve.value / s.reserve.shares) : 1,
    spilloverToJunior: s.transfers.spilloverToJunior / 1000,
    spilloverToReserve: s.transfers.spilloverToReserve / 1000,
    backstopFromReserve: s.transfers.backstopFromReserve / 1000,
    backstopFromJunior: s.transfers.backstopFromJunior / 1000,
    zone: s.zone,
    // Total spillovers and backstops for this epoch
    totalSpillover: (s.transfers.spilloverToJunior + s.transfers.spilloverToReserve) / 1000,
    totalBackstop: (s.transfers.backstopFromReserve + s.transfers.backstopFromJunior) / 1000,
  }));

  const initialValues = simulationData.snapshots[0];
  const finalValues = simulationData.snapshots[simulationData.snapshots.length - 1];

  const calculateROI = (initial: number, final: number) => {
    return ((final - initial) / initial * 100).toFixed(2);
  };

  const seniorROI = calculateROI(initialValues.senior.value, finalValues.senior.value);
  const juniorROI = calculateROI(initialValues.junior.value, finalValues.junior.value);
  const reserveROI = calculateROI(initialValues.reserve.value, finalValues.reserve.value);

  const totalSpillovers = simulationData.snapshots.reduce((sum, s) => 
    sum + s.transfers.spilloverToJunior + s.transfers.spilloverToReserve, 0
  );
  
  const totalBackstops = simulationData.snapshots.reduce((sum, s) => 
    sum + s.transfers.backstopFromReserve + s.transfers.backstopFromJunior, 0
  );

  return (
    <div className="space-y-6">
      {/* Scenario Selector */}
      <div className="bg-white/5 rounded-xl p-6 backdrop-blur-sm border border-white/10">
        <h2 className="text-xl font-bold text-white mb-4">Select Scenario</h2>
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-6 gap-3">
          {scenarios.map((scenario) => (
            <button
              key={scenario.id}
              onClick={() => setSelectedScenario(scenario.id)}
              className={`px-4 py-3 rounded-lg font-semibold transition-all text-sm ${
                selectedScenario === scenario.id
                  ? 'bg-purple-600 text-white shadow-lg shadow-purple-500/50'
                  : 'bg-white/5 text-gray-400 hover:bg-white/10'
              }`}
            >
              {scenario.name}
            </button>
          ))}
        </div>
      </div>

      {/* Key Metrics Overview */}
      <div className="bg-gradient-to-br from-purple-500/10 to-blue-500/10 rounded-xl p-6 backdrop-blur-sm border border-purple-500/30 mb-6">
        <h2 className="text-2xl font-bold text-white mb-4 flex items-center gap-2">
          <Activity className="w-6 h-6" />
          Simulation Key Metrics
        </h2>
        <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-4">
          <div>
            <div className="text-gray-400 text-xs mb-1">SAIL Price</div>
            <div className="text-xl font-bold text-orange-400">
              ${(finalValues.pool.sailPrice / 1000).toFixed(2)}
            </div>
            <div className="text-xs text-gray-500">
              {((finalValues.pool.sailPrice / initialValues.pool.sailPrice - 1) * 100).toFixed(1)}% change
            </div>
          </div>
          <div>
            <div className="text-gray-400 text-xs mb-1">LP Token Price</div>
            <div className="text-xl font-bold text-blue-400">
              ${(finalValues.pool.lpTokenPrice / 1000).toFixed(2)}
            </div>
            <div className="text-xs text-gray-500">
              {((finalValues.pool.lpTokenPrice / initialValues.pool.lpTokenPrice - 1) * 100).toFixed(1)}% change
            </div>
          </div>
          <div>
            <div className="text-gray-400 text-xs mb-1">Backing Ratio</div>
            <div className="text-xl font-bold text-green-400">
              {finalValues.senior.backingRatio}%
            </div>
            <div className="text-xs text-gray-500">
              {finalValues.senior.backingRatio >= 100 ? 'Healthy ✓' : 'Warning!'}
            </div>
          </div>
          <div>
            <div className="text-gray-400 text-xs mb-1">Total Spillovers</div>
            <div className="text-xl font-bold text-green-400">
              ${(totalSpillovers / 1000000).toFixed(2)}M
            </div>
            <div className="text-xs text-gray-500">
              {simulationData.snapshots.filter(s => s.transfers.spilloverToJunior > 0 || s.transfers.spilloverToReserve > 0).length} events
            </div>
          </div>
          <div>
            <div className="text-gray-400 text-xs mb-1">Total Backstops</div>
            <div className="text-xl font-bold text-red-400">
              ${(totalBackstops / 1000000).toFixed(2)}M
            </div>
            <div className="text-xs text-gray-500">
              {simulationData.snapshots.filter(s => s.transfers.backstopFromReserve > 0 || s.transfers.backstopFromJunior > 0).length} events
            </div>
          </div>
          <div>
            <div className="text-gray-400 text-xs mb-1">Reserve Health</div>
            <div className="text-xl font-bold text-purple-400">
              ${(finalValues.reserve.value / 1000000).toFixed(2)}M
            </div>
            <div className="text-xs text-gray-500">
              {finalValues.reserve.value > 0 ? 'Active' : 'Depleted'}
            </div>
          </div>
        </div>
      </div>

      {/* Summary Stats */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-gradient-to-br from-green-500/20 to-green-600/20 rounded-xl p-6 border border-green-500/30">
          <div className="flex items-center justify-between mb-2">
            <span className="text-gray-400 text-sm">Senior ROI</span>
            <TrendingUp className="w-5 h-5 text-green-400" />
          </div>
          <div className="text-3xl font-bold text-white">{seniorROI}%</div>
          <div className="text-sm text-gray-400 mt-1">
            ${(finalValues.senior.value / 1000000).toFixed(2)}M TVL
          </div>
        </div>

        <div className={`bg-gradient-to-br ${
          parseFloat(juniorROI) >= 0 ? 'from-blue-500/20 to-blue-600/20' : 'from-red-500/20 to-red-600/20'
        } rounded-xl p-6 border ${
          parseFloat(juniorROI) >= 0 ? 'border-blue-500/30' : 'border-red-500/30'
        }`}>
          <div className="flex items-center justify-between mb-2">
            <span className="text-gray-400 text-sm">Junior ROI</span>
            {parseFloat(juniorROI) >= 0 ? (
              <TrendingUp className="w-5 h-5 text-blue-400" />
            ) : (
              <TrendingDown className="w-5 h-5 text-red-400" />
            )}
          </div>
          <div className={`text-3xl font-bold ${parseFloat(juniorROI) >= 0 ? 'text-blue-400' : 'text-red-400'}`}>
            {juniorROI}%
          </div>
          <div className="text-sm text-gray-400 mt-1">
            ${(finalValues.junior.value / 1000000).toFixed(2)}M TVL
          </div>
          <div className="text-xs text-gray-500 mt-1">
            Unstaking: {(finalValues.junior.shares > 0 ? (finalValues.junior.value / finalValues.junior.shares).toFixed(4) : '1.0000')}
          </div>
        </div>

        <div className={`bg-gradient-to-br ${
          parseFloat(reserveROI) >= 0 ? 'from-purple-500/20 to-purple-600/20' : 'from-red-500/20 to-red-600/20'
        } rounded-xl p-6 border ${
          parseFloat(reserveROI) >= 0 ? 'border-purple-500/30' : 'border-red-500/30'
        }`}>
          <div className="flex items-center justify-between mb-2">
            <span className="text-gray-400 text-sm">Reserve ROI</span>
            {parseFloat(reserveROI) >= 0 ? (
              <TrendingUp className="w-5 h-5 text-purple-400" />
            ) : (
              <TrendingDown className="w-5 h-5 text-red-400" />
            )}
          </div>
          <div className={`text-3xl font-bold ${parseFloat(reserveROI) >= 0 ? 'text-purple-400' : 'text-red-400'}`}>
            {reserveROI}%
          </div>
          <div className="text-sm text-gray-400 mt-1">
            ${(finalValues.reserve.value / 1000000).toFixed(2)}M TVL
          </div>
          <div className="text-xs text-gray-500 mt-1">
            Unstaking: {(finalValues.reserve.shares > 0 ? (finalValues.reserve.value / finalValues.reserve.shares).toFixed(4) : '1.0000')}
          </div>
        </div>

        <div className="bg-gradient-to-br from-orange-500/20 to-orange-600/20 rounded-xl p-6 border border-orange-500/30">
          <div className="flex items-center justify-between mb-2">
            <span className="text-gray-400 text-sm">SAIL Price</span>
            <DollarSign className="w-5 h-5 text-orange-400" />
          </div>
          <div className="text-3xl font-bold text-white">
            ${(finalValues.pool.sailPrice / 1000).toFixed(2)}
          </div>
          <div className="text-sm text-gray-400 mt-1">
            {((finalValues.pool.sailPrice / initialValues.pool.sailPrice - 1) * 100).toFixed(1)}% change
          </div>
        </div>
      </div>

      {/* SAIL Price Chart */}
      <div className="bg-white/5 rounded-xl p-6 backdrop-blur-sm border border-white/10">
        <h3 className="text-lg font-bold text-white mb-4">⛵ SAIL Token Price</h3>
        <p className="text-sm text-gray-400 mb-3">Non-stablecoin price movement drives LP value changes</p>
        <ResponsiveContainer width="100%" height={300}>
          <AreaChart data={chartData}>
            <defs>
              <linearGradient id="colorSail" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#f59e0b" stopOpacity={0.8}/>
                <stop offset="95%" stopColor="#f59e0b" stopOpacity={0}/>
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#ffffff20" />
            <XAxis dataKey="epoch" stroke="#9ca3af" label={{ value: 'Epoch (Months)', position: 'insideBottom', offset: -5, fill: '#9ca3af' }} />
            <YAxis stroke="#9ca3af" label={{ value: 'SAIL Price (USD)', angle: -90, position: 'insideLeft', fill: '#9ca3af' }} />
            <Tooltip 
              contentStyle={{ backgroundColor: '#1f2937', border: '1px solid #374151', borderRadius: '8px' }}
              labelStyle={{ color: '#9ca3af' }}
              formatter={(value: number) => `$${value.toFixed(2)}`}
            />
            <Area type="monotone" dataKey="sailPrice" stroke="#f59e0b" strokeWidth={2} fillOpacity={1} fill="url(#colorSail)" />
          </AreaChart>
        </ResponsiveContainer>
      </div>

      {/* Vault Values Chart */}
      <div className="bg-white/5 rounded-xl p-6 backdrop-blur-sm border border-white/10">
        <h3 className="text-lg font-bold text-white mb-4">💰 Vault TVL Evolution</h3>
        <p className="text-sm text-gray-400 mb-3">Total Value Locked in each vault over time</p>
        <ResponsiveContainer width="100%" height={300}>
          <LineChart data={chartData}>
            <CartesianGrid strokeDasharray="3 3" stroke="#ffffff20" />
            <XAxis dataKey="epoch" stroke="#9ca3af" label={{ value: 'Epoch (Months)', position: 'insideBottom', offset: -5, fill: '#9ca3af' }} />
            <YAxis stroke="#9ca3af" label={{ value: 'TVL (Millions USD)', angle: -90, position: 'insideLeft', fill: '#9ca3af' }} />
            <Tooltip 
              contentStyle={{ backgroundColor: '#1f2937', border: '1px solid #374151', borderRadius: '8px' }}
              labelStyle={{ color: '#9ca3af' }}
              formatter={(value: number) => `$${value.toFixed(2)}M`}
            />
            <Legend />
            <Line type="monotone" dataKey="seniorValue" stroke="#10b981" name="Senior TVL" strokeWidth={3} dot={{ r: 4 }} />
            <Line type="monotone" dataKey="juniorValue" stroke="#3b82f6" name="Junior TVL" strokeWidth={3} dot={{ r: 4 }} />
            <Line type="monotone" dataKey="reserveValue" stroke="#8b5cf6" name="Reserve TVL" strokeWidth={3} dot={{ r: 4 }} />
          </LineChart>
        </ResponsiveContainer>
      </div>

      {/* LP Token Price Chart */}
      <div className="bg-white/5 rounded-xl p-6 backdrop-blur-sm border border-white/10">
        <h3 className="text-lg font-bold text-white mb-4">🪙 LP Token Price</h3>
        <p className="text-sm text-gray-400 mb-3">Calculated from pool reserves: (USDE + SAIL value) / LP supply</p>
        <ResponsiveContainer width="100%" height={300}>
          <AreaChart data={chartData}>
            <defs>
              <linearGradient id="colorLP" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.8}/>
                <stop offset="95%" stopColor="#3b82f6" stopOpacity={0}/>
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#ffffff20" />
            <XAxis dataKey="epoch" stroke="#9ca3af" label={{ value: 'Epoch (Months)', position: 'insideBottom', offset: -5, fill: '#9ca3af' }} />
            <YAxis stroke="#9ca3af" label={{ value: 'Price (USD)', angle: -90, position: 'insideLeft', fill: '#9ca3af' }} />
            <Tooltip 
              contentStyle={{ backgroundColor: '#1f2937', border: '1px solid #374151', borderRadius: '8px' }}
              labelStyle={{ color: '#9ca3af' }}
              formatter={(value: number) => `$${value.toFixed(2)}`}
            />
            <Area type="monotone" dataKey="lpPrice" stroke="#3b82f6" fillOpacity={1} fill="url(#colorLP)" />
          </AreaChart>
        </ResponsiveContainer>
      </div>

      {/* Backing Ratio Chart */}
      <div className="bg-white/5 rounded-xl p-6 backdrop-blur-sm border border-white/10">
        <h3 className="text-lg font-bold text-white mb-4">🛡️ Senior Backing Ratio</h3>
        <p className="text-sm text-gray-400 mb-3">Determines spillover (&gt;110%) or backstop (&lt;100%) actions</p>
        <ResponsiveContainer width="100%" height={300}>
          <AreaChart data={chartData}>
            <defs>
              <linearGradient id="colorBacking" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#10b981" stopOpacity={0.8}/>
                <stop offset="95%" stopColor="#10b981" stopOpacity={0}/>
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#ffffff20" />
            <XAxis dataKey="epoch" stroke="#9ca3af" label={{ value: 'Epoch (Months)', position: 'insideBottom', offset: -5, fill: '#9ca3af' }} />
            <YAxis stroke="#9ca3af" label={{ value: 'Backing Ratio (%)', angle: -90, position: 'insideLeft', fill: '#9ca3af' }} />
            <Tooltip 
              contentStyle={{ backgroundColor: '#1f2937', border: '1px solid #374151', borderRadius: '8px' }}
              labelStyle={{ color: '#9ca3af' }}
              formatter={(value: number) => `${value}%`}
            />
            <ReferenceLine y={100} stroke="#ef4444" strokeDasharray="3 3" strokeWidth={2} label={{ value: '100% (Min)', fill: '#ef4444', position: 'right' }} />
            <ReferenceLine y={110} stroke="#f59e0b" strokeDasharray="3 3" strokeWidth={2} label={{ value: '110% (Spillover)', fill: '#f59e0b', position: 'right' }} />
            <Area type="monotone" dataKey="backingRatio" stroke="#10b981" strokeWidth={3} fillOpacity={1} fill="url(#colorBacking)" />
          </AreaChart>
        </ResponsiveContainer>
      </div>

      {/* Senior APY Chart */}
      <div className="bg-white/5 rounded-xl p-6 backdrop-blur-sm border border-white/10">
        <h3 className="text-lg font-bold text-white mb-4">📈 Senior APY (Dynamic 11-13%)</h3>
        <p className="text-sm text-gray-400 mb-3">APY dynamically selected based on backing ratio each month</p>
        <ResponsiveContainer width="100%" height={300}>
          <BarChart data={simulationData.snapshots}>
            <CartesianGrid strokeDasharray="3 3" stroke="#ffffff20" />
            <XAxis dataKey="epoch" stroke="#9ca3af" label={{ value: 'Epoch (Months)', position: 'insideBottom', offset: -5, fill: '#9ca3af' }} />
            <YAxis stroke="#9ca3af" label={{ value: 'APY (%)', angle: -90, position: 'insideLeft', fill: '#9ca3af' }} domain={[0, 15]} />
            <Tooltip 
              contentStyle={{ backgroundColor: '#1f2937', border: '1px solid #374151', borderRadius: '8px' }}
              labelStyle={{ color: '#9ca3af' }}
              formatter={(value: number) => `${value}%`}
            />
            <Bar dataKey="senior.apy" fill="#10b981" name="Senior APY" />
          </BarChart>
        </ResponsiveContainer>
      </div>

      {/* Unstaking Ratios Chart */}
      <div className="bg-white/5 rounded-xl p-6 backdrop-blur-sm border border-white/10">
        <h3 className="text-lg font-bold text-white mb-4">📊 Unstaking Ratios (Junior & Reserve)</h3>
        <p className="text-sm text-gray-400 mb-3">Value per share - shows if vaults gained or lost value</p>
        <ResponsiveContainer width="100%" height={300}>
          <LineChart data={chartData}>
            <CartesianGrid strokeDasharray="3 3" stroke="#ffffff20" />
            <XAxis dataKey="epoch" stroke="#9ca3af" label={{ value: 'Epoch (Months)', position: 'insideBottom', offset: -5, fill: '#9ca3af' }} />
            <YAxis stroke="#9ca3af" label={{ value: 'Ratio (USD per share)', angle: -90, position: 'insideLeft', fill: '#9ca3af' }} />
            <Tooltip 
              contentStyle={{ backgroundColor: '#1f2937', border: '1px solid #374151', borderRadius: '8px' }}
              labelStyle={{ color: '#9ca3af' }}
              formatter={(value: number) => `${value.toFixed(4)} USD`}
            />
            <Legend />
            <ReferenceLine y={1} stroke="#9ca3af" strokeDasharray="3 3" label={{ value: '1.0 (Par)', fill: '#9ca3af' }} />
            <Line type="monotone" dataKey="juniorUnstakingRatio" stroke="#3b82f6" name="Junior Ratio" strokeWidth={3} dot={{ r: 4 }} />
            <Line type="monotone" dataKey="reserveUnstakingRatio" stroke="#8b5cf6" name="Reserve Ratio" strokeWidth={3} dot={{ r: 4 }} />
          </LineChart>
        </ResponsiveContainer>
      </div>

      {/* Spillover & Backstop Events */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-white/5 rounded-xl p-6 backdrop-blur-sm border border-white/10">
          <h3 className="text-lg font-bold text-white mb-4">💰 Spillover Events (Profit Distribution)</h3>
          <p className="text-sm text-gray-400 mb-3">When backing ratio &gt; 110%, excess profits flow to Junior (80%) and Reserve (20%)</p>
          <ResponsiveContainer width="100%" height={250}>
            <BarChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#ffffff20" />
              <XAxis dataKey="epoch" stroke="#9ca3af" label={{ value: 'Epoch', position: 'insideBottom', offset: -5 }} />
              <YAxis stroke="#9ca3af" label={{ value: 'Amount (K USD)', angle: -90, position: 'insideLeft', fill: '#9ca3af' }} />
              <Tooltip 
                contentStyle={{ backgroundColor: '#1f2937', border: '1px solid #374151', borderRadius: '8px' }}
                labelStyle={{ color: '#9ca3af' }}
                formatter={(value: number) => `$${value.toFixed(2)}K`}
              />
              <Legend />
              <Bar dataKey="spilloverToJunior" fill="#3b82f6" name="To Junior (80%)" />
              <Bar dataKey="spilloverToReserve" fill="#8b5cf6" name="To Reserve (20%)" />
            </BarChart>
          </ResponsiveContainer>
          <div className="mt-4 text-center">
            <div className="text-2xl font-bold text-green-400">
              ${(totalSpillovers / 1000000).toFixed(2)}M
            </div>
            <div className="text-sm text-gray-400">Total Profit Distributed</div>
            <div className="text-xs text-gray-500 mt-1">
              {simulationData.snapshots.filter(s => s.transfers.spilloverToJunior > 0 || s.transfers.spilloverToReserve > 0).length} spillover events
            </div>
          </div>
        </div>

        <div className="bg-white/5 rounded-xl p-6 backdrop-blur-sm border border-white/10">
          <h3 className="text-lg font-bold text-white mb-4">🛡️ Backstop Events (Protection Activated)</h3>
          <p className="text-sm text-gray-400 mb-3">When backing ratio &lt; 100%, Reserve (primary) and Junior (secondary) protect Senior</p>
          <ResponsiveContainer width="100%" height={250}>
            <BarChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#ffffff20" />
              <XAxis dataKey="epoch" stroke="#9ca3af" label={{ value: 'Epoch', position: 'insideBottom', offset: -5 }} />
              <YAxis stroke="#9ca3af" label={{ value: 'Amount (K USD)', angle: -90, position: 'insideLeft', fill: '#9ca3af' }} />
              <Tooltip 
                contentStyle={{ backgroundColor: '#1f2937', border: '1px solid #374151', borderRadius: '8px' }}
                labelStyle={{ color: '#9ca3af' }}
                formatter={(value: number) => `$${value.toFixed(2)}K`}
              />
              <Legend />
              <Bar dataKey="backstopFromReserve" fill="#8b5cf6" name="From Reserve (Primary)" />
              <Bar dataKey="backstopFromJunior" fill="#3b82f6" name="From Junior (Secondary)" />
            </BarChart>
          </ResponsiveContainer>
          <div className="mt-4 text-center">
            <div className="text-2xl font-bold text-red-400">
              ${(totalBackstops / 1000000).toFixed(2)}M
            </div>
            <div className="text-sm text-gray-400">Total Protection Provided</div>
            <div className="text-xs text-gray-500 mt-1">
              {simulationData.snapshots.filter(s => s.transfers.backstopFromReserve > 0 || s.transfers.backstopFromJunior > 0).length} backstop events
            </div>
          </div>
        </div>
      </div>

      {/* Zone Distribution */}
      <div className="bg-white/5 rounded-xl p-6 backdrop-blur-sm border border-white/10">
        <h3 className="text-lg font-bold text-white mb-4">
          <Activity className="w-5 h-5 inline mr-2" />
          Protocol Zone Activity
        </h3>
        <div className="grid grid-cols-3 gap-4">
          <div className="bg-green-500/20 rounded-lg p-4 border border-green-500/30">
            <div className="text-green-400 text-sm font-semibold mb-1">SPILLOVER ZONE</div>
            <div className="text-2xl font-bold text-white">
              {chartData.filter(d => d.zone === 'SPILLOVER').length}
            </div>
            <div className="text-xs text-gray-400 mt-1">&gt;110% backing</div>
          </div>
          
          <div className="bg-blue-500/20 rounded-lg p-4 border border-blue-500/30">
            <div className="text-blue-400 text-sm font-semibold mb-1">HEALTHY ZONE</div>
            <div className="text-2xl font-bold text-white">
              {chartData.filter(d => d.zone === 'HEALTHY').length}
            </div>
            <div className="text-xs text-gray-400 mt-1">100-110% backing</div>
          </div>
          
          <div className="bg-red-500/20 rounded-lg p-4 border border-red-500/30">
            <div className="text-red-400 text-sm font-semibold mb-1">BACKSTOP ZONE</div>
            <div className="text-2xl font-bold text-white">
              {chartData.filter(d => d.zone === 'BACKSTOP').length}
            </div>
            <div className="text-xs text-gray-400 mt-1">&lt;100% backing</div>
          </div>
        </div>
      </div>

      {/* Detailed Monthly Metrics Table */}
      <div className="bg-white/5 rounded-xl p-6 backdrop-blur-sm border border-white/10">
        <h3 className="text-lg font-bold text-white mb-4">
          📋 Monthly Metrics Breakdown
        </h3>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="border-b border-white/10">
              <tr className="text-gray-400">
                <th className="text-left p-2">Epoch</th>
                <th className="text-right p-2">SAIL Price</th>
                <th className="text-right p-2">LP Price</th>
                <th className="text-right p-2">Senior APY</th>
                <th className="text-right p-2">Backing %</th>
                <th className="text-right p-2">Senior TVL</th>
                <th className="text-right p-2">Junior TVL</th>
                <th className="text-right p-2">Junior Ratio</th>
                <th className="text-right p-2">Reserve TVL</th>
                <th className="text-right p-2">Reserve Ratio</th>
                <th className="text-center p-2">Zone</th>
              </tr>
            </thead>
            <tbody>
              {simulationData.snapshots.map((snapshot, idx) => {
                const juniorRatio = snapshot.junior.shares > 0 ? (snapshot.junior.value / snapshot.junior.shares).toFixed(4) : '1.0000';
                const reserveRatio = snapshot.reserve.shares > 0 ? (snapshot.reserve.value / snapshot.reserve.shares).toFixed(4) : '1.0000';
                const zoneColor = snapshot.zone === 'SPILLOVER' ? 'text-green-400' : snapshot.zone === 'BACKSTOP' ? 'text-red-400' : 'text-blue-400';
                
                return (
                  <tr key={idx} className="border-b border-white/5 hover:bg-white/5">
                    <td className="p-2 text-white font-semibold">{snapshot.epoch}</td>
                    <td className="p-2 text-right text-orange-400">${(snapshot.pool.sailPrice / 1000).toFixed(2)}</td>
                    <td className="p-2 text-right text-blue-400">${(snapshot.pool.lpTokenPrice / 1000).toFixed(2)}</td>
                    <td className="p-2 text-right text-green-400">{snapshot.senior.apy || 0}%</td>
                    <td className="p-2 text-right text-white">{snapshot.senior.backingRatio}%</td>
                    <td className="p-2 text-right text-green-300">${(snapshot.senior.value / 1000000).toFixed(2)}M</td>
                    <td className="p-2 text-right text-blue-300">${(snapshot.junior.value / 1000000).toFixed(2)}M</td>
                    <td className="p-2 text-right text-blue-400">{juniorRatio}</td>
                    <td className="p-2 text-right text-purple-300">${(snapshot.reserve.value / 1000000).toFixed(2)}M</td>
                    <td className="p-2 text-right text-purple-400">{reserveRatio}</td>
                    <td className={`p-2 text-center text-xs font-semibold ${zoneColor}`}>{snapshot.zone}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

