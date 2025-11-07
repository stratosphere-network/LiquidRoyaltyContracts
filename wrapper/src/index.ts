import express, { Request, Response } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { getUniswapPair, getReserves, getLPTokenPrice, getVaultsTotalSupply, getVaultsValueInUSD, getSeniorBackingRatio, getProjectedSeniorBackingRatio, getVaultsOnChainValue, getVaultsProfits, getVaultsLPHoldings, getVaultsUpdateBPS, getJuniorTokenPrice, getReserveTokenPrice, swapTokens, addLiquidity, depositToVault, investVaultInLP, stakeAndInvestComplete, getRebaseConfig, setRebaseInterval, updateVaultValue, executeSeniorRebase, updateAllVaultsAndRebase, whitelistAddress } from './utils';

// Load environment variables
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Enable CORS for all origins
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true
}));

app.use(express.json());

// Health endpoint
app.get('/health', (req: Request, res: Response) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Get LP pair address
app.get('/pair', (req: Request, res: Response) => {
  const pairAddress = getUniswapPair()
  res.status(200).json({
    pairAddress
  })
})

// Get pool reserves
app.get('/reserves', async (req: Request, res: Response) => {
  try {
    const reserves = await getReserves()
    res.status(200).json({
      success: true,
      data: reserves
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    })
  }
})

// Get stablecoin price
app.get('/lp-price', async (req: Request, res: Response) => {
  try {
    const priceData = await getLPTokenPrice()
    res.status(200).json({
      success: true,
      data: priceData
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    })
  }
})

// Get vaults total supply
app.get('/vaults/total-supply', async (req: Request, res: Response) => {
  try {
    const supplyData = await getVaultsTotalSupply()
    res.status(200).json({
      success: true,
      data: supplyData
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    })
  }
})

// Get vaults value in USD
app.get('/vaults/value', async (req: Request, res: Response) => {
  try {
    const valueData = await getVaultsValueInUSD()
    res.status(200).json({
      success: true,
      data: valueData
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    })
  }
})

// Get senior backing ratio
app.get('/senior/backing-ratio', async (req: Request, res: Response) => {
  try {
    const backingData = await getSeniorBackingRatio()
    res.status(200).json({
      success: true,
      data: backingData
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    })
  }
})

// Get projected senior backing ratio
app.get('/senior/projected-backing-ratio', async (req: Request, res: Response) => {
  try {
    const projectedData = await getProjectedSeniorBackingRatio()
    res.status(200).json({
      success: true,
      data: projectedData
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    })
  }
})

// Get vaults on-chain reported value
app.get('/vaults/onchain-value', async (req: Request, res: Response) => {
  try {
    const onchainValue = await getVaultsOnChainValue()
    res.status(200).json({
      success: true,
      data: onchainValue
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    })
  }
})

// Get junior token price
app.get('/junior/token-price', async (req: Request, res: Response) => {
  try {
    const priceData = await getJuniorTokenPrice()
    res.status(200).json({
      success: true,
      data: priceData
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    })
  }
})

// Get reserve vault token price
app.get('/reserve/token-price', async (req: Request, res: Response) => {
  try {
    const priceData = await getReserveTokenPrice()
    res.status(200).json({
      success: true,
      data: priceData
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    })
  }
})

// Get vaults profits
app.get('/vaults/profits', async (req: Request, res: Response) => {
  try {
    const profitsData = await getVaultsProfits()
    res.status(200).json({
      success: true,
      data: profitsData
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    })
  }
})

app.get('/vaults/lp-holdings', async (req: Request, res: Response) => {
  try {
    const lpHoldingsData = await getVaultsLPHoldings()
    res.status(200).json({
      success: true,
      data: lpHoldingsData
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    })
  }
})

app.get('/vaults/update-bps', async (req: Request, res: Response) => {
  try {
    const bpsData = await getVaultsUpdateBPS()
    res.status(200).json({
      success: true,
      data: bpsData
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    })
  }
})

// Swap tokens
app.post('/swap', async (req: Request, res: Response) => {
  try {
    const { privateKey, tokenIn, amountIn, slippageTolerance } = req.body
    
    if (!privateKey || !tokenIn || !amountIn) {
      return res.status(400).json({
        success: false,
        error: 'Missing required parameters: privateKey, tokenIn, amountIn'
      })
    }
    
    if (tokenIn !== 'TUSD' && tokenIn !== 'TSAIL') {
      return res.status(400).json({
        success: false,
        error: 'tokenIn must be either "TUSD" or "TSAIL"'
      })
    }
    
    const result = await swapTokens(privateKey, tokenIn, amountIn, slippageTolerance)
    res.status(200).json(result)
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    })
  }
})

