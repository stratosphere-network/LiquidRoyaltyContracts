/**
 * Vault State Snapshots
 * Historical data for plotting graphs and tracking system evolution
 */

export interface VaultSnapshot {
  timestamp: string;
  blockNumber?: number;
  event: string;
  
  // Market prices
  sailPrice: number;
  lpPrice: number;
  
  // Senior Vault
  senior: {
    supply: number;
    lpTokens: number;
    onChainValue: number;
    offChainValue: number;
    backingRatio: number;
    offChainBackingRatio: number;
  };
  
  // Junior Vault
  junior: {
    supply: number;
    lpTokens: number;
    onChainValue: number;
    offChainValue: number;
    unstakingRatio: number;
  };
  
  // Reserve Vault
  reserve: {
    supply: number;
    lpTokens: number;
    onChainValue: number;
    offChainValue: number;
    unstakingRatio: number;
  };
  
  // Rebase metrics (for plotting)
  rebase?: {
    occurred: boolean;
    supplyBefore?: number;
    supplyAfter?: number;
    tokensPrinted?: number;
    percentageIncrease?: number;
    apyType?: '11%' | '12%' | '13%';
    backstopTriggered?: boolean;
    backstopAmount?: number;
    backstopSource?: 'reserve' | 'junior' | 'both' | 'none';
  };
  
  notes?: string;
}

