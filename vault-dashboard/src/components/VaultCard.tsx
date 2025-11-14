import { useState, useEffect } from 'react';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { formatEther, parseEther } from 'viem';
import { ArrowDownToLine, ArrowUpFromLine, TrendingUp, Database, Shield, Activity, CheckCircle, Link2, Globe, Rocket } from 'lucide-react';
import SeniorVaultABI from '../contracts/abi/UnifiedConcreteSeniorVault.json';
import JuniorVaultABI from '../contracts/abi/ConcreteJuniorVault.json';
import ReserveVaultABI from '../contracts/abi/ConcreteReserveVault.json';
import HookABI from '../contracts/abi/KodiakVaultHook.json';
import ERC20ABI from '../contracts/abi/MockERC20.json';
import { ADDRESSES } from '../contracts/addresses';

interface VaultCardProps {
  name: string;
  symbol: string;
  address: `0x${string}`;
  description: string;
  color: string;
}

export function VaultCard({ name, symbol, address, description, color }: VaultCardProps) {
  const { address: userAddress } = useAccount();
  const [amount, setAmount] = useState('');
  const [mode, setMode] = useState<'deposit' | 'withdraw' | 'mint' | 'redeem'>('deposit');
  const [showDetails, setShowDetails] = useState(false);
  const [showAdvanced, setShowAdvanced] = useState(false);

  // Select correct ABI based on vault address (extract .abi array from JSON)
  const vaultABI = 
    address === ADDRESSES.SENIOR_VAULT ? SeniorVaultABI.abi :
    address === ADDRESSES.JUNIOR_VAULT ? JuniorVaultABI.abi :
    ReserveVaultABI.abi;

  // Read vault data (using vaultValue instead of totalAssets as ABIs are up-to-date with this)
  const { data: totalAssets } = useReadContract({
    address,
    abi: vaultABI,
    functionName: 'vaultValue',
  });

  const { data: totalSupply, error: totalSupplyError } = useReadContract({
    address,
    abi: vaultABI,
    functionName: 'totalSupply',
  });

  useEffect(() => {
    console.log(`[${symbol}] Total Supply:`, {
      totalSupply,
      error: totalSupplyError
    });
  }, [totalSupply, totalSupplyError, symbol]);

  const { data: userBalance } = useReadContract({
    address,
    abi: vaultABI,
    functionName: 'balanceOf',
    args: userAddress ? [userAddress] : undefined,
  });

  const { data: vaultValue, error: vaultValueError, isLoading: vaultValueLoading } = useReadContract({
    address,
    abi: vaultABI,
    functionName: 'vaultValue',
  });

  // Debug logging with alert
  useEffect(() => {
    const debug = {
      vaultValue,
      error: vaultValueError ? (vaultValueError as any).message : null,
      loading: vaultValueLoading,
      address,
      abiType: address === ADDRESSES.SENIOR_VAULT ? 'Senior' : address === ADDRESSES.JUNIOR_VAULT ? 'Junior' : 'Reserve'
    };
    console.log(`[${symbol}] Vault Value:`, debug);
    
    // Alert on error
    if (vaultValueError && !vaultValueLoading) {
      alert(`❌ ${symbol} vault read FAILED!\n\nError: ${(vaultValueError as any).message}\n\nCheck console for details.`);
    }
  }, [vaultValue, vaultValueError, vaultValueLoading, symbol, address]);

  const { data: isPaused } = useReadContract({
    address,
    abi: vaultABI,
    functionName: 'paused',
  });

  const { data: seniorVault } = useReadContract({
    address,
    abi: vaultABI,
    functionName: 'seniorVault',
  });

  const { data: kodiakHook } = useReadContract({
    address,
    abi: vaultABI,
    functionName: 'kodiakHook',
  });

  // Senior Vault Cooldown (7 days)
  const isSenior = address === ADDRESSES.SENIOR_VAULT;
  
  const { data: cooldownStart } = useReadContract({
    address,
    abi: vaultABI,
    functionName: 'cooldownStart',
    args: userAddress ? [userAddress] : undefined,
    query: { enabled: isSenior && !!userAddress },
  });

  const { data: canWithdrawWithoutPenalty } = useReadContract({
    address,
    abi: vaultABI,
    functionName: 'canWithdrawWithoutPenalty',
    args: userAddress ? [userAddress] : undefined,
    query: { enabled: isSenior && !!userAddress, refetchInterval: 10000 },
  });

  const { data: withdrawalPenalty } = useReadContract({
    address,
    abi: vaultABI,
    functionName: 'calculateWithdrawalPenalty',
    args: userAddress && amount ? [userAddress, parseEther(amount || '0')] : undefined,
    query: { enabled: isSenior && !!userAddress && !!amount },
  });

  // Calculate cooldown time remaining
  const [timeRemaining, setTimeRemaining] = useState<string>('');
  const COOLDOWN_PERIOD = 7 * 24 * 60 * 60; // 7 days in seconds

  useEffect(() => {
    if (!isSenior || !cooldownStart || Number(cooldownStart) === 0) {
      setTimeRemaining('');
      return;
    }

    const updateTimeRemaining = () => {
      const now = Math.floor(Date.now() / 1000);
      const cooldownStartNum = Number(cooldownStart);
      const elapsed = now - cooldownStartNum;
      const remaining = COOLDOWN_PERIOD - elapsed;

      if (remaining <= 0) {
        setTimeRemaining('Ready!');
        return;
      }

      const days = Math.floor(remaining / (24 * 60 * 60));
      const hours = Math.floor((remaining % (24 * 60 * 60)) / (60 * 60));
      const minutes = Math.floor((remaining % (60 * 60)) / 60);
      
      setTimeRemaining(`${days}d ${hours}h ${minutes}m`);
    };

    updateTimeRemaining();
    const interval = setInterval(updateTimeRemaining, 60000); // Update every minute

    return () => clearInterval(interval);
  }, [cooldownStart, isSenior]);

  const { data: lpHoldings } = useReadContract({
    address,
    abi: vaultABI,
    functionName: 'getLPHoldings',
  });

  // Get hook contract address for this vault (MUST be defined before using in hooks below)
  const hookAddress = 
    address === ADDRESSES.SENIOR_VAULT ? ADDRESSES.SENIOR_HOOK :
    address === ADDRESSES.JUNIOR_VAULT ? ADDRESSES.JUNIOR_HOOK :
    ADDRESSES.RESERVE_HOOK;

  // Read Hook Contract State
  const { data: hookVault } = useReadContract({
    address: hookAddress,
    abi: HookABI.abi,
    functionName: 'vault',
  });

  const { data: hookAdmin } = useReadContract({
    address: hookAddress,
    abi: HookABI.abi,
    functionName: 'admin',
  });

  const { data: hookRouter } = useReadContract({
    address: hookAddress,
    abi: HookABI.abi,
    functionName: 'kodiakRouter',
  });

  const { data: hookIsland } = useReadContract({
    address: hookAddress,
    abi: HookABI.abi,
    functionName: 'kodiakIsland',
  });

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
        console.log(`[${symbol}] Enso API Response:`, data);
        setEnsoLPPrice(data.price);
      } catch (error) {
        console.error(`[${symbol}] Error fetching Enso LP price:`, error);
      }
    };
    
    fetchEnsoPrice();
    // Refresh every 30 seconds
    const interval = setInterval(fetchEnsoPrice, 30000);
    return () => clearInterval(interval);
  }, [symbol]);

  // Preview functions - show expected results
  const { data: previewDepositData } = useReadContract({
    address,
    abi: vaultABI,
    functionName: 'previewDeposit',
    args: amount ? [parseEther(amount)] : undefined,
  });

  const { data: previewWithdrawData } = useReadContract({
    address,
    abi: vaultABI,
    functionName: 'previewWithdraw',
    args: amount ? [parseEther(amount)] : undefined,
  });

  const { data: previewMintData } = useReadContract({
    address,
    abi: vaultABI,
    functionName: 'previewMint',
    args: amount ? [parseEther(amount)] : undefined,
  });

  const { data: previewRedeemData } = useReadContract({
    address,
    abi: vaultABI,
    functionName: 'previewRedeem',
    args: amount ? [parseEther(amount)] : undefined,
  });

  // Max functions - show maximum allowed
  const { data: maxDeposit } = useReadContract({
    address,
    abi: vaultABI,
    functionName: 'maxDeposit',
    args: userAddress ? [userAddress] : undefined,
  });

  const { data: maxWithdraw } = useReadContract({
    address,
    abi: vaultABI,
    functionName: 'maxWithdraw',
    args: userAddress ? [userAddress] : undefined,
  });

  const { data: maxMint } = useReadContract({
    address,
    abi: vaultABI,
    functionName: 'maxMint',
    args: userAddress ? [userAddress] : undefined,
  });

  const { data: maxRedeem } = useReadContract({
    address,
    abi: vaultABI,
    functionName: 'maxRedeem',
    args: userAddress ? [userAddress] : undefined,
  });

  // Check HONEY allowance
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: ADDRESSES.HONEY,
    abi: ERC20ABI.abi,
    functionName: 'allowance',
    args: userAddress ? [userAddress, address] : undefined,
  });

  // Get HONEY balance of the vault
  const { data: vaultHoneyBalance } = useReadContract({
    address: ADDRESSES.HONEY,
    abi: ERC20ABI.abi,
    functionName: 'balanceOf',
    args: [address],
  });

  // Get HONEY balance of the hook
  const { data: hookHoneyBalance, error: hookHoneyError, isLoading: hookHoneyLoading } = useReadContract({
    address: ADDRESSES.HONEY,
    abi: ERC20ABI.abi,
    functionName: 'balanceOf',
    args: [hookAddress],
  });

  // Get Kodiak LP token balance of the hook (LP tokens are held by hook, not vault)
  const { data: hookLPBalance, error: hookLPError, isLoading: hookLPLoading } = useReadContract({
    address: ADDRESSES.KODIAK_ISLAND,
    abi: ERC20ABI.abi,
    functionName: 'balanceOf',
    args: [hookAddress],
  });

  // Get WBTC balance of the hook
  const { data: hookWBTCBalance } = useReadContract({
    address: ADDRESSES.WBTC,
    abi: ERC20ABI.abi,
    functionName: 'balanceOf',
    args: [hookAddress],
  });

  // Get WBTC balance of the vault (if any)
  const { data: vaultWBTCBalance } = useReadContract({
    address: ADDRESSES.WBTC,
    abi: ERC20ABI.abi,
    functionName: 'balanceOf',
    args: [address],
  });

  // Get LP balance of the vault (if any)
  const { data: vaultLPBalance } = useReadContract({
    address: ADDRESSES.KODIAK_ISLAND,
    abi: ERC20ABI.abi,
    functionName: 'balanceOf',
    args: [address],
  });

  // Fetch WBTC price for accurate valuation
  const [wbtcPrice, setWBTCPrice] = useState<number>(0);
  useEffect(() => {
    const fetchWBTCPrice = async () => {
      try {
        const response = await fetch(
          `https://api.enso.finance/api/v1/prices/80094/${ADDRESSES.WBTC}`,
          {
            headers: {
              'Authorization': 'Bearer 3ea9ecd8-5058-493c-8c73-42811e78ed2c'
            }
          }
        );
        const data = await response.json();
        setWBTCPrice(data.price);
      } catch (error) {
        console.error('Error fetching WBTC price:', error);
        setWBTCPrice(97000); // Fallback to ~$97k
      }
    };
    
    fetchWBTCPrice();
  }, []);

  // Debug hook balance reads
  useEffect(() => {
    console.log(`[${symbol}] Hook Balance Reads:`, {
      hookAddress,
      honey: {
        value: hookHoneyBalance ? formatEther(hookHoneyBalance as bigint) : null,
        error: hookHoneyError ? (hookHoneyError as any).message : null,
        loading: hookHoneyLoading
      },
      lp: {
        value: hookLPBalance ? formatEther(hookLPBalance as bigint) : null,
        error: hookLPError ? (hookLPError as any).message : null,
        loading: hookLPLoading
      }
    });
  }, [hookHoneyBalance, hookHoneyError, hookHoneyLoading, hookLPBalance, hookLPError, hookLPLoading, symbol, hookAddress]);

  // Debug logging
  console.log('VaultCard Debug:', {
    vaultAddress: address,
    hookAddress,
    hookHoneyBalance: hookHoneyBalance ? formatEther(hookHoneyBalance as bigint) : 'null',
    hookLPBalance: hookLPBalance ? formatEther(hookLPBalance as bigint) : 'null',
  });

  // Calculate COMPLETE backing value: (Vault assets + Hook assets)
  // Vault assets
  const vaultHoneyValue = vaultHoneyBalance ? parseFloat(formatEther(vaultHoneyBalance as bigint)) : 0;
  const vaultWBTCValue = vaultWBTCBalance ? (Number(vaultWBTCBalance) / 1e8) * wbtcPrice : 0;
  const vaultLPValue = vaultLPBalance ? parseFloat(formatEther(vaultLPBalance as bigint)) * (ensoLPPrice || 0) : 0;
  
  // Hook assets
  const hookHoneyValue = hookHoneyBalance ? parseFloat(formatEther(hookHoneyBalance as bigint)) : 0;
  const hookWBTCValue = hookWBTCBalance ? (Number(hookWBTCBalance) / 1e8) * wbtcPrice : 0;
  const hookLPValue = hookLPBalance ? parseFloat(formatEther(hookLPBalance as bigint)) * (ensoLPPrice || 0) : 0;
  
  // Total = Vault + Hook (all assets in USD)
  const calculatedValueManual = 
    vaultHoneyValue + vaultWBTCValue + vaultLPValue +
    hookHoneyValue + hookWBTCValue + hookLPValue;

  // Calculate ratios (Senior = Backing %, Junior/Reserve = Unstaking decimal)
  const multiplier = isSenior ? 100 : 1; // Senior shows %, others show decimal
  
  // FIXED: Backing ratio = vaultValue / totalSupply (not the inverse!)
  const onChainRatio = totalSupply && vaultValue
    ? (parseFloat(formatEther(vaultValue as bigint)) / parseFloat(formatEther(totalSupply as bigint))) * multiplier
    : 0;
  
  // Offchain backing = (Vault assets + Hook assets) / totalSupply
  const offChainRatio = totalSupply && calculatedValueManual > 0
    ? (calculatedValueManual / parseFloat(formatEther(totalSupply as bigint))) * multiplier
    : 0;

  // Debug ratio calculation with detailed breakdown
  useEffect(() => {
    console.log(`[${symbol}] COMPLETE Backing Calculation:`, {
      vault: {
        honey: vaultHoneyValue,
        wbtc: vaultWBTCValue,
        lp: vaultLPValue,
        total: vaultHoneyValue + vaultWBTCValue + vaultLPValue
      },
      hook: {
        honey: hookHoneyValue,
        wbtc: hookWBTCValue,
        lp: hookLPValue,
        total: hookHoneyValue + hookWBTCValue + hookLPValue
      },
      combined: {
        totalAssets: calculatedValueManual,
        totalSupply: totalSupply ? parseFloat(formatEther(totalSupply as bigint)) : 0,
        backingRatio: offChainRatio,
        wbtcPrice,
        lpPrice: ensoLPPrice
      }
    });
  }, [symbol, vaultHoneyValue, vaultWBTCValue, vaultLPValue, hookHoneyValue, hookWBTCValue, hookLPValue, calculatedValueManual, totalSupply, offChainRatio, wbtcPrice, ensoLPPrice]);

  // Keep old debug for compatibility
  useEffect(() => {
    const lpBalanceNum = hookLPBalance ? parseFloat(formatEther(hookLPBalance as bigint)) : 0;
    const lpValue = lpBalanceNum * (ensoLPPrice || 0);
    const honeyBalance = vaultHoneyBalance ? parseFloat(formatEther(vaultHoneyBalance as bigint)) : 0;
    
    const debug = {
      '1_LP_Balance': lpBalanceNum,
      '2_LP_Price': ensoLPPrice,
      '3_LP_Value': lpValue,
      '4_HONEY_Balance': honeyBalance,
      '5_Total_OffChain': calculatedValueManual,
      '6_TotalSupply': totalSupply ? parseFloat(formatEther(totalSupply as bigint)) : 0,
      '7_OffChain_Ratio': offChainRatio,
      '8_OnChain_Value': vaultValue ? parseFloat(formatEther(vaultValue as bigint)) : 0,
      '9_OnChain_Ratio': onChainRatio
    };
    
    console.log(`[${symbol}] OFF-CHAIN CALCULATION:`, debug);
    
    // Alert if all values are there but ratio is still 0
    if (lpBalanceNum > 0 && ensoLPPrice && ensoLPPrice > 0 && offChainRatio === 0 && totalSupply) {
      console.error(`[${symbol}] ⚠️ OFF-CHAIN VALUES EXIST BUT RATIO IS 0!`, debug);
    }
    
    // Alert if LP price is missing
    if (!ensoLPPrice && lpBalanceNum > 0) {
      console.warn(`[${symbol}] ⚠️ LP PRICE IS NULL (Enso API not responding)`);
    }
    
    // Alert if LP balance is 0
    if (lpBalanceNum === 0) {
      console.warn(`[${symbol}] ⚠️ NO LP TOKENS IN HOOK (nothing deployed to Kodiak)`);
    }
  }, [vaultValue, totalSupply, hookLPBalance, ensoLPPrice, vaultHoneyBalance, calculatedValueManual, onChainRatio, offChainRatio, symbol]);

  const { writeContract, data: hash } = useWriteContract();
  const { isLoading: isConfirming, isSuccess: txSuccess } = useWaitForTransactionReceipt({ hash });

  // Refetch allowance after successful transaction
  useEffect(() => {
    if (txSuccess) {
      refetchAllowance();
    }
  }, [txSuccess, refetchAllowance]);

  // Check if approval is needed for deposit or mint
  const needsApproval = 
    (mode === 'deposit' || mode === 'mint') && 
    amount && 
    parseEther(amount) > ((allowance as bigint) || 0n);

  const handleDeposit = () => {
    if (!userAddress || !amount) return;
    writeContract({
      address,
      abi: vaultABI,
      functionName: 'deposit',
      args: [parseEther(amount), userAddress],
    });
  };

  const handleInitiateCooldown = () => {
    if (!userAddress || !isSenior) return;
    writeContract({
      address,
      abi: vaultABI,
      functionName: 'initiateCooldown',
    });
  };

  const handleWithdraw = () => {
    if (!userAddress || !amount) return;
    writeContract({
      address,
      abi: vaultABI,
      functionName: 'withdraw',
      args: [parseEther(amount), userAddress, userAddress],
      gas: 1500000n, // Increased gas limit for LP liquidation + HONEY transfer
    });
  };

  const handleMint = () => {
    if (!userAddress || !amount) return;
    writeContract({
      address,
      abi: vaultABI,
      functionName: 'mint',
      args: [parseEther(amount), userAddress],
    });
  };

  const handleRedeem = () => {
    if (!userAddress || !amount) return;
    writeContract({
      address,
      abi: vaultABI,
      functionName: 'redeem',
      args: [parseEther(amount), userAddress, userAddress],
      gas: 1500000n, // Increased gas limit for LP liquidation + HONEY transfer
    });
  };

  const handleSetMax = () => {
    if (mode === 'deposit' && maxDeposit) {
      setAmount(formatEther(maxDeposit as bigint));
    } else if (mode === 'withdraw' && maxWithdraw) {
      setAmount(formatEther(maxWithdraw as bigint));
    } else if (mode === 'mint' && maxMint) {
      setAmount(formatEther(maxMint as bigint));
    } else if (mode === 'redeem' && maxRedeem) {
      setAmount(formatEther(maxRedeem as bigint));
    }
  };

  const handleApprove = () => {
    if (!amount) return;
    writeContract({
      address: ADDRESSES.HONEY,
      abi: ERC20ABI.abi,
      functionName: 'approve',
      args: [address, parseEther(amount)],
    });
  };

  // Share price is always 1.0 (1:1 with stablecoin for rebasing tokens)
  const sharePrice = 1.0;

  return (
    <div className="bg-white/5 backdrop-blur-sm rounded-xl border border-white/10 overflow-hidden hover:border-white/20 transition-all">
      {/* Header */}
      <div className={`bg-gradient-to-r ${color} p-6`}>
        <div className="flex justify-between items-start">
          <div>
            <h3 className="text-2xl font-bold text-white">{name}</h3>
            <p className="text-white/80 text-sm">{description}</p>
            {isPaused && (
              <span className="inline-block mt-2 px-2 py-1 bg-red-500 text-white text-xs rounded">
                PAUSED
              </span>
            )}
          </div>
          <button
            onClick={() => setShowDetails(!showDetails)}
            className="text-white/60 hover:text-white transition-colors"
          >
            <Activity className="w-5 h-5" />
          </button>
        </div>
      </div>

      {/* Main Stats */}
      <div className="p-6 space-y-4">
        {/* Vault Value (On-Chain) - PROMINENT */}
        <div className="bg-gradient-to-r from-blue-500/20 to-purple-500/20 border border-blue-500/30 rounded-lg p-4">
          <div className="flex justify-between items-center">
            <div className="flex items-center gap-2">
              <Database className="w-5 h-5 text-blue-400" />
              <span className="text-blue-200 font-semibold">Vault Value (On-Chain)</span>
            </div>
            <span className="text-white font-bold text-xl">
              {vaultValue ? `$${parseFloat(formatEther(vaultValue as bigint)).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}` : '$0.00'}
            </span>
          </div>
        </div>

        {/* Backing/Unstaking Ratios - PROMINENT */}
        <div className="grid grid-cols-2 gap-3">
          {/* On-Chain Ratio */}
          <div className="bg-gradient-to-r from-cyan-500/20 to-teal-500/20 border border-cyan-500/30 rounded-lg p-3">
            <div className="text-xs text-cyan-300 mb-1">
              {isSenior ? 'On-Chain Backing' : 'On-Chain Unstaking'}
            </div>
            <div className="text-2xl font-bold text-white">
              {onChainRatio ? `${onChainRatio.toFixed(isSenior ? 2 : 4)}${isSenior ? '%' : 'x'}` : 'N/A'}
            </div>
            <div className="text-xs text-gray-400 mt-1">
              totalAssets() / Supply
            </div>
          </div>
          
          {/* Off-Chain Ratio */}
          <div className="bg-gradient-to-r from-emerald-500/20 to-green-500/20 border border-emerald-500/30 rounded-lg p-3">
            <div className="text-xs text-emerald-300 mb-1">
              {isSenior ? 'Off-Chain Backing' : 'Off-Chain Unstaking'}
            </div>
            <div className="text-2xl font-bold text-white">
              {offChainRatio > 0 ? `${offChainRatio.toFixed(isSenior ? 2 : 4)}${isSenior ? '%' : 'x'}` : 'N/A'}
            </div>
            <div className="text-xs text-gray-400 mt-1">
              (LP×Enso + HONEY) / Supply
            </div>
          </div>
        </div>

        {/* TVL */}
        <div className="flex justify-between items-center">
          <span className="text-gray-400 text-sm">Total Value Locked</span>
          <span className="text-white font-bold text-lg">
            {totalAssets ? `${parseFloat(formatEther(totalAssets as bigint)).toFixed(2)} HONEY` : '...'}
          </span>
        </div>

        {/* Share Price */}
        <div className="flex justify-between items-center">
          <span className="text-gray-400 text-sm">Share Price</span>
          <span className="text-green-400 font-semibold">
            {sharePrice.toFixed(4)} HONEY
          </span>
        </div>

        {/* User Balance */}
        <div className="flex justify-between items-center">
          <span className="text-gray-400 text-sm">Your Balance</span>
          <span className="text-white font-semibold">
            {userBalance ? `${parseFloat(formatEther(userBalance as bigint)).toFixed(4)} ${symbol}` : '0'}
          </span>
        </div>

        {/* Vault HONEY Balance */}
        <div className="flex justify-between items-center">
          <span className="text-gray-400 text-sm">Vault HONEY Balance</span>
          <span className="text-yellow-400 font-semibold">
            {vaultHoneyBalance ? `${parseFloat(formatEther(vaultHoneyBalance as bigint)).toFixed(2)} HONEY` : '0 HONEY'}
          </span>
        </div>

        {/* COMPREHENSIVE ASSET BREAKDOWN - VAULT + HOOK */}
        <div className="bg-gradient-to-br from-blue-500/10 via-purple-500/10 to-green-500/10 backdrop-blur-sm rounded-xl border border-white/20 p-6 space-y-4">
          <h4 className="text-white font-bold text-lg flex items-center gap-2">
            <Database className="w-5 h-5 text-cyan-400" />
            Complete Asset Breakdown
          </h4>
          
          {/* VAULT ASSETS */}
          <div className="space-y-2">
            <div className="text-blue-300 font-semibold text-sm mb-2 border-b border-blue-500/30 pb-1">
              📦 Vault Assets (Idle)
            </div>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
              {/* Vault HONEY */}
              <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-lg p-3">
                <div className="text-yellow-400 text-xs font-semibold mb-1">HONEY</div>
                <div className="text-white text-sm font-bold">
                  {vaultHoneyBalance ? (Number(vaultHoneyBalance) / 1e18).toFixed(2) : '0.00'}
                </div>
                <div className="text-yellow-300 text-xs mt-1">
                  ${vaultHoneyValue.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </div>
              </div>
              
              {/* Vault WBTC */}
              <div className="bg-orange-500/10 border border-orange-500/30 rounded-lg p-3">
                <div className="text-orange-400 text-xs font-semibold mb-1">WBTC</div>
                <div className="text-white text-sm font-bold">
                  {vaultWBTCBalance ? (Number(vaultWBTCBalance) / 1e8).toFixed(8) : '0.00000000'}
                </div>
                <div className="text-orange-300 text-xs mt-1">
                  ${vaultWBTCValue.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </div>
                {wbtcPrice > 0 && (
                  <div className="text-gray-400 text-xs mt-0.5">
                    @ ${wbtcPrice.toLocaleString()}/WBTC
                  </div>
                )}
              </div>
              
              {/* Vault LP */}
              <div className="bg-purple-500/10 border border-purple-500/30 rounded-lg p-3">
                <div className="text-purple-400 text-xs font-semibold mb-1">LP Tokens</div>
                <div className="text-white text-sm font-bold">
                  {vaultLPBalance ? (Number(vaultLPBalance) / 1e18).toFixed(12) : '0.000000000000'}
                </div>
                <div className="text-purple-300 text-xs mt-1">
                  ${vaultLPValue.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </div>
              </div>
            </div>
            <div className="text-right text-sm font-bold text-blue-300 mt-2">
              Vault Total: ${(vaultHoneyValue + vaultWBTCValue + vaultLPValue).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
            </div>
          </div>

          {/* HOOK ASSETS */}
          <div className="space-y-2">
            <div className="text-green-300 font-semibold text-sm mb-2 border-b border-green-500/30 pb-1 flex items-center gap-2">
              <Rocket className="w-4 h-4" />
              🚀 Hook Assets (Deployed to Kodiak)
            </div>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
              {/* Hook HONEY */}
              <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-lg p-3">
                <div className="text-yellow-400 text-xs font-semibold mb-1">HONEY</div>
                <div className="text-white text-sm font-bold">
                  {hookHoneyBalance ? (Number(hookHoneyBalance) / 1e18).toFixed(2) : '0.00'}
                </div>
                <div className="text-yellow-300 text-xs mt-1">
                  ${hookHoneyValue.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </div>
              </div>
              
              {/* Hook WBTC */}
              <div className="bg-orange-500/10 border border-orange-500/30 rounded-lg p-3">
                <div className="text-orange-400 text-xs font-semibold mb-1">WBTC</div>
                <div className="text-white text-sm font-bold">
                  {hookWBTCBalance ? (Number(hookWBTCBalance) / 1e8).toFixed(8) : '0.00000000'}
                </div>
                <div className="text-orange-300 text-xs mt-1">
                  ${hookWBTCValue.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </div>
                {wbtcPrice > 0 && (
                  <div className="text-gray-400 text-xs mt-0.5">
                    @ ${wbtcPrice.toLocaleString()}/WBTC
                  </div>
                )}
              </div>
              
              {/* Hook LP */}
              <div className="bg-purple-500/10 border border-purple-500/30 rounded-lg p-3">
                <div className="text-purple-400 text-xs font-semibold mb-1">LP Tokens</div>
                <div className="text-white text-sm font-bold">
                  {hookLPBalance ? (Number(hookLPBalance) / 1e18).toFixed(12) : '0.000000000000'}
                </div>
                <div className="text-purple-300 text-xs mt-1">
                  ${hookLPValue.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </div>
                {ensoLPPrice && (
                  <div className="text-gray-400 text-xs mt-0.5">
                    @ ${(ensoLPPrice / 1000000).toFixed(2)}M/LP
                  </div>
                )}
              </div>
            </div>
            <div className="text-right text-sm font-bold text-green-300 mt-2">
              Hook Total: ${(hookHoneyValue + hookWBTCValue + hookLPValue).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
            </div>
          </div>

          {/* TOTAL COMBINED TVL */}
          <div className="bg-gradient-to-r from-cyan-500/20 to-emerald-500/20 border-2 border-cyan-500/50 rounded-lg p-4 mt-4">
            <div className="flex justify-between items-center">
              <span className="text-cyan-200 font-bold text-base">🌟 Total Combined TVL</span>
              <span className="text-white font-bold text-2xl">
                ${calculatedValueManual.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </span>
            </div>
            <div className="text-xs text-gray-400 mt-2 flex items-center justify-between">
              <span>Vault + Hook (all assets)</span>
              <span className="text-cyan-300">Prices from Enso API</span>
            </div>
          </div>
        </div>


        {/* Detailed Stats (Collapsible) */}
        {showDetails && (
          <div className="mt-4 pt-4 border-t border-white/10 space-y-3">
            <h4 className="text-white font-semibold text-sm mb-3 flex items-center gap-2">
              <Database className="w-4 h-4" />
              Detailed Information
            </h4>

            {/* Total Supply */}
            <div className="flex justify-between items-center text-sm">
              <span className="text-gray-500">Total Supply</span>
              <span className="text-gray-300 font-mono">
                {totalSupply ? parseFloat(formatEther(totalSupply as bigint)).toFixed(4) : '0'}
              </span>
            </div>

            {/* Vault Value */}
            <div className="flex justify-between items-center text-sm">
              <span className="text-gray-500">Vault Value (Idle)</span>
              <span className="text-gray-300 font-mono">
                {vaultValue ? parseFloat(formatEther(vaultValue as bigint)).toFixed(2) : '0'} HONEY
              </span>
            </div>

            {/* LP Holdings */}
            {lpHoldings && (lpHoldings as any[]).length > 0 && (
              <div className="space-y-2">
                <span className="text-gray-500 text-sm">LP Holdings:</span>
                {(lpHoldings as any[]).map((holding: any, idx: number) => (
                  <div key={idx} className="flex justify-between items-center text-xs bg-white/5 p-2 rounded">
                    <span className="text-gray-400 font-mono">{holding.lpToken?.slice(0, 10)}...</span>
                    <span className="text-green-400">{parseFloat(formatEther(holding.amount || 0n)).toFixed(4)}</span>
                  </div>
                ))}
              </div>
            )}
            {/* Hook Address & Complete State */}
            {kodiakHook && (
              <div className="space-y-2 mt-3 pt-3 border-t border-white/10">
                <div className="flex items-center gap-2 text-sm text-blue-300 font-semibold mb-2">
                  <Link2 className="w-4 h-4" />
                  Kodiak Hook State
                </div>
                
                {/* Hook Address */}
                <div className="flex justify-between items-center text-xs">
                  <span className="text-gray-500">Contract:</span>
                  <a 
                    href={`https://artio.beratrail.io/address/${kodiakHook}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-blue-400 hover:text-blue-300 font-mono underline"
                  >
                    {(kodiakHook as string)?.slice(0, 8)}...{(kodiakHook as string)?.slice(-6)}
                  </a>
                </div>

                {/* Hook Admin */}
                {hookAdmin && (
                  <div className="flex justify-between items-center text-xs">
                    <span className="text-gray-500">Hook Admin:</span>
                    <span className="text-pink-400 font-mono">
                      {(hookAdmin as string)?.slice(0, 6)}...{(hookAdmin as string)?.slice(-4)}
                    </span>
                  </div>
                )}

                {/* Connected Vault */}
                {hookVault && (
                  <div className="flex justify-between items-center text-xs">
                    <span className="text-gray-500">Connected To:</span>
                    <span className={`font-mono ${(hookVault as string).toLowerCase() === address.toLowerCase() ? 'text-green-400' : 'text-orange-400'}`}>
                      {(hookVault as string).toLowerCase() === address.toLowerCase() ? '✓ This Vault' : 'Other Vault'}
                    </span>
                  </div>
                )}

                {/* Kodiak Router */}
                {hookRouter && (
                  <div className="flex justify-between items-center text-xs">
                    <span className="text-gray-500">Kodiak Router:</span>
                    <span className="text-cyan-400 font-mono">
                      {(hookRouter as string)?.slice(0, 6)}...{(hookRouter as string)?.slice(-4)}
                    </span>
                  </div>
                )}

                {/* Kodiak Island */}
                {hookIsland && (
                  <div className="flex justify-between items-center text-xs">
                    <span className="text-gray-500">Kodiak Island:</span>
                    <span className="text-purple-400 font-mono">
                      {(hookIsland as string)?.slice(0, 6)}...{(hookIsland as string)?.slice(-4)}
                    </span>
                  </div>
                )}

                {/* Hook Balances */}
                <div className="bg-blue-500/10 border border-blue-500/20 rounded p-2 space-y-1 mt-2">
                  <div className="text-xs text-blue-300 font-semibold">Hook Balances:</div>
                  <div className="flex justify-between items-center text-xs">
                    <span className="text-gray-400">HONEY:</span>
                    <span className="text-yellow-400 font-mono">
                      {hookHoneyBalance ? `${parseFloat(formatEther(hookHoneyBalance as bigint)).toFixed(4)}` : '0.0000'}
                    </span>
                  </div>
                  <div className="flex justify-between items-center text-xs">
                    <span className="text-gray-400">Kodiak LP:</span>
                    <div className="flex flex-col items-end">
                      <span className="text-purple-400 font-mono text-xs">
                        {hookLPBalance ? `${parseFloat(formatEther(hookLPBalance as bigint)).toFixed(18)}` : '0.000000000000000000'}
                      </span>
                      {hookLPBalance && ensoLPPrice && (
                        <span className="text-green-400 font-bold text-xs">
                          ≈ ${(parseFloat(formatEther(hookLPBalance as bigint)) * ensoLPPrice).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                        </span>
                      )}
                    </div>
                  </div>
                  {ensoLPPrice && (
                    <div className="flex justify-between items-center text-xs pt-1 border-t border-blue-500/20">
                      <span className="text-gray-400">LP Price (Enso):</span>
                      <span className="text-green-400 font-mono font-semibold">
                        ${ensoLPPrice.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                      </span>
                    </div>
                  )}
                </div>

                {/* Hook Status Indicator */}
                <div className="flex items-center justify-center gap-2 text-xs mt-2 p-2 bg-green-500/10 border border-green-500/20 rounded">
                  <Shield className="w-3 h-3 text-green-400" />
                  <span className="text-green-400 font-semibold">Hook Active & Connected</span>
                </div>
              </div>
            )}

            {/* Senior Vault Reference */}
            {seniorVault && (
              <div className="flex justify-between items-center text-sm">
                <span className="text-gray-500">Senior Vault</span>
                <span className="text-cyan-400 font-mono text-xs">{(seniorVault as string)?.slice(0, 10)}...</span>
              </div>
            )}

            {/* Contract Address */}
            <div className="flex justify-between items-center text-sm">
              <span className="text-gray-500">Contract</span>
              <a 
                href={`https://artio.beratrail.io/address/${address}`}
                target="_blank"
                rel="noopener noreferrer"
                className="text-purple-400 hover:text-purple-300 font-mono text-xs underline"
              >
                {address.slice(0, 6)}...{address.slice(-4)}
              </a>
            </div>
          </div>
        )}

        {/* Mode Toggle */}
        <div className="space-y-2 mt-4">
          <div className="flex rounded-lg overflow-hidden border border-white/10">
          <button
            onClick={() => setMode('deposit')}
            className={`flex-1 py-2 text-sm font-semibold transition-colors ${
              mode === 'deposit' ? 'bg-purple-600 text-white' : 'bg-transparent text-gray-400'
            }`}
          >
            Deposit
          </button>
          <button
            onClick={() => setMode('withdraw')}
            className={`flex-1 py-2 text-sm font-semibold transition-colors ${
              mode === 'withdraw' ? 'bg-purple-600 text-white' : 'bg-transparent text-gray-400'
            }`}
          >
            Withdraw
          </button>
          </div>
          
          {/* Advanced Toggle */}
          <button
            onClick={() => setShowAdvanced(!showAdvanced)}
            className="w-full text-xs text-gray-400 hover:text-gray-300 py-1"
          >
            {showAdvanced ? '▼' : '▶'} Advanced (Mint/Redeem)
          </button>
          
          {/* Advanced Mode Toggle */}
          {showAdvanced && (
            <div className="flex rounded-lg overflow-hidden border border-white/10">
              <button
                onClick={() => setMode('mint')}
                className={`flex-1 py-2 text-sm font-semibold transition-colors ${
                  mode === 'mint' ? 'bg-green-600 text-white' : 'bg-transparent text-gray-400'
                }`}
              >
                Mint
              </button>
              <button
                onClick={() => setMode('redeem')}
                className={`flex-1 py-2 text-sm font-semibold transition-colors ${
                  mode === 'redeem' ? 'bg-orange-600 text-white' : 'bg-transparent text-gray-400'
                }`}
              >
                Redeem
              </button>
            </div>
          )}
        </div>

        {/* Input */}
        <div className="space-y-2">
          <div className="flex space-x-2">
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
              placeholder={
                mode === 'deposit' ? 'Amount in HONEY' :
                mode === 'withdraw' ? 'Amount in HONEY' :
                mode === 'mint' ? 'Shares to mint' :
                'Shares to redeem'
              }
              className="flex-1 px-4 py-3 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-purple-500"
            />
            <button
              onClick={handleSetMax}
              className="px-4 py-3 bg-white/5 border border-white/10 rounded-lg text-gray-400 hover:text-white hover:bg-white/10 transition-colors text-sm font-semibold"
            >
              MAX
            </button>
          </div>
          
          {/* Preview Info */}
          {amount && (
            <div className="bg-blue-500/10 border border-blue-500/20 rounded-lg p-3 text-xs space-y-1">
              {mode === 'deposit' && previewDepositData && (
                <div className="flex justify-between text-blue-300">
                  <span>You'll receive:</span>
                  <span className="font-semibold">{parseFloat(formatEther(previewDepositData as bigint)).toFixed(4)} {symbol}</span>
                </div>
              )}
              {mode === 'withdraw' && previewWithdrawData && (
                <div className="flex justify-between text-blue-300">
                  <span>Shares needed:</span>
                  <span className="font-semibold">{parseFloat(formatEther(previewWithdrawData as bigint)).toFixed(4)} {symbol}</span>
                </div>
              )}
              {mode === 'mint' && previewMintData && (
                <div className="flex justify-between text-blue-300">
                  <span>Assets needed:</span>
                  <span className="font-semibold">{parseFloat(formatEther(previewMintData as bigint)).toFixed(4)} HONEY</span>
                </div>
              )}
              {mode === 'redeem' && previewRedeemData && (
                <div className="flex justify-between text-blue-300">
                  <span>You'll receive:</span>
                  <span className="font-semibold">{parseFloat(formatEther(previewRedeemData as bigint)).toFixed(4)} HONEY</span>
                </div>
              )}
            </div>
          )}
          
          {/* Max Limits */}
          <div className="flex justify-between text-xs text-gray-500">
            <span>
              {mode === 'deposit' && maxDeposit && `Max Deposit: ${parseFloat(formatEther(maxDeposit as bigint)).toFixed(2)} HONEY`}
              {mode === 'withdraw' && maxWithdraw && `Max Withdraw: ${parseFloat(formatEther(maxWithdraw as bigint)).toFixed(2)} HONEY`}
              {mode === 'mint' && maxMint && `Max Mint: ${parseFloat(formatEther(maxMint as bigint)).toFixed(2)} shares`}
              {mode === 'redeem' && maxRedeem && `Max Redeem: ${parseFloat(formatEther(maxRedeem as bigint)).toFixed(2)} shares`}
            </span>
          </div>
        </div>

        {/* Senior Vault Cooldown Section */}
        {isSenior && mode === 'withdraw' && userAddress && (
          <div className="space-y-3">
            {/* Cooldown Status */}
            <div className={`border rounded-lg p-4 ${
              canWithdrawWithoutPenalty 
                ? 'bg-green-500/10 border-green-500/30' 
                : Number(cooldownStart) === 0
                ? 'bg-yellow-500/10 border-yellow-500/30'
                : 'bg-orange-500/10 border-orange-500/30'
            }`}>
              <div className="flex justify-between items-center mb-2">
                <span className="text-sm font-semibold">
                  {canWithdrawWithoutPenalty ? '✅ Cooldown Complete' : Number(cooldownStart) === 0 ? '⏰ Cooldown Not Started' : '⏳ Cooldown Active'}
                </span>
                {!canWithdrawWithoutPenalty && Number(cooldownStart) > 0 && (
                  <span className="text-xs font-mono bg-black/30 px-2 py-1 rounded">
                    {timeRemaining}
                  </span>
                )}
              </div>
              
              {Number(cooldownStart) === 0 && (
                <div className="space-y-2">
                  <p className="text-xs text-gray-300">
                    To avoid the 5% early withdrawal penalty, initiate cooldown and wait 7 days.
                  </p>
                  <button
                    onClick={handleInitiateCooldown}
                    disabled={isConfirming}
                    className="w-full py-2 bg-gradient-to-r from-blue-600 to-cyan-600 hover:from-blue-700 hover:to-cyan-700 text-white rounded-lg font-semibold text-sm disabled:opacity-50"
                  >
                    {isConfirming ? 'Processing...' : '🕐 Start Cooldown (7 Days)'}
                  </button>
                </div>
              )}
              
              {!canWithdrawWithoutPenalty && Number(cooldownStart) > 0 && (
                <p className="text-xs text-gray-300">
                  Wait {timeRemaining} to withdraw penalty-free, or withdraw now with 5% penalty.
                </p>
              )}
              
              {canWithdrawWithoutPenalty && (
                <p className="text-xs text-green-300">
                  You can now withdraw penalty-free! No fees will be charged.
                </p>
              )}
            </div>

            {/* Penalty Warning */}
            {!canWithdrawWithoutPenalty && amount && withdrawalPenalty && (
              <div className="bg-red-500/10 border border-red-500/30 rounded-lg p-3 space-y-2">
                <div className="flex justify-between items-center text-sm">
                  <span className="text-red-300 font-semibold">⚠️ Early Withdrawal Penalty:</span>
                  <span className="text-red-400 font-bold">
                    {parseFloat(formatEther((withdrawalPenalty as any)[0] || 0n)).toFixed(4)} HONEY (5%)
                  </span>
                </div>
                <div className="flex justify-between items-center text-xs border-t border-red-500/20 pt-2">
                  <span className="text-gray-400">You'll receive:</span>
                  <span className="text-white font-semibold">
                    {parseFloat(formatEther((withdrawalPenalty as any)[1] || 0n)).toFixed(4)} HONEY
                  </span>
                </div>
                <p className="text-xs text-gray-400 mt-1">
                  💡 Tip: Initiate cooldown and wait 7 days to avoid this penalty!
                </p>
              </div>
            )}
          </div>
        )}

        {/* Approve Button (if needed for deposit/mint) */}
        {needsApproval && (
          <button
            onClick={handleApprove}
            disabled={isConfirming || !amount}
            className="w-full py-3 rounded-lg font-semibold transition-all flex items-center justify-center space-x-2 bg-gradient-to-r from-yellow-600 to-orange-600 hover:from-yellow-700 hover:to-orange-700 text-white disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isConfirming ? (
              <span>Processing...</span>
            ) : (
              <>
                <CheckCircle className="w-5 h-5" />
                <span>Approve HONEY (Step 1)</span>
              </>
            )}
          </button>
        )}

        {/* Action Button */}
        <button
          onClick={
            mode === 'deposit' ? handleDeposit :
            mode === 'withdraw' ? handleWithdraw :
            mode === 'mint' ? handleMint :
            handleRedeem
          }
          disabled={isConfirming || !amount || isPaused as boolean || needsApproval as boolean}
          className={`w-full py-3 rounded-lg font-semibold transition-all flex items-center justify-center space-x-2 ${
            mode === 'deposit'
              ? 'bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700'
              : mode === 'withdraw'
              ? 'bg-gradient-to-r from-red-600 to-orange-600 hover:from-red-700 hover:to-orange-700'
              : mode === 'mint'
              ? 'bg-gradient-to-r from-green-600 to-emerald-600 hover:from-green-700 hover:to-emerald-700'
              : 'bg-gradient-to-r from-orange-600 to-yellow-600 hover:from-orange-700 hover:to-yellow-700'
          } text-white disabled:opacity-50 disabled:cursor-not-allowed`}
        >
          {isConfirming ? (
            <span>Processing...</span>
          ) : isPaused ? (
            <span>Vault Paused</span>
          ) : needsApproval ? (
            <span>Approve First ☝️</span>
          ) : mode === 'deposit' ? (
            <>
              <ArrowDownToLine className="w-5 h-5" />
              <span>Deposit</span>
            </>
          ) : mode === 'withdraw' ? (
            <>
              <ArrowUpFromLine className="w-5 h-5" />
              <span>Withdraw</span>
            </>
          ) : mode === 'mint' ? (
            <>
              <ArrowDownToLine className="w-5 h-5" />
              <span>Mint Shares</span>
            </>
          ) : (
            <>
              <ArrowUpFromLine className="w-5 h-5" />
              <span>Redeem Shares</span>
            </>
          )}
        </button>
        
        {/* Mode Explanations */}
        <div className="text-xs text-gray-500 mt-2">
          {mode === 'deposit' && <p>💡 Deposit HONEY to receive vault shares</p>}
          {mode === 'withdraw' && <p>💡 Withdraw HONEY by burning shares (may vary based on share price)</p>}
          {mode === 'mint' && <p>💡 Mint exact amount of shares by depositing HONEY</p>}
          {mode === 'redeem' && <p>💡 Redeem exact amount of shares to receive HONEY</p>}
        </div>
      </div>
    </div>
  );
}
