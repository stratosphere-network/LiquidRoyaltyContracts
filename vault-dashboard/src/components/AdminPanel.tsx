import { useState, useEffect } from 'react';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { formatEther, parseEther } from 'viem';
import { Shield, Settings, AlertCircle, CheckCircle, Network, DollarSign, List, Globe, Rocket, UserPlus, Clock, Zap, Calculator, RefreshCw } from 'lucide-react';
import SeniorVaultABI from '../contracts/abi/UnifiedConcreteSeniorVault.json';
import HookABI from '../contracts/abi/KodiakVaultHook.json';
import ERC20ABI from '../contracts/abi/MockERC20.json';
import { ADDRESSES } from '../contracts/addresses';
import { calculateMinLPTokensLive, getKodiakDeploySwapData, getWBTCToHoneySwapData, getWBTCPrice, getTokenPrice } from '../utils/ensoHelper';

type AdminAction = 'pause' | 'rebase' | 'setvaultvalue' | 'kodiak' | 'whitelist' | 'oracle' | 'admin' | 'emergency';

export function AdminPanel() {
  const { address: userAddress } = useAccount();
  const [selectedVault, setSelectedVault] = useState<'senior' | 'junior' | 'reserve'>('senior');
  const [actionType, setActionType] = useState<AdminAction>('pause');
  const [inputValue, setInputValue] = useState('');
  const [inputValue2, setInputValue2] = useState('');
  const [inputValue3, setInputValue3] = useState('');
  const [inputValue4, setInputValue4] = useState('');
  const [inputValue5, setInputValue5] = useState('');
  const [inputValue6, setInputValue6] = useState('');
  const [inputValue7, setInputValue7] = useState('0x5f41cF4eB62f8A7F46B00e8C51F44C0E3A95c68c'); // Enso aggregator
  const [inputValue8, setInputValue8] = useState(''); // WBTC amount for dust management
  const [inputValue9, setInputValue9] = useState(''); // Swap data for dust management
  const [inputValue10, setInputValue10] = useState(''); // Aggregator address for dust management
  const [rebaseIntervalValue, setRebaseIntervalValue] = useState(''); // Separate state for rebase interval
  const [boolValue1, setBoolValue1] = useState(false);
  const [boolValue2, setBoolValue2] = useState(false);
  const [boolValue3, setBoolValue3] = useState(false);
  const [isCalculating, setIsCalculating] = useState(false);
  const [calculationError, setCalculationError] = useState<string>('');
  const [isFetchingSwapData, setIsFetchingSwapData] = useState(false);
  const [swapDataError, setSwapDataError] = useState<string>('');
  const [expectedHoneyOut, setExpectedHoneyOut] = useState<string>('');
  const [wbtcPrice, setWBTCPrice] = useState<number>(0);
  const [lpPrice, setLPPrice] = useState<number>(0);
  const [hookTVL, setHookTVL] = useState<{wbtc: number, honey: number, lp: number, total: number}>({ wbtc: 0, honey: 0, lp: 0, total: 0});

  const vaultAddress = 
    selectedVault === 'senior' ? ADDRESSES.SENIOR_VAULT :
    selectedVault === 'junior' ? ADDRESSES.JUNIOR_VAULT :
    ADDRESSES.RESERVE_VAULT;

  const hookAddress =
    selectedVault === 'senior' ? ADDRESSES.SENIOR_HOOK :
    selectedVault === 'junior' ? ADDRESSES.JUNIOR_HOOK :
    ADDRESSES.RESERVE_HOOK;

  // Read vault admin data
  const { data: admin } = useReadContract({
    address: vaultAddress,
    abi: SeniorVaultABI.abi,
    functionName: 'admin',
  });

  const { data: isPaused } = useReadContract({
    address: vaultAddress,
    abi: SeniorVaultABI.abi,
    functionName: 'paused',
  });

  // Read rebase data
  const { data: minRebaseInterval } = useReadContract({
    address: vaultAddress,
    abi: SeniorVaultABI.abi,
    functionName: 'minRebaseInterval',
  });

  const { data: lastRebaseTime } = useReadContract({
    address: vaultAddress,
    abi: SeniorVaultABI.abi,
    functionName: 'lastRebaseTime',
  });

  const { data: rebaseIndex } = useReadContract({
    address: vaultAddress,
    abi: SeniorVaultABI.abi,
    functionName: 'rebaseIndex',
  });

  const { data: seniorVault } = useReadContract({
    address: vaultAddress,
    abi: SeniorVaultABI.abi,
    functionName: 'seniorVault',
  });

  const { data: juniorVault } = useReadContract({
    address: vaultAddress,
    abi: SeniorVaultABI.abi,
    functionName: 'juniorVault',
  });

  const { data: reserveVault } = useReadContract({
    address: vaultAddress,
    abi: SeniorVaultABI.abi,
    functionName: 'reserveVault',
  });

  const { data: treasury } = useReadContract({
    address: vaultAddress,
    abi: SeniorVaultABI.abi,
    functionName: 'treasury',
  });

  const { data: whitelistedLPTokens } = useReadContract({
    address: vaultAddress,
    abi: SeniorVaultABI.abi,
    functionName: 'getWhitelistedLPTokens',
  });

  const { data: whitelistedProtocols } = useReadContract({
    address: vaultAddress,
    abi: SeniorVaultABI.abi,
    functionName: 'getWhitelistedLPs',
  });

  const { data: oracleConfig } = useReadContract({
    address: vaultAddress,
    abi: SeniorVaultABI.abi,
    functionName: 'getOracleConfig',
  });

  const { data: lpHoldings } = useReadContract({
    address: vaultAddress,
    abi: SeniorVaultABI.abi,
    functionName: 'getLPHoldings',
  });

  const { data: totalAssets } = useReadContract({
    address: vaultAddress,
    abi: SeniorVaultABI.abi,
    functionName: 'totalAssets',
  });

  // Check if Enso aggregator is whitelisted
  const { data: isEnsoWhitelisted, refetch: refetchWhitelist } = useReadContract({
    address: hookAddress,
    abi: HookABI.abi,
    functionName: 'whitelistedAggregators',
    args: ['0x5f41cF4eB62f8A7F46B00e8C51F44C0E3A95c68c' as `0x${string}`],
  });

  const { data: vaultValue } = useReadContract({
    address: vaultAddress,
    abi: SeniorVaultABI.abi,
    functionName: 'getVaultValue',
  });

  const { data: calculatedValue } = useReadContract({
    address: vaultAddress,
    abi: SeniorVaultABI.abi,
    functionName: 'getCalculatedVaultValue',
  });

  // Read hook data
  const { data: kodiakRouter } = useReadContract({
    address: hookAddress,
    abi: HookABI.abi,
    functionName: 'kodiakRouter',
  });

  const { data: kodiakIsland } = useReadContract({
    address: hookAddress,
    abi: HookABI.abi,
    functionName: 'kodiakIsland',
  });

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

  // Hook balance tracking
  const { data: hookWBTCBalance } = useReadContract({
    address: ADDRESSES.WBTC,
    abi: ERC20ABI.abi,
    functionName: 'balanceOf',
    args: [hookAddress],
  });

  const { data: hookHONEYBalance } = useReadContract({
    address: ADDRESSES.HONEY,
    abi: ERC20ABI.abi,
    functionName: 'balanceOf',
    args: [hookAddress],
  });

  const { data: hookLPBalance } = useReadContract({
    address: ADDRESSES.KODIAK_ISLAND,
    abi: ERC20ABI.abi,
    functionName: 'balanceOf',
    args: [hookAddress],
  });

  const { writeContract, data: hash } = useWriteContract();
  const { isLoading: isConfirming } = useWaitForTransactionReceipt({ hash });

  const isAdmin = userAddress && admin && userAddress.toLowerCase() === (admin as string).toLowerCase();

  // Fetch prices and calculate hook TVL
  useEffect(() => {
    const fetchPricesAndCalculateTVL = async () => {
      try {
        // Fetch WBTC and LP prices
        const [wbtcPriceVal, lpPriceVal] = await Promise.all([
          getWBTCPrice(),
          getTokenPrice(80094, ADDRESSES.KODIAK_ISLAND).then(p => p.price).catch(() => 60000000) // Fallback to ~$60M/LP
        ]);

        setWBTCPrice(wbtcPriceVal);
        setLPPrice(lpPriceVal);

        // Calculate TVL
        if (hookWBTCBalance && hookHONEYBalance && hookLPBalance) {
          const wbtcValue = (Number(hookWBTCBalance) / 1e8) * wbtcPriceVal;
          const honeyValue = Number(hookHONEYBalance) / 1e18; // Assume HONEY = $1
          const lpValue = (Number(hookLPBalance) / 1e18) * lpPriceVal;
          const totalValue = wbtcValue + honeyValue + lpValue;

          setHookTVL({
            wbtc: wbtcValue,
            honey: honeyValue,
            lp: lpValue,
            total: totalValue
          });
        }
      } catch (error) {
        console.error('Error fetching prices:', error);
      }
    };

    if (hookWBTCBalance !== undefined && hookHONEYBalance !== undefined && hookLPBalance !== undefined) {
      fetchPricesAndCalculateTVL();
    }
  }, [hookWBTCBalance, hookHONEYBalance, hookLPBalance]);

  const handlePause = () => {
    writeContract({
      address: vaultAddress,
      abi: SeniorVaultABI.abi,
      functionName: 'pause',
    });
  };

  const handleUnpause = () => {
    writeContract({
      address: vaultAddress,
      abi: SeniorVaultABI.abi,
      functionName: 'unpause',
    });
  };

  // Fetch LP price from Enso for rebase
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
        
        // Auto-fill the input field with Enso price when it loads
        // Only if input is empty (don't overwrite user's manual input)
        if (!inputValue && actionType === 'rebase') {
          setInputValue(data.price.toString());
        }
      } catch (error) {
        console.error('Error fetching Enso LP price:', error);
      }
    };
    
    fetchEnsoPrice();
    const interval = setInterval(fetchEnsoPrice, 30000);
    return () => clearInterval(interval);
  }, [actionType]);
  
  // Auto-fill input when switching to rebase tab
  useEffect(() => {
    if (actionType === 'rebase' && ensoLPPrice && !inputValue) {
      setInputValue(ensoLPPrice.toString());
    }
  }, [actionType, ensoLPPrice]);

  const handleRebase = () => {
    // ALWAYS use manual LP price from Enso (oracle is not configured!)
    const lpPriceToUse = inputValue && parseFloat(inputValue) > 0 
      ? inputValue 
      : (ensoLPPrice ? ensoLPPrice.toString() : null);
    
    if (!lpPriceToUse) {
      alert('LP price not available! Please wait or enter manually.');
      return;
    }
    
    const lpPriceWei = parseEther(lpPriceToUse);
    writeContract({
      address: vaultAddress,
      abi: SeniorVaultABI.abi,
      functionName: 'rebase',
      args: [lpPriceWei],
    });
  };

  const handleSetVaultValue = () => {
    if (!inputValue) return;
    writeContract({
      address: vaultAddress,
      abi: SeniorVaultABI.abi,
      functionName: 'setVaultValue',
      args: [parseEther(inputValue)],
    });
  };

  const handleWhitelistLP = () => {
    if (!inputValue) return;
    writeContract({
      address: vaultAddress,
      abi: SeniorVaultABI.abi,
      functionName: 'addWhitelistedLPToken',
      args: [inputValue as `0x${string}`],
    });
  };

  const handleRemoveWhitelistLPToken = () => {
    if (!inputValue) return;
    writeContract({
      address: vaultAddress,
      abi: SeniorVaultABI.abi,
      functionName: 'removeWhitelistedLPToken',
      args: [inputValue as `0x${string}`],
    });
  };

  const handleAddWhitelistLP = () => {
    if (!inputValue) return;
    writeContract({
      address: vaultAddress,
      abi: SeniorVaultABI.abi,
      functionName: 'addWhitelistedLP',
      args: [inputValue as `0x${string}`],
    });
  };

  const handleRemoveWhitelistLP = () => {
    if (!inputValue) return;
    writeContract({
      address: vaultAddress,
      abi: SeniorVaultABI.abi,
      functionName: 'removeWhitelistedLP',
      args: [inputValue as `0x${string}`],
    });
  };

  const handleAddWhitelistDepositor = () => {
    if (!inputValue) return;
    writeContract({
      address: vaultAddress,
      abi: SeniorVaultABI.abi,
      functionName: 'addWhitelistedDepositor',
      args: [inputValue as `0x${string}`],
    });
  };

  const handleRemoveWhitelistDepositor = () => {
    if (!inputValue) return;
    writeContract({
      address: vaultAddress,
      abi: SeniorVaultABI.abi,
      functionName: 'removeWhitelistedDepositor',
      args: [inputValue as `0x${string}`],
    });
  };

  const handleWhitelistAggregator = () => {
    console.log('🔧 Whitelist button clicked!');
    console.log('Input value7:', inputValue7);
    console.log('Hook address:', hookAddress);
    console.log('User address:', userAddress);
    console.log('Hook admin:', hookAdmin);
    
    if (!inputValue7) {
      console.error('❌ No aggregator address provided');
      return;
    }
    
    console.log('✅ Calling writeContract...');
    writeContract({
      address: hookAddress,
      abi: HookABI.abi,
      functionName: 'setAggregatorWhitelisted',
      args: [
        inputValue7 as `0x${string}`, // aggregator address
        true, // whitelist = true
      ],
    });
  };

  const handleDeployToKodiak = () => {
    if (!inputValue || !inputValue2) return;
    writeContract({
      address: vaultAddress,
      abi: SeniorVaultABI.abi,
      functionName: 'deployToKodiak',
      args: [
        parseEther(inputValue), // amount
        parseEther(inputValue2), // minLPTokens
        (inputValue3 || '0x0000000000000000000000000000000000000000') as `0x${string}`, // swapToToken0Aggregator
        inputValue4 || '0x', // swapToToken0Data
        (inputValue5 || '0x0000000000000000000000000000000000000000') as `0x${string}`, // swapToToken1Aggregator
        inputValue6 || '0x', // swapToToken1Data
      ],
    });
  };

  const handleWithdrawLPTokens = () => {
    if (!inputValue || !inputValue2 || !inputValue3 || !inputValue4) return;
    writeContract({
      address: vaultAddress,
      abi: SeniorVaultABI.abi,
      functionName: 'withdrawLPTokens',
      args: [
        inputValue as `0x${string}`, // lpToken
        inputValue2 as `0x${string}`, // lp (protocol address)
        parseEther(inputValue3), // amount
        parseEther(inputValue4), // minStablecoinOut
        (inputValue5 || '0x0000000000000000000000000000000000000000') as `0x${string}`, // swapAggregator
        inputValue6 || '0x', // swapData
      ],
    });
  };

  // Hook Dust Management
  const handleRescueHoneyToVault = () => {
    const hookAddress = vaultName === 'Senior' ? ADDRESSES.SENIOR_HOOK : 
                       vaultName === 'Junior' ? ADDRESSES.JUNIOR_HOOK : 
                       ADDRESSES.RESERVE_HOOK;
    writeContract({
      address: hookAddress,
      abi: HookABI.abi,
      functionName: 'adminRescueTokens',
      args: [
        ADDRESSES.HONEY, // token
        vaultAddress, // to (vault)
        0n, // amount (0 = all)
      ],
    });
  };

  // Fetch WBTC → HONEY swap data from Enso
  const handleFetchSwapData = async () => {
    if (!inputValue8) {
      setSwapDataError('Please enter WBTC amount first');
      return;
    }

    const hookAddress = selectedVault === 'senior' ? ADDRESSES.SENIOR_HOOK : 
                       selectedVault === 'junior' ? ADDRESSES.JUNIOR_HOOK : 
                       ADDRESSES.RESERVE_HOOK;
    
    setIsFetchingSwapData(true);
    setSwapDataError('');
    setExpectedHoneyOut('');

    try {
      console.log('🔄 Fetching swap data from Enso...');
      const result = await getWBTCToHoneySwapData(inputValue8, hookAddress);
      
      if (result.success && result.swapData && result.aggregator) {
        // Auto-fill the form
        setInputValue9(result.swapData);
        setInputValue10(result.aggregator);
        setExpectedHoneyOut((parseFloat(result.expectedHoneyOut) / 1e18).toFixed(6));
        console.log('✅ Swap data fetched successfully!');
      } else {
        setSwapDataError(result.error || 'Failed to fetch swap data');
      }
    } catch (error) {
      console.error('❌ Error fetching swap data:', error);
      setSwapDataError(error instanceof Error ? error.message : 'Unknown error');
    } finally {
      setIsFetchingSwapData(false);
    }
  };

  const handleSwapWBTCToVault = () => {
    if (!inputValue8 || !inputValue9) return;
    const hookAddress = selectedVault === 'senior' ? ADDRESSES.SENIOR_HOOK : 
                       selectedVault === 'junior' ? ADDRESSES.JUNIOR_HOOK : 
                       ADDRESSES.RESERVE_HOOK;
    // Parse WBTC amount (8 decimals)
    const wbtcAmount = BigInt(Math.floor(parseFloat(inputValue8) * 1e8));
    writeContract({
      address: hookAddress,
      abi: HookABI.abi,
      functionName: 'adminSwapAndReturnToVault',
      args: [
        ADDRESSES.WBTC, // tokenIn
        wbtcAmount, // amountIn (in WBTC 8 decimals)
        inputValue9 as `0x${string}`, // swapData (from Enso API)
        (inputValue10 || ADDRESSES.ENSO_AGGREGATOR) as `0x${string}`, // aggregator
      ],
    });
  };

  const handleEmergencyWithdraw = () => {
    if (!inputValue) return;
    writeContract({
      address: vaultAddress,
      abi: SeniorVaultABI.abi,
      functionName: 'emergencyWithdraw',
      args: [parseEther(inputValue)],
      gas: 1500000n, // Increased gas limit for LP liquidation + HONEY transfer
    });
  };

  const handleConfigureOracle = () => {
    if (!inputValue || !inputValue2) {
      console.error('Missing required inputs:', { inputValue, inputValue2 });
      alert('Please fill in Island Address and Max Deviation BPS');
      return;
    }
    
    const config = {
      island: inputValue,
      stablecoinIsToken0: boolValue1,
      maxDeviationBps: inputValue2,
      enableValidation: boolValue2,
      useCalculatedValue: boolValue3,
    };
    
    console.log('🔧 Configuring Oracle with:', config);
    console.log('📍 Vault Address:', vaultAddress);
    console.log('Args:', [
      inputValue as `0x${string}`,
      boolValue1,
      BigInt(inputValue2),
      boolValue2,
      boolValue3,
    ]);
    
    try {
      writeContract({
        address: vaultAddress,
        abi: SeniorVaultABI.abi,
        functionName: 'configureOracle',
        args: [
          inputValue as `0x${string}`, // island
          boolValue1, // stablecoinIsToken0
          BigInt(inputValue2), // maxDeviationBps
          boolValue2, // enableValidation
          boolValue3, // useCalculatedValue
        ],
      });
      console.log('✅ Transaction sent!');
    } catch (error) {
      console.error('❌ Transaction failed:', error);
      alert('Transaction failed: ' + (error as Error).message);
    }
  };

  const handleSetKodiakHook = () => {
    if (!inputValue) return;
    writeContract({
      address: vaultAddress,
      abi: SeniorVaultABI.abi,
      functionName: 'setKodiakHook',
      args: [inputValue as `0x${string}`],
    });
  };

  const handleTransferAdmin = () => {
    if (!inputValue) return;
    writeContract({
      address: vaultAddress,
      abi: SeniorVaultABI.abi,
      functionName: 'transferAdmin',
      args: [inputValue as `0x${string}`],
    });
  };

  const handleSetMinRebaseInterval = () => {
    if (!rebaseIntervalValue) return;
    writeContract({
      address: vaultAddress,
      abi: SeniorVaultABI.abi,
      functionName: 'setMinRebaseInterval',
      args: [BigInt(rebaseIntervalValue)],
    });
  };

  const handleUpdateJuniorReserve = () => {
    if (!inputValue || !inputValue2) return;
    writeContract({
      address: vaultAddress,
      abi: SeniorVaultABI.abi,
      functionName: 'updateJuniorReserve',
      args: [
        inputValue as `0x${string}`, // junior
        inputValue2 as `0x${string}`, // reserve
      ],
    });
  };

  const handleSweepToKodiak = () => {
    if (!inputValue) return;
    writeContract({
      address: vaultAddress,
      abi: SeniorVaultABI.abi,
      functionName: 'sweepToKodiak',
      args: [parseEther(inputValue)],
    });
  };

  const handleInvestInLP = () => {
    if (!inputValue || !inputValue2) return;
    writeContract({
      address: vaultAddress,
      abi: SeniorVaultABI.abi,
      functionName: 'investInLP',
      args: [
        inputValue as `0x${string}`, // lpToken
        parseEther(inputValue2), // amount
      ],
    });
  };

  const handleAutoCalculateMinLP = async () => {
    if (!inputValue) {
      setCalculationError('Please enter HONEY amount first');
      return;
    }

    setIsCalculating(true);
    setCalculationError('');

    try {
      console.log('🧮 Auto-calculating min LP tokens...');
      
      const result = await calculateMinLPTokensLive(
        inputValue,  // HONEY amount
        1000         // 10% slippage
      );

      console.log('✅ Calculation complete:', result);
      
      // Set inputValue2 to the calculated minLPTokens
      setInputValue2(result.minLPTokens);
      
      // Show success message briefly
      setCalculationError(`✅ Calculated! Expected: ${parseFloat(result.expectedLPTokens).toFixed(10)} LP (Price: $${result.lpPrice.toLocaleString()})`);
      
      setTimeout(() => setCalculationError(''), 5000);
    } catch (error) {
      console.error('❌ Calculation failed:', error);
      setCalculationError(`Error: ${error instanceof Error ? error.message : 'Failed to calculate'}`);
    } finally {
      setIsCalculating(false);
    }
  };

  const handleAutoFillAll = async () => {
    if (!inputValue) {
      setCalculationError('Please enter HONEY amount first');
      return;
    }

    setIsCalculating(true);
    setCalculationError('');

    try {
      console.log('🚀 Auto-filling ALL parameters from Enso...');
      
      // Get swap route and min LP tokens
      const result = await getKodiakDeploySwapData(
        inputValue,
        hookAddress
      );

      if (!result.success) {
        throw new Error(result.error || 'Failed to get route');
      }

      console.log('✅ Enso route received:', result);
      
      // Calculate min LP tokens (20% slippage for better success rate)
      const minLPResult = await calculateMinLPTokensLive(inputValue, 2000);
      
      // Auto-fill ALL fields!
      setInputValue2(minLPResult.minLPTokens);
      setInputValue3(result.swapParams?.swapToToken0Aggregator || '');
      setInputValue4(result.swapParams?.swapToToken0Data || '');
      setInputValue5(result.swapParams?.swapToToken1Aggregator || '');
      setInputValue6(result.swapParams?.swapToToken1Data || '');
      
      // Show success message
      const priceImpact = (result.swapParams?.priceImpact || 0) / 100;
      setCalculationError(
        `✅ All fields auto-filled! Route via ${result.route?.route?.[0]?.protocol || 'DEX'} | ` +
        `Price Impact: ${priceImpact.toFixed(2)}% | ` +
        `Expected LP: ${parseFloat(minLPResult.expectedLPTokens).toFixed(10)}`
      );
      
      setTimeout(() => setCalculationError(''), 8000);
    } catch (error) {
      console.error('❌ Auto-fill failed:', error);
      setCalculationError(`Error: ${error instanceof Error ? error.message : 'Failed to fetch route'}`);
    } finally {
      setIsCalculating(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Admin Status */}
      <div className={`p-6 rounded-xl ${isAdmin ? 'bg-gradient-to-r from-purple-600/20 to-pink-600/20 border border-purple-500/30' : 'bg-red-600/20 border border-red-500/30'}`}>
        <div className="flex items-center space-x-3">
          {isAdmin ? (
            <>
              <CheckCircle className="w-6 h-6 text-green-400" />
              <div>
                <h3 className="text-white font-bold">Admin Access Granted</h3>
                <p className="text-gray-300 text-sm">You have full control over the protocol</p>
              </div>
            </>
          ) : (
            <>
              <AlertCircle className="w-6 h-6 text-red-400" />
              <div>
                <h3 className="text-white font-bold">View-Only Mode</h3>
                <p className="text-gray-300 text-sm">Connect with admin wallet to make changes</p>
              </div>
            </>
          )}
        </div>
      </div>

      {/* Vault Selector */}
      <div className="bg-white/5 backdrop-blur-sm rounded-xl border border-white/10 p-6">
        <h3 className="text-white font-bold mb-4 flex items-center gap-2">
          <Settings className="w-5 h-5" />
          Select Vault
        </h3>
        <div className="grid grid-cols-3 gap-3">
          {(['senior', 'junior', 'reserve'] as const).map((vault) => (
            <button
              key={vault}
              onClick={() => setSelectedVault(vault)}
              className={`py-3 px-4 rounded-lg font-semibold transition-all ${
                selectedVault === vault
                  ? 'bg-gradient-to-r from-purple-600 to-pink-600 text-white'
                  : 'bg-white/5 text-gray-400 hover:bg-white/10'
              }`}
            >
              {vault.charAt(0).toUpperCase() + vault.slice(1)}
            </button>
          ))}
        </div>
      </div>

      {/* Protocol State */}
      <div className="bg-white/5 backdrop-blur-sm rounded-xl border border-white/10 p-6">
        <h3 className="text-white font-bold mb-4 flex items-center gap-2">
          <Shield className="w-5 h-5" />
          Protocol State - {selectedVault.charAt(0).toUpperCase() + selectedVault.slice(1)} Vault
        </h3>
        
        <div className="space-y-4">
          {/* Status */}
          <div className="flex justify-between items-center pb-3 border-b border-white/10">
            <span className="text-gray-400">Status</span>
            <span className={`font-semibold ${isPaused ? 'text-red-400' : 'text-green-400'}`}>
              {isPaused ? '⏸ PAUSED' : '▶ ACTIVE'}
            </span>
          </div>

          {/* Admin */}
          <div className="flex justify-between items-center pb-3 border-b border-white/10">
            <span className="text-gray-400">Admin</span>
            <span className="text-purple-400 font-mono text-sm">
              {admin ? `${(admin as string).slice(0, 6)}...${(admin as string).slice(-4)}` : 'N/A'}
            </span>
          </div>

          {/* Treasury */}
          {treasury && (
            <div className="flex justify-between items-center pb-3 border-b border-white/10">
              <span className="text-gray-400">Treasury</span>
              <span className="text-yellow-400 font-mono text-sm">
                {(treasury as string).slice(0, 6)}...{(treasury as string).slice(-4)}
              </span>
            </div>
          )}

          {/* Total Assets */}
          <div className="flex justify-between items-center pb-3 border-b border-white/10">
            <span className="text-gray-400">Total Assets (Idle)</span>
            <span className="text-white font-bold">
              {totalAssets ? `${parseFloat(formatEther(totalAssets as bigint)).toFixed(2)} HONEY` : '0'}
            </span>
          </div>

          {/* Vault Value */}
          <div className="flex justify-between items-center pb-3 border-b border-white/10">
            <span className="text-gray-400">Vault Value (Idle)</span>
            <span className="text-blue-400 font-bold">
              {vaultValue ? `${parseFloat(formatEther(vaultValue as bigint)).toFixed(2)} HONEY` : '0'}
            </span>
          </div>

          {/* Calculated Value */}
          <div className="flex justify-between items-center pb-3 border-b border-white/10">
            <span className="text-gray-400">Calculated Value (with LP)</span>
            <span className="text-purple-400 font-bold">
              {calculatedValue ? `${parseFloat(formatEther(calculatedValue as bigint)).toFixed(2)} HONEY` : '0'}
            </span>
          </div>

          {/* Senior Vault */}
          {seniorVault && (
            <div className="flex justify-between items-center pb-3 border-b border-white/10">
              <span className="text-gray-400">Senior Vault</span>
              <span className="text-cyan-400 font-mono text-sm">
                {(seniorVault as string).slice(0, 6)}...{(seniorVault as string).slice(-4)}
              </span>
            </div>
          )}

          {/* Junior Vault */}
          {juniorVault && (
            <div className="flex justify-between items-center pb-3 border-b border-white/10">
              <span className="text-gray-400">Junior Vault</span>
              <span className="text-orange-400 font-mono text-sm">
                {(juniorVault as string).slice(0, 6)}...{(juniorVault as string).slice(-4)}
              </span>
            </div>
          )}

          {/* Reserve Vault */}
          {reserveVault && (
            <div className="flex justify-between items-center pb-3 border-b border-white/10">
              <span className="text-gray-400">Reserve Vault</span>
              <span className="text-green-400 font-mono text-sm">
                {(reserveVault as string).slice(0, 6)}...{(reserveVault as string).slice(-4)}
              </span>
            </div>
          )}
        </div>
      </div>

      {/* Oracle Configuration */}
      {oracleConfig && (
        <div className="bg-white/5 backdrop-blur-sm rounded-xl border border-white/10 p-6">
          <h3 className="text-white font-bold mb-4 flex items-center gap-2">
            <Globe className="w-5 h-5" />
            Oracle Configuration
          </h3>
          
          <div className="space-y-3">
            <div className="flex justify-between items-center">
              <span className="text-gray-400">Island Address</span>
              <span className="text-blue-400 font-mono text-sm">
                {(oracleConfig as any).island?.slice(0, 10)}...
              </span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-gray-400">Stablecoin is Token1</span>
              <span className="text-white">{(oracleConfig as any).stablecoinIsToken1 ? '✓ Yes' : '✗ No'}</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-gray-400">Max Deviation</span>
              <span className="text-yellow-400">{(oracleConfig as any).maxDeviation || 0}%</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-gray-400">Validation Enabled</span>
              <span className={`font-semibold ${(oracleConfig as any).enableValidation ? 'text-green-400' : 'text-red-400'}`}>
                {(oracleConfig as any).enableValidation ? '✓ Enabled' : '✗ Disabled'}
              </span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-gray-400">Use Calculated Price</span>
              <span className={`font-semibold ${(oracleConfig as any).useCalculated ? 'text-green-400' : 'text-red-400'}`}>
                {(oracleConfig as any).useCalculated ? '✓ Yes' : '✗ No'}
              </span>
            </div>
          </div>
        </div>
      )}

      {/* Hook TVL Dashboard */}
      <div className="bg-gradient-to-br from-purple-500/10 via-blue-500/10 to-green-500/10 backdrop-blur-sm rounded-xl border border-white/20 p-6 mb-6">
        <h3 className="text-white font-bold mb-4 flex items-center gap-2">
          <DollarSign className="w-5 h-5 text-green-400" />
          Hook TVL Dashboard
        </h3>
        
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          {/* WBTC Balance */}
          <div className="bg-orange-500/10 border border-orange-500/30 rounded-lg p-4">
            <div className="text-orange-400 text-xs font-semibold mb-1">WBTC Balance</div>
            <div className="text-white text-lg font-bold">
              {hookWBTCBalance ? (Number(hookWBTCBalance) / 1e8).toFixed(8) : '0.00000000'}
            </div>
            <div className="text-orange-300 text-xs mt-1">
              ${hookTVL.wbtc.toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2})}
            </div>
            {wbtcPrice > 0 && (
              <div className="text-gray-400 text-xs mt-0.5">
                @ ${wbtcPrice.toLocaleString()}/WBTC
              </div>
            )}
          </div>

          {/* HONEY Balance */}
          <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-lg p-4">
            <div className="text-yellow-400 text-xs font-semibold mb-1">HONEY Balance</div>
            <div className="text-white text-lg font-bold">
              {hookHONEYBalance ? (Number(hookHONEYBalance) / 1e18).toFixed(6) : '0.000000'}
            </div>
            <div className="text-yellow-300 text-xs mt-1">
              ${hookTVL.honey.toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2})}
            </div>
          </div>

          {/* LP Balance */}
          <div className="bg-blue-500/10 border border-blue-500/30 rounded-lg p-4">
            <div className="text-blue-400 text-xs font-semibold mb-1">LP Tokens</div>
            <div className="text-white text-lg font-bold">
              {hookLPBalance ? (Number(hookLPBalance) / 1e18).toFixed(12) : '0.000000000000'}
            </div>
            <div className="text-blue-300 text-xs mt-1">
              ${hookTVL.lp.toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2})}
            </div>
            {lpPrice > 0 && (
              <div className="text-gray-400 text-xs mt-0.5">
                @ ${(lpPrice / 1000000).toFixed(2)}M/LP
              </div>
            )}
          </div>

          {/* Total TVL */}
          <div className="bg-green-500/10 border border-green-500/30 rounded-lg p-4">
            <div className="text-green-400 text-xs font-semibold mb-1">Total TVL</div>
            <div className="text-white text-2xl font-bold">
              ${hookTVL.total.toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2})}
            </div>
            <div className="text-green-300 text-xs mt-1">
              Hook Asset Value
            </div>
          </div>
        </div>

        <div className="mt-4 text-xs text-gray-400 bg-black/20 p-3 rounded">
          💡 Prices fetched from Enso API. WBTC dust accumulates from LP liquidations during withdrawals.
        </div>
      </div>

      {/* Hook Information */}
      <div className="bg-white/5 backdrop-blur-sm rounded-xl border border-white/10 p-6">
        <h3 className="text-white font-bold mb-4 flex items-center gap-2">
          <Network className="w-5 h-5" />
          Kodiak Hook Details
        </h3>
        
        <div className="space-y-3">
          <div className="flex justify-between items-center">
            <span className="text-gray-400">Hook Address</span>
            <span className="text-purple-400 font-mono text-sm">
              {hookAddress.slice(0, 6)}...{hookAddress.slice(-4)}
            </span>
          </div>
          <div className="flex justify-between items-center">
            <span className="text-gray-400">Hook Admin</span>
            <span className="text-pink-400 font-mono text-sm">
              {hookAdmin ? `${(hookAdmin as string).slice(0, 6)}...${(hookAdmin as string).slice(-4)}` : 'N/A'}
            </span>
          </div>
          <div className="flex justify-between items-center">
            <span className="text-gray-400">Kodiak Router</span>
            <span className="text-blue-400 font-mono text-sm">
              {kodiakRouter ? `${(kodiakRouter as string).slice(0, 6)}...${(kodiakRouter as string).slice(-4)}` : 'N/A'}
            </span>
          </div>
          <div className="flex justify-between items-center">
            <span className="text-gray-400">Kodiak Island</span>
            <span className="text-cyan-400 font-mono text-sm">
              {kodiakIsland ? `${(kodiakIsland as string).slice(0, 6)}...${(kodiakIsland as string).slice(-4)}` : 'N/A'}
            </span>
          </div>
          <div className="flex justify-between items-center">
            <span className="text-gray-400">Connected Vault</span>
            <span className="text-green-400 font-mono text-sm">
              {hookVault ? `${(hookVault as string).slice(0, 6)}...${(hookVault as string).slice(-4)}` : 'N/A'}
            </span>
          </div>
        </div>
      </div>

      {/* LP Holdings */}
      {lpHoldings && (lpHoldings as any[]).length > 0 && (
        <div className="bg-white/5 backdrop-blur-sm rounded-xl border border-white/10 p-6">
          <h3 className="text-white font-bold mb-4 flex items-center gap-2">
            <DollarSign className="w-5 h-5" />
            LP Holdings
          </h3>
          
          <div className="space-y-2">
            {(lpHoldings as any[]).map((holding: any, idx: number) => (
              <div key={idx} className="flex justify-between items-center bg-white/5 p-3 rounded">
                <span className="text-gray-400 font-mono text-sm">{holding.lpToken?.slice(0, 10)}...</span>
                <span className="text-green-400 font-semibold">
                  {parseFloat(formatEther(holding.amount || 0n)).toFixed(4)} LP
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Whitelisted LP Tokens */}
      {whitelistedLPTokens && (whitelistedLPTokens as any[]).length > 0 && (
        <div className="bg-white/5 backdrop-blur-sm rounded-xl border border-white/10 p-6">
          <h3 className="text-white font-bold mb-4 flex items-center gap-2">
            <List className="w-5 h-5" />
            Whitelisted LP Tokens
          </h3>
          
          <div className="space-y-2">
            {(whitelistedLPTokens as any[]).map((token: string, idx: number) => (
              <div key={idx} className="bg-green-500/10 border border-green-500/20 p-2 rounded">
                <span className="text-green-400 font-mono text-xs">{token}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Whitelisted Protocols */}
      {whitelistedProtocols && (whitelistedProtocols as any[]).length > 0 && (
        <div className="bg-white/5 backdrop-blur-sm rounded-xl border border-white/10 p-6">
          <h3 className="text-white font-bold mb-4 flex items-center gap-2">
            <Shield className="w-5 h-5" />
            Whitelisted LP Protocols
          </h3>
          
          <div className="space-y-2">
            {(whitelistedProtocols as any[]).map((protocol: string, idx: number) => (
              <div key={idx} className="bg-blue-500/10 border border-blue-500/20 p-2 rounded">
                <span className="text-blue-400 font-mono text-xs">{protocol}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Action Type Selector */}
      {isAdmin && (
        <div className="bg-white/5 backdrop-blur-sm rounded-xl border border-white/10 p-6">
          <h3 className="text-white font-bold mb-4 flex items-center gap-2">
            <Settings className="w-5 h-5" />
            Admin Actions
          </h3>
          <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-8 gap-2">
            {[
              { id: 'pause' as AdminAction, label: 'Pause', icon: Shield },
              { id: 'setvaultvalue' as AdminAction, label: 'Set Value', icon: DollarSign },
              { id: 'rebase' as AdminAction, label: 'Rebase', icon: Zap },
              { id: 'kodiak' as AdminAction, label: 'Kodiak LP', icon: Rocket },
              { id: 'whitelist' as AdminAction, label: 'Whitelist', icon: List },
              { id: 'oracle' as AdminAction, label: 'Oracle', icon: Globe },
              { id: 'admin' as AdminAction, label: 'Admin', icon: UserPlus },
              { id: 'emergency' as AdminAction, label: 'Emergency', icon: AlertCircle },
            ].map((action) => (
              <button
                key={action.id}
                onClick={() => {
                  setActionType(action.id);
                  setInputValue('');
                  setInputValue2('');
                  setInputValue3('');
                  setInputValue4('');
                  setInputValue5('');
                  setInputValue6('');
                }}
                className={`py-2 px-3 rounded-lg font-semibold text-sm transition-all flex items-center justify-center gap-1 ${
                  actionType === action.id
                    ? 'bg-gradient-to-r from-purple-600 to-pink-600 text-white'
                    : 'bg-white/5 text-gray-400 hover:bg-white/10'
                }`}
              >
                <action.icon className="w-4 h-4" />
                {action.label}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Admin Actions Panels */}
      {isAdmin && (
        <div className="bg-white/5 backdrop-blur-sm rounded-xl border border-white/10 p-6">
          {/* Pause Controls */}
          {actionType === 'pause' && (
            <div className="space-y-4">
              <h4 className="text-white font-bold flex items-center gap-2">
                <Shield className="w-5 h-5" />
                Emergency Pause Controls
              </h4>
              <p className="text-gray-400 text-sm">Pause or unpause all vault operations</p>
              <div className="flex space-x-3">
                <button
                  onClick={handlePause}
                  disabled={isConfirming || isPaused as boolean}
                  className="flex-1 py-3 bg-red-600 hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-semibold"
                >
                  ⏸ Pause Vault
                </button>
                <button
                  onClick={handleUnpause}
                  disabled={isConfirming || !(isPaused as boolean)}
                  className="flex-1 py-3 bg-green-600 hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-semibold"
                >
                  ▶ Unpause Vault
                </button>
              </div>
            </div>
          )}

          {/* Set Vault Value */}
          {actionType === 'setvaultvalue' && (
            <div className="space-y-4">
              <h4 className="text-white font-bold flex items-center gap-2">
                <DollarSign className="w-5 h-5" />
                Set Vault Value
              </h4>
              
              <div className="bg-gradient-to-r from-blue-500/20 to-cyan-500/20 border border-blue-500/50 rounded-lg p-4 space-y-3">
                <h5 className="text-blue-300 font-bold text-sm flex items-center gap-2">
                  <RefreshCw className="w-5 h-5" />
                  💰 Update Vault's Internal totalAssets Value
                </h5>
                <p className="text-gray-300 text-xs">
                  Manually set the vault's internal <code className="bg-black/30 px-1 rounded">totalAssets()</code> value to match the actual value (idle HONEY + LP positions). 
                </p>
                <div className="bg-black/30 rounded p-3 space-y-1">
                  <div className="flex justify-between text-xs">
                    <span className="text-gray-400">Current getVaultValue():</span>
                    <strong className="text-yellow-400">{vaultValue ? `${parseFloat(formatEther(vaultValue as bigint)).toFixed(2)} HONEY` : 'Loading...'}</strong>
                  </div>
                </div>
                <div className="space-y-2">
                  <label className="text-xs text-gray-400">New Vault Value (in HONEY)</label>
                  <input
                    type="text"
                    value={inputValue}
                    onChange={(e) => setInputValue(e.target.value)}
                    placeholder="3.00"
                    className="w-full px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-blue-500 text-sm"
                  />
                  <p className="text-xs text-gray-400">
                    💡 <strong>Tip:</strong> Check the dashboard's "Total Value (with LP)" to see the actual value, then enter it here.
                  </p>
                </div>
                <button
                  onClick={handleSetVaultValue}
                  disabled={isConfirming || !inputValue}
                  className="w-full py-3 bg-gradient-to-r from-blue-600 to-cyan-600 hover:from-blue-700 hover:to-cyan-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-bold text-sm"
                >
                  {isConfirming ? '⏳ Setting Value...' : '💰 Set Vault Value'}
                </button>
              </div>
            </div>
          )}

          {/* Rebase Operations */}
          {actionType === 'rebase' && (
            <div className="space-y-4">
              <h4 className="text-white font-bold flex items-center gap-2">
                <Zap className="w-5 h-5" />
                Rebase Operations
              </h4>

              {/* REBASE INFO - PROMINENT */}
              <div className="bg-gradient-to-r from-purple-500/20 to-indigo-500/20 border border-purple-500/50 rounded-lg p-4 space-y-3">
                <h5 className="text-purple-300 font-bold text-sm flex items-center gap-2">
                  <Clock className="w-5 h-5" />
                  📊 Rebase Information
                </h5>
                <div className="bg-black/30 rounded p-3 space-y-2">
                  <div className="flex justify-between text-xs">
                    <span className="text-gray-400">Min Rebase Interval:</span>
                    <strong className="text-yellow-400">
                      {minRebaseInterval ? `${Number(minRebaseInterval)} seconds (${(Number(minRebaseInterval) / 3600).toFixed(2)} hours)` : 'Loading...'}
                    </strong>
                  </div>
                  <div className="flex justify-between text-xs">
                    <span className="text-gray-400">Last Rebase Time:</span>
                    <strong className="text-blue-400">
                      {lastRebaseTime && rebaseIndex && parseFloat(formatEther(rebaseIndex as bigint)) !== 1.0
                        ? new Date(Number(lastRebaseTime) * 1000).toLocaleString() 
                        : 'Never (initial state)'}
                    </strong>
                  </div>
                  <div className="flex justify-between text-xs">
                    <span className="text-gray-400">Time Since Last Rebase:</span>
                    <strong className="text-green-400">
                      {lastRebaseTime && rebaseIndex && parseFloat(formatEther(rebaseIndex as bigint)) !== 1.0
                        ? `${Math.floor((Date.now() / 1000 - Number(lastRebaseTime)) / 60)} minutes ago`
                        : 'N/A (no rebases yet)'}
                    </strong>
                  </div>
                  <div className="flex justify-between text-xs">
                    <span className="text-gray-400">Rebase Index (Multiplier):</span>
                    <strong className="text-cyan-400">
                      {rebaseIndex ? `${parseFloat(formatEther(rebaseIndex as bigint)).toFixed(4)}x` : '1.0000x'}
                    </strong>
                  </div>
                  <div className="flex justify-between text-xs pt-2 border-t border-purple-500/20">
                    <span className="text-gray-400">Can Rebase Now?</span>
                    <strong className={
                      lastRebaseTime && minRebaseInterval && 
                      (Date.now() / 1000 - Number(lastRebaseTime)) >= Number(minRebaseInterval)
                        ? 'text-green-400' 
                        : 'text-red-400'
                    }>
                      {lastRebaseTime && minRebaseInterval 
                        ? (Date.now() / 1000 - Number(lastRebaseTime)) >= Number(minRebaseInterval)
                          ? '✅ YES' 
                          : `❌ NO (wait ${Math.ceil((Number(minRebaseInterval) - (Date.now() / 1000 - Number(lastRebaseTime))) / 60)} more minutes)`
                        : 'Checking...'}
                    </strong>
                  </div>
                </div>
              </div>

              {/* EXECUTE REBASE */}
              <div className="bg-gradient-to-r from-green-500/20 to-emerald-500/20 border border-green-500/50 rounded-lg p-4 space-y-3">
                <h5 className="text-green-300 font-bold text-sm">⚡ Execute Rebase</h5>
                <p className="text-gray-300 text-xs">
                  Automatically calculate vault value (idle HONEY + LP positions) and distribute profits/losses across all vaults based on risk tiers.
                </p>
                
                {/* Show current LP price from Enso */}
                <div className="bg-black/30 rounded p-3">
                  <div className="flex justify-between text-xs mb-2">
                    <span className="text-gray-400">LP Price (from Enso):</span>
                    <strong className="text-cyan-400">
                      {ensoLPPrice ? `$${ensoLPPrice.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}` : 'Loading...'}
                    </strong>
                  </div>
                  <p className="text-xs text-gray-400">
                    💡 This price will be used for rebase calculations
                  </p>
                </div>

                {/* LP Price Input (Auto-filled from Enso) */}
                <div className="space-y-2">
                  <label className="text-xs text-gray-400 flex items-center gap-2">
                    <span>LP Price for Rebase</span>
                    <span className="text-green-400 text-xs">✓ Auto-filled from Enso</span>
                  </label>
                  <input
                    type="text"
                    value={inputValue}
                    onChange={(e) => setInputValue(e.target.value)}
                    placeholder={ensoLPPrice ? ensoLPPrice.toString() : "Loading..."}
                    className="w-full px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-green-500 text-sm font-mono"
                  />
                  <p className="text-xs text-gray-400">
                    💡 Auto-filled with live Enso price. Edit if needed.
                  </p>
                </div>

                <button
                  onClick={handleRebase}
                  disabled={isConfirming || !ensoLPPrice}
                  className="w-full py-3 bg-gradient-to-r from-purple-600 to-indigo-600 hover:from-purple-700 hover:to-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-semibold"
                >
                  {isConfirming ? '⏳ Rebasing...' : !ensoLPPrice ? '⏳ Loading Price...' : '⚡ Execute Rebase Now'}
                </button>
              </div>
              
              {/* CHANGE REBASE INTERVAL */}
              <div className="bg-gradient-to-r from-orange-500/20 to-yellow-500/20 border border-orange-500/50 rounded-lg p-4 space-y-3">
                <h5 className="text-orange-300 font-bold text-sm flex items-center gap-2">
                  <Settings className="w-5 h-5" />
                  ⏱️ Change Rebase Interval
                </h5>
                <p className="text-gray-300 text-xs">
                  Set the minimum time (in seconds) required between rebase executions. This prevents too-frequent rebases.
                </p>
                <div className="space-y-2">
                  <label className="text-xs text-gray-400">New Min Rebase Interval (seconds)</label>
                  <div className="flex space-x-2">
                    <input
                      type="number"
                      value={rebaseIntervalValue}
                      onChange={(e) => setRebaseIntervalValue(e.target.value)}
                      placeholder="3600"
                      className="flex-1 px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-orange-500"
                    />
                    <button
                      onClick={handleSetMinRebaseInterval}
                      disabled={isConfirming || !rebaseIntervalValue}
                      className="px-6 py-2 bg-gradient-to-r from-orange-600 to-yellow-600 hover:from-orange-700 hover:to-yellow-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-semibold"
                    >
                      {isConfirming ? '⏳' : <Clock className="w-4 h-4" />}
                    </button>
                  </div>
                  <p className="text-xs text-gray-400">
                    💡 Common values: 3600 (1 hour), 86400 (1 day), 604800 (1 week)
                  </p>
                </div>
              </div>
            </div>
          )}

          {/* Kodiak LP Operations */}
          {actionType === 'kodiak' && (
            <div className="space-y-6">
              <h4 className="text-white font-bold flex items-center gap-2">
                <Rocket className="w-5 h-5" />
                Kodiak LP Management
              </h4>
              
              {/* WHITELIST AGGREGATOR - MUST BE DONE FIRST! */}
              <div className={`${isEnsoWhitelisted === true ? 'bg-green-500/20 border-green-500/50' : 'bg-red-500/20 border-red-500/50'} border-2 rounded-lg p-4 space-y-3`}>
                <div className="flex items-center justify-between">
                  <h5 className={`${isEnsoWhitelisted === true ? 'text-green-300' : 'text-red-300'} font-bold text-sm flex items-center gap-2`}>
                    {isEnsoWhitelisted === true ? <CheckCircle className="w-5 h-5" /> : <AlertCircle className="w-5 h-5" />}
                    {isEnsoWhitelisted === true ? '✅ STEP 1: Enso Aggregator Whitelisted!' : '🔴 STEP 1: Whitelist Enso Aggregator (REQUIRED FIRST!)'}
                  </h5>
                </div>
                <div className="bg-black/30 rounded p-3 space-y-2">
                  {isEnsoWhitelisted !== true && (
                    <p className="text-yellow-300 text-xs font-semibold">
                      ⚠️ Before using "Deploy to Kodiak", you MUST whitelist the Enso aggregator address in the hook!
                    </p>
                  )}
                  {isEnsoWhitelisted === true && (
                    <p className="text-green-300 text-xs font-semibold">
                      ✅ Enso aggregator is whitelisted! You can now use "Deploy to Kodiak" below.
                    </p>
                  )}
                  <p className="text-gray-300 text-xs">
                    Enso Aggregator: <span className="text-purple-400 font-mono">0x5f41cF4eB62f8A7F46B00e8C51F44C0E3A95c68c</span>
                  </p>
                  <div className="flex items-center justify-between pt-2 border-t border-white/10">
                    <span className="text-gray-400 text-xs">Current Status:</span>
                    <span className={`font-bold text-xs ${isEnsoWhitelisted === true ? 'text-green-400' : 'text-red-400'}`}>
                      {isEnsoWhitelisted === true ? '✓ WHITELISTED' : isEnsoWhitelisted === undefined ? '⏳ LOADING...' : '✗ NOT WHITELISTED'}
                    </span>
                  </div>
                </div>
                
                <div className="space-y-2">
                  <label className="text-xs text-gray-400">Aggregator Address to Whitelist</label>
                  <input
                    type="text"
                    value={inputValue7 || '0x5f41cF4eB62f8A7F46B00e8C51F44C0E3A95c68c'}
                    onChange={(e) => setInputValue7(e.target.value)}
                    placeholder="0x5f41cF4eB62f8A7F46B00e8C51F44C0E3A95c68c"
                    className="w-full px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-red-500 text-sm font-mono"
                  />
                </div>
                
                {/* Warning if not hook admin */}
                {userAddress && hookAdmin && userAddress.toLowerCase() !== (hookAdmin as string).toLowerCase() && (
                  <div className="bg-yellow-500/20 border border-yellow-500/50 rounded p-2">
                    <p className="text-yellow-300 text-xs">
                      ⚠️ <strong>Warning:</strong> Your address is not the Hook Admin. Only the Hook Admin can whitelist aggregators.
                      <br />
                      <span className="text-gray-300">Hook Admin: <span className="font-mono">{(hookAdmin as string).slice(0, 10)}...{(hookAdmin as string).slice(-8)}</span></span>
                    </p>
                  </div>
                )}
                
                <button
                  onClick={handleWhitelistAggregator}
                  disabled={!inputValue7 || isConfirming}
                  className="w-full py-3 bg-gradient-to-r from-red-600 to-orange-600 hover:from-red-700 hover:to-orange-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-bold text-sm"
                >
                  {isConfirming ? '⏳ Whitelisting...' : '✅ Whitelist Aggregator in Hook'}
                </button>
                <p className="text-xs text-gray-400 text-center">
                  This enables the hook to use Enso for swaps
                </p>
              </div>
              
              {/* Deploy to Kodiak */}
              <div className="bg-green-500/10 border border-green-500/20 rounded-lg p-4 space-y-3">
                <div className="flex items-center justify-between">
                  <h5 className="text-green-400 font-semibold text-sm">Deploy to Kodiak</h5>
                  <a 
                    href="/home/amschel/stratosphere/LiquidRoyaltyContracts/get_enso_route.sh"
                    target="_blank"
                    className="text-xs text-blue-400 hover:text-blue-300 underline"
                  >
                    📜 Use Enso Script
                  </a>
                </div>
                
                {/* Auto-Fill Button - PROMINENT */}
                <div className="bg-gradient-to-r from-purple-500/20 to-blue-500/20 border-2 border-purple-500/50 rounded-lg p-3">
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-purple-300 font-semibold text-sm">✨ One-Click Auto-Fill</span>
                    <span className="text-purple-400 text-xs">Powered by Enso</span>
                  </div>
                  <button
                    onClick={handleAutoFillAll}
                    disabled={isCalculating || !inputValue}
                    className="w-full py-3 bg-gradient-to-r from-purple-600 to-blue-600 hover:from-purple-700 hover:to-blue-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-bold text-sm flex items-center justify-center gap-2 transition-all"
                  >
                    {isCalculating ? (
                      <>⏳ Fetching Route from Enso...</>
                    ) : (
                      <>
                        <Rocket className="w-4 h-4" />
                        🚀 Auto-Fill All Parameters
                      </>
                    )}
                  </button>
                  <p className="text-xs text-purple-300 mt-2 text-center">
                    Automatically fills swap params + min LP tokens
                  </p>
                </div>
                
                <input
                  type="number"
                  value={inputValue}
                  onChange={(e) => setInputValue(e.target.value)}
                  placeholder="Amount (HONEY)"
                  className="w-full px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-green-500 text-sm"
                />
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <label className="text-xs text-gray-400">Min LP Tokens (Slippage: 20%)</label>
                    <button
                      onClick={handleAutoCalculateMinLP}
                      disabled={isCalculating || !inputValue}
                      className="px-3 py-1 bg-blue-600 hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded text-xs font-semibold flex items-center gap-1"
                    >
                      {isCalculating ? (
                        <>⏳ Calculating...</>
                      ) : (
                        <>
                          <Calculator className="w-3 h-3" />
                          Auto-Calculate
                        </>
                      )}
                    </button>
                  </div>
                  <input
                    type="number"
                    value={inputValue2}
                    onChange={(e) => setInputValue2(e.target.value)}
                    placeholder="Min LP Tokens (or click Auto-Calculate)"
                    className="w-full px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-green-500 text-sm"
                    step="0.000000000000000001"
                  />
                  {calculationError && (
                    <p className={`text-xs ${calculationError.startsWith('✅') ? 'text-green-400' : 'text-red-400'}`}>
                      {calculationError}
                    </p>
                  )}
                </div>
                
                <div className="border border-red-500/30 rounded-lg p-3 space-y-2 bg-red-500/5">
                  <div className="flex items-center justify-between">
                    <span className="text-red-400 font-semibold text-xs">🔴 Swap Parameters (REQUIRED)</span>
                    <span className="text-green-300 text-xs">✨ Auto-filled by button above</span>
                  </div>
                  <div className="mt-2 space-y-2">
                    <input
                      type="text"
                      value={inputValue3}
                      onChange={(e) => setInputValue3(e.target.value)}
                      placeholder="Swap to Token0 Aggregator (0x...)"
                      className="w-full px-3 py-1.5 bg-white/5 border border-white/10 rounded text-white placeholder-gray-500 text-xs"
                    />
                    <input
                      type="text"
                      value={inputValue4}
                      onChange={(e) => setInputValue4(e.target.value)}
                      placeholder="Swap to Token0 Data (0x...)"
                      className="w-full px-3 py-1.5 bg-white/5 border border-white/10 rounded text-white placeholder-gray-500 text-xs"
                    />
                    <input
                      type="text"
                      value={inputValue5}
                      onChange={(e) => setInputValue5(e.target.value)}
                      placeholder="Swap to Token1 Aggregator (0x...)"
                      className="w-full px-3 py-1.5 bg-white/5 border border-white/10 rounded text-white placeholder-gray-500 text-xs"
                    />
                    <input
                      type="text"
                      value={inputValue6}
                      onChange={(e) => setInputValue6(e.target.value)}
                      placeholder="Swap to Token1 Data (0x...)"
                      className="w-full px-3 py-1.5 bg-white/5 border border-white/10 rounded text-white placeholder-gray-500 text-xs"
                    />
                  </div>
                </div>
                
                <button
                  onClick={handleDeployToKodiak}
                  disabled={isConfirming || !inputValue || !inputValue2 || !inputValue3 || !inputValue4}
                  className="w-full py-2 bg-green-600 hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-semibold text-sm"
                >
                  🚀 Deploy to Kodiak
                </button>
                {(!inputValue || !inputValue2 || !inputValue3 || !inputValue4) && (
                  <p className="text-red-400 text-xs text-center">
                    ⚠️ All fields including swap params are required!
                  </p>
                )}
              </div>

              {/* Withdraw LP Tokens */}
              <div className="bg-orange-500/10 border border-orange-500/20 rounded-lg p-4 space-y-3">
                <h5 className="text-orange-400 font-semibold text-sm">Withdraw LP Tokens</h5>
                <input
                  type="text"
                  value={inputValue}
                  onChange={(e) => setInputValue(e.target.value)}
                  placeholder="LP Token Address (0x...)"
                  className="w-full px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-orange-500 text-sm"
                />
                <input
                  type="text"
                  value={inputValue2}
                  onChange={(e) => setInputValue2(e.target.value)}
                  placeholder="LP Protocol Address (0x...)"
                  className="w-full px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-orange-500 text-sm"
                />
                <input
                  type="number"
                  value={inputValue3}
                  onChange={(e) => setInputValue3(e.target.value)}
                  placeholder="Amount (LP tokens)"
                  className="w-full px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-orange-500 text-sm"
                />
                <input
                  type="number"
                  value={inputValue4}
                  onChange={(e) => setInputValue4(e.target.value)}
                  placeholder="Min Stablecoin Out"
                  className="w-full px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-orange-500 text-sm"
                />
                <details className="text-xs">
                  <summary className="text-gray-400 cursor-pointer">Advanced: Swap Params (optional)</summary>
                  <div className="mt-2 space-y-2">
                    <input
                      type="text"
                      value={inputValue5}
                      onChange={(e) => setInputValue5(e.target.value)}
                      placeholder="Swap Aggregator (0x...)"
                      className="w-full px-3 py-1.5 bg-white/5 border border-white/10 rounded text-white placeholder-gray-500 text-xs"
                    />
                    <input
                      type="text"
                      value={inputValue6}
                      onChange={(e) => setInputValue6(e.target.value)}
                      placeholder="Swap Data (0x...)"
                      className="w-full px-3 py-1.5 bg-white/5 border border-white/10 rounded text-white placeholder-gray-500 text-xs"
                    />
                  </div>
                </details>
                <button
                  onClick={handleWithdrawLPTokens}
                  disabled={isConfirming || !inputValue || !inputValue2 || !inputValue3 || !inputValue4}
                  className="w-full py-2 bg-orange-600 hover:bg-orange-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-semibold text-sm"
                >
                  💰 Withdraw LP Tokens
                </button>
              </div>

              {/* Alternative Functions */}
              <div className="space-y-4">
                <p className="text-yellow-400 text-xs">
                  ⚠️ Note: Sweep and Invest also require swap params for WBTC-HONEY pool. Use "Deploy to Kodiak" above for full control.
                </p>
              </div>
              
              {/* Hide sweep/invest for now since they also need swap params
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="bg-blue-500/10 border border-blue-500/20 rounded-lg p-3 space-y-2">
                  <h5 className="text-blue-400 font-semibold text-xs">Sweep to Kodiak</h5>
                  <input
                    type="number"
                    value={inputValue}
                    onChange={(e) => setInputValue(e.target.value)}
                    placeholder="Amount"
                    className="w-full px-3 py-1.5 bg-white/5 border border-white/10 rounded text-white placeholder-gray-500 text-xs"
                  />
                  <button
                    onClick={handleSweepToKodiak}
                    disabled={isConfirming || !inputValue}
                    className="w-full py-1.5 bg-blue-600 hover:bg-blue-700 disabled:opacity-50 text-white rounded text-xs font-semibold"
                  >
                    Sweep
                  </button>
                </div>
                <div className="bg-cyan-500/10 border border-cyan-500/20 rounded-lg p-3 space-y-2">
                  <h5 className="text-cyan-400 font-semibold text-xs">Invest in LP</h5>
                  <input
                    type="text"
                    value={inputValue}
                    onChange={(e) => setInputValue(e.target.value)}
                    placeholder="LP Token (0x...)"
                    className="w-full px-3 py-1.5 bg-white/5 border border-white/10 rounded text-white placeholder-gray-500 text-xs"
                  />
                  <input
                    type="number"
                    value={inputValue2}
                    onChange={(e) => setInputValue2(e.target.value)}
                    placeholder="Amount"
                    className="w-full px-3 py-1.5 bg-white/5 border border-white/10 rounded text-white placeholder-gray-500 text-xs"
                  />
                  <button
                    onClick={handleInvestInLP}
                    disabled={isConfirming || !inputValue || !inputValue2}
                    className="w-full py-1.5 bg-cyan-600 hover:bg-cyan-700 disabled:opacity-50 text-white rounded text-xs font-semibold"
                  >
                    Invest
                  </button>
                </div>
              </div>
              */}

              {/* Hook Dust Management */}
              <div className="bg-gradient-to-br from-purple-500/10 to-orange-500/10 border border-purple-500/30 rounded-lg p-6 space-y-4 mt-6">
                <h4 className="text-white font-bold flex items-center gap-2">
                  <DollarSign className="w-5 h-5" />
                  Hook Dust Recovery
                </h4>
                <p className="text-gray-400 text-sm">
                  💡 When LP is burned for withdrawals, WBTC dust accumulates in the hook. Use these tools to recover it.
                </p>

                {/* Rescue HONEY to Vault */}
                <div className="bg-purple-500/10 border border-purple-500/20 rounded-lg p-4 space-y-3">
                  <h5 className="text-purple-400 font-semibold text-sm">Rescue HONEY Dust to Vault</h5>
                  <p className="text-gray-400 text-xs">
                    Sends all HONEY dust from hook directly to vault (no swap needed).
                  </p>
                  <button
                    onClick={handleRescueHoneyToVault}
                    disabled={isConfirming}
                    className="w-full py-3 bg-purple-600 hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-semibold transition-all"
                  >
                    💰 Rescue HONEY to Vault
                  </button>
                </div>

                {/* Swap WBTC to Vault */}
                <div className="bg-orange-500/10 border border-orange-500/20 rounded-lg p-4 space-y-3">
                  <h5 className="text-orange-400 font-semibold text-sm">Swap WBTC Dust to Vault</h5>
                  <p className="text-gray-400 text-xs">
                    Swap WBTC dust → HONEY → send to vault. Auto-fetch swap data from Enso!
                  </p>
                  <input
                    type="text"
                    value={inputValue8}
                    onChange={(e) => {
                      setInputValue8(e.target.value);
                      setSwapDataError('');
                      setExpectedHoneyOut('');
                    }}
                    placeholder="WBTC Amount (e.g., 0.00000528)"
                    className="w-full px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-orange-500"
                  />
                  
                  {/* Auto-Fetch Button */}
                  <button
                    onClick={handleFetchSwapData}
                    disabled={isFetchingSwapData || !inputValue8}
                    className="w-full py-2 bg-blue-600 hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-semibold transition-all flex items-center justify-center gap-2"
                  >
                    {isFetchingSwapData ? (
                      <>
                        <RefreshCw className="w-4 h-4 animate-spin" />
                        Fetching from Enso...
                      </>
                    ) : (
                      <>
                        <Zap className="w-4 h-4" />
                        Auto-Fetch Swap Data
                      </>
                    )}
                  </button>

                  {/* Show expected output */}
                  {expectedHoneyOut && (
                    <div className="bg-green-500/10 border border-green-500/30 rounded p-2 text-xs text-green-300">
                      ✅ Expected HONEY out: <span className="font-bold">{expectedHoneyOut} HONEY</span>
                    </div>
                  )}

                  {/* Show error */}
                  {swapDataError && (
                    <div className="bg-red-500/10 border border-red-500/30 rounded p-2 text-xs text-red-300">
                      ❌ {swapDataError}
                    </div>
                  )}

                  <input
                    type="text"
                    value={inputValue9}
                    onChange={(e) => setInputValue9(e.target.value)}
                    placeholder="Swap Data (auto-filled or paste manually)"
                    className="w-full px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-orange-500 font-mono text-xs"
                    readOnly={isFetchingSwapData}
                  />
                  <input
                    type="text"
                    value={inputValue10}
                    onChange={(e) => setInputValue10(e.target.value)}
                    placeholder="Aggregator (auto-filled or paste manually)"
                    className="w-full px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-orange-500 font-mono text-xs"
                    readOnly={isFetchingSwapData}
                  />
                  <button
                    onClick={handleSwapWBTCToVault}
                    disabled={isConfirming || !inputValue8 || !inputValue9}
                    className="w-full py-3 bg-orange-600 hover:bg-orange-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-semibold transition-all"
                  >
                    🔄 Execute Swap to Vault
                  </button>
                  <div className="text-xs text-gray-400 space-y-1 bg-black/20 p-3 rounded">
                    <p className="font-semibold text-blue-300">💡 Easy Mode:</p>
                    <ol className="list-decimal list-inside space-y-1 ml-2">
                      <li>Enter WBTC amount</li>
                      <li>Click "Auto-Fetch Swap Data" (uses Enso API)</li>
                      <li>Review and click "Execute Swap to Vault"</li>
                    </ol>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Whitelist Management */}
          {actionType === 'whitelist' && (
            <div className="space-y-6">
              <h4 className="text-white font-bold flex items-center gap-2">
                <List className="w-5 h-5" />
                Whitelist Management
              </h4>

              {/* LP Tokens */}
              <div className="bg-purple-500/10 border border-purple-500/20 rounded-lg p-4 space-y-3">
                <h5 className="text-purple-400 font-semibold">LP Tokens</h5>
                <input
                  type="text"
                  value={inputValue}
                  onChange={(e) => setInputValue(e.target.value)}
                  placeholder="LP Token Address (0x...)"
                  className="w-full px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-purple-500"
                />
                <div className="grid grid-cols-2 gap-3">
                  <button
                    onClick={handleWhitelistLP}
                    disabled={isConfirming || !inputValue}
                    className="py-2 bg-green-600 hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-semibold"
                  >
                    ➕ Add
                  </button>
                  <button
                    onClick={handleRemoveWhitelistLPToken}
                    disabled={isConfirming || !inputValue}
                    className="py-2 bg-red-600 hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-semibold"
                  >
                    ➖ Remove
                  </button>
                </div>
              </div>

              {/* LP Protocols */}
              <div className="bg-blue-500/10 border border-blue-500/20 rounded-lg p-4 space-y-3">
                <h5 className="text-blue-400 font-semibold">LP Protocols</h5>
                <input
                  type="text"
                  value={inputValue}
                  onChange={(e) => setInputValue(e.target.value)}
                  placeholder="LP Protocol Address (0x...)"
                  className="w-full px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-blue-500"
                />
                <div className="grid grid-cols-2 gap-3">
                  <button
                    onClick={handleAddWhitelistLP}
                    disabled={isConfirming || !inputValue}
                    className="py-2 bg-green-600 hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-semibold"
                  >
                    ➕ Add
                  </button>
                  <button
                    onClick={handleRemoveWhitelistLP}
                    disabled={isConfirming || !inputValue}
                    className="py-2 bg-red-600 hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-semibold"
                  >
                    ➖ Remove
                  </button>
                </div>
              </div>

              {/* Depositors */}
              <div className="bg-green-500/10 border border-green-500/20 rounded-lg p-4 space-y-3">
                <h5 className="text-green-400 font-semibold">Depositors</h5>
                <input
                  type="text"
                  value={inputValue}
                  onChange={(e) => setInputValue(e.target.value)}
                  placeholder="Depositor Address (0x...)"
                  className="w-full px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-green-500"
                />
                <div className="grid grid-cols-2 gap-3">
                  <button
                    onClick={handleAddWhitelistDepositor}
                    disabled={isConfirming || !inputValue}
                    className="py-2 bg-green-600 hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-semibold"
                  >
                    ➕ Add
                  </button>
                  <button
                    onClick={handleRemoveWhitelistDepositor}
                    disabled={isConfirming || !inputValue}
                    className="py-2 bg-red-600 hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-semibold"
                  >
                    ➖ Remove
                  </button>
                </div>
              </div>
            </div>
          )}

          {/* Oracle Configuration */}
          {actionType === 'oracle' && (
            <div className="space-y-4">
              <h4 className="text-white font-bold flex items-center gap-2">
                <Globe className="w-5 h-5" />
                Oracle Configuration
              </h4>
              <p className="text-gray-400 text-sm">Configure LP price oracle settings</p>
              
              <div className="space-y-3">
                <div>
                  <label className="text-sm text-gray-400 mb-1 block">Kodiak Island Contract Address</label>
                  <input
                    type="text"
                    value={inputValue}
                    onChange={(e) => setInputValue(e.target.value)}
                    placeholder="0xf6b16E73d3b0e2784AAe8C4cd06099BE65d092Bf"
                    className="w-full px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-purple-500"
                  />
                </div>
                
                <div>
                  <label className="text-sm text-gray-400 mb-1 block">Max Deviation (BPS) - e.g., 500 = 5%</label>
                  <input
                    type="number"
                    value={inputValue2}
                    onChange={(e) => setInputValue2(e.target.value)}
                    placeholder="500"
                    className="w-full px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-purple-500"
                  />
                </div>
                
                <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-lg p-3 space-y-2">
                  <p className="text-yellow-400 text-xs font-semibold">⚠️ IMPORTANT: For WBTC-HONEY pool</p>
                  <div className="space-y-2">
                    <label className="flex items-start space-x-2 text-sm text-gray-300 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={boolValue1}
                        onChange={(e) => setBoolValue1(e.target.checked)}
                        className="w-4 h-4 rounded bg-white/5 border-white/10 mt-0.5"
                      />
                      <div>
                        <div>Stablecoin is Token0</div>
                        <div className="text-xs text-gray-500">❌ UNCHECK for WBTC-HONEY (HONEY is token1)</div>
                      </div>
                    </label>
                    <label className="flex items-start space-x-2 text-sm text-gray-300 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={boolValue2}
                        onChange={(e) => setBoolValue2(e.target.checked)}
                        className="w-4 h-4 rounded bg-white/5 border-white/10 mt-0.5"
                      />
                      <div>
                        <div>Enable Validation</div>
                        <div className="text-xs text-gray-500">✅ Recommended: Prevents extreme price swings</div>
                      </div>
                    </label>
                    <label className="flex items-start space-x-2 text-sm text-green-400 cursor-pointer border border-green-500/30 bg-green-500/10 rounded p-2">
                      <input
                        type="checkbox"
                        checked={boolValue3}
                        onChange={(e) => setBoolValue3(e.target.checked)}
                        className="w-4 h-4 rounded bg-white/5 border-white/10 mt-0.5"
                      />
                      <div>
                        <div className="font-semibold">✅ Use Calculated Value (REQUIRED!)</div>
                        <div className="text-xs text-green-300">Must be checked to activate the oracle!</div>
                      </div>
                    </label>
                  </div>
                </div>

                <button
                  onClick={handleConfigureOracle}
                  disabled={isConfirming || !inputValue || !inputValue2}
                  className="w-full py-3 bg-gradient-to-r from-purple-600 to-blue-600 hover:from-purple-700 hover:to-blue-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-semibold transition-all"
                >
                  {isConfirming ? '⏳ Configuring...' : '🔧 Configure Oracle'}
                </button>
                {(!inputValue || !inputValue2) && (
                  <p className="text-red-400 text-xs mt-2">
                    ⚠️ Please fill in Island Address and Max Deviation
                  </p>
                )}
              </div>
            </div>
          )}

          {/* Admin Management */}
          {actionType === 'admin' && (
            <div className="space-y-6">
              <h4 className="text-white font-bold flex items-center gap-2">
                <UserPlus className="w-5 h-5" />
                Admin Management
              </h4>

              {/* Transfer Admin */}
              <div className="bg-yellow-500/10 border border-yellow-500/20 rounded-lg p-4 space-y-3">
                <h5 className="text-yellow-400 font-semibold">Transfer Admin Rights</h5>
                <p className="text-gray-400 text-xs">⚠️ Be careful! This transfers full admin control.</p>
                <input
                  type="text"
                  value={inputValue}
                  onChange={(e) => setInputValue(e.target.value)}
                  placeholder="New Admin Address (0x...)"
                  className="w-full px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-yellow-500"
                />
                <button
                  onClick={handleTransferAdmin}
                  disabled={isConfirming || !inputValue}
                  className="w-full py-2 bg-yellow-600 hover:bg-yellow-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-semibold"
                >
                  👤 Transfer Admin
                </button>
              </div>

              {/* Set Kodiak Hook */}
              <div className="bg-purple-500/10 border border-purple-500/20 rounded-lg p-4 space-y-3">
                <h5 className="text-purple-400 font-semibold">Set Kodiak Hook</h5>
                <input
                  type="text"
                  value={inputValue}
                  onChange={(e) => setInputValue(e.target.value)}
                  placeholder="Hook Contract Address (0x...)"
                  className="w-full px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-purple-500"
                />
                <button
                  onClick={handleSetKodiakHook}
                  disabled={isConfirming || !inputValue}
                  className="w-full py-2 bg-purple-600 hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-semibold"
                >
                  🔗 Set Hook
                </button>
              </div>

              {/* Update Junior/Reserve Vaults */}
              <div className="bg-cyan-500/10 border border-cyan-500/20 rounded-lg p-4 space-y-3">
                <h5 className="text-cyan-400 font-semibold">Update Junior & Reserve Vaults</h5>
                <input
                  type="text"
                  value={inputValue}
                  onChange={(e) => setInputValue(e.target.value)}
                  placeholder="Junior Vault Address (0x...)"
                  className="w-full px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-cyan-500"
                />
                <input
                  type="text"
                  value={inputValue2}
                  onChange={(e) => setInputValue2(e.target.value)}
                  placeholder="Reserve Vault Address (0x...)"
                  className="w-full px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-cyan-500"
                />
                <button
                  onClick={handleUpdateJuniorReserve}
                  disabled={isConfirming || !inputValue || !inputValue2}
                  className="w-full py-2 bg-cyan-600 hover:bg-cyan-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-semibold"
                >
                  🔄 Update Vaults
                </button>
              </div>
            </div>
          )}

          {/* Emergency Actions */}
          {actionType === 'emergency' && (
            <div className="space-y-4">
              <h4 className="text-white font-bold flex items-center gap-2">
                <AlertCircle className="w-5 h-5" />
                Emergency Actions
              </h4>
              <div className="bg-red-500/10 border border-red-500/20 rounded-lg p-4 space-y-3">
                <h5 className="text-red-400 font-semibold">Emergency Withdraw</h5>
                <p className="text-gray-400 text-xs">⚠️ Use only in emergencies! Bypasses normal checks.</p>
                <input
                  type="number"
                  value={inputValue}
                  onChange={(e) => setInputValue(e.target.value)}
                  placeholder="Amount (HONEY)"
                  className="w-full px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-red-500"
                />
                <button
                  onClick={handleEmergencyWithdraw}
                  disabled={isConfirming || !inputValue}
                  className="w-full py-3 bg-red-600 hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-semibold"
                >
                  🚨 Emergency Withdraw
                </button>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