export const vaultSnapshots: VaultSnapshot[] = [
  {
    timestamp: "2025-11-10T12:00:00.000Z",
    event: "Initial State (Before 100 USDE stake in Senior)",
    
    sailPrice: 10.04,
    lpPrice: 6.34,
    
    senior: {
      supply: 1629.69,
      lpTokens: 260.00,
      onChainValue: 1644.05,
      offChainValue: 1648.74,
      backingRatio: 100.88,
      offChainBackingRatio: 101.17,
    },
    
    junior: {
      supply: 100.00,
      lpTokens: 15.77,
      onChainValue: 99.77,
      offChainValue: 99.70,
      unstakingRatio: 0.999918,
    },
    
    reserve: {
      supply: 1000.00,
      lpTokens: 149.66,
      onChainValue: 948.62,
      offChainValue: 948.62,
      unstakingRatio: 0.948620,
    },
    
    notes: "System at equilibrium. Senior slightly overcollateralized at 100.88%. Junior and Reserve healthy."
  },
  
  {
    timestamp: "2025-11-10T12:15:00.000Z",
    event: "After 100 USDE stake in Senior",
    
    sailPrice: 10.04,
    lpPrice: 6.34,
    
    senior: {
      supply: 1729.69,
      lpTokens: 275.89,
      onChainValue: 1748.00,
      offChainValue: 1748.74, // estimated (275.89 * 6.34)
      backingRatio: 101.06, // 1748 / 1729.69
      offChainBackingRatio: 101.10, // estimated
    },
    
    junior: {
      supply: 100.00,
      lpTokens: 15.77,
      onChainValue: 99.77,
      offChainValue: 99.70,
      unstakingRatio: 0.999918,
    },
    
    reserve: {
      supply: 1000.00,
      lpTokens: 149.66,
      onChainValue: 948.62,
      offChainValue: 948.62,
      unstakingRatio: 0.948620,
    },
    
    notes: "Staked 100 USDE in Senior. Supply increased by 100 (+6.14%), LP tokens increased by 15.89 (+6.11%). Backing ratio improved from 100.88% to 101.06%."
  },
  
  {
    timestamp: "2025-11-10T12:30:00.000Z",
    event: "After 300k SAIL dump (Swapped SAIL → USDE)",
    
    sailPrice: 5.941762,
    lpPrice: 4.876852,
    
    senior: {
      supply: 1729.690745,
      lpTokens: 275.898985,
      onChainValue: 1648.73887,
      offChainValue: 1345.52,
      backingRatio: 95.32,
      offChainBackingRatio: 77.79,
    },
    
    junior: {
      supply: 200.081272,
      lpTokens: 31.494768,
      onChainValue: 99.701046,
      offChainValue: 153.60,
      unstakingRatio: 0.767665,
    },
    
    reserve: {
      supply: 1000.00,
      lpTokens: 149.668134,
      onChainValue: 946.70887,
      offChainValue: 729.91,
      unstakingRatio: 0.729909,
    },
    
    notes: "🚨 CRITICAL: 300k SAIL dump caused massive price impact! SAIL crashed -41% ($10.04 → $5.94), LP dropped -23% ($6.34 → $4.88). Senior backing ratio fell to 95.32% (BELOW 100% - DEPEGGED!). Off-chain backing at 77.79%. Junior supply doubled to 200.08 (+100%). Reserve value dropped -23% ($948.62 → $729.91). System now requires backstop to restore Senior to 100.9%!"
  },
  
  {
    timestamp: "2025-11-10T12:45:00.000Z",
    event: "After Rebase + Backstop (Reserve → Senior)",
    
    sailPrice: 5.941762,
    lpPrice: 4.876852,
    
    senior: {
      supply: 1746.181063,
      lpTokens: 361.441762,
      onChainValue: 1761.576717,
      offChainValue: 1762.70,
      backingRatio: 100.88,
      offChainBackingRatio: 100.95,
    },
    
    junior: {
      supply: 200.081272,
      lpTokens: 31.494768,
      onChainValue: 153.595324,
      offChainValue: 153.60,
      unstakingRatio: 0.767665,
    },
    
    reserve: {
      supply: 1000.00,
      lpTokens: 64.125357,
      onChainValue: 312.729876,
      offChainValue: 312.73,
      unstakingRatio: 0.312730,
    },
    
    // 📊 REBASE METRICS (FOR PLOTTING)
    rebase: {
      occurred: true,
      supplyBefore: 1729.690745,
      supplyAfter: 1746.181063,
      tokensPrinted: 16.490318,
      percentageIncrease: 0.9534, // 0.9534% rebase
      apyType: '11%', // Minimum APY used (system under stress)
      backstopTriggered: true,
      backstopAmount: 417.18, // ~$417 in LP tokens transferred
      backstopSource: 'reserve', // Reserve provided all backstop, Junior untouched
    },
    
    notes: "✅ BACKSTOP EXECUTED! Reserve provided massive backstop to restore Senior to peg. Senior backing restored from 95.32% to 100.88% (REPEGGED!). Senior supply rebased +16.49 snrUSD (1729.69 → 1746.18, +0.95% rebase). Senior received +85.54 LP tokens from Reserve (275.90 → 361.44, +31%). Reserve HEAVILY DEPLETED: LP tokens dropped -85.54 (149.67 → 64.13, -57%), value crashed from $729.91 to $312.73 (-$417.18 / -57%). Junior untouched (secondary backstop not needed). System successfully restored peg through Reserve sacrifice!"
  },
  
  {
    timestamp: "2025-11-10T13:00:00.000Z",
    event: "After 900k USDE → SAIL pump (Before 2nd rebase)",
    
    sailPrice: 7.406945,
    lpPrice: 5.445900,
    
    senior: {
      supply: 1746.181063,
      lpTokens: 361.441762,
      onChainValue: 1761.576717,
      offChainValue: 1968.38,
      backingRatio: 100.88,
      offChainBackingRatio: 112.72,
    },
    
    junior: {
      supply: 200.081272,
      lpTokens: 31.494768,
      onChainValue: 153.595324,
      offChainValue: 171.52,
      unstakingRatio: 0.857238,
    },
    
    reserve: {
      supply: 1000.00,
      lpTokens: 64.125357,
      onChainValue: 312.729876,
      offChainValue: 349.22,
      unstakingRatio: 0.349220,
    },
    
    notes: "🚀 RECOVERY PUMP! Swapped 900k USDE for SAIL to pump the market. SAIL recovered +24.7% ($5.94 → $7.41), LP recovered +11.7% ($4.88 → $5.45). Senior off-chain backing jumped from 100.95% to 112.72% (ABOVE 110% - PROFIT SPILLOVER ZONE!). Junior value increased $153.60 → $171.52 (+11.7%). Reserve value increased $312.73 → $349.22 (+11.7%). System now in Zone 1 (>110%) - should trigger profit spillover to Junior/Reserve on next rebase!"
  },
  
  {
    timestamp: "2025-11-10T13:15:00.000Z",
    event: "After 2nd 900k USDE → SAIL pump (Before 2nd rebase)",
    
    sailPrice: 9.033170,
    lpPrice: 6.014947,
    
    senior: {
      supply: 1746.181063,
      lpTokens: 361.441762,
      onChainValue: 1761.576717,
      offChainValue: 2174.05,
      backingRatio: 100.88,
      offChainBackingRatio: 124.50,
    },
    
    junior: {
      supply: 200.081272,
      lpTokens: 31.494768,
      onChainValue: 153.595324,
      offChainValue: 189.44,
      unstakingRatio: 0.946812,
    },
    
    reserve: {
      supply: 1000.00,
      lpTokens: 64.125357,
      onChainValue: 312.729876,
      offChainValue: 385.71,
      unstakingRatio: 0.385711,
    },
    
    notes: "🚀🚀 DOUBLE PUMP! Second 900k USDE → SAIL swap! SAIL surged another +21.9% ($7.41 → $9.03), LP +10.4% ($5.45 → $6.01). Senior off-chain backing now at 124.50% (MASSIVE EXCESS - 14.5% above threshold!). Senior off-chain TVL jumped $1,968 → $2,174 (+$206 / +10.5%). Junior $171.52 → $189.44 (+$17.92 / +10.4%). Reserve $349.22 → $385.71 (+$36.49 / +10.4%). System in deep Zone 1 - next rebase should distribute ~$253 in excess profits (80% to Junior, 20% to Reserve)!"
  },
  
  {
    timestamp: "2025-11-10T13:30:00.000Z",
    event: "After 2nd Rebase + PROFIT SPILLOVER (Senior → Junior/Reserve)",
    
    sailPrice: 9.033170,
    lpPrice: 6.014947,
    
    senior: {
      supply: 1765.854097,
      lpTokens: 323.167446,
      onChainValue: 1942.023347,
      offChainValue: 1943.84,
      backingRatio: 109.98,
      offChainBackingRatio: 110.08,
    },
    
    junior: {
      supply: 200.081272,
      lpTokens: 62.114222,
      onChainValue: 373.613752,
      offChainValue: 373.61,
      unstakingRatio: 1.867310,
    },
    
    reserve: {
      supply: 1000.00,
      lpTokens: 71.78022,
      onChainValue: 431.754222,
      offChainValue: 431.75,
      unstakingRatio: 0.431754,
    },
    
    // 📊 REBASE METRICS (FOR PLOTTING)
    rebase: {
      occurred: true,
      supplyBefore: 1746.181063,
      supplyAfter: 1765.854097,
      tokensPrinted: 19.673034,
      percentageIncrease: 1.126, // 1.126% rebase (likely 13% APY!)
      apyType: '13%', // Maximum APY (system healthy)
      backstopTriggered: false,
      backstopAmount: 0,
      backstopSource: 'none',
    },
    
    notes: "🎉 PROFIT SPILLOVER EXECUTED! Senior gave 38.27 LP tokens to Junior/Reserve. Senior backing reduced from 124.50% to 110.08% (TARGET ACHIEVED!). Senior supply rebased +19.67 snrUSD (1746.18 → 1765.85, +1.126% rebase - highest APY!). Junior RECEIVED +30.62 LP tokens (31.49 → 62.11, +97.2%), value jumped $189.44 → $373.61 (+$184.17 / +97.2%). Reserve RECEIVED +7.65 LP tokens (64.13 → 71.78, +11.9%), value jumped $385.71 → $431.75 (+$46.04 / +11.9%). Perfect 80/20 split verified! This is the OPPOSITE of backstop - Senior SHARED profits with Junior/Reserve!"
  }
];

