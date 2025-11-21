/**
 * TypeScript Analysis Tool for Rebase Simulations
 * Reads JSON files and generates comprehensive statistics
 */

import * as fs from 'fs';
import * as path from 'path';

interface PoolState {
  usdeReserve: string;
  sailReserve: string;
  sailPrice: string;
  lpTokenPrice: string;
  totalLPSupply: string;
}

interface SeniorState {
  lpAmount: string;
  value: string;
  supply: string;
  backingRatio: string;
  rebaseIndex: string;
  apy: number;
}

interface JuniorState {
  lpAmount: string;
  value: string;
  shares: string;
}

interface ReserveState {
  sailAmount: string;
  value: string;
  shares: string;
}

interface Transfers {
  spilloverToJunior: string;
  spilloverToReserve: string;
  backstopFromReserve: string;
  backstopFromJunior: string;
}

interface Snapshot {
  epoch: number;
  timestamp: number;
  zone: string;
  pool: PoolState;
  senior: SeniorState;
  junior: JuniorState;
  reserve: ReserveState;
  transfers: Transfers;
}

interface SimulationData {
  simulation: string;
  snapshots: Snapshot[];
}

class SimulationAnalyzer {
  private data: SimulationData;
  private scenarioName: string;

  constructor(data: SimulationData, scenarioName: string) {
    this.data = data;
    this.scenarioName = scenarioName;
  }

  analyze(): void {
    console.log('\n' + '='.repeat(80));
    console.log(`${this.scenarioName} - Analysis Report`);
    console.log('='.repeat(80));

    this.analyzePrices();
    this.analyzeBackingRatio();
    this.analyzeVaultValues();
    this.analyzeZoneDistribution();
    this.analyzeAPYSelection();
    this.analyzeTransfers();
    this.analyzeRebaseIndex();
  }

  private analyzePrices(): void {
    const snapshots = this.data.snapshots;
    const initialSail = parseFloat(snapshots[0].pool.sailPrice) / 1000;
    const finalSail = parseFloat(snapshots[snapshots.length - 1].pool.sailPrice) / 1000;
    const minSail = Math.min(...snapshots.map(s => parseFloat(s.pool.sailPrice) / 1000));
    const maxSail = Math.max(...snapshots.map(s => parseFloat(s.pool.sailPrice) / 1000));

    console.log('\n📊 SAIL Price Analysis:');
    console.log(`  Initial:  $${initialSail.toFixed(2)}`);
    console.log(`  Final:    $${finalSail.toFixed(2)}`);
    console.log(`  Min:      $${minSail.toFixed(2)}`);
    console.log(`  Max:      $${maxSail.toFixed(2)}`);
    console.log(`  Change:   ${((finalSail / initialSail - 1) * 100).toFixed(1)}%`);

    const initialLP = parseFloat(snapshots[0].pool.lpTokenPrice) / 1000;
    const finalLP = parseFloat(snapshots[snapshots.length - 1].pool.lpTokenPrice) / 1000;

    console.log('\n📊 LP Token Price Analysis:');
    console.log(`  Initial:  $${initialLP.toFixed(2)}`);
    console.log(`  Final:    $${finalLP.toFixed(2)}`);
    console.log(`  Change:   ${((finalLP / initialLP - 1) * 100).toFixed(1)}%`);
  }

  private analyzeBackingRatio(): void {
    const snapshots = this.data.snapshots;
    const ratios = snapshots.map(s => parseFloat(s.senior.backingRatio));
    
    const initial = ratios[0];
    const final = ratios[ratios.length - 1];
    const min = Math.min(...ratios);
    const max = Math.max(...ratios);
    const avg = ratios.reduce((a, b) => a + b, 0) / ratios.length;

    console.log('\n📊 Senior Backing Ratio:');
    console.log(`  Initial:  ${initial.toFixed(1)}%`);
    console.log(`  Final:    ${final.toFixed(1)}%`);
    console.log(`  Min:      ${min.toFixed(1)}%`);
    console.log(`  Max:      ${max.toFixed(1)}%`);
    console.log(`  Average:  ${avg.toFixed(1)}%`);
    console.log(`  Std Dev:  ${this.calculateStdDev(ratios).toFixed(1)}%`);
  }

