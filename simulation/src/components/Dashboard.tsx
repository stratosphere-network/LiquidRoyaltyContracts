import { useState, useEffect } from 'react';
import { apiService } from '../services/api';
import './Dashboard.css';

export function Dashboard() {
  const [data, setData] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchData = async () => {
    try {
      setLoading(true);
      setError(null);

      // Fetch data with delays to avoid rate limiting
      const tokenPrices = await apiService.getTokenPrices().catch((err) => {
        console.error('Failed to fetch token prices:', err);
        return { sail: 0, usde: 1, lp: 0 };
      });
      await new Promise(r => setTimeout(r, 500));
      
      const poolData = await apiService.getPoolData().catch(() => ({ sailReserve: 0, usdeReserve: 0 }));
      await new Promise(r => setTimeout(r, 500));
      
      const vaultsSupplyRes = await apiService.getVaultsSupply().catch(() => ({ 
        data: {
          seniorVault: { totalSupply: '0' },
          juniorVault: { totalSupply: '0' },
          reserveVault: { totalSupply: '0' }
        }
      }));
      await new Promise(r => setTimeout(r, 500));
      
      const vaultsValueRes = await apiService.getVaultsValueInUSD().catch(() => ({
        data: {
          seniorVault: { totalAssets: '0', valueUSD: '0' },
          juniorVault: { totalAssets: '0', valueUSD: '0' },
          reserveVault: { totalAssets: '0', valueUSD: '0' }
        }
      }));
      await new Promise(r => setTimeout(r, 500));
      
      const vaultsLPHoldingsRes = await apiService.getVaultsLPHoldings().catch(() => ({
        data: {
          seniorVault: { lpTokens: '0', valueUSD: '0' },
          juniorVault: { lpTokens: '0', valueUSD: '0' },
          reserveVault: { lpTokens: '0', valueUSD: '0' }
        }
      }));
      await new Promise(r => setTimeout(r, 500));
      
      const vaultsOnChainRes = await apiService.getVaultsOnChainValue().catch(() => ({
        data: {
          seniorVault: { vaultValue: '0' },
          juniorVault: { vaultValue: '0' },
          reserveVault: { vaultValue: '0' }
        }
      }));
      await new Promise(r => setTimeout(r, 500));
      
      const seniorBackingRes = await apiService.getSeniorBackingRatio().catch(() => ({ data: { backingRatio: 0 } }));
      await new Promise(r => setTimeout(r, 500));
      
      const projectedBackingRes = await apiService.getProjectedSeniorBackingRatio().catch(() => ({ data: { projectedBackingRatio: 0 } }));
      await new Promise(r => setTimeout(r, 500));
      
      const juniorPriceRes = await apiService.getJuniorTokenPrice().catch(() => ({ data: { juniorVault: { tokenPrice: '0' } } }));
      await new Promise(r => setTimeout(r, 500));
      
      const reservePriceRes = await apiService.getReserveTokenPrice().catch(() => ({ data: { price: 0 } }));
      await new Promise(r => setTimeout(r, 500));
      
      const rebaseConfigRes = await apiService.getRebaseConfig().catch(() => ({ data: {} }));

      // Calculate pool composition
      const totalPoolValue = poolData.sailReserve * tokenPrices.sail + poolData.usdeReserve * tokenPrices.usde;
      const sailPoolValue = poolData.sailReserve * tokenPrices.sail;
      const usdePoolValue = poolData.usdeReserve * tokenPrices.usde;

      setData({
        tokenPrices,
        poolData,
        poolComposition: {
          sail: poolData.sailReserve.toLocaleString(undefined, { maximumFractionDigits: 2 }),
          usde: poolData.usdeReserve.toLocaleString(undefined, { maximumFractionDigits: 2 }),
          sailPercent: totalPoolValue > 0 ? (sailPoolValue / totalPoolValue) * 100 : 50,
          usdePercent: totalPoolValue > 0 ? (usdePoolValue / totalPoolValue) * 100 : 50
        },
        vaults: {
          supply: vaultsSupplyRes.data,
          value: vaultsValueRes.data,
          lpHoldings: vaultsLPHoldingsRes.data,
          onChainValue: vaultsOnChainRes.data
        },
        seniorBacking: seniorBackingRes.data,
        projectedBacking: projectedBackingRes.data,
        juniorPrice: juniorPriceRes.data,
        reservePrice: reservePriceRes.data,
        rebaseConfig: rebaseConfigRes.data
      });
    } catch (err: any) {
      console.error('Error fetching dashboard data:', err);
      setError(err.message || 'Failed to fetch data');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  if (loading) {
    return (
      <div className="dashboard">
        <div className="loading">Loading dashboard data... (this may take ~5 seconds)</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="dashboard">
        <div className="error">Error: {error}</div>
        <button onClick={fetchData} className="refresh-btn">Retry</button>
      </div>
    );
  }

  if (!data) {
    return (
      <div className="dashboard">
        <div className="error">No data available</div>
        <button onClick={fetchData} className="refresh-btn">Refresh</button>
      </div>
    );
  }

  // Safety check
  if (!data.tokenPrices || !data.vaults) {
    return (
      <div className="dashboard">
        <div className="error">Backend is offline. Please start the backend server.</div>
        <button onClick={fetchData} className="refresh-btn">Retry</button>
      </div>
    );
  }

  const fmt = (val: any) => parseFloat(val || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 6 });
  const pct = (val: number) => val.toFixed(2) + '%';

  // Calculate composition percentages
  const calcComposition = (stablecoinVal: number, lpVal: number) => {
    const total = stablecoinVal + lpVal;
    if (total === 0) return { stablePercent: 0, lpPercent: 0 };
    return {
      stablePercent: (stablecoinVal / total) * 100,
      lpPercent: (lpVal / total) * 100
    };
  };

  const seniorComp = calcComposition(
    parseFloat(data.vaults?.value?.seniorVault?.valueUSD || 0),
    parseFloat(data.vaults?.lpHoldings?.seniorVault?.valueUSD || 0)
  );
  const juniorComp = calcComposition(
    parseFloat(data.vaults?.value?.juniorVault?.valueUSD || 0),
    parseFloat(data.vaults?.lpHoldings?.juniorVault?.valueUSD || 0)
  );
  const reserveComp = calcComposition(
    parseFloat(data.vaults?.value?.reserveVault?.valueUSD || 0),
    parseFloat(data.vaults?.lpHoldings?.reserveVault?.valueUSD || 0)
  );

  // Calculate TVL (now using totalValueUSD which includes stablecoin + LP value)
  const seniorTVL = parseFloat(data.vaults?.value?.seniorVault?.totalValueUSD || 0);
  const juniorTVL = parseFloat(data.vaults?.value?.juniorVault?.totalValueUSD || 0);
  const reserveTVL = parseFloat(data.vaults?.value?.reserveVault?.totalValueUSD || 0);

  return (
    <div className="dashboard">
      <div className="dashboard-header">
        <h1>Liquid Royalty Protocol</h1>
        <button onClick={fetchData} className="refresh-btn">🔄 Refresh</button>
      </div>

      {/* Token Prices */}
      <div className="section">
        <h2>Token Prices</h2>
        <div className="cards">
          <div className="card">
            <div className="card-label">SAIL Price</div>
            <div className="card-value">${(data.tokenPrices?.sail || 0).toFixed(6)}</div>
          </div>
          <div className="card">
            <div className="card-label">LP Token Price</div>
            <div className="card-value">${(data.tokenPrices?.lp || 0).toFixed(6)}</div>
          </div>
        </div>
      </div>

      {/* Pool Composition */}
      <div className="section">
        <h2>Pool Composition (SAIL/USDe)</h2>
        <div className="cards">
          <div className="card">
            <div className="card-label">SAIL</div>
            <div className="card-value">{data.poolComposition.sail}</div>
            <div className="card-sublabel">{pct(data.poolComposition.sailPercent)} of pool</div>
          </div>
          <div className="card">
            <div className="card-label">USDe</div>
            <div className="card-value">{data.poolComposition.usde}</div>
            <div className="card-sublabel">{pct(data.poolComposition.usdePercent)} of pool</div>
          </div>
        </div>
      </div>

      {/* Senior Vault */}
      <div className="section vault-section">
        <h2>Senior Vault (snrUSD)</h2>
        <div className="cards">
          <div className="card">
            <div className="card-label">Supply</div>
            <div className="card-value">{fmt(data.vaults?.supply?.seniorVault?.totalSupply)}</div>
          </div>
          <div className="card">
            <div className="card-label">TVL</div>
            <div className="card-value">${fmt(seniorTVL)}</div>
          </div>
          <div className="card highlight">
            <div className="card-label">Backing Ratio (On-chain)</div>
            <div className="card-value">{pct(data.seniorBacking?.backingRatio || 0)}</div>
            <div className="card-sublabel">On-chain value / Supply</div>
          </div>
          <div className="card highlight">
            <div className="card-label">Projected Backing (Off-chain)</div>
            <div className="card-value">{pct(data.projectedBacking?.projectedBackingRatio || 0)}</div>
            <div className="card-sublabel">Calculated value / Supply</div>
          </div>
        </div>
        
        <h3>Composition</h3>
        <div className="cards">
          <div className="card">
            <div className="card-label">USDe Balance</div>
            <div className="card-value">${fmt(data.vaults?.value?.seniorVault?.valueUSD)}</div>
            <div className="card-sublabel">{pct(seniorComp.stablePercent)} of TVL</div>
          </div>
          <div className="card">
            <div className="card-label">LP Tokens</div>
            <div className="card-value">{fmt(data.vaults?.lpHoldings?.seniorVault?.lpTokens)}</div>
            <div className="card-sublabel">{pct(seniorComp.lpPercent)} of TVL (${fmt(data.vaults?.lpHoldings?.seniorVault?.valueUSD)})</div>
          </div>
        </div>

        <h3>Values</h3>
        <div className="cards">
          <div className="card">
            <div className="card-label">On-chain Value</div>
            <div className="card-value">${fmt(data.vaults?.onChainValue?.seniorVault?.vaultValue)}</div>
          </div>
          <div className="card">
            <div className="card-label">Calculated Value</div>
            <div className="card-value">${fmt(seniorTVL)}</div>
          </div>
        </div>
      </div>

      {/* Junior Vault */}
      <div className="section vault-section">
        <h2>Junior Vault (jnrUSD)</h2>
        <div className="cards">
          <div className="card">
            <div className="card-label">Supply</div>
            <div className="card-value">{fmt(data.vaults?.supply?.juniorVault.totalSupply)}</div>
          </div>
          <div className="card">
            <div className="card-label">TVL</div>
            <div className="card-value">${fmt(juniorTVL)}</div>
          </div>
          <div className="card highlight">
            <div className="card-label">Unstaking Ratio (Price)</div>
            <div className="card-value">${(Number(data.juniorPrice?.juniorVault?.tokenPrice) || 0).toFixed(6)}</div>
            <div className="card-sublabel">Calculated value / Supply</div>
          </div>
        </div>
        
        <h3>Composition</h3>
        <div className="cards">
          <div className="card">
            <div className="card-label">USDe Balance</div>
            <div className="card-value">${fmt(data.vaults?.value?.juniorVault.valueUSD)}</div>
            <div className="card-sublabel">{pct(juniorComp.stablePercent)} of TVL</div>
          </div>
          <div className="card">
            <div className="card-label">LP Tokens</div>
            <div className="card-value">{fmt(data.vaults?.lpHoldings?.juniorVault.lpTokens)}</div>
            <div className="card-sublabel">{pct(juniorComp.lpPercent)} of TVL (${fmt(data.vaults?.lpHoldings?.juniorVault.valueUSD)})</div>
          </div>
        </div>

        <h3>Values</h3>
        <div className="cards">
          <div className="card">
            <div className="card-label">On-chain Value</div>
            <div className="card-value">${fmt(data.vaults?.onChainValue?.juniorVault.vaultValue)}</div>
          </div>
          <div className="card">
            <div className="card-label">Calculated Value</div>
            <div className="card-value">${fmt(juniorTVL)}</div>
          </div>
        </div>
      </div>

      {/* Reserve Vault */}
      <div className="section vault-section">
        <h2>Reserve Vault (resUSD)</h2>
        <div className="cards">
          <div className="card">
            <div className="card-label">Supply</div>
            <div className="card-value">{fmt(data.vaults?.supply?.reserveVault.totalSupply)}</div>
          </div>
          <div className="card">
            <div className="card-label">TVL</div>
            <div className="card-value">${fmt(reserveTVL)}</div>
          </div>
          <div className="card highlight">
            <div className="card-label">Unstaking Ratio (Price)</div>
            <div className="card-value">${(Number(data.reservePrice?.reserveVault?.tokenPrice || data.reservePrice?.price) || 0).toFixed(6)}</div>
            <div className="card-sublabel">Calculated value / Supply</div>
          </div>
        </div>
        
        <h3>Composition</h3>
        <div className="cards">
          <div className="card">
            <div className="card-label">USDe Balance</div>
            <div className="card-value">${fmt(data.vaults?.value?.reserveVault.valueUSD)}</div>
            <div className="card-sublabel">{pct(reserveComp.stablePercent)} of TVL</div>
          </div>
          <div className="card">
            <div className="card-label">LP Tokens</div>
            <div className="card-value">{fmt(data.vaults?.lpHoldings?.reserveVault.lpTokens)}</div>
            <div className="card-sublabel">{pct(reserveComp.lpPercent)} of TVL (${fmt(data.vaults?.lpHoldings?.reserveVault.valueUSD)})</div>
          </div>
        </div>

        <h3>Values</h3>
        <div className="cards">
          <div className="card">
            <div className="card-label">On-chain Value</div>
            <div className="card-value">${fmt(data.vaults?.onChainValue?.reserveVault.vaultValue)}</div>
          </div>
          <div className="card">
            <div className="card-label">Calculated Value</div>
            <div className="card-value">${fmt(reserveTVL)}</div>
          </div>
        </div>
      </div>

      {/* Admin Rebase Section */}
      <div className="section admin-section">
        <h2>⚡ Admin: Rebase (Updates All Vaults + Executes Rebase)</h2>
        <RebaseSection data={data} onRebaseComplete={fetchData} />
      </div>
    </div>
  );
}

// Rebase Section Component
function RebaseSection({ data, onRebaseComplete }: { data: any, onRebaseComplete: () => void }) {
  const [adminKey, setAdminKey] = useState('');
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');

  const handleRebase = async () => {
    if (!adminKey) {
      setMessage('❌ Please enter admin private key');
      return;
    }

    setLoading(true);
    setMessage('');

    try {
      const result = await apiService.updateAllVaultsAndRebase(adminKey);
      
      if (result.success) {
        const { vaultUpdates, rebase } = result;
        setMessage(
          `✅ Rebase Complete!\n\n` +
          `📊 Vault Updates:\n` +
          `Senior: $${vaultUpdates.senior.before} → $${vaultUpdates.senior.after}\n` +
          `Junior: $${vaultUpdates.junior.before} → $${vaultUpdates.junior.after}\n` +
          `Reserve: $${vaultUpdates.reserve.before} → $${vaultUpdates.reserve.after}\n\n` +
          `⚡ Rebase:\n` +
          `Supply Change: ${rebase.after.supplyChange}\n` +
          `TX: ${rebase.transactionHash}`
        );
        
        // Refresh data after 3 seconds
        setTimeout(() => {
          onRebaseComplete();
        }, 3000);
      }
    } catch (error: any) {
      setMessage(`❌ Error: ${error?.response?.data?.error || error.message}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="rebase-container">
      <div className="rebase-info">
        <div className="cards">
          <div className="card">
            <div className="card-label">Rebase Interval</div>
            <div className="card-value">{data?.rebaseConfig?.minRebaseInterval || 'N/A'}</div>
          </div>
          <div className="card">
            <div className="card-label">Last Rebase</div>
            <div className="card-value">{data?.rebaseConfig?.lastRebaseTimeFormatted || 'Never'}</div>
          </div>
          <div className="card">
            <div className="card-label">Can Rebase</div>
            <div className="card-value">{data?.rebaseConfig?.canRebase ? '✅ Yes' : '⏳ Not Yet'}</div>
          </div>
          <div className="card">
            <div className="card-label">Time Until Next</div>
            <div className="card-value">{data?.rebaseConfig?.timeUntilRebase || 'N/A'}</div>
          </div>
        </div>
      </div>

      <div className="rebase-action">
        <input
          type="password"
          placeholder="Admin Private Key (0x...)"
          value={adminKey}
          onChange={(e) => setAdminKey(e.target.value)}
          className="admin-input"
          disabled={loading}
        />
        <button
          onClick={handleRebase}
          disabled={loading || !data?.rebaseConfig?.canRebase}
          className="rebase-btn"
        >
          {loading ? '⏳ Updating & Rebasing...' : '⚡ Update All Vaults & Rebase'}
        </button>
      </div>

      {message && (
        <div className={`message ${message.startsWith('✅') ? 'success' : 'error'}`}>
          <pre>{message}</pre>
        </div>
      )}

      <div className="rebase-note">
        <strong>Note:</strong> This will:<br />
        1. Update Senior vault value (USDe + LP holdings)<br />
        2. Update Junior vault value (USDe + LP holdings)<br />
        3. Update Reserve vault value (USDe + LP holdings)<br />
        4. Execute Senior vault rebase (adjusts supply based on backing ratio)
      </div>
    </div>
  );
}
