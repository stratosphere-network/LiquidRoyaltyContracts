import { useState, useEffect } from 'react';
import { apiService } from '../services/api';
import { config } from '../config';
import type { PoolReserves, LPPriceData, VaultsData, BackingRatioData, JuniorTokenPriceData } from '../types';
import './Dashboard.css';

export const Dashboard = () => {
  const [reserves, setReserves] = useState<PoolReserves | null>(null);
  const [lpPrice, setLpPrice] = useState<LPPriceData | null>(null);
  const [vaultsValue, setVaultsValue] = useState<VaultsData | null>(null);
  const [vaultsSupply, setVaultsSupply] = useState<VaultsData | null>(null);
  const [vaultsOnChain, setVaultsOnChain] = useState<VaultsData | null>(null);
  const [vaultsProfits, setVaultsProfits] = useState<any>(null);
  const [backingRatio, setBackingRatio] = useState<BackingRatioData | null>(null);
  const [juniorPrice, setJuniorPrice] = useState<JuniorTokenPriceData | null>(null);
  const [loading, setLoading] = useState(true);
  const [adminLoading, setAdminLoading] = useState(false);
  const [adminMessage, setAdminMessage] = useState<{type: 'success' | 'error', text: string} | null>(null);

  const fetchAllData = async () => {
    try {
      setLoading(true);
      const [
        reservesRes,
        lpPriceRes,
        vaultsValueRes,
        vaultsSupplyRes,
        vaultsOnChainRes,
        vaultsProfitsRes,
        backingRatioRes,
        juniorPriceRes
      ] = await Promise.all([
        apiService.getReserves(),
        apiService.getLPPrice(),
        apiService.getVaultsValue(),
        apiService.getVaultsTotalSupply(),
        apiService.getVaultsOnChainValue(),
        apiService.getVaultsProfits(),
        apiService.getSeniorBackingRatio(),
        apiService.getJuniorTokenPrice()
      ]);

      setReserves(reservesRes.data);
      setLpPrice(lpPriceRes.data);
      setVaultsValue(vaultsValueRes.data);
      setVaultsSupply(vaultsSupplyRes.data);
      setVaultsOnChain(vaultsOnChainRes.data);
      setVaultsProfits(vaultsProfitsRes.data);
      setBackingRatio(backingRatioRes.data);
      setJuniorPrice(juniorPriceRes.data);
    } catch (error) {
      console.error('Error fetching data:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleUpdateVaultValue = async () => {
    if (!vaultsValue || !vaultsOnChain) {
      setAdminMessage({ type: 'error', text: 'Data not loaded yet' });
      return;
    }

    try {
      setAdminLoading(true);
      setAdminMessage(null);

      // Calculate profit BPS: ((calculated - onchain) / onchain) * 10000
      const calculatedValue = parseFloat(vaultsValue.seniorVault.valueUSD);
      const onChainValue = parseFloat(vaultsOnChain.seniorVault.vaultValue);
      const profitBps = Math.round(((calculatedValue - onChainValue) / onChainValue) * 10000);

      console.log(`Calculated: $${calculatedValue}, OnChain: $${onChainValue}, Profit BPS: ${profitBps}`);

      const result = await apiService.updateVaultValue(config.bots.whale.privateKey, profitBps);
      
      if (result.success) {
        const message = result.multipleUpdates 
          ? `✅ Vault updated in ${result.totalUpdates} steps! Total: ${result.profitPercent}. New value: $${result.newValue}`
          : `✅ Vault value updated! ${result.profitPercent} profit. New value: $${result.newValue}`;
        
        setAdminMessage({ 
          type: 'success', 
          text: message
        });
        
        // Wait 3 seconds before refreshing to avoid rate limits
        await new Promise(resolve => setTimeout(resolve, 3000));
        await fetchAllData();
      }
    } catch (error: any) {
      setAdminMessage({ type: 'error', text: `❌ Error: ${error.message}` });
    } finally {
      setAdminLoading(false);
      setTimeout(() => setAdminMessage(null), 5000);
    }
  };

  const handleRebase = async () => {
    try {
      setAdminLoading(true);
      setAdminMessage(null);

      const result = await apiService.executeRebase(config.bots.whale.privateKey);
      
      if (result.success) {
        setAdminMessage({ 
          type: 'success', 
          text: `✅ Rebase complete! Supply change: ${result.after.supplyChange}` 
        });
        
        // Wait 3 seconds before refreshing to avoid rate limits
        await new Promise(resolve => setTimeout(resolve, 3000));
        await fetchAllData();
      }
    } catch (error: any) {
      setAdminMessage({ type: 'error', text: `❌ Error: ${error.message}` });
    } finally {
      setAdminLoading(false);
      setTimeout(() => setAdminMessage(null), 5000);
    }
  };

  useEffect(() => {
    fetchAllData();
    
    // Auto-update vault value every 10 minutes
    const autoUpdateInterval = setInterval(async () => {
      console.log('🔄 Auto-updating vault value...');
      await handleUpdateVaultValue();
    }, 10 * 60 * 1000); // 10 minutes

    return () => clearInterval(autoUpdateInterval);
  }, [vaultsValue, vaultsOnChain]); // Re-run when data changes

  if (loading) {
    return (
      <div className="dashboard loading">
        <div className="shimmer loading-card"></div>
        <div className="shimmer loading-card"></div>
        <div className="shimmer loading-card"></div>
      </div>
    );
  }

  return (
    <div className="dashboard">
      {/* Header */}
      <div className="dashboard-header">
        <div>
          <h1 className="gradient-text">VAULT SIMULATOR</h1>
          <p className="subtitle">Real-time vault & pool analytics • Auto-update every 10min</p>
        </div>
        <div className="header-controls">
          <button 
            onClick={fetchAllData} 
            disabled={loading}
            className="refresh-btn"
          >
            🔄 {loading ? 'Refreshing...' : 'Refresh Data'}
          </button>
          <button 
            onClick={handleUpdateVaultValue} 
            disabled={adminLoading || !vaultsValue || !vaultsOnChain}
            className="admin-btn update-btn"
          >
            💰 {adminLoading ? 'Updating...' : 'Update Value'}
          </button>
          <button 
            onClick={handleRebase} 
            disabled={adminLoading}
            className="admin-btn rebase-btn"
          >
            🎯 {adminLoading ? 'Rebasing...' : 'Rebase'}
          </button>
        </div>
      </div>

      {/* Admin Message */}
      {adminMessage && (
        <div className={`admin-message ${adminMessage.type}`}>
          {adminMessage.text}
        </div>
      )}

      {/* Pool Info */}
      <div className="section">
        <h2 className="section-title">
          <span className="glow">💧</span> Uniswap V2 Pool
        </h2>
        <div className="cards-grid">
          <div className="stat-card glass">
            <div className="stat-label">LP Token Price</div>
            <div className="stat-value gradient-text">${lpPrice?.lpTokenPrice}</div>
            <div className="stat-meta">TUSD per LP</div>
          </div>
          <div className="stat-card glass">
            <div className="stat-label">TSAIL Price</div>
            <div className="stat-value" style={{ color: 'var(--neon-blue)' }}>${lpPrice?.tsailPrice}</div>
            <div className="stat-meta">in TUSD</div>
          </div>
          <div className="stat-card glass">
            <div className="stat-label">Pool TVL</div>
            <div className="stat-value" style={{ color: 'var(--neon-green)' }}>${parseFloat(lpPrice?.totalPoolValue || '0').toLocaleString()}</div>
            <div className="stat-meta">Total Value Locked</div>
          </div>
          <div className="stat-card glass">
            <div className="stat-label">TUSD Reserve</div>
            <div className="stat-value">{parseFloat(reserves?.tusdReserve || '0').toFixed(2)}</div>
            <div className="stat-meta">TUSD</div>
          </div>
          <div className="stat-card glass">
            <div className="stat-label">TSAIL Reserve</div>
            <div className="stat-value">{parseFloat(reserves?.tsailReserve || '0').toFixed(2)}</div>
            <div className="stat-meta">TSAIL</div>
          </div>
        </div>
      </div>

      {/* Vaults Overview */}
      <div className="section">
        <h2 className="section-title">
          <span className="glow">🏦</span> Vaults Overview
        </h2>
        <div className="vaults-grid">
          {/* Senior Vault */}
          <div className="vault-card senior glass">
            <div className="vault-header">
              <h3>Senior Vault</h3>
              <span className="vault-badge">SNR</span>
            </div>
            <div className="vault-stats">
              <div className="vault-stat">
                <span className="label">Total Supply</span>
                <span className="value">{parseFloat(vaultsSupply?.seniorVault.totalSupply || '0').toLocaleString(undefined, {maximumFractionDigits: 2})} SNR</span>
              </div>
              <div className="vault-stat">
                <span className="label">Value USD (Calculated)</span>
                <span className="value">${parseFloat(vaultsValue?.seniorVault.valueUSD || '0').toLocaleString()}</span>
              </div>
              <div className="vault-stat">
                <span className="label">On-Chain Value</span>
                <span className="value onchain">${parseFloat(vaultsOnChain?.seniorVault.vaultValue || '0').toLocaleString()}</span>
              </div>
              <div className="vault-stat">
                <span className="label">Total Assets</span>
                <span className="value">{parseFloat(vaultsValue?.seniorVault.totalAssets || '0').toFixed(2)} LP</span>
              </div>
              <div className="vault-stat">
                <span className="label">Backing Ratio</span>
                <span className="value highlight">{backingRatio?.seniorVault.backingRatio}</span>
              </div>
              <div className="vault-stat">
                <span className="label">Profit</span>
                <span className={`value ${vaultsProfits?.seniorVault.profit?.startsWith('+') ? 'profit' : 'loss'}`}>
                  {vaultsProfits?.seniorVault.profit}
                </span>
              </div>
            </div>
          </div>

          {/* Junior Vault */}
          <div className="vault-card junior glass">
            <div className="vault-header">
              <h3>Junior Vault</h3>
              <span className="vault-badge">JNR</span>
            </div>
            <div className="vault-stats">
              <div className="vault-stat">
                <span className="label">Total Supply</span>
                <span className="value">{parseFloat(vaultsSupply?.juniorVault.totalSupply || '0').toLocaleString(undefined, {maximumFractionDigits: 2})} JNR</span>
              </div>
              <div className="vault-stat">
                <span className="label">Value USD (Calculated)</span>
                <span className="value">${parseFloat(vaultsValue?.juniorVault.valueUSD || '0').toLocaleString()}</span>
              </div>
              <div className="vault-stat">
                <span className="label">On-Chain Value</span>
                <span className="value onchain">${parseFloat(vaultsOnChain?.juniorVault.vaultValue || '0').toLocaleString()}</span>
              </div>
              <div className="vault-stat">
                <span className="label">Total Assets</span>
                <span className="value">{parseFloat(vaultsValue?.juniorVault.totalAssets || '0').toFixed(2)} LP</span>
              </div>
              <div className="vault-stat">
                <span className="label">Token Price</span>
                <span className="value highlight">${juniorPrice?.juniorVault.tokenPrice}</span>
              </div>
              <div className="vault-stat">
                <span className="label">Profit</span>
                <span className={`value ${vaultsProfits?.juniorVault.profit?.startsWith('+') ? 'profit' : 'loss'}`}>
                  {vaultsProfits?.juniorVault.profit}
                </span>
              </div>
            </div>
          </div>

          {/* Reserve Vault */}
          <div className="vault-card reserve glass">
            <div className="vault-header">
              <h3>Reserve Vault</h3>
              <span className="vault-badge">RSV</span>
            </div>
            <div className="vault-stats">
              <div className="vault-stat">
                <span className="label">Total Supply</span>
                <span className="value">{parseFloat(vaultsSupply?.reserveVault.totalSupply || '0').toLocaleString(undefined, {maximumFractionDigits: 2})} RSV</span>
              </div>
              <div className="vault-stat">
                <span className="label">Value USD (Calculated)</span>
                <span className="value">${parseFloat(vaultsValue?.reserveVault.valueUSD || '0').toLocaleString()}</span>
              </div>
              <div className="vault-stat">
                <span className="label">On-Chain Value</span>
                <span className="value onchain">${parseFloat(vaultsOnChain?.reserveVault.vaultValue || '0').toLocaleString()}</span>
              </div>
              <div className="vault-stat">
                <span className="label">Total Assets</span>
                <span className="value">{parseFloat(vaultsValue?.reserveVault.totalAssets || '0').toFixed(2)} LP</span>
              </div>
              <div className="vault-stat">
                <span className="label">Profit</span>
                <span className={`value ${vaultsProfits?.reserveVault.profit?.startsWith('+') ? 'profit' : 'loss'}`}>
                  {vaultsProfits?.reserveVault.profit}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Total Stats */}
      <div className="section">
        <div className="total-stats glass">
          <div className="total-stat">
            <span className="label">Total Protocol TVL</span>
            <span className="value gradient-text">${parseFloat(vaultsValue?.total.valueUSD || '0').toLocaleString()}</span>
          </div>
          <div className="total-stat">
            <span className="label">Total Protocol Profit</span>
            <span className={`value ${vaultsProfits?.total.profit?.startsWith('+') ? 'profit' : 'loss'}`}>
              {vaultsProfits?.total.profit}
            </span>
          </div>
        </div>
      </div>
    </div>
  );
};