// Add liquidity
app.post('/add-liquidity', async (req: Request, res: Response) => {
  try {
    const { privateKey, amountTUSD, amountTSAIL, slippageTolerance } = req.body
    
    if (!privateKey || !amountTUSD || !amountTSAIL) {
      return res.status(400).json({
        success: false,
        error: 'Missing required parameters: privateKey, amountTUSD, amountTSAIL'
      })
    }
    
    const result = await addLiquidity(privateKey, amountTUSD, amountTSAIL, slippageTolerance)
    res.status(200).json(result)
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    })
  }
})

// Deposit LP tokens to vault - user deposits directly
app.post('/deposit-to-vault', async (req: Request, res: Response) => {
  try {
    const { privateKey, amountLPTokens, vaultType } = req.body
    
    if (!privateKey || !amountLPTokens || !vaultType) {
      return res.status(400).json({
        success: false,
        error: 'Missing required parameters: privateKey, amountLPTokens, vaultType (junior/senior/reserve)'
      })
    }
    
    if (vaultType !== 'junior' && vaultType !== 'senior' && vaultType !== 'reserve') {
      return res.status(400).json({
        success: false,
        error: 'vaultType must be either "junior", "senior", or "reserve"'
      })
    }
    
    const result = await depositToVault(privateKey, amountLPTokens, vaultType)
    res.status(200).json(result)
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    })
  }
})

// Invest vault funds in LP protocol - admin only
app.post('/invest-vault-in-lp', async (req: Request, res: Response) => {
  try {
    const { privateKey, vaultType, lpProtocolAddress, amount } = req.body
    
    if (!privateKey || !vaultType || !lpProtocolAddress || !amount) {
      return res.status(400).json({
        success: false,
        error: 'Missing required parameters: privateKey, vaultType, lpProtocolAddress, amount'
      })
    }
    
    if (vaultType !== 'junior' && vaultType !== 'senior' && vaultType !== 'reserve') {
      return res.status(400).json({
        success: false,
        error: 'vaultType must be either "junior", "senior", or "reserve"'
      })
    }
    
    const result = await investVaultInLP(privateKey, vaultType, lpProtocolAddress, amount)
    res.status(200).json(result)
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    })
  }
})

// MASTER FUNCTION: Complete stake and invest flow
app.post('/stake-and-invest-complete', async (req: Request, res: Response) => {
  try {
    const { userPrivateKey, adminPrivateKey, vaultType, amountTSTUSDE, slippageTolerance } = req.body
    
    if (!userPrivateKey || !adminPrivateKey || !vaultType || !amountTSTUSDE) {
      return res.status(400).json({
        success: false,
        error: 'Missing required parameters: userPrivateKey, adminPrivateKey, vaultType, amountTSTUSDE'
      })
    }
    
    if (vaultType !== 'junior' && vaultType !== 'senior' && vaultType !== 'reserve') {
      return res.status(400).json({
        success: false,
        error: 'vaultType must be either "junior", "senior", or "reserve"'
      })
    }
    
    const result = await stakeAndInvestComplete(
      userPrivateKey,
      adminPrivateKey,
      vaultType,
      amountTSTUSDE,
      slippageTolerance || 0.5
    )
    res.status(200).json(result)
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    })
  }
})

// Get rebase configuration
app.get('/rebase/config', async (req: Request, res: Response) => {
  try {
    const config = await getRebaseConfig()
    res.json({
      success: true,
      data: config
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    })
  }
})

// Set rebase interval (admin only)
app.post('/rebase/set-interval', async (req: Request, res: Response) => {
  try {
    const { privateKey, intervalSeconds } = req.body
    
    if (!privateKey) {
      return res.status(400).json({
        success: false,
        error: 'privateKey is required'
      })
    }
    
    if (!intervalSeconds || typeof intervalSeconds !== 'number') {
      return res.status(400).json({
        success: false,
        error: 'intervalSeconds must be a number'
      })
    }
    
    const result = await setRebaseInterval(privateKey, intervalSeconds)
    res.json(result)
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    })
  }
})