  private analyzeVaultValues(): void {
    const snapshots = this.data.snapshots;
    const lastSnap = snapshots[snapshots.length - 1];

    const seniorValue = parseFloat(lastSnap.senior.value);
    const juniorValue = parseFloat(lastSnap.junior.value);
    const reserveValue = parseFloat(lastSnap.reserve.value);
    const totalValue = seniorValue + juniorValue + reserveValue;

    console.log('\n📊 Final Vault Values:');
    console.log(`  Senior:   $${seniorValue.toLocaleString()}`);
    console.log(`  Junior:   $${juniorValue.toLocaleString()}`);
    console.log(`  Reserve:  $${reserveValue.toLocaleString()}`);
    console.log(`  Total:    $${totalValue.toLocaleString()}`);

    console.log('\n📊 Vault Value Changes:');
    const seniorChange = ((seniorValue / parseFloat(snapshots[0].senior.value)) - 1) * 100;
    const juniorChange = ((juniorValue / parseFloat(snapshots[0].junior.value)) - 1) * 100;
    const reserveChange = ((reserveValue / parseFloat(snapshots[0].reserve.value)) - 1) * 100;

    console.log(`  Senior:   ${seniorChange >= 0 ? '+' : ''}${seniorChange.toFixed(1)}%`);
    console.log(`  Junior:   ${juniorChange >= 0 ? '+' : ''}${juniorChange.toFixed(1)}%`);
    console.log(`  Reserve:  ${reserveChange >= 0 ? '+' : ''}${reserveChange.toFixed(1)}%`);
  }

  private analyzeZoneDistribution(): void {
    const snapshots = this.data.snapshots;
    const zoneCounts: { [key: string]: number } = {};

    snapshots.forEach(s => {
      zoneCounts[s.zone] = (zoneCounts[s.zone] || 0) + 1;
    });

    const total = snapshots.length;

    console.log('\n📊 Zone Distribution:');
    Object.entries(zoneCounts)
      .sort((a, b) => b[1] - a[1])
      .forEach(([zone, count]) => {
        const pct = (count / total * 100).toFixed(1);
        console.log(`  ${zone.padEnd(12)} ${count} epochs (${pct}%)`);
      });
  }

  private analyzeAPYSelection(): void {
    const snapshots = this.data.snapshots.filter(s => s.senior.apy > 0); // Skip initial
    const apyCounts: { [key: number]: number } = {};

    snapshots.forEach(s => {
      apyCounts[s.senior.apy] = (apyCounts[s.senior.apy] || 0) + 1;
    });

    const apyMap: { [key: number]: string } = { 1: '11%', 2: '12%', 3: '13%' };
    const total = snapshots.length;

    console.log('\n📊 APY Selection Distribution:');
    Object.entries(apyCounts)
      .sort((a, b) => parseInt(b[0]) - parseInt(a[0]))
      .forEach(([apy, count]) => {
        const pct = (count / total * 100).toFixed(1);
        console.log(`  ${apyMap[parseInt(apy)].padEnd(5)} ${count} epochs (${pct}%)`);
      });
  }

  private analyzeTransfers(): void {
    const snapshots = this.data.snapshots;
    
    const totalSpilloverJunior = snapshots.reduce((sum, s) => 
      sum + parseFloat(s.transfers.spilloverToJunior), 0);
    const totalSpilloverReserve = snapshots.reduce((sum, s) => 
      sum + parseFloat(s.transfers.spilloverToReserve), 0);
    const totalBackstopReserve = snapshots.reduce((sum, s) => 
      sum + parseFloat(s.transfers.backstopFromReserve), 0);
    const totalBackstopJunior = snapshots.reduce((sum, s) => 
      sum + parseFloat(s.transfers.backstopFromJunior), 0);

    console.log('\n📊 Cumulative Spillovers:');
    console.log(`  To Junior:    $${totalSpilloverJunior.toLocaleString()}`);
    console.log(`  To Reserve:   $${totalSpilloverReserve.toLocaleString()}`);
    console.log(`  Total:        $${(totalSpilloverJunior + totalSpilloverReserve).toLocaleString()}`);

    console.log('\n📊 Cumulative Backstops:');
    console.log(`  From Reserve: $${totalBackstopReserve.toLocaleString()}`);
    console.log(`  From Junior:  $${totalBackstopJunior.toLocaleString()}`);
    console.log(`  Total:        $${(totalBackstopReserve + totalBackstopJunior).toLocaleString()}`);

    const netFlow = (totalSpilloverJunior + totalSpilloverReserve) - 
                    (totalBackstopReserve + totalBackstopJunior);
    console.log(`\n📊 Net Flow:    $${netFlow.toLocaleString()}`);
  }

