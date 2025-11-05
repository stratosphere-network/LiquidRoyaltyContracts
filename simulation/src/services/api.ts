import axios from 'axios';
import { config } from '../config';
import type {
  PoolReserves,
  LPPriceData,
  VaultsData,
  BackingRatioData,
  JuniorTokenPriceData,
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

  async getSeniorBackingRatio(): Promise<{ success: boolean; data: BackingRatioData }> {
    const response = await api.get('/senior/backing-ratio');
    return response.data;
  },

  async getJuniorTokenPrice(): Promise<{ success: boolean; data: JuniorTokenPriceData }> {
    const response = await api.get('/junior/token-price');
    return response.data;
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

  async zapAndStake(
    privateKey: string,
    amountTUSD: string,
    vaultType: VaultType,
    slippageTolerance?: number
  ): Promise<ZapResult> {
    const response = await api.post('/zap-and-stake', {
      privateKey,
      amountTUSD,
      vaultType,
      slippageTolerance: slippageTolerance || 0.5
    });
    return response.data;
  },

  // Admin operations
  async updateVaultValue(privateKey: string, profitBps: number): Promise<any> {
    const response = await api.post('/vault/update-value', {
      privateKey,
      profitBps
    });
    return response.data;
  },

  async executeRebase(privateKey: string): Promise<any> {
    const response = await api.post('/vault/rebase', {
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