// Update vault value (admin only)
app.post('/vault/update-value', async (req: Request, res: Response) => {
  try {
    const { privateKey, profitBps, vaultType } = req.body
    
    if (!privateKey) {
      return res.status(400).json({
        success: false,
        error: 'privateKey is required'
      })
    }
    
    if (typeof profitBps !== 'number') {
      return res.status(400).json({
        success: false,
        error: 'profitBps must be a number (basis points: -5000 to +10000)'
      })
    }
    
    // Validate vaultType
    const validVaultTypes = ['senior', 'junior', 'reserve']
    const vault = vaultType || 'senior'
    if (!validVaultTypes.includes(vault)) {
      return res.status(400).json({
        success: false,
        error: `vaultType must be one of: ${validVaultTypes.join(', ')}`
      })
    }
    
    const result = await updateVaultValue(privateKey, profitBps, vault)
    res.json(result)
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    })
  }
})

// Execute rebase (admin only)
app.post('/vault/rebase', async (req: Request, res: Response) => {
  try {
    const { privateKey } = req.body
    
    if (!privateKey) {
      return res.status(400).json({
        success: false,
        error: 'privateKey is required'
      })
    }
    
    const result = await executeSeniorRebase(privateKey)
    res.json(result)
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    })
  }
})

// Update all vaults and execute rebase (admin only)
app.post('/vault/update-and-rebase', async (req: Request, res: Response) => {
  try {
    const { privateKey } = req.body
    
    if (!privateKey) {
      return res.status(400).json({
        success: false,
        error: 'privateKey is required'
      })
    }
    
    const result = await updateAllVaultsAndRebase(privateKey)
    res.json(result)
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    })
  }
})

// Whitelist address for Senior Vault (admin only)
app.post('/vault/whitelist', async (req: Request, res: Response) => {
  try {
    const { privateKey, address } = req.body
    
    if (!privateKey) {
      return res.status(400).json({
        success: false,
        error: 'privateKey is required'
      })
    }
    
    if (!address) {
      return res.status(400).json({
        success: false,
        error: 'address is required'
      })
    }
    
    const result = await whitelistAddress(privateKey, address)
    res.json(result)
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    })
  }
})

app.listen(PORT, () => {
  console.log(`🚀 Server is running on http://localhost:${PORT}`);
  console.log(`📍 Health check available at http://localhost:${PORT}/health`);
  console.log(`📊 Pool reserves at http://localhost:${PORT}/reserves`);
  console.log(`💰 stablecoin price at http://localhost:${PORT}/lp-price`);
  console.log(`🏦 Vaults total supply at http://localhost:${PORT}/vaults/total-supply`);
  console.log(`💵 Vaults USD value at http://localhost:${PORT}/vaults/value`);
  console.log(`📈 Senior backing ratio at http://localhost:${PORT}/senior/backing-ratio`);
  console.log(`⛓️  Vaults on-chain value at http://localhost:${PORT}/vaults/onchain-value`);
  console.log(`💎 Junior token price at http://localhost:${PORT}/junior/token-price`);
  console.log(`📊 Vaults profits at http://localhost:${PORT}/vaults/profits`);
  console.log(`💎 Vaults LP holdings at http://localhost:${PORT}/vaults/lp-holdings`);
  console.log(`📐 Vaults update BPS at GET http://localhost:${PORT}/vaults/update-bps`);
  console.log(`🔄 Swap tokens at POST http://localhost:${PORT}/swap`);
  console.log(`💧 Add liquidity at POST http://localhost:${PORT}/add-liquidity`);
  console.log(`💼 Deposit to vault at POST http://localhost:${PORT}/deposit-to-vault`);
  console.log(`🏦 Invest vault in LP at POST http://localhost:${PORT}/invest-vault-in-lp`);
  console.log(`🚀 Complete stake & invest at POST http://localhost:${PORT}/stake-and-invest-complete`);
  console.log(`📊 Projected backing ratio at GET http://localhost:${PORT}/senior/projected-backing-ratio`);
  console.log(`⏱️  Rebase config at GET http://localhost:${PORT}/rebase/config`);
  console.log(`⚙️  Set rebase interval at POST http://localhost:${PORT}/rebase/set-interval`);
  console.log(`💰 Update vault value at POST http://localhost:${PORT}/vault/update-value`);
  console.log(`🎯 Execute rebase at POST http://localhost:${PORT}/vault/rebase`);
  console.log(`✅ Whitelist address at POST http://localhost:${PORT}/vault/whitelist`);
});

