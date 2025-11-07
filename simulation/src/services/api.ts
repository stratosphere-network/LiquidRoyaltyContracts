import axios from 'axios';
import { config } from '../config';
import type {
  PoolReserves,
  LPPriceData,
  VaultsData,
  BackingRatioData,
  JuniorTokenPriceData,
  ReserveTokenPriceData,
  SwapResult,
  ZapResult,
  VaultType
} from '../types';

const api = axios.create({
  baseURL: config.apiUrl,
  headers: {
    'Content-Type': 'application/json'
  }
});

export const apiService = {
  // Health check
  async healthCheck() {
    const response = await api.get('/health');
    return response.data;
  },

  // Pool data
  async getPairAddress(): Promise<{ pairAddress: string }> {
    const response = await api.get('/pair');
    return response.data;
  },

  async getReserves(): Promise<{ success: boolean; data: PoolReserves }> {
    const response = await api.get('/reserves');
    return response.data;
  },

  async getLPPrice(): Promise<{ success: boolean; data: LPPriceData }> {
    const response = await api.get('/lp-price');
    return response.data;
  },

  // Vaults data
  async getVaultsTotalSupply(): Promise<{ success: boolean; data: VaultsData }> {
    const response = await api.get('/vaults/total-supply');
    return response.data;
  },

  async getVaultsValue(): Promise<{ success: boolean; data: VaultsData }> {
    const response = await api.get('/vaults/value');
    return response.data;
  },

  async getVaultsOnChainValue(): Promise<{ success: boolean; data: VaultsData }> {
    const response = await api.get('/vaults/onchain-value');
    return response.data;
  },

  async getVaultsProfits(): Promise<{ success: boolean; data: any }> {
    const response = await api.get('/vaults/profits');
    return response.data;
  },

  async getVaultsLPHoldings(): Promise<{ success: boolean; data: any }> {
    const response = await api.get('/vaults/lp-holdings');
    return response.data;
  },

  async getVaultsUpdateBPS(): Promise<{ success: boolean; data: any }> {
    const response = await api.get('/vaults/update-bps');
    return response.data;
  },

  async getSeniorBackingRatio(): Promise<{ success: boolean; data: BackingRatioData }> {
    const response = await api.get('/senior/backing-ratio');
    return response.data;
  },

  async getProjectedSeniorBackingRatio(): Promise<{ success: boolean; data: any }> {
    const response = await api.get('/senior/projected-backing-ratio');
    return response.data;
  },

  async getJuniorTokenPrice(): Promise<{ success: boolean; data: JuniorTokenPriceData }> {
    const response = await api.get('/junior/token-price');
    return response.data;
  },

  async getReserveTokenPrice(): Promise<{ success: boolean; data: ReserveTokenPriceData }> {
    const response = await api.get('/reserve/token-price');
    return response.data;
  },

  async getVaultsSupply(): Promise<{ success: boolean; data: any }> {
    const response = await api.get('/vaults/total-supply');
    return response.data;
  },

  async getVaultsValueInUSD(): Promise<{ success: boolean; data: any }> {
    const response = await api.get('/vaults/value');
    return response.data;
  },

  async getPoolData(): Promise<{ sailReserve: number; usdeReserve: number }> {
    const reservesResponse = await api.get('/reserves');
    const reserves = reservesResponse.data.data;
    return {
      sailReserve: parseFloat(reserves.tsailReserve),
      usdeReserve: parseFloat(reserves.tusdReserve)
    };
  },

  async getTokenPrices(): Promise<{ sail: number; usde: number; lp: number }> {
    const lpResponse = await api.get('/lp-price');
    const lpData = lpResponse.data.data;
    
    return {
      sail: parseFloat(lpData.tsailPrice || lpData.tsailPriceInTUSD || 0),
      usde: 1, // USDe is stablecoin
      lp: parseFloat(lpData.lpTokenPriceInTUSD || lpData.lpTokenPrice || 0)
    };
  },

  // Trading operations
  async swapTokens(
    privateKey: string,
    tokenIn: 'TUSD' | 'TSAIL',
    amountIn: string,
    slippageTolerance?: number
  ): Promise<SwapResult> {
    const response = await api.post('/swap', {
      privateKey,
      tokenIn,
      amountIn,
      slippageTolerance: slippageTolerance || 0.5
    });
    return response.data;
  },

  async addLiquidity(
    privateKey: string,
    amountTUSD: string,
    amountTSAIL: string,
    slippageTolerance?: number
  ): Promise<any> {
    const response = await api.post('/add-liquidity', {
      privateKey,
      amountTUSD,
      amountTSAIL,
      slippageTolerance: slippageTolerance || 0.5
    });
    return response.data;
  },

  // Complete stake and invest flow (ONE master function)
  async stakeAndInvestComplete(
    userPrivateKey: string,
    adminPrivateKey: string,
    vaultType: VaultType,
    amountTSTUSDE: string,
    slippageTolerance?: number
  ): Promise<any> {
    const response = await api.post('/stake-and-invest-complete', {
      userPrivateKey,
      adminPrivateKey,
      vaultType,
      amountTSTUSDE,
      slippageTolerance: slippageTolerance || 0.5
    });
    return response.data;
  },

  async depositToVault(
    privateKey: string,
    amountLPTokens: string,
    vaultType: VaultType
  ): Promise<any> {
    const response = await api.post('/deposit-to-vault', {
      privateKey,
      amountLPTokens,
      vaultType
    });
    return response.data;
  },

  async investVaultInLP(
    privateKey: string,
    vaultType: VaultType,
    lpProtocolAddress: string,
    amount: string
  ): Promise<any> {
    const response = await api.post('/invest-vault-in-lp', {
      privateKey,
      vaultType,
      lpProtocolAddress,
      amount
    });
    return response.data;
  },

  // Admin operations
  async updateVaultValue(privateKey: string, profitBps: number, vaultType: 'senior' | 'junior' | 'reserve' = 'senior'): Promise<any> {
    const response = await api.post('/vault/update-value', {
      privateKey,
      profitBps,
      vaultType
    });
    return response.data;
  },

  async executeRebase(privateKey: string): Promise<any> {
    const response = await api.post('/vault/rebase', {
      privateKey
    });
    return response.data;
  },

  async updateAllVaultsAndRebase(privateKey: string): Promise<any> {
    const response = await api.post('/vault/update-and-rebase', {
      privateKey
    });
    return response.data;
  },

  async getRebaseConfig(): Promise<any> {
    const response = await api.get('/rebase/config');
    return response.data;
  },

  async whitelistAddress(privateKey: string, address: string): Promise<any> {
    const response = await api.post('/vault/whitelist', {
      privateKey,
      address
    });
    return response.data;
  }
};

