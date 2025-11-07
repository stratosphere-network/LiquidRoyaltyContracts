export interface VaultData {
  address: string;
  totalSupply: string;
  totalAssets: string;
  valueUSD: string;
  vaultValue: string;
  profit?: string;
  profitRaw?: string;
}

export interface PoolReserves {
  token0: string;
  token1: string;
  reserve0: string;
  reserve1: string;
  tsailReserve: string;
  tusdReserve: string;
  blockTimestampLast: number;
}

export interface LPPriceData {
  lpTokenPrice: string;
  lpTokenPriceInTUSD: string;
  totalSupply: string;
  totalPoolValue: string;
  tsailPrice: string;
  reserves: {
    tsail: string;
    tusd: string;
  };
}

export interface VaultsData {
  seniorVault: VaultData;
  juniorVault: VaultData;
  reserveVault: VaultData;
  total: {
    formatted?: string;
    totalAssets?: string;
    valueUSD?: string;
    vaultValue?: string;
  };
}

export interface BackingRatioData {
  seniorVault: {
    address: string;
    totalSupply: string;
    totalAssets: string;
    onChainValue: string;
    calculatedValueUSD: string;
    backingRatio: string;
  };
  lpTokenPrice: string;
  backingRatioRaw: string;
}

export interface ProjectedBackingRatioData {
  seniorVault: {
    address: string;
    totalSupply: string;
    onChainValue: string;
    calculatedValueUSD: string;
    valueDelta: string;
    currentBackingRatio: string;
    projectedBackingRatio: string;
    backingRatioDelta: string;
  };
  lpTokenPrice: string;
  currentBackingRatioRaw: string;
  projectedBackingRatioRaw: string;
  suggestion: string;
}

export interface JuniorTokenPriceData {
  juniorVault: {
    address: string;
    totalSupply: string;
    totalAssets: string;
    valueUSD: string;
    tokenPrice: string;
  };
  price: number;
  lpTokenPrice: string;
}

export interface ReserveTokenPriceData {
  reserveVault: {
    address: string;
    totalSupply: string;
    totalAssets: string;
    valueUSD: string;
    tokenPrice: string;
  };
  price: number;
  lpTokenPrice: string;
}

export interface SwapResult {
  success: boolean;
  transactionHash?: string;
  from?: string;
  swap?: {
    tokenIn: string;
    tokenOut: string;
    amountIn: string;
    amountOutExpected: string;
    amountOutMin: string;
    slippage: string;
  };
  blockNumber?: number;
  gasUsed?: string;
  error?: string;
}

export interface ZapResult {
  success: boolean;
  steps?: {
    transfer: any;
    swap: any;
    liquidity: any;
    vault: any;
  };
  totalTUSDUsed?: string;
  finalTransactionHash?: string;
  error?: string;
}

export type BotType = 'whale' | 'farmer';
export type BotStrategy = 'conservative' | 'risky';
export type VaultType = 'junior' | 'senior' | 'reserve';

export interface Bot {
  id: string;
  name: string;
  type: BotType;
  strategy: BotStrategy;
  privateKey: string;
  address: string;
  isActive: boolean;
}

export interface Transaction {
  id: string;
  timestamp: number;
  botId: string;
  botName: string;
  action: 'swap' | 'add_liquidity' | 'zap_stake' | 'withdraw';
  details: string;
  txHash?: string;
  status: 'pending' | 'success' | 'failed';
}

export interface VaultUpdateBPSData {
  lpTokenPrice: string;
  seniorVault: {
    address: string;
    currentValueUSD: string;
    onChainValue: string;
    profitPercent: string;
    bps: number;
    bpsRaw: number;
    capped: boolean;
    warning: string | null;
    callData: string;
  };
  juniorVault: {
    address: string;
    currentValueUSD: string;
    onChainValue: string;
    profitPercent: string;
    bps: number;
    bpsRaw: number;
    capped: boolean;
    warning: string | null;
    callData: string;
  };
  reserveVault: {
    address: string;
    currentValueUSD: string;
    onChainValue: string;
    profitPercent: string;
    bps: number;
    bpsRaw: number;
    capped: boolean;
    warning: string | null;
    callData: string;
  };
  instructions: {
    message: string;
    example: string;
    limits: {
      min: string;
      max: string;
    };
  };
}


  };
  totalTUSDUsed?: string;
  finalTransactionHash?: string;
  error?: string;
}

export type BotType = 'whale' | 'farmer';
export type BotStrategy = 'conservative' | 'risky';
export type VaultType = 'junior' | 'senior' | 'reserve';

export interface Bot {
  id: string;
  name: string;
  type: BotType;
  strategy: BotStrategy;
  privateKey: string;
  address: string;
  isActive: boolean;
}

export interface Transaction {
  id: string;
  timestamp: number;
  botId: string;
  botName: string;
  action: 'swap' | 'add_liquidity' | 'zap_stake' | 'withdraw';
  details: string;
  txHash?: string;
  status: 'pending' | 'success' | 'failed';
}

export interface VaultUpdateBPSData {
  lpTokenPrice: string;
  seniorVault: {
    address: string;
    currentValueUSD: string;
    onChainValue: string;
    profitPercent: string;
    bps: number;
    bpsRaw: number;
    capped: boolean;
    warning: string | null;
    callData: string;
  };
  juniorVault: {
    address: string;
    currentValueUSD: string;
    onChainValue: string;
    profitPercent: string;
    bps: number;
    bpsRaw: number;
    capped: boolean;
    warning: string | null;
    callData: string;
  };
  reserveVault: {
    address: string;
    currentValueUSD: string;
    onChainValue: string;
    profitPercent: string;
    bps: number;
    bpsRaw: number;
    capped: boolean;
    warning: string | null;
    callData: string;
  };
  instructions: {
    message: string;
    example: string;
    limits: {
      min: string;
      max: string;
    };
  };
}