/**
 * Helper function to add new snapshots
 */
export function addSnapshot(snapshot: VaultSnapshot): void {
  vaultSnapshots.push(snapshot);
  console.log(`📊 Snapshot recorded: ${snapshot.event}`);
}

/**
 * Helper function to get snapshots for a specific vault
 */
export function getVaultHistory(vaultType: 'senior' | 'junior' | 'reserve') {
  return vaultSnapshots.map(snapshot => ({
    timestamp: snapshot.timestamp,
    event: snapshot.event,
    ...snapshot[vaultType]
  }));
}

/**
 * Helper function to get backing ratio history
 */
export function getBackingRatioHistory() {
  return vaultSnapshots.map(snapshot => ({
    timestamp: snapshot.timestamp,
    event: snapshot.event,
    onChain: snapshot.senior.backingRatio,
    offChain: snapshot.senior.offChainBackingRatio
  }));
}

/**
 * Helper function to get price history
 */
export function getPriceHistory() {
  return vaultSnapshots.map(snapshot => ({
    timestamp: snapshot.timestamp,
    event: snapshot.event,
    sailPrice: snapshot.sailPrice,
    lpPrice: snapshot.lpPrice
  }));
}

/**
 * 📊 GET REBASE HISTORY FOR PLOTTING
 * Returns all rebase events with key metrics
 */
export function getRebaseHistory() {
  return vaultSnapshots
    .filter(snapshot => snapshot.rebase?.occurred)
    .map(snapshot => ({
      timestamp: snapshot.timestamp,
      event: snapshot.event,
      supplyBefore: snapshot.rebase!.supplyBefore,
      supplyAfter: snapshot.rebase!.supplyAfter,
      tokensPrinted: snapshot.rebase!.tokensPrinted,
      percentageIncrease: snapshot.rebase!.percentageIncrease,
      apyType: snapshot.rebase!.apyType,
      backstopTriggered: snapshot.rebase!.backstopTriggered,
      backstopAmount: snapshot.rebase!.backstopAmount,
      backstopSource: snapshot.rebase!.backstopSource,
    }));
}