  private analyzeRebaseIndex(): void {
    const snapshots = this.data.snapshots.filter(s => s.senior.apy > 0);
    const initialIndex = parseFloat(snapshots[0].senior.rebaseIndex) / 1000;
    const finalIndex = parseFloat(snapshots[snapshots.length - 1].senior.rebaseIndex) / 1000;

    const totalReturn = ((finalIndex / initialIndex) - 1) * 100;
    const avgMonthlyReturn = Math.pow(finalIndex / initialIndex, 1 / snapshots.length) - 1;
    const annualizedAPY = (Math.pow(1 + avgMonthlyReturn, 12) - 1) * 100;

    console.log('\n📊 Rebase Index Growth:');
    console.log(`  Initial:          ${initialIndex.toFixed(4)}`);
    console.log(`  Final:            ${finalIndex.toFixed(4)}`);
    console.log(`  Total Return:     ${totalReturn.toFixed(2)}%`);
    console.log(`  Avg Monthly:      ${(avgMonthlyReturn * 100).toFixed(2)}%`);
    console.log(`  Annualized APY:   ${annualizedAPY.toFixed(2)}%`);
  }

  private calculateStdDev(values: number[]): number {
    const avg = values.reduce((a, b) => a + b, 0) / values.length;
    const variance = values.reduce((sum, val) => sum + Math.pow(val - avg, 2), 0) / values.length;
    return Math.sqrt(variance);
  }

  generateCSV(): string {
    const snapshots = this.data.snapshots;
    const headers = [
      'epoch', 'timestamp', 'zone',
      'sail_price', 'lp_price', 'usde_reserve', 'sail_reserve',
      'senior_value', 'senior_supply', 'senior_backing', 'senior_index', 'senior_apy',
      'junior_value', 'junior_lp',
      'reserve_value', 'reserve_sail',
      'spillover_junior', 'spillover_reserve', 'backstop_reserve', 'backstop_junior'
    ];

    let csv = headers.join(',') + '\n';

    snapshots.forEach(s => {
      const row = [
        s.epoch,
        s.timestamp,
        s.zone,
        parseFloat(s.pool.sailPrice) / 1000,
        parseFloat(s.pool.lpTokenPrice) / 1000,
        s.pool.usdeReserve,
        s.pool.sailReserve,
        s.senior.value,
        s.senior.supply,
        s.senior.backingRatio,
        parseFloat(s.senior.rebaseIndex) / 1000,
        s.senior.apy,
        s.junior.value,
        s.junior.lpAmount,
        s.reserve.value,
        s.reserve.sailAmount,
        s.transfers.spilloverToJunior,
        s.transfers.spilloverToReserve,
        s.transfers.backstopFromReserve,
        s.transfers.backstopFromJunior
      ];
      csv += row.join(',') + '\n';
    });

    return csv;
  }
}

// Main execution
function main() {
  console.log('\n📊 Rebase Simulation Analysis Tool (TypeScript)');
  console.log('='.repeat(80));

  const scenarios = [
    { file: 'scenario1_bull_market.json', name: 'Scenario 1: Bull Market' },
    { file: 'scenario2_bear_market.json', name: 'Scenario 2: Bear Market' },
    { file: 'scenario3_volatile_market.json', name: 'Scenario 3: Volatile Market' },
    { file: 'scenario4_stable_market.json', name: 'Scenario 4: Stable Market' },
    { file: 'scenario5_flash_crash_recovery.json', name: 'Scenario 5: Flash Crash & Recovery' },
    { file: 'scenario6_slow_bleed_24m.json', name: 'Scenario 6: Slow Bleed (24 Months)' },
    { file: 'scenario7_parabolic_bull.json', name: 'Scenario 7: Parabolic Bull Run' },
  ];

  scenarios.forEach(({ file, name }) => {
    try {
      const filePath = path.join(__dirname, file);
      if (!fs.existsSync(filePath)) {
        console.log(`\n⚠️  File not found: ${file}`);
        return;
      }

      const data = JSON.parse(fs.readFileSync(filePath, 'utf-8')) as SimulationData;
      const analyzer = new SimulationAnalyzer(data, name);
      
      analyzer.analyze();
      
      // Generate CSV
      const csv = analyzer.generateCSV();
      const csvPath = filePath.replace('.json', '.csv');
      fs.writeFileSync(csvPath, csv);
      console.log(`\n✅ CSV exported: ${path.basename(csvPath)}`);
      
    } catch (error) {
      console.error(`\n❌ Error processing ${file}:`, error);
    }
  });

  console.log('\n' + '='.repeat(80));
  console.log('✅ Analysis complete!');
  console.log('='.repeat(80) + '\n');
}

// Run if executed directly
if (require.main === module) {
  main();
}

export { SimulationAnalyzer, SimulationData, Snapshot };


