import { useState, useEffect } from 'react';
import { useReadContract } from 'wagmi';
import { formatEther } from 'viem';
import { DollarSign, TrendingUp, Users, Activity } from 'lucide-react';
import { VaultCard } from './VaultCard';
import { ADDRESSES } from '../contracts/addresses';
import SeniorVaultABI from '../contracts/abi/UnifiedConcreteSeniorVault.json';
import JuniorVaultABI from '../contracts/abi/ConcreteJuniorVault.json';
import ReserveVaultABI from '../contracts/abi/ConcreteReserveVault.json';
import ERC20ABI from '../contracts/abi/MockERC20.json';

export function VaultDashboard() {
  // Fetch LP token price from Enso API
  const [ensoLPPrice, setEnsoLPPrice] = useState<number | null>(null);
  
  useEffect(() => {
    const fetchEnsoPrice = async () => {
      try {
        const response = await fetch(
          `https://api.enso.finance/api/v1/prices/80094/${ADDRESSES.KODIAK_ISLAND}`,
          {
            headers: {
              'Authorization': 'Bearer 3ea9ecd8-5058-493c-8c73-42811e78ed2c'
            }
          }
        );
        const data = await response.json();
        setEnsoLPPrice(data.price);
      } catch (error) {
        console.error('Error fetching Enso LP price:', error);
      }
    };
    
    fetchEnsoPrice();
    const interval = setInterval(fetchEnsoPrice, 30000);
    return () => clearInterval(interval);
  }, []);

  // Read HONEY balance from all vaults (more accurate than totalAssets)
  const { data: seniorAssets } = useReadContract({
    address: ADDRESSES.HONEY,
    abi: ERC20ABI.abi,
    functionName: 'balanceOf',
    args: [ADDRESSES.SENIOR_VAULT],
  });

  const { data: juniorAssets } = useReadContract({
    address: ADDRESSES.HONEY,
    abi: ERC20ABI.abi,
    functionName: 'balanceOf',
    args: [ADDRESSES.JUNIOR_VAULT],
  });

  const { data: reserveAssets } = useReadContract({
    address: ADDRESSES.HONEY,
    abi: ERC20ABI.abi,
    functionName: 'balanceOf',
    args: [ADDRESSES.RESERVE_VAULT],
  });

  // Read LP balances from each hook
  const { data: seniorHookLP } = useReadContract({
    address: ADDRESSES.KODIAK_ISLAND,
    abi: ERC20ABI.abi,
    functionName: 'balanceOf',
    args: [ADDRESSES.SENIOR_HOOK],
  });

  const { data: juniorHookLP } = useReadContract({
    address: ADDRESSES.KODIAK_ISLAND,
    abi: ERC20ABI.abi,
    functionName: 'balanceOf',
    args: [ADDRESSES.JUNIOR_HOOK],
  });

  const { data: reserveHookLP } = useReadContract({
    address: ADDRESSES.KODIAK_ISLAND,
    abi: ERC20ABI.abi,
    functionName: 'balanceOf',
    args: [ADDRESSES.RESERVE_HOOK],
  });

  // Read total supply
  const { data: seniorSupply } = useReadContract({
    address: ADDRESSES.SENIOR_VAULT,
    abi: SeniorVaultABI.abi,
    functionName: 'totalSupply',
  });

  const { data: juniorSupply } = useReadContract({
    address: ADDRESSES.JUNIOR_VAULT,
    abi: JuniorVaultABI.abi,
    functionName: 'totalSupply',
  });

  const { data: reserveSupply } = useReadContract({
    address: ADDRESSES.RESERVE_VAULT,
    abi: ReserveVaultABI.abi,
    functionName: 'totalSupply',
  });

  // Calculate totals
  const totalIdle = 
    (seniorAssets ? parseFloat(formatEther(seniorAssets as bigint)) : 0) +
    (juniorAssets ? parseFloat(formatEther(juniorAssets as bigint)) : 0) +
    (reserveAssets ? parseFloat(formatEther(reserveAssets as bigint)) : 0);

  const totalShares =
    (seniorSupply ? parseFloat(formatEther(seniorSupply as bigint)) : 0) +
    (juniorSupply ? parseFloat(formatEther(juniorSupply as bigint)) : 0) +
    (reserveSupply ? parseFloat(formatEther(reserveSupply as bigint)) : 0);

  // Calculate total LP value using Enso price
  const seniorLPValue = seniorHookLP && ensoLPPrice 
    ? parseFloat(formatEther(seniorHookLP as bigint)) * ensoLPPrice 
    : 0;
  
  const juniorLPValue = juniorHookLP && ensoLPPrice 
    ? parseFloat(formatEther(juniorHookLP as bigint)) * ensoLPPrice 
    : 0;
  
  const reserveLPValue = reserveHookLP && ensoLPPrice 
    ? parseFloat(formatEther(reserveHookLP as bigint)) * ensoLPPrice 
    : 0;

  const totalLPValueUSD = seniorLPValue + juniorLPValue + reserveLPValue;
  
  // Convert total LP value from USD to HONEY (assuming 1 HONEY = $1)
  const lpValueInHoney = totalLPValueUSD;
  
  // Total value = idle HONEY + LP value (in HONEY equivalent) - both already in HONEY units
  const totalCalculated = totalIdle + lpValueInHoney;

  // Debug logging
  console.log('VaultDashboard Calculations:', {
    seniorAssets: seniorAssets ? formatEther(seniorAssets as bigint) : 'null',
    juniorAssets: juniorAssets ? formatEther(juniorAssets as bigint) : 'null',
    reserveAssets: reserveAssets ? formatEther(reserveAssets as bigint) : 'null',
    totalIdle,
    seniorLPValue,
    juniorLPValue,
    reserveLPValue,
    totalLPValueUSD,
    lpValueInHoney,
    totalCalculated,
    totalShares,
    ensoLPPrice,
  });

  return (
    <div className="space-y-8">
      {/* Protocol Overview Stats */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Total TVL (Idle) */}
        <div className="bg-gradient-to-br from-purple-600/20 to-pink-600/20 backdrop-blur-sm rounded-xl border border-purple-500/30 p-6">
          <div className="flex items-center justify-between mb-2">
            <span className="text-gray-300 text-sm">Total TVL (Idle)</span>
            <DollarSign className="w-5 h-5 text-purple-400" />
          </div>
          <div className="text-2xl font-bold text-white">
            {totalIdle.toFixed(2)} HONEY
          </div>
          <div className="text-xs text-gray-400 mt-1">
            Assets in vaults
          </div>
        </div>

        {/* Total Value with LP */}
        <div className="bg-gradient-to-br from-cyan-600/20 to-blue-600/20 backdrop-blur-sm rounded-xl border border-cyan-500/30 p-6">
          <div className="flex items-center justify-between mb-2">
            <span className="text-gray-300 text-sm">Total Value (with LP)</span>
            <TrendingUp className="w-5 h-5 text-cyan-400" />
          </div>
          <div className="text-2xl font-bold text-white">
            {totalCalculated.toFixed(2)} HONEY
          </div>
          <div className="text-xs text-gray-400 mt-1">
            Including LP positions
          </div>
        </div>

        {/* LP Holdings Value */}
        <div className="bg-gradient-to-br from-green-600/20 to-emerald-600/20 backdrop-blur-sm rounded-xl border border-green-500/30 p-6">
          <div className="flex items-center justify-between mb-2">
            <span className="text-gray-300 text-sm">LP Holdings</span>
            <Activity className="w-5 h-5 text-green-400" />
          </div>
          <div className="text-2xl font-bold text-white">
            {lpValueInHoney.toFixed(2)} HONEY
          </div>
          <div className="text-xs text-gray-400 mt-1">
            Deployed to Kodiak (${totalLPValueUSD.toFixed(2)})
          </div>
        </div>

        {/* Total Shares */}
        <div className="bg-gradient-to-br from-orange-600/20 to-yellow-600/20 backdrop-blur-sm rounded-xl border border-orange-500/30 p-6">
          <div className="flex items-center justify-between mb-2">
            <span className="text-gray-300 text-sm">Total Shares</span>
            <Users className="w-5 h-5 text-orange-400" />
          </div>
          <div className="text-2xl font-bold text-white">
            {totalShares.toFixed(2)}
          </div>
          <div className="text-xs text-gray-400 mt-1">
            Across all vaults
          </div>
        </div>
      </div>

      {/* Individual Vault Cards */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <VaultCard
          name="Senior Vault"
          symbol="svHONEY"
          address={ADDRESSES.SENIOR_VAULT}
          description="Low-risk, stable returns"
          color="from-cyan-500 to-blue-600"
        />
        <VaultCard
          name="Junior Vault"
          symbol="jvHONEY"
          address={ADDRESSES.JUNIOR_VAULT}
          description="Medium-risk, balanced returns"
          color="from-orange-500 to-pink-600"
        />
        <VaultCard
          name="Reserve Vault"
          symbol="rvHONEY"
          address={ADDRESSES.RESERVE_VAULT}
          description="High-risk, highest returns"
          color="from-green-500 to-emerald-600"
        />
      </div>

      {/* Protocol Info */}
      <div className="bg-white/5 backdrop-blur-sm rounded-xl border border-white/10 p-6">
        <h3 className="text-white font-bold mb-4">Protocol Information</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
          <div>
            <span className="text-gray-400">Network:</span>
            <span className="text-white ml-2 font-semibold">Berachain Testnet (Chain ID: 80094)</span>
          </div>
          <div>
            <span className="text-gray-400">Stablecoin:</span>
            <span className="text-green-400 ml-2 font-mono">HONEY</span>
          </div>
          <div>
            <span className="text-gray-400">DEX:</span>
            <span className="text-purple-400 ml-2">Kodiak Island</span>
          </div>
          <div>
            <span className="text-gray-400">Pool:</span>
            <span className="text-blue-400 ml-2">WBTC/HONEY</span>
          </div>
        </div>
      </div>
    </div>
  );
}