/**
 * 📈 GET SUPPLY CHANGE PERCENTAGES FOR PLOTTING
 * Perfect for line/bar charts showing rebase impact
 */
export function getRebasePercentages() {
  return vaultSnapshots
    .filter(snapshot => snapshot.rebase?.occurred)
    .map(snapshot => ({
      timestamp: snapshot.timestamp,
      event: snapshot.event,
      percentageIncrease: snapshot.rebase!.percentageIncrease,
      apyType: snapshot.rebase!.apyType,
    }));
}

/**
 * 📊 GET BACKSTOP HISTORY FOR PLOTTING
 * Track when and how much backstop was provided
 */
export function getBackstopHistory() {
  return vaultSnapshots
    .filter(snapshot => snapshot.rebase?.backstopTriggered)
    .map(snapshot => ({
      timestamp: snapshot.timestamp,
      event: snapshot.event,
      backstopAmount: snapshot.rebase!.backstopAmount,
      backstopSource: snapshot.rebase!.backstopSource,
      seniorBackingBefore: vaultSnapshots[vaultSnapshots.indexOf(snapshot) - 1]?.senior.backingRatio,
      seniorBackingAfter: snapshot.senior.backingRatio,
    }));
}

/**
 * Export data as CSV for external analysis
 */
export function exportToCSV(): string {
  const headers = [
    'Timestamp',
    'Event',
    'SAIL Price',
    'LP Price',
    'SNR Supply',
    'SNR LP Tokens',
    'SNR OnChain Value',
    'SNR OffChain Value',
    'SNR Backing Ratio',
    'SNR OffChain Backing',
    'JNR Supply',
    'JNR LP Tokens',
    'JNR OnChain Value',
    'JNR OffChain Value',
    'JNR Unstaking Ratio',
    'RSV Supply',
    'RSV LP Tokens',
    'RSV OnChain Value',
    'RSV OffChain Value',
    'RSV Unstaking Ratio',
    'Rebase Occurred',
    'Tokens Printed',
    'Rebase %',
    'APY Type',
    'Backstop Triggered',
    'Backstop Amount',
    'Backstop Source',
    'Notes'
  ].join(',');
  
  const rows = vaultSnapshots.map(s => [
    s.timestamp,
    `"${s.event}"`,
    s.sailPrice,
    s.lpPrice,
    s.senior.supply,
    s.senior.lpTokens,
    s.senior.onChainValue,
    s.senior.offChainValue,
    s.senior.backingRatio,
    s.senior.offChainBackingRatio,
    s.junior.supply,
    s.junior.lpTokens,
    s.junior.onChainValue,
    s.junior.offChainValue,
    s.junior.unstakingRatio,
    s.reserve.supply,
    s.reserve.lpTokens,
    s.reserve.onChainValue,
    s.reserve.offChainValue,
    s.reserve.unstakingRatio,
    s.rebase?.occurred || false,
    s.rebase?.tokensPrinted || 0,
    s.rebase?.percentageIncrease || 0,
    s.rebase?.apyType || 'N/A',
    s.rebase?.backstopTriggered || false,
    s.rebase?.backstopAmount || 0,
    s.rebase?.backstopSource || 'none',
    `"${s.notes || ''}"`
  ].join(','));
  
  return [headers, ...rows].join('\n');
}

// ============================================
// 📊 PLOTTING DATA SUMMARY
// ============================================
// Use these helper functions to extract data for charts:
//
// 1. getRebaseHistory() - Full rebase data with all metrics
//    Perfect for: Timeline charts, rebase event markers
//
// 2. getRebasePercentages() - Just the % increases
//    Perfect for: Bar chart showing "How much Senior printed each rebase"
//    Example: 0.9534% on 2025-11-10 rebase
//
// 3. getBackstopHistory() - When/how much backstop provided
//    Perfect for: Backstop impact visualization, before/after backing ratios
//    Example: Reserve provided $417.18 to restore Senior from 95.32% to 100.88%
//
// 4. getBackingRatioHistory() - Senior backing over time
//    Perfect for: Line chart showing peg stability
//
// 5. getVaultHistory('senior'|'junior'|'reserve') - Per-vault metrics
//    Perfect for: TVL trends, supply changes, unstaking ratios
//
// 6. getPriceHistory() - SAIL & LP token prices
//    Perfect for: Price impact analysis (e.g., -41% SAIL dump)
//
// 7. exportToCSV() - Export everything for Excel/external tools
// ============================================

