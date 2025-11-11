import { Token } from '@uniswap/sdk-core'
import { Pair } from '@uniswap/v2-sdk'
import * as ethers from 'ethers'
import {
    TSAIL_ADDRESS,
    TUSD_ADDRESS,
    LP_PAIR_ADDRESS,
    CHAIN_ID,
    RPC_URL,
    SENIOR_VAULT_ADDRESS,
    JUNIOR_VAULT_ADDRESS,
    RESERVE_VAULT_ADDRESS,
    VAULT_ABI,
    ERC20_ABI,
    UNISWAP_V2_ROUTER,
    ROUTER_ABI,
    ADMIN_ADDRESS
} from './constants'

// Uniswap V2 Pair ABI (only the functions we need)
const PAIR_ABI = [
    'function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast)',
    'function token0() external view returns (address)',
    'function token1() external view returns (address)',
    'function totalSupply() external view returns (uint256)'
]

export const getUniswapPair = () => {
    // Return the actual LP pair address
    return LP_PAIR_ADDRESS
}

export const getPairTokens = () => {
    // Create token instances for the pair
    const tsail = new Token(CHAIN_ID, TSAIL_ADDRESS, 18, 'TSAIL', 'Token SAIL')
    const tusd = new Token(CHAIN_ID, TUSD_ADDRESS, 18, 'TUSD', 'Token USD')
    
    return { tsail, tusd }
}

export const getReserves = async () => {
    try {
        // Create provider
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        
        // Create contract instance
        const pairContract = new ethers.Contract(LP_PAIR_ADDRESS, PAIR_ABI, provider)
        
        // Get reserves
        const [reserve0, reserve1, blockTimestampLast] = await pairContract.getReserves()
        
        // Get token addresses to determine which reserve is which
        const token0 = await pairContract.token0()
        const token1 = await pairContract.token1()
        
        // Format reserves (convert from wei to human-readable)
        const reserve0Formatted = ethers.formatUnits(reserve0, 18)
        const reserve1Formatted = ethers.formatUnits(reserve1, 18)
        
        // Determine which token is which
        const isTsailToken0 = token0.toLowerCase() === TSAIL_ADDRESS.toLowerCase()
        
        return {
            token0: token0,
            token1: token1,
            reserve0: reserve0Formatted,
            reserve1: reserve1Formatted,
            tsailReserve: isTsailToken0 ? reserve0Formatted : reserve1Formatted,
            tusdReserve: isTsailToken0 ? reserve1Formatted : reserve0Formatted,
            blockTimestampLast: Number(blockTimestampLast),
            raw: {
                reserve0: reserve0.toString(),
                reserve1: reserve1.toString()
            }
        }
    } catch (error) {
        console.error('Error fetching reserves:', error)
        throw error
    }
}

export const getLPTokenPrice = async () => {
    try {
        // Create provider
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        
        // Create contract instance
        const pairContract = new ethers.Contract(LP_PAIR_ADDRESS, PAIR_ABI, provider)
        
        // Get reserves and total supply
        const [reserve0, reserve1] = await pairContract.getReserves()
        const totalSupply = await pairContract.totalSupply()
        
        // Get token addresses to determine which reserve is which
        const token0 = await pairContract.token0()
        const isTsailToken0 = token0.toLowerCase() === TSAIL_ADDRESS.toLowerCase()
        
        // Get reserves for each token
        const tsailReserve = isTsailToken0 ? reserve0 : reserve1
        const tusdReserve = isTsailToken0 ? reserve1 : reserve0
        
        // Calculate TSAIL price in TUSD
        const tsailPrice = Number(ethers.formatUnits(tusdReserve, 18)) / Number(ethers.formatUnits(tsailReserve, 18))
        
        // Calculate total pool value in TUSD
        // Total Value = (TSAIL reserve * TSAIL price) + TUSD reserve
        const tsailReserveFormatted = Number(ethers.formatUnits(tsailReserve, 18))
        const tusdReserveFormatted = Number(ethers.formatUnits(tusdReserve, 18))
        const totalPoolValueInTUSD = (tsailReserveFormatted * tsailPrice) + tusdReserveFormatted
        
        // Calculate LP token price
        const totalSupplyFormatted = Number(ethers.formatUnits(totalSupply, 18))
        const lpTokenPrice = totalPoolValueInTUSD / totalSupplyFormatted
        
        return {
            lpTokenPrice: lpTokenPrice.toFixed(6),
            lpTokenPriceInTUSD: lpTokenPrice.toFixed(6),
            totalSupply: totalSupplyFormatted.toFixed(6),
            totalPoolValue: totalPoolValueInTUSD.toFixed(6),
            tsailPrice: tsailPrice.toFixed(6),
            reserves: {
                tsail: tsailReserveFormatted.toFixed(6),
                tusd: tusdReserveFormatted.toFixed(6)
            }
        }
    } catch (error) {
        console.error('Error calculating LP token price:', error)
        throw error
    }
}

export const getVaultsTotalSupply = async () => {
    try {
        // Create provider
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        
        // Create contract instances for each vault
        const seniorVault = new ethers.Contract(SENIOR_VAULT_ADDRESS, VAULT_ABI, provider)
        const juniorVault = new ethers.Contract(JUNIOR_VAULT_ADDRESS, VAULT_ABI, provider)
        const reserveVault = new ethers.Contract(RESERVE_VAULT_ADDRESS, VAULT_ABI, provider)
        
        // Fetch total supply from all vaults in parallel
        const [seniorSupply, juniorSupply, reserveSupply] = await Promise.all([
            seniorVault.totalSupply(),
            juniorVault.totalSupply(),
            reserveVault.totalSupply()
        ])
        
        // Format the supplies
        const seniorSupplyFormatted = ethers.formatUnits(seniorSupply, 18)
        const juniorSupplyFormatted = ethers.formatUnits(juniorSupply, 18)
        const reserveSupplyFormatted = ethers.formatUnits(reserveSupply, 18)
        
        return {
            seniorVault: {
                address: SENIOR_VAULT_ADDRESS,
                totalSupply: seniorSupplyFormatted,
                totalSupplyRaw: seniorSupply.toString()
            },
            juniorVault: {
                address: JUNIOR_VAULT_ADDRESS,
                totalSupply: juniorSupplyFormatted,
                totalSupplyRaw: juniorSupply.toString()
            },
            reserveVault: {
                address: RESERVE_VAULT_ADDRESS,
                totalSupply: reserveSupplyFormatted,
                totalSupplyRaw: reserveSupply.toString()
            },
            total: {
                formatted: (
                    Number(seniorSupplyFormatted) + 
                    Number(juniorSupplyFormatted) + 
                    Number(reserveSupplyFormatted)
                ).toFixed(6)
            }
        }
    } catch (error) {
        console.error('Error fetching vaults total supply:', error)
        throw error
    }
}

/**
 * Calculate total USD value of a vault
 * Combines stablecoin balance (actual balanceOf) + LP token holdings value
 * @param vaultContract Vault contract instance
 * @param vaultAddress Vault address to check USDe balance
 * @param lpPrice LP token price in USD
 * @param provider Provider instance
 * @returns Total USD value
 */
async function calculateVaultUSDValue(vaultContract: ethers.Contract, vaultAddress: string, lpPrice: number, provider: ethers.JsonRpcProvider, isSenior: boolean = false): Promise<number> {
    try {
        // 1. Get ACTUAL stablecoin balance (not totalAssets which returns _vaultValue)
        const usdeToken = new ethers.Contract(TUSD_ADDRESS, ERC20_ABI, provider)
        const actualBalance = await usdeToken.balanceOf(vaultAddress)
        const stablecoinValueUSD = Number(ethers.formatUnits(actualBalance, 18))
        
        // 2. Get LP token holdings and calculate their USD value
        let lpTokenValueUSD = 0
        try {
            // Senior vault uses getLPTokenHoldings(), others use getLPHoldings()
            const functionName = isSenior ? 'getLPTokenHoldings' : 'getLPHoldings'
            const holdings = await vaultContract[functionName]()
            for (const holding of holdings) {
                const amountFormatted = Number(ethers.formatUnits(holding.amount, 18))
                lpTokenValueUSD += amountFormatted * lpPrice
            }
        } catch (error) {
            // If function doesn't exist or fails, assume no LP holdings (silently)
        }
        
        // 3. Total USD value = actual stablecoins + LP tokens value
        return stablecoinValueUSD + lpTokenValueUSD
    } catch (error) {
        console.error('Error calculating vault USD value:', error)
        throw error
    }
}

export const getVaultsValueInUSD = async () => {
    try {
        // Create provider
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        
        // Create contract instances for each vault
        const seniorVault = new ethers.Contract(SENIOR_VAULT_ADDRESS, VAULT_ABI, provider)
        const juniorVault = new ethers.Contract(JUNIOR_VAULT_ADDRESS, VAULT_ABI, provider)
        const reserveVault = new ethers.Contract(RESERVE_VAULT_ADDRESS, VAULT_ABI, provider)
        
        // Get LP token price
        const lpPriceData = await getLPTokenPrice()
        const lpPrice = Number(lpPriceData.lpTokenPriceInTUSD)
        
        // Get actual USDe balances (not totalAssets which returns _vaultValue)
        const usdeToken = new ethers.Contract(TUSD_ADDRESS, ERC20_ABI, provider)
        const [seniorAssets, juniorAssets, reserveAssets] = await Promise.all([
            usdeToken.balanceOf(SENIOR_VAULT_ADDRESS),
            usdeToken.balanceOf(JUNIOR_VAULT_ADDRESS),
            usdeToken.balanceOf(RESERVE_VAULT_ADDRESS)
        ])
        
        // Convert to USD (USDe is 1:1 with USD)
        const seniorUsdeValueUSD = Number(ethers.formatUnits(seniorAssets, 18))
        const juniorUsdeValueUSD = Number(ethers.formatUnits(juniorAssets, 18))
        const reserveUsdeValueUSD = Number(ethers.formatUnits(reserveAssets, 18))
        
        // Calculate total USD values including LP token holdings
        const [seniorTotalValueUSD, juniorTotalValueUSD, reserveTotalValueUSD] = await Promise.all([
            calculateVaultUSDValue(seniorVault, SENIOR_VAULT_ADDRESS, lpPrice, provider, true),
            calculateVaultUSDValue(juniorVault, JUNIOR_VAULT_ADDRESS, lpPrice, provider, false),
            calculateVaultUSDValue(reserveVault, RESERVE_VAULT_ADDRESS, lpPrice, provider, false)
        ])
        
        const totalValueUSD = seniorTotalValueUSD + juniorTotalValueUSD + reserveTotalValueUSD
        
        return {
            lpTokenPrice: lpPrice.toFixed(6),
            seniorVault: {
                address: SENIOR_VAULT_ADDRESS,
                totalAssets: ethers.formatUnits(seniorAssets, 18),
                valueUSD: seniorUsdeValueUSD.toFixed(2),  // ONLY USDe balance
                totalValueUSD: seniorTotalValueUSD.toFixed(2),  // USDe + LP value
                totalAssetsRaw: seniorAssets.toString()
            },
            juniorVault: {
                address: JUNIOR_VAULT_ADDRESS,
                totalAssets: ethers.formatUnits(juniorAssets, 18),
                valueUSD: juniorUsdeValueUSD.toFixed(2),  // ONLY USDe balance
                totalValueUSD: juniorTotalValueUSD.toFixed(2),  // USDe + LP value
                totalAssetsRaw: juniorAssets.toString()
            },
            reserveVault: {
                address: RESERVE_VAULT_ADDRESS,
                totalAssets: ethers.formatUnits(reserveAssets, 18),
                valueUSD: reserveUsdeValueUSD.toFixed(2),  // ONLY USDe balance
                totalValueUSD: reserveTotalValueUSD.toFixed(2),  // USDe + LP value
                totalAssetsRaw: reserveAssets.toString()
            },
            total: {
                totalAssets: (
                    Number(ethers.formatUnits(seniorAssets, 18)) + 
                    Number(ethers.formatUnits(juniorAssets, 18)) + 
                    Number(ethers.formatUnits(reserveAssets, 18))
                ).toFixed(6),
                valueUSD: totalValueUSD.toFixed(2)
            }
        }
    } catch (error) {
        console.error('Error calculating vaults value in USD:', error)
        throw error
    }
}

export const getSeniorBackingRatio = async () => {
    try {
        // Create provider
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        
        // Create contract instance for senior vault
        const seniorVault = new ethers.Contract(SENIOR_VAULT_ADDRESS, VAULT_ABI, provider)
        
        // Fetch total supply, on-chain vault value, and LP price in parallel
        const [seniorSupply, vaultValue, seniorAssets, lpPriceData] = await Promise.all([
            seniorVault.totalSupply(),
            seniorVault.vaultValue(),
            seniorVault.totalAssets(),
            getLPTokenPrice()
        ])
        
        // Format values
        const seniorSupplyFormatted = Number(ethers.formatUnits(seniorSupply, 18))
        const vaultValueFormatted = Number(ethers.formatUnits(vaultValue, 18))
        const lpPrice = Number(lpPriceData.lpTokenPriceInTUSD)
        
        // Calculate real-time USD value using actual holdings (for comparison)
        const calculatedValueUSD = await calculateVaultUSDValue(seniorVault, SENIOR_VAULT_ADDRESS, lpPrice, provider, true)
        
        // Backing ratio uses ON-CHAIN vaultValue (not calculated value)
        // This is what the contract uses for rebases and spillover logic
        const backingRatioValue = seniorSupplyFormatted > 0 ? (vaultValueFormatted / seniorSupplyFormatted) * 100 : 100
        
        return {
            seniorVault: {
                address: SENIOR_VAULT_ADDRESS,
                totalSupply: seniorSupplyFormatted.toFixed(6),
                totalAssets: ethers.formatUnits(seniorAssets, 18),
                onChainValue: vaultValueFormatted.toFixed(2),
                calculatedValueUSD: calculatedValueUSD.toFixed(2),
                backingRatio: backingRatioValue.toFixed(2) + '%'
            },
            lpTokenPrice: lpPrice.toFixed(6),
            backingRatio: backingRatioValue // Frontend expects this at root level (as number)
        }
    } catch (error) {
        console.error('Error calculating senior backing ratio:', error)
        throw error
    }
}

export const getProjectedSeniorBackingRatio = async () => {
    try {
        // Create provider
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        
        // Create contract instance for senior vault
        const seniorVault = new ethers.Contract(SENIOR_VAULT_ADDRESS, VAULT_ABI, provider)
        
        // Fetch total supply, on-chain vault value, and LP price in parallel
        const [seniorSupply, vaultValue, lpPriceData] = await Promise.all([
            seniorVault.totalSupply(),
            seniorVault.vaultValue(),
            getLPTokenPrice()
        ])
        
        // Format values
        const seniorSupplyFormatted = Number(ethers.formatUnits(seniorSupply, 18))
        const vaultValueFormatted = Number(ethers.formatUnits(vaultValue, 18))
        const lpPrice = Number(lpPriceData.lpTokenPriceInTUSD)
        
        // Calculate real-time USD value using actual holdings
        const calculatedValueUSD = await calculateVaultUSDValue(seniorVault, SENIOR_VAULT_ADDRESS, lpPrice, provider, true)
        
        // Current backing ratio (using on-chain value)
        const currentBackingRatio = seniorSupplyFormatted > 0 ? (vaultValueFormatted / seniorSupplyFormatted) * 100 : 100
        
        // Projected backing ratio (using calculated real-time value)
        const projectedBackingRatio = seniorSupplyFormatted > 0 ? (calculatedValueUSD / seniorSupplyFormatted) * 100 : 100
        
        // Calculate the difference
        const backingRatioDelta = projectedBackingRatio - currentBackingRatio
        const profitDelta = calculatedValueUSD - vaultValueFormatted
        
        return {
            seniorVault: {
                address: SENIOR_VAULT_ADDRESS,
                totalSupply: seniorSupplyFormatted.toFixed(6),
                onChainValue: vaultValueFormatted.toFixed(2),
                calculatedValueUSD: calculatedValueUSD.toFixed(2),
                valueDelta: profitDelta.toFixed(2),
                currentBackingRatio: currentBackingRatio.toFixed(2) + '%',
                projectedBackingRatio: projectedBackingRatio.toFixed(2) + '%',
                backingRatioDelta: (backingRatioDelta >= 0 ? '+' : '') + backingRatioDelta.toFixed(2) + '%'
            },
            lpTokenPrice: lpPrice.toFixed(6),
            projectedBackingRatio: projectedBackingRatio, // Frontend expects this at root level (as number)
            suggestion: Math.abs(backingRatioDelta) > 1 
                ? `Consider updating vault value. Projected backing is ${backingRatioDelta > 0 ? 'higher' : 'lower'} by ${Math.abs(backingRatioDelta).toFixed(2)}%`
                : 'Vault value is in sync with market'
        }
    } catch (error) {
        console.error('Error calculating projected backing ratio:', error)
        throw error
    }
}

export const getVaultsOnChainValue = async () => {
    try {
        // Create provider
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        
        // Create contract instances for each vault
        const seniorVault = new ethers.Contract(SENIOR_VAULT_ADDRESS, VAULT_ABI, provider)
        const juniorVault = new ethers.Contract(JUNIOR_VAULT_ADDRESS, VAULT_ABI, provider)
        const reserveVault = new ethers.Contract(RESERVE_VAULT_ADDRESS, VAULT_ABI, provider)
        
        // Fetch vaultValue from all vaults in parallel
        const [seniorValue, juniorValue, reserveValue] = await Promise.all([
            seniorVault.vaultValue(),
            juniorVault.vaultValue(),
            reserveVault.vaultValue()
        ])
        
        // Format the values (assuming 18 decimals)
        const seniorValueFormatted = Number(ethers.formatUnits(seniorValue, 18))
        const juniorValueFormatted = Number(ethers.formatUnits(juniorValue, 18))
        const reserveValueFormatted = Number(ethers.formatUnits(reserveValue, 18))
        
        return {
            seniorVault: {
                address: SENIOR_VAULT_ADDRESS,
                vaultValue: seniorValueFormatted.toFixed(6),
                vaultValueRaw: seniorValue.toString()
            },
            juniorVault: {
                address: JUNIOR_VAULT_ADDRESS,
                vaultValue: juniorValueFormatted.toFixed(6),
                vaultValueRaw: juniorValue.toString()
            },
            reserveVault: {
                address: RESERVE_VAULT_ADDRESS,
                vaultValue: reserveValueFormatted.toFixed(6),
                vaultValueRaw: reserveValue.toString()
            },
            total: {
                vaultValue: (seniorValueFormatted + juniorValueFormatted + reserveValueFormatted).toFixed(6)
            }
        }
    } catch (error) {
        console.error('Error fetching vaults on-chain value:', error)
        throw error
    }
}

export const getJuniorTokenPrice = async () => {
    try {
        // Create provider
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        
        // Create contract instance for junior vault
        const juniorVault = new ethers.Contract(JUNIOR_VAULT_ADDRESS, VAULT_ABI, provider)
        
        // Fetch total supply and LP price
        const [juniorSupply, lpPriceData] = await Promise.all([
            juniorVault.totalSupply(),
            getLPTokenPrice()
        ])
        
        // Format values
        const juniorSupplyFormatted = Number(ethers.formatUnits(juniorSupply, 18))
        const lpPrice = Number(lpPriceData.lpTokenPriceInTUSD)
        
        // Calculate USD value using actual USDe balance + LP token holdings
        const juniorValueUSD = await calculateVaultUSDValue(juniorVault, JUNIOR_VAULT_ADDRESS, lpPrice, provider, false)
        
        // Calculate junior token price: valueUSD / totalSupply
        const juniorTokenPrice = juniorSupplyFormatted > 0 ? juniorValueUSD / juniorSupplyFormatted : 0
        
        // Get totalAssets for reference
        const juniorAssets = await juniorVault.totalAssets()
        
        return {
            juniorVault: {
                address: JUNIOR_VAULT_ADDRESS,
                totalSupply: juniorSupplyFormatted.toFixed(6),
                totalAssets: ethers.formatUnits(juniorAssets, 18),
                valueUSD: juniorValueUSD.toFixed(2),
                tokenPrice: juniorTokenPrice.toFixed(6)
            },
            lpTokenPrice: lpPrice.toFixed(6)
        }
    } catch (error) {
        console.error('Error calculating junior token price:', error)
        throw error
    }
}

export const getReserveTokenPrice = async () => {
    try {
        // Create provider
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        
        // Create contract instance for reserve vault
        const reserveVault = new ethers.Contract(RESERVE_VAULT_ADDRESS, VAULT_ABI, provider)
        
        // Fetch total supply and LP price
        const [reserveSupply, lpPriceData] = await Promise.all([
            reserveVault.totalSupply(),
            getLPTokenPrice()
        ])
        
        // Format values
        const reserveSupplyFormatted = Number(ethers.formatUnits(reserveSupply, 18))
        const lpPrice = Number(lpPriceData.lpTokenPriceInTUSD)
        
        // Calculate USD value using actual USDe balance + LP token holdings
        const reserveValueUSD = await calculateVaultUSDValue(reserveVault, RESERVE_VAULT_ADDRESS, lpPrice, provider, false)
        
        // Calculate reserve token price: valueUSD / totalSupply
        const reserveTokenPrice = reserveSupplyFormatted > 0 ? reserveValueUSD / reserveSupplyFormatted : 0
        
        // Get totalAssets for reference
        const reserveAssets = await reserveVault.totalAssets()
        
        return {
            reserveVault: {
                address: RESERVE_VAULT_ADDRESS,
                totalSupply: reserveSupplyFormatted.toFixed(6),
                totalAssets: ethers.formatUnits(reserveAssets, 18),
                valueUSD: reserveValueUSD.toFixed(2),
                tokenPrice: reserveTokenPrice.toFixed(6)
            },
            price: reserveTokenPrice,
            lpTokenPrice: lpPrice.toFixed(6)
        }
    } catch (error) {
        console.error('Error calculating reserve token price:', error)
        throw error
    }
}

export const swapTokens = async (
    privateKey: string,
    tokenIn: 'TUSD' | 'TSAIL',
    amountIn: string,
    slippageTolerance: number = 0.5 // 0.5% slippage by default
) => {
    try {
        // Create provider and wallet
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        const wallet = new ethers.Wallet(privateKey, provider)
        
        // Determine token addresses based on swap direction
        const tokenInAddress = tokenIn === 'TUSD' ? TUSD_ADDRESS : TSAIL_ADDRESS
        const tokenOutAddress = tokenIn === 'TUSD' ? TSAIL_ADDRESS : TUSD_ADDRESS
        
        // Convert amount to wei
        const amountInWei = ethers.parseUnits(amountIn, 18)
        
        // Create contract instances
        const tokenInContract = new ethers.Contract(tokenInAddress, ERC20_ABI, wallet)
        const routerContract = new ethers.Contract(UNISWAP_V2_ROUTER, ROUTER_ABI, wallet)
        const pairContract = new ethers.Contract(LP_PAIR_ADDRESS, PAIR_ABI, provider)
        
        // Check balance
        const balance = await tokenInContract.balanceOf(wallet.address)
        if (balance < amountInWei) {
            throw new Error(`Insufficient balance. Have: ${ethers.formatUnits(balance, 18)}, Need: ${amountIn}`)
        }
        
        // Check allowance
        const allowance = await tokenInContract.allowance(wallet.address, UNISWAP_V2_ROUTER)
        
        // Approve if needed
        if (allowance < amountInWei) {
            console.log('Approving token spend...')
            const approveTx = await tokenInContract.approve(UNISWAP_V2_ROUTER, amountInWei)
            await approveTx.wait()
            console.log('Approval confirmed')
        }
        
        // Get reserves to calculate expected output
        const [reserve0, reserve1] = await pairContract.getReserves()
        const token0 = await pairContract.token0()
        
        // Determine which reserve is which
        const isTsailToken0 = token0.toLowerCase() === TSAIL_ADDRESS.toLowerCase()
        const reserveIn = tokenIn === 'TUSD' 
            ? (isTsailToken0 ? reserve1 : reserve0)
            : (isTsailToken0 ? reserve0 : reserve1)
        const reserveOut = tokenIn === 'TUSD'
            ? (isTsailToken0 ? reserve0 : reserve1)
            : (isTsailToken0 ? reserve1 : reserve0)
        
        // Calculate expected output using Uniswap V2 formula: amountOut = (amountIn * 997 * reserveOut) / (reserveIn * 1000 + amountIn * 997)
        const amountInWithFee = amountInWei * BigInt(997)
        const numerator = amountInWithFee * reserveOut
        const denominator = (reserveIn * BigInt(1000)) + amountInWithFee
        const amountOutExpected = numerator / denominator
        
        // Calculate minimum output with slippage tolerance
        const amountOutMin = (amountOutExpected * BigInt(Math.floor((100 - slippageTolerance) * 100))) / BigInt(10000)
        
        // Set deadline (10 minutes from now)
        const deadline = Math.floor(Date.now() / 1000) + 600
        
        // Execute swap
        const path = [tokenInAddress, tokenOutAddress]
        console.log('Executing swap...')
        const swapTx = await routerContract.swapExactTokensForTokens(
            amountInWei,
            amountOutMin,
            path,
            wallet.address,
            deadline
        )
        
        const receipt = await swapTx.wait()
        
        return {
            success: true,
            transactionHash: receipt.hash,
            from: wallet.address,
            swap: {
                tokenIn: tokenIn,
                tokenOut: tokenIn === 'TUSD' ? 'TSAIL' : 'TUSD',
                amountIn: amountIn,
                amountOutExpected: ethers.formatUnits(amountOutExpected, 18),
                amountOutMin: ethers.formatUnits(amountOutMin, 18),
                slippage: slippageTolerance + '%'
            },
            blockNumber: receipt.blockNumber,
            gasUsed: receipt.gasUsed.toString()
        }
    } catch (error) {
        console.error('Error swapping tokens:', error)
        throw error
    }
}

export const addLiquidity = async (
    privateKey: string,
    amountTUSD: string,
    amountTSAIL: string,
    slippageTolerance: number = 0.5 // 0.5% slippage by default
) => {
    try {
        // Create provider and wallet
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        const wallet = new ethers.Wallet(privateKey, provider)
        
        // Create contract instances
        const tusdContract = new ethers.Contract(TUSD_ADDRESS, ERC20_ABI, wallet)
        const tsailContract = new ethers.Contract(TSAIL_ADDRESS, ERC20_ABI, wallet)
        const routerContract = new ethers.Contract(UNISWAP_V2_ROUTER, ROUTER_ABI, wallet)
        const pairContract = new ethers.Contract(LP_PAIR_ADDRESS, PAIR_ABI, provider)
        
        // Get current reserves to calculate optimal ratio
        const [reserve0, reserve1] = await pairContract.getReserves()
        const token0 = await pairContract.token0()
        const isTsailToken0 = token0.toLowerCase() === TSAIL_ADDRESS.toLowerCase()
        
        const tusdReserve = isTsailToken0 ? reserve1 : reserve0
        const tsailReserve = isTsailToken0 ? reserve0 : reserve1
        
        // Convert input amounts to wei
        let amountTUSDWei = ethers.parseUnits(amountTUSD, 18)
        let amountTSAILWei = ethers.parseUnits(amountTSAIL, 18)
        
        // Calculate optimal amounts based on current pool ratio
        // The router will use these ratios, so we need to adjust one of the amounts
        const optimalTUSD = (amountTSAILWei * tusdReserve) / tsailReserve
        const optimalTSAIL = (amountTUSDWei * tsailReserve) / tusdReserve
        
        // Use the smaller ratio to ensure we don't exceed the desired amounts
        if (optimalTUSD <= amountTUSDWei) {
            amountTUSDWei = optimalTUSD
        } else {
            amountTSAILWei = optimalTSAIL
        }
        
        console.log(`Optimal amounts: TUSD=${ethers.formatUnits(amountTUSDWei, 18)}, TSAIL=${ethers.formatUnits(amountTSAILWei, 18)}`)
        
        // Check balances
        const [tusdBalance, tsailBalance] = await Promise.all([
            tusdContract.balanceOf(wallet.address),
            tsailContract.balanceOf(wallet.address)
        ])
        
        if (tusdBalance < amountTUSDWei) {
            throw new Error(`Insufficient TUSD balance. Have: ${ethers.formatUnits(tusdBalance, 18)}, Need: ${ethers.formatUnits(amountTUSDWei, 18)}`)
        }
        
        if (tsailBalance < amountTSAILWei) {
            throw new Error(`Insufficient TSAIL balance. Have: ${ethers.formatUnits(tsailBalance, 18)}, Need: ${ethers.formatUnits(amountTSAILWei, 18)}`)
        }
        
        // Check allowances
        const [tusdAllowance, tsailAllowance] = await Promise.all([
            tusdContract.allowance(wallet.address, UNISWAP_V2_ROUTER),
            tsailContract.allowance(wallet.address, UNISWAP_V2_ROUTER)
        ])
        
        // Approve TUSD if needed
        if (tusdAllowance < amountTUSDWei) {
            console.log('Approving TUSD...')
            const approveTx = await tusdContract.approve(UNISWAP_V2_ROUTER, amountTUSDWei)
            await approveTx.wait()
            console.log('TUSD approval confirmed')
        }
        
        // Approve TSAIL if needed
        if (tsailAllowance < amountTSAILWei) {
            console.log('Approving TSAIL...')
            const approveTx = await tsailContract.approve(UNISWAP_V2_ROUTER, amountTSAILWei)
            await approveTx.wait()
            console.log('TSAIL approval confirmed')
        }
        
        // Calculate minimum amounts with slippage tolerance (wider tolerance for minimums)
        const amountTUSDMin = (amountTUSDWei * BigInt(Math.floor((100 - slippageTolerance - 2) * 100))) / BigInt(10000)
        const amountTSAILMin = (amountTSAILWei * BigInt(Math.floor((100 - slippageTolerance - 2) * 100))) / BigInt(10000)
        
        // Set deadline (10 minutes from now)
        const deadline = Math.floor(Date.now() / 1000) + 600
        
        // Add liquidity
        console.log('Adding liquidity...')
        const addLiquidityTx = await routerContract.addLiquidity(
            TUSD_ADDRESS,
            TSAIL_ADDRESS,
            amountTUSDWei,
            amountTSAILWei,
            amountTUSDMin,
            amountTSAILMin,
            wallet.address,
            deadline
        )
        
        const receipt = await addLiquidityTx.wait()
        
        return {
            success: true,
            transactionHash: receipt.hash,
            from: wallet.address,
            liquidity: {
                tusdAmount: ethers.formatUnits(amountTUSDWei, 18),
                tsailAmount: ethers.formatUnits(amountTSAILWei, 18),
                tusdMin: ethers.formatUnits(amountTUSDMin, 18),
                tsailMin: ethers.formatUnits(amountTSAILMin, 18),
                slippage: slippageTolerance + '%'
            },
            blockNumber: receipt.blockNumber,
            gasUsed: receipt.gasUsed.toString()
        }
    } catch (error) {
        console.error('Error adding liquidity:', error)
        throw error
    }
}

/**
 * Simple deposit: User deposits LP tokens to vault and receives shares
 * @param userPrivateKey User's private key
 * @param amountLPTokens Amount of LP tokens to deposit
 * @param vaultType Which vault to deposit to
 */
export const depositToVault = async (
    userPrivateKey: string,
    amountLPTokens: string,
    vaultType: 'junior' | 'senior' | 'reserve'
) => {
    try {
        // Create provider and wallet
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        const userWallet = new ethers.Wallet(userPrivateKey, provider)

        // Determine vault address
        const vaultAddress = vaultType === 'junior' 
            ? JUNIOR_VAULT_ADDRESS 
            : vaultType === 'senior' 
            ? SENIOR_VAULT_ADDRESS 
            : RESERVE_VAULT_ADDRESS

        // Create contract instances
        const lpContract = new ethers.Contract(LP_PAIR_ADDRESS, ERC20_ABI, userWallet)
        const vaultContract = new ethers.Contract(vaultAddress, VAULT_ABI, userWallet)
        
        const amountWei = ethers.parseUnits(amountLPTokens, 18)
        
        // Check balance
        const balance = await lpContract.balanceOf(userWallet.address)
        if (balance < amountWei) {
            throw new Error(`Insufficient LP token balance. Have: ${ethers.formatUnits(balance, 18)}, Need: ${amountLPTokens}`)
        }
        
        // Check allowance
        const allowance = await lpContract.allowance(userWallet.address, vaultAddress)
        
        // Approve if needed
        if (allowance < amountWei) {
            console.log('Approving LP tokens for vault...')
            const approveTx = await lpContract.approve(vaultAddress, amountWei)
            await approveTx.wait()
            console.log('Approval confirmed')
        }
        
        // Deposit to vault
        console.log(`Depositing ${amountLPTokens} LP tokens to ${vaultType} vault...`)
        const depositTx = await vaultContract.deposit(amountWei, userWallet.address)
        const receipt = await depositTx.wait()
        
        console.log(`✅ Deposited successfully! TX: ${receipt.hash}`)
        
        return {
            success: true,
            transactionHash: receipt.hash,
            from: userWallet.address,
            vault: {
                type: vaultType,
                address: vaultAddress,
                lpDeposited: amountLPTokens
            },
            blockNumber: receipt.blockNumber,
            gasUsed: receipt.gasUsed.toString()
        }
    } catch (error) {
        console.error('Error depositing to vault:', error)
        throw error
    }
}

/**
 * Admin invests vault's LP tokens into an LP protocol
 * @param adminPrivateKey Admin's private key
 * @param vaultType Which vault to invest from
 * @param lpProtocolAddress Address of the LP protocol
 * @param amount Amount of LP tokens to invest
 */
export const investVaultInLP = async (
    adminPrivateKey: string,
    vaultType: 'junior' | 'senior' | 'reserve',
    lpProtocolAddress: string,
    amount: string
) => {
    try {
        // Create provider and wallet
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        const adminWallet = new ethers.Wallet(adminPrivateKey, provider)
        
        // Determine vault address
        const vaultAddress = vaultType === 'junior' 
            ? JUNIOR_VAULT_ADDRESS 
            : vaultType === 'senior' 
            ? SENIOR_VAULT_ADDRESS 
            : RESERVE_VAULT_ADDRESS
        
        // Create contract instance
        const vaultContract = new ethers.Contract(vaultAddress, VAULT_ABI, adminWallet)
        
        const amountWei = ethers.parseUnits(amount, 18)
        
        console.log(`Investing ${amount} LP tokens from ${vaultType} vault to LP protocol ${lpProtocolAddress}...`)
        
        // Call investInLP
        const tx = await vaultContract.investInLP(lpProtocolAddress, amountWei)
        const receipt = await tx.wait()
        
        console.log(`✅ Investment successful! TX: ${receipt.hash}`)

        return {
            success: true,
            transactionHash: receipt.hash,
                vault: {
                    type: vaultType,
                address: vaultAddress
            },
            lpProtocol: lpProtocolAddress,
            amount: amount,
            blockNumber: receipt.blockNumber,
            gasUsed: receipt.gasUsed.toString()
        }
    } catch (error) {
        console.error('Error investing in LP:', error)
        throw error
    }
}

export const getVaultsLPHoldings = async () => {
    try {
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        const lpPrice = Number((await getLPTokenPrice()).lpTokenPriceInTUSD)
        
        const seniorVault = new ethers.Contract(SENIOR_VAULT_ADDRESS, VAULT_ABI, provider)
        const juniorVault = new ethers.Contract(JUNIOR_VAULT_ADDRESS, VAULT_ABI, provider)
        const reserveVault = new ethers.Contract(RESERVE_VAULT_ADDRESS, VAULT_ABI, provider)
        
        const getLPHoldingsForVault = async (vault: ethers.Contract, isSenior: boolean) => {
            try {
                // Senior vault uses getLPTokenHoldings(), others use getLPHoldings()
                const functionName = isSenior ? 'getLPTokenHoldings' : 'getLPHoldings'
                const holdings = await vault[functionName]()
                let totalLPTokens = BigInt(0)
                for (const holding of holdings) {
                    totalLPTokens += holding.amount
                }
                const formatted = ethers.formatUnits(totalLPTokens, 18)
                const valueUSD = Number(formatted) * lpPrice
                return {
                    lpTokens: formatted,
                    valueUSD: valueUSD.toFixed(2)
                }
            } catch (error) {
                // Silently return 0 - vault doesn't have the function yet
                return { lpTokens: '0', valueUSD: '0.00' }
            }
        }
        
        const [seniorLP, juniorLP, reserveLP] = await Promise.all([
            getLPHoldingsForVault(seniorVault, true),
            getLPHoldingsForVault(juniorVault, false),
            getLPHoldingsForVault(reserveVault, false)
        ])

        return {
            lpTokenPrice: lpPrice.toFixed(6),
            seniorVault: seniorLP,
            juniorVault: juniorLP,
            reserveVault: reserveLP,
            total: {
                lpTokens: (Number(seniorLP.lpTokens) + Number(juniorLP.lpTokens) + Number(reserveLP.lpTokens)).toFixed(6),
                valueUSD: (Number(seniorLP.valueUSD) + Number(juniorLP.valueUSD) + Number(reserveLP.valueUSD)).toFixed(2)
            }
        }
    } catch (error) {
        console.error('Error fetching vaults LP holdings:', error)
        throw error
    }
}

export const getVaultsProfits = async () => {
    try {
        // Create provider
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        
        // Create contract instances for each vault
        const seniorVault = new ethers.Contract(SENIOR_VAULT_ADDRESS, VAULT_ABI, provider)
        const juniorVault = new ethers.Contract(JUNIOR_VAULT_ADDRESS, VAULT_ABI, provider)
        const reserveVault = new ethers.Contract(RESERVE_VAULT_ADDRESS, VAULT_ABI, provider)
        
        // Fetch vault values and LP price in parallel
        const [
            seniorValue, juniorValue, reserveValue,
            lpPriceData
        ] = await Promise.all([
            seniorVault.vaultValue(),
            juniorVault.vaultValue(),
            reserveVault.vaultValue(),
            getLPTokenPrice()
        ])
        
        const lpPrice = Number(lpPriceData.lpTokenPriceInTUSD)
        
        // Calculate current USD values using actual USDe balance + LP token holdings
        const [seniorCurrentUSD, juniorCurrentUSD, reserveCurrentUSD] = await Promise.all([
            calculateVaultUSDValue(seniorVault, SENIOR_VAULT_ADDRESS, lpPrice, provider, true),
            calculateVaultUSDValue(juniorVault, JUNIOR_VAULT_ADDRESS, lpPrice, provider, false),
            calculateVaultUSDValue(reserveVault, RESERVE_VAULT_ADDRESS, lpPrice, provider, false)
        ])
        
        // Format vault values
        const seniorValueFormatted = Number(ethers.formatUnits(seniorValue, 18))
        const juniorValueFormatted = Number(ethers.formatUnits(juniorValue, 18))
        const reserveValueFormatted = Number(ethers.formatUnits(reserveValue, 18))
        
        // Calculate profit percentages: ((currentUSD - onChainValue) / onChainValue) * 100
        const seniorProfitPercent = seniorValueFormatted > 0 
            ? ((seniorCurrentUSD - seniorValueFormatted) / seniorValueFormatted) * 100 
            : 0
        const juniorProfitPercent = juniorValueFormatted > 0 
            ? ((juniorCurrentUSD - juniorValueFormatted) / juniorValueFormatted) * 100 
            : 0
        const reserveProfitPercent = reserveValueFormatted > 0 
            ? ((reserveCurrentUSD - reserveValueFormatted) / reserveValueFormatted) * 100 
            : 0
        
        const totalOnChainValue = seniorValueFormatted + juniorValueFormatted + reserveValueFormatted
        const totalCurrentUSD = seniorCurrentUSD + juniorCurrentUSD + reserveCurrentUSD
        const totalProfitPercent = totalOnChainValue > 0 
            ? ((totalCurrentUSD - totalOnChainValue) / totalOnChainValue) * 100 
            : 0
        
        // Format with + or - sign
        const formatProfit = (profitPercent: number) => {
            const sign = profitPercent >= 0 ? '+' : ''
            return sign + profitPercent.toFixed(2) + '%'
        }
        
        return {
            lpTokenPrice: lpPrice.toFixed(6),
            seniorVault: {
                address: SENIOR_VAULT_ADDRESS,
                currentValueUSD: seniorCurrentUSD.toFixed(2),
                onChainValue: seniorValueFormatted.toFixed(2),
                profit: formatProfit(seniorProfitPercent),
                profitRaw: seniorProfitPercent.toFixed(6)
            },
            juniorVault: {
                address: JUNIOR_VAULT_ADDRESS,
                currentValueUSD: juniorCurrentUSD.toFixed(2),
                onChainValue: juniorValueFormatted.toFixed(2),
                profit: formatProfit(juniorProfitPercent),
                profitRaw: juniorProfitPercent.toFixed(6)
            },
            reserveVault: {
                address: RESERVE_VAULT_ADDRESS,
                currentValueUSD: reserveCurrentUSD.toFixed(2),
                onChainValue: reserveValueFormatted.toFixed(2),
                profit: formatProfit(reserveProfitPercent),
                profitRaw: reserveProfitPercent.toFixed(6)
            },
            total: {
                currentValueUSD: totalCurrentUSD.toFixed(2),
                onChainValue: totalOnChainValue.toFixed(2),
                profit: formatProfit(totalProfitPercent),
                profitRaw: totalProfitPercent.toFixed(6)
            }
        }
    } catch (error) {
        console.error('Error calculating vaults profits:', error)
        throw error
    }
}

/**
 * Get BPS values for updateVaultValue() calls
 * @returns BPS values that admin should use to update each vault
 */
export const getVaultsUpdateBPS = async () => {
    try {
        // Create provider
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        
        // Create contract instances for each vault
        const seniorVault = new ethers.Contract(SENIOR_VAULT_ADDRESS, VAULT_ABI, provider)
        const juniorVault = new ethers.Contract(JUNIOR_VAULT_ADDRESS, VAULT_ABI, provider)
        const reserveVault = new ethers.Contract(RESERVE_VAULT_ADDRESS, VAULT_ABI, provider)
        
        // Fetch vault values and LP price in parallel
        const [
            seniorValue, juniorValue, reserveValue,
            lpPriceData
        ] = await Promise.all([
            seniorVault.vaultValue(),
            juniorVault.vaultValue(),
            reserveVault.vaultValue(),
            getLPTokenPrice()
        ])
        
        const lpPrice = Number(lpPriceData.lpTokenPriceInTUSD)
        
        // Calculate current USD values using actual USDe balance + LP token holdings
        const [seniorCurrentUSD, juniorCurrentUSD, reserveCurrentUSD] = await Promise.all([
            calculateVaultUSDValue(seniorVault, SENIOR_VAULT_ADDRESS, lpPrice, provider, true),
            calculateVaultUSDValue(juniorVault, JUNIOR_VAULT_ADDRESS, lpPrice, provider, false),
            calculateVaultUSDValue(reserveVault, RESERVE_VAULT_ADDRESS, lpPrice, provider, false)
        ])
        
        // Format vault values
        const seniorValueFormatted = Number(ethers.formatUnits(seniorValue, 18))
        const juniorValueFormatted = Number(ethers.formatUnits(juniorValue, 18))
        const reserveValueFormatted = Number(ethers.formatUnits(reserveValue, 18))
        
        // Calculate profit percentages: ((currentUSD - onChainValue) / onChainValue) * 100
        const seniorProfitPercent = seniorValueFormatted > 0 
            ? ((seniorCurrentUSD - seniorValueFormatted) / seniorValueFormatted) * 100 
            : 0
        const juniorProfitPercent = juniorValueFormatted > 0 
            ? ((juniorCurrentUSD - juniorValueFormatted) / juniorValueFormatted) * 100 
            : 0
        const reserveProfitPercent = reserveValueFormatted > 0 
            ? ((reserveCurrentUSD - reserveValueFormatted) / reserveValueFormatted) * 100 
            : 0
        
        // Convert to BPS (basis points): percent * 100
        // Example: 5% = 500 BPS, -2% = -200 BPS
        const seniorBPS = Math.round(seniorProfitPercent * 100)
        const juniorBPS = Math.round(juniorProfitPercent * 100)
        const reserveBPS = Math.round(reserveProfitPercent * 100)
        
        // Check if BPS are within allowed range (-5000 to +10000)
        const MIN_BPS = -5000  // -50%
        const MAX_BPS = 10000  // +100%
        
        const checkBPS = (bps: number, vaultName: string) => {
            if (bps < MIN_BPS) {
                return {
                    bps: MIN_BPS,
                    capped: true,
                    warning: `${vaultName} profit is below minimum (-50%). Capped to ${MIN_BPS} BPS.`
                }
            }
            if (bps > MAX_BPS) {
                return {
                    bps: MAX_BPS,
                    capped: true,
                    warning: `${vaultName} profit exceeds maximum (+100%). Capped to ${MAX_BPS} BPS.`
                }
            }
            return {
                bps,
                capped: false,
                warning: null
            }
        }
        
        const seniorCheck = checkBPS(seniorBPS, 'Senior')
        const juniorCheck = checkBPS(juniorBPS, 'Junior')
        const reserveCheck = checkBPS(reserveBPS, 'Reserve')
        
        return {
            lpTokenPrice: lpPrice.toFixed(6),
            seniorVault: {
                address: SENIOR_VAULT_ADDRESS,
                currentValueUSD: seniorCurrentUSD.toFixed(2),
                onChainValue: seniorValueFormatted.toFixed(2),
                profitPercent: seniorProfitPercent.toFixed(2) + '%',
                bps: seniorCheck.bps,
                bpsRaw: seniorBPS,
                capped: seniorCheck.capped,
                warning: seniorCheck.warning,
                callData: `updateVaultValue(${seniorCheck.bps})`
            },
            juniorVault: {
                address: JUNIOR_VAULT_ADDRESS,
                currentValueUSD: juniorCurrentUSD.toFixed(2),
                onChainValue: juniorValueFormatted.toFixed(2),
                profitPercent: juniorProfitPercent.toFixed(2) + '%',
                bps: juniorCheck.bps,
                bpsRaw: juniorBPS,
                capped: juniorCheck.capped,
                warning: juniorCheck.warning,
                callData: `updateVaultValue(${juniorCheck.bps})`
            },
            reserveVault: {
                address: RESERVE_VAULT_ADDRESS,
                currentValueUSD: reserveCurrentUSD.toFixed(2),
                onChainValue: reserveValueFormatted.toFixed(2),
                profitPercent: reserveProfitPercent.toFixed(2) + '%',
                bps: reserveCheck.bps,
                bpsRaw: reserveBPS,
                capped: reserveCheck.capped,
                warning: reserveCheck.warning,
                callData: `updateVaultValue(${reserveCheck.bps})`
            },
            instructions: {
                message: "Use the 'bps' values to call updateVaultValue() on each vault",
                example: `seniorVault.updateVaultValue(${seniorCheck.bps})`,
                limits: {
                    min: MIN_BPS + ' BPS (-50%)',
                    max: MAX_BPS + ' BPS (+100%)'
                }
            }
        }
    } catch (error) {
        console.error('Error calculating vaults update BPS:', error)
        throw error
    }
}

/**
 * MASTER FUNCTION: Complete stake and invest flow
 * Does everything in one call:
 * 1. User deposits TSTUSDE to vault (gets shares)
 * 2. Admin calls investInLP (vault sends TSTUSDE to admin)
 * 3. Admin swaps half TSTUSDE to TSAIL
 * 4. Admin adds liquidity (gets LP tokens)
 * 5. Admin transfers LP tokens to vault
 */
export const stakeAndInvestComplete = async (
    userPrivateKey: string,
    adminPrivateKey: string,
    vaultType: 'junior' | 'senior' | 'reserve',
    amountTSTUSDE: string,
    slippageTolerance: number = 0.5
) => {
    try {
        console.log('🚀 Starting complete stake and invest flow...')
    
        
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        const userWallet = new ethers.Wallet(userPrivateKey, provider)
        const adminWallet = new ethers.Wallet(adminPrivateKey, provider)
        console.log('userWallet', userWallet.address)
        console.log('adminWallet', adminWallet.address)
        
        // Approval constants used throughout
        const maxUint256 = ethers.MaxUint256
        const infiniteThreshold = maxUint256 / BigInt(2)
        
        // Determine vault address
        const vaultAddress = vaultType === 'junior' 
            ? JUNIOR_VAULT_ADDRESS 
            : vaultType === 'senior' 
            ? SENIOR_VAULT_ADDRESS 
            : RESERVE_VAULT_ADDRESS
        
        const amountWei: bigint = ethers.parseUnits(amountTSTUSDE, 18)
        
        // ==============================================
        // STEP 0: Pre-update vault value (CRITICAL!)
        // ==============================================
        console.log('\n🔄 STEP 0: Pre-updating vault value before deposit...')
        console.log('   (Ensures correct share calculation)')
        try {
            // Get LP price
            const lpPriceData = await getLPTokenPrice()
            const lpPrice = Number(lpPriceData.lpTokenPriceInTUSD)
            
            // Get vault's actual balances
            const usdeToken = new ethers.Contract(TUSD_ADDRESS, ERC20_ABI, provider)
            const actualUsdeBalance = await usdeToken.balanceOf(vaultAddress)
            const actualUsdeValue = Number(ethers.formatUnits(actualUsdeBalance, 18))
            
            // Get vault's LP holdings
            const vaultForCheck = new ethers.Contract(vaultAddress, VAULT_ABI, provider)
            let lpHoldingsValue = 0
            try {
                const functionName = vaultType === 'senior' ? 'getLPTokenHoldings' : 'getLPHoldings'
                const holdings = await vaultForCheck[functionName]()
                for (const holding of holdings) {
                    const amountFormatted = Number(ethers.formatUnits(holding.amount, 18))
                    lpHoldingsValue += amountFormatted * lpPrice
                }
            } catch (e) {
                // No LP holdings yet
            }
            
            // Calculate total actual value
            const calculatedValue = actualUsdeValue + lpHoldingsValue
            
            // Get current on-chain vault value
            const currentVaultValue = await vaultForCheck.vaultValue()
            const currentVaultValueNum = Number(ethers.formatUnits(currentVaultValue, 18))
            
            console.log(`   Current vault value: $${currentVaultValueNum.toFixed(2)}`)
            console.log(`   Calculated value: $${calculatedValue.toFixed(2)}`)
            
            // Skip if calculated value is too small (< $0.01)
            if (calculatedValue < 0.01) {
                console.log('   ⏭️  Skipped (calculated value too small, will use deposit amount)')
            } else {
                // Check if update is needed (>0.1% difference)
                const diffPercent = Math.abs((calculatedValue - currentVaultValueNum) / currentVaultValueNum * 100)
                
                if (diffPercent < 0.01) {
                    console.log('   ⏭️  Skipped (difference < 0.01%)')
                } else {
                    console.log(`   Setting vault value to $${calculatedValue.toFixed(2)}...`)
                    const vaultWithSigner = vaultForCheck.connect(adminWallet) as ethers.Contract
                    const newValueWei = ethers.parseUnits(calculatedValue.toFixed(18), 18)
                    
                    const updateTx = await vaultWithSigner.setVaultValue(newValueWei, {
                        gasLimit: 200000
                    })
                    const updateReceipt = await updateTx.wait()
                    console.log(`✅ Vault value updated! TX: ${updateReceipt.hash}`)
                    
                    // Wait for state to sync
                    console.log('   ⏳ Waiting 3 seconds for blockchain state to sync...')
                    await new Promise(resolve => setTimeout(resolve, 3000))
                }
            }
        } catch (error: any) {
            console.warn('   ⚠️  Pre-update failed (continuing anyway):', error?.message || error)
        }
        
        // ==============================================
        // STEP 1: User deposits TSTUSDE to vault
        // ==============================================
        console.log('\n📥 STEP 1: User depositing to vault...')
        
        // Note: OpenZeppelin ERC4626 has first deposit protection that causes
        // shares = deposit / 2 when totalSupply = 0 and totalAssets = 1 wei
        // This is intentional to prevent inflation attacks
        // STEP 6 will correct the vault value after investInLP
        const tstusdeContract = new ethers.Contract(TUSD_ADDRESS, ERC20_ABI, userWallet)
        const vaultContract = new ethers.Contract(vaultAddress, VAULT_ABI, userWallet)
        
        // Check user balance
        const userBalance = await tstusdeContract.balanceOf(userWallet.address)
        if (userBalance < amountWei) {
            throw new Error(`Insufficient TSTUSDE. Have: ${ethers.formatUnits(userBalance, 18)}}`)
        }
        
        // Approve vault (infinite approval) - ensure infinite approval
        const userAllowance = await tstusdeContract.allowance(userWallet.address, vaultAddress)
        
        if (userAllowance < infiniteThreshold) {
            console.log('Approving vault (infinite)...')
            // Reset to 0 first if needed
            if (userAllowance > BigInt(0)) {
                const resetTx = await tstusdeContract.approve(vaultAddress, 0, { gasLimit: 100000 })
                await resetTx.wait()
                await new Promise(resolve => setTimeout(resolve, 3000))
            }
            // Approve infinite
            const approveTx = await tstusdeContract.approve(vaultAddress, maxUint256, {
                gasLimit: 100000
            })
            await approveTx.wait()
            console.log('Approval confirmed, waiting 5 seconds...')
            await new Promise(resolve => setTimeout(resolve, 5000))
        }
        
        // Deposit to vault (with manual gas limit to avoid estimation issues)
        const depositTx = await vaultContract.deposit(amountWei, userWallet.address, {
            gasLimit: 500000 // Manual gas limit to bypass estimation
        })
        const depositReceipt = await depositTx.wait()
     
        console.log(`   TX: ${depositReceipt.hash}`)
        
        // ==============================================
        // STEP 2: Admin calls investInLP on vault
        // ==============================================
        console.log('\n💼 STEP 2: Admin calling investInLP...')
        const vaultAsAdmin = new ethers.Contract(vaultAddress, VAULT_ABI, adminWallet)
        
        const investTx = await vaultAsAdmin.investInLP(adminWallet.address, amountWei, {
            gasLimit: 300000
        })
        const investReceipt = await investTx.wait()
        console.log(`✅ Vault transferred ${amountTSTUSDE} TSTUSDE to admin`)
        console.log(`   TX: ${investReceipt.hash}`)
        
        // ==============================================
        // STEP 3: Admin swaps half TSTUSDE to TSAIL
        // ==============================================
        console.log('\n🔄 STEP 3: Admin swapping half to TSAIL...')
        const halfAmount = amountWei / BigInt(2)
        const halfAmountFormatted = ethers.formatUnits(halfAmount, 18)
        
        const tstusdeAsAdmin = new ethers.Contract(TUSD_ADDRESS, ERC20_ABI, adminWallet)
        const tsailAsAdmin = new ethers.Contract(TSAIL_ADDRESS, ERC20_ABI, adminWallet)
        const routerAsAdmin = new ethers.Contract(UNISWAP_V2_ROUTER, ROUTER_ABI, adminWallet)
        
        // Approve router for TSTUSDE (infinite) - always ensure infinite approval
        const routerAllowance = await tstusdeAsAdmin.allowance(adminWallet.address, UNISWAP_V2_ROUTER)
        
        if (routerAllowance < infiniteThreshold) {
            console.log('Approving router (infinite)...')
            // Reset to 0 first (some tokens require this)
            if (routerAllowance > BigInt(0)) {
                const resetTx = await tstusdeAsAdmin.approve(UNISWAP_V2_ROUTER, 0, { gasLimit: 100000 })
                await resetTx.wait()
                await new Promise(resolve => setTimeout(resolve, 3000))
            }
            // Now approve infinite
            const approveTx = await tstusdeAsAdmin.approve(UNISWAP_V2_ROUTER, maxUint256, {
                gasLimit: 100000
            })
            await approveTx.wait()
            console.log('Router approval confirmed, waiting 5 seconds...')
            await new Promise(resolve => setTimeout(resolve, 5000))
        }
        
        // Get expected TSAIL output
        const path = [TUSD_ADDRESS, TSAIL_ADDRESS]
        const amounts = await routerAsAdmin.getAmountsOut(halfAmount, path)
        const tsailExpected = amounts[1]
        const tsailMin = (tsailExpected * BigInt(Math.floor((100 - slippageTolerance) * 100))) / BigInt(10000)
        
        console.log(`Expected TSAIL from swap: ${ethers.formatUnits(tsailExpected, 18)}`)
        
        // Swap
        const deadline = Math.floor(Date.now() / 1000) + 600
        const swapTx = await routerAsAdmin.swapExactTokensForTokens(
            halfAmount,
            tsailMin,
            path,
            adminWallet.address,
            deadline,
            { gasLimit: 500000 }
        )
        const swapReceipt = await swapTx.wait()
        
        // Use the expected amount as the received amount (more reliable than balance diff)
        const tsailReceived: bigint = tsailExpected
        console.log(`✅ Swapped ${halfAmountFormatted} TSTUSDE → ${ethers.formatUnits(tsailReceived, 18)} TSAIL`)
        console.log(`   TX: ${swapReceipt.hash}`)
        
        // ==============================================
        // STEP 4: Admin adds liquidity to Uniswap
        // ==============================================
        console.log('\n💧 STEP 4: Admin adding liquidity...')
        console.log('   Fetching pool reserves...')
        
        // Get current reserves for optimal amounts
        const pairContract = new ethers.Contract(LP_PAIR_ADDRESS, PAIR_ABI, provider)
        const reserves = await pairContract.getReserves()
        const token0 = await pairContract.token0()
        console.log('   ✓ Got pool reserves')
        
        const [tusdReserve, tsailReserve] = token0.toLowerCase() === TUSD_ADDRESS.toLowerCase()
            ? [reserves.reserve0, reserves.reserve1]
            : [reserves.reserve1, reserves.reserve0]
        
        // Calculate optimal amounts
        let finalTUSD: bigint = halfAmount
        let finalTSAIL: bigint = tsailReceived
        
        const optimalTUSD: bigint = (finalTSAIL * tusdReserve) / tsailReserve
        const optimalTSAIL: bigint = (finalTUSD * tsailReserve) / tusdReserve
        
        if (optimalTUSD <= finalTUSD) {
            finalTUSD = optimalTUSD
        } else {
            finalTSAIL = optimalTSAIL
        }
        
        // Approve both tokens (infinite) - ensure infinite approval
        console.log('   Checking TUSD approval...')
        const tusdAllowance2 = await tstusdeAsAdmin.allowance(adminWallet.address, UNISWAP_V2_ROUTER)
        if (tusdAllowance2 < infiniteThreshold) {
            console.log('   → Approving TUSD for liquidity (infinite)...')
            if (tusdAllowance2 > BigInt(0)) {
                console.log('      Resetting existing approval to 0...')
                const resetTx = await tstusdeAsAdmin.approve(UNISWAP_V2_ROUTER, 0, { gasLimit: 100000 })
                await resetTx.wait()
                console.log('      ✓ Reset confirmed, waiting 3 seconds...')
                await new Promise(resolve => setTimeout(resolve, 3000))
            }
            console.log('      Setting infinite approval...')
            const approveTx = await tstusdeAsAdmin.approve(UNISWAP_V2_ROUTER, maxUint256, {
                gasLimit: 100000
            })
            await approveTx.wait()
            console.log('      ✓ TUSD approved, waiting 5 seconds...')
            await new Promise(resolve => setTimeout(resolve, 5000))
        } else {
            console.log('   ✓ TUSD already approved')
        }
        
        console.log('   Checking TSAIL approval...')
        const tsailAllowance = await tsailAsAdmin.allowance(adminWallet.address, UNISWAP_V2_ROUTER)
        if (tsailAllowance < infiniteThreshold) {
            console.log('   → Approving TSAIL for liquidity (infinite)...')
            if (tsailAllowance > BigInt(0)) {
                console.log('      Resetting existing approval to 0...')
                const resetTx = await tsailAsAdmin.approve(UNISWAP_V2_ROUTER, 0, { gasLimit: 100000 })
                await resetTx.wait()
                console.log('      ✓ Reset confirmed, waiting 3 seconds...')
                await new Promise(resolve => setTimeout(resolve, 3000))
            }
            console.log('      Setting infinite approval...')
            const approveTx = await tsailAsAdmin.approve(UNISWAP_V2_ROUTER, maxUint256, {
                gasLimit: 100000
            })
            await approveTx.wait()
            console.log('      ✓ TSAIL approved, waiting 5 seconds...')
            await new Promise(resolve => setTimeout(resolve, 5000))
        } else {
            console.log('   ✓ TSAIL already approved')
        }
        
        // Calculate minimum amounts with slippage
        console.log('   Calculating optimal amounts...')
        const amountTUSDMin = (finalTUSD * BigInt(Math.floor((100 - slippageTolerance - 2) * 100))) / BigInt(10000)
        const amountTSAILMin = (finalTSAIL * BigInt(Math.floor((100 - slippageTolerance - 2) * 100))) / BigInt(10000)
        console.log(`   → TUSD: ${ethers.formatUnits(finalTUSD, 18)} (min: ${ethers.formatUnits(amountTUSDMin, 18)})`)
        console.log(`   → TSAIL: ${ethers.formatUnits(finalTSAIL, 18)} (min: ${ethers.formatUnits(amountTSAILMin, 18)})`)
        
        // Initialize LP contract
        const lpContract = new ethers.Contract(LP_PAIR_ADDRESS, ERC20_ABI, adminWallet)
        
        // Add liquidity
        console.log('   Executing addLiquidity transaction...')
        const addLiquidityTx = await routerAsAdmin.addLiquidity(
            TUSD_ADDRESS,
            TSAIL_ADDRESS,
            finalTUSD,
            finalTSAIL,
            amountTUSDMin,
            amountTSAILMin,
            adminWallet.address,
            deadline,
            { gasLimit: 800000 }
        )
        const liquidityReceipt = await addLiquidityTx.wait()
        console.log('   ✓ Transaction confirmed!')
        
        // Parse LP tokens received from Transfer event in the receipt
        console.log('   Parsing LP tokens from transaction receipt...')
        const transferTopic = ethers.id("Transfer(address,address,uint256)")
        let lpTokensReceived: bigint = BigInt(0)
        
        // Find the Transfer event from LP token contract to admin
        for (const log of liquidityReceipt.logs) {
            if (log.address.toLowerCase() === LP_PAIR_ADDRESS.toLowerCase() && 
                log.topics[0] === transferTopic &&
                log.topics[2] === ethers.zeroPadValue(adminWallet.address, 32).toLowerCase()) {
                // This is the LP token transfer to admin (minting event)
                lpTokensReceived = BigInt(log.data)
                break
            }
        }
        
        console.log(`✅ Added liquidity, received ${ethers.formatUnits(lpTokensReceived, 18)} LP tokens`)
        console.log(`   TX: ${liquidityReceipt.hash}`)
        
        // ==============================================
        // STEP 5: Admin transfers LP tokens to vault
        // ==============================================
        console.log('\n📤 STEP 5: Admin transferring LP tokens to vault...')
        console.log(`   Sending ${ethers.formatUnits(lpTokensReceived, 18)} LP tokens...`)
        
        const transferTx = await lpContract.transfer(vaultAddress, lpTokensReceived, {
            gasLimit: 200000
        })
        console.log('   Waiting for confirmation...')
        const transferReceipt = await transferTx.wait()
        console.log(`✅ Transferred ${ethers.formatUnits(lpTokensReceived, 18)} LP tokens to vault`)
        console.log(`   TX: ${transferReceipt.hash}`)
        
        // Wait for blockchain state to update
        console.log('   ⏳ Waiting 3 seconds for blockchain state to sync...')
        await new Promise(resolve => setTimeout(resolve, 3000))
        
        // ==============================================
        // STEP 6: Auto-update vault value
        // ==============================================
        console.log('\n🔄 STEP 6: Auto-updating vault value...')
        try {
            // Get LP price from pool
            const lpPriceData = await getLPTokenPrice()
            const lpPrice = Number(lpPriceData.lpTokenPriceInTUSD)
            
            // Calculate LP value from tokens we just added (no fetching needed!)
            const lpTokensAmount = Number(ethers.formatUnits(lpTokensReceived, 18))
            const lpHoldingsValue = lpTokensAmount * lpPrice
            
            console.log(`   LP Tokens added: ${lpTokensAmount.toFixed(6)}`)
            console.log(`   LP Token price: $${lpPrice.toFixed(2)}`)
            console.log(`   LP Value: $${lpHoldingsValue.toFixed(2)}`)
            
            // USDe Balance: Should be 0 after investInLP (all transferred to LP protocol)
            // We don't fetch it to avoid RPC caching issues
            const actualUsdeValue = 0
            
            console.log(`   USDe Balance: $${actualUsdeValue.toFixed(2)} (expected 0 after investInLP)`)
            
            // Calculate total actual value (just LP value since USDe is 0)
            const calculatedValue = lpHoldingsValue
            
            // Get current on-chain vault value
            const vault = new ethers.Contract(vaultAddress, VAULT_ABI, provider)
            const currentVaultValue = await vault.vaultValue()
            const currentVaultValueNum = Number(ethers.formatUnits(currentVaultValue, 18))
            
            console.log(`   Current vault value: $${currentVaultValueNum.toFixed(2)}`)
            console.log(`   Calculated value: $${calculatedValue.toFixed(2)}`)
            
            // Skip if calculated value is too small (< $0.01)
            if (calculatedValue < 0.01) {
                console.log('   ⏭️  Skipped (calculated value too small)')
            } else {
                // Check if update is needed (>0.1% difference)
                const diffPercent = Math.abs((calculatedValue - currentVaultValueNum) / currentVaultValueNum * 100)
                
                if (diffPercent < 0.01) {
                    console.log('   ⏭️  Skipped (difference < 0.01%)')
                } else {
                    console.log(`   Setting vault value to $${calculatedValue.toFixed(2)}...`)
                    const vaultWithSigner = vault.connect(adminWallet) as ethers.Contract
                    const newValueWei = ethers.parseUnits(calculatedValue.toFixed(18), 18)
                    
                    const updateTx = await vaultWithSigner.setVaultValue(newValueWei, {
                        gasLimit: 200000
                    })
                    const updateReceipt = await updateTx.wait()
                    console.log(`✅ Vault value updated! TX: ${updateReceipt.hash}`)
                }
            }
        } catch (error: any) {
            console.warn('   ⚠️  Auto-update failed (non-critical):', error?.message || error)
        }
        
        // ==============================================
        // FINAL SUMMARY
        // ==============================================
        console.log('\n🎉 COMPLETE! All steps successful!')
        
        // Get final vault LP balance
        const vaultLPBalance = await lpContract.balanceOf(vaultAddress)
        
        return {
            success: true,
            summary: {
                userDeposited: amountTSTUSDE + ' TSTUSDE',
                userReceivedShares: 'Check vault balance',
                vaultTransferredToAdmin: amountTSTUSDE + ' TSTUSDE',
                adminSwapped: halfAmountFormatted + ' TSTUSDE → ' + ethers.formatUnits(tsailReceived, 18) + ' TSAIL',
                lpTokensGenerated: ethers.formatUnits(lpTokensReceived, 18),
                lpTokensSentToVault: ethers.formatUnits(lpTokensReceived, 18),
                vaultFinalLPBalance: ethers.formatUnits(vaultLPBalance, 18)
            },
            transactions: {
                step1_userDeposit: depositReceipt.hash,
                step2_investInLP: investReceipt.hash,
                step3_swap: swapReceipt.hash,
                step4_addLiquidity: liquidityReceipt.hash,
                step5_transferToVault: transferReceipt.hash
            },
            vault: {
                type: vaultType,
                address: vaultAddress
            },
            user: userWallet.address,
            admin: adminWallet.address
        }
    } catch (error) {
        console.error('❌ Error in complete flow:', error)
        throw error
    }
}

export const getRebaseConfig = async () => {
    try {
        // Create provider
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        
        // Create contract instance for senior vault
        const seniorVault = new ethers.Contract(SENIOR_VAULT_ADDRESS, VAULT_ABI, provider)
        
        // Fetch rebase configuration
        const [minInterval, lastRebaseTime, totalSupply, vaultValue, rebaseIndex, epoch] = await Promise.all([
            seniorVault.minRebaseInterval(),
            seniorVault.lastRebaseTime(),
            seniorVault.totalSupply(),
            seniorVault.vaultValue(),
            seniorVault.rebaseIndex(),
            seniorVault.epoch()
        ])
        
        // Format values
        const minIntervalSeconds = Number(minInterval)
        const lastRebaseTimestamp = Number(lastRebaseTime)
        const currentTimestamp = Math.floor(Date.now() / 1000)
        const timeSinceLastRebase = currentTimestamp - lastRebaseTimestamp
        const timeUntilNextRebase = Math.max(0, minIntervalSeconds - timeSinceLastRebase)
        const canRebaseNow = timeSinceLastRebase >= minIntervalSeconds
        
        const currentSupply = ethers.formatUnits(totalSupply, 18)
        const currentVaultValue = ethers.formatUnits(vaultValue, 18)
        const currentRebaseIndex = ethers.formatUnits(rebaseIndex, 18)
        const currentEpoch = Number(epoch)
        
        return {
            currentSupply: currentSupply,
            vaultValue: currentVaultValue,
            rebaseIndex: currentRebaseIndex,
            epoch: currentEpoch,
            lastRebaseTime: lastRebaseTimestamp,
            lastRebaseFormatted: lastRebaseTimestamp === 0 ? 'Never' : new Date(lastRebaseTimestamp * 1000).toLocaleString(),
            minIntervalFormatted: formatDuration(minIntervalSeconds),
            timeSinceFormatted: formatDuration(timeSinceLastRebase),
            timeRemainingFormatted: canRebaseNow ? null : formatDuration(timeUntilNextRebase),
            canRebase: canRebaseNow,
            seniorVault: {
                address: SENIOR_VAULT_ADDRESS,
                minRebaseInterval: minIntervalSeconds,
                minRebaseIntervalFormatted: formatDuration(minIntervalSeconds),
                lastRebaseTime: lastRebaseTimestamp,
                lastRebaseTimeFormatted: new Date(lastRebaseTimestamp * 1000).toISOString(),
                timeSinceLastRebase: timeSinceLastRebase,
                timeSinceLastRebaseFormatted: formatDuration(timeSinceLastRebase),
                timeUntilNextRebase: timeUntilNextRebase,
                timeUntilNextRebaseFormatted: formatDuration(timeUntilNextRebase),
                canRebaseNow: canRebaseNow
            },
            currentTime: currentTimestamp,
            currentTimeFormatted: new Date(currentTimestamp * 1000).toISOString()
        }
    } catch (error) {
        console.error('Error fetching rebase config:', error)
        throw error
    }
}

export const setRebaseInterval = async (
    adminPrivateKey: string,
    newIntervalSeconds: number
) => {
    try {
        // Create provider and wallet
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        const adminWallet = new ethers.Wallet(adminPrivateKey, provider)
        
        // Create contract instance
        const seniorVault = new ethers.Contract(SENIOR_VAULT_ADDRESS, VAULT_ABI, adminWallet)
        
        console.log(`Setting rebase interval to ${newIntervalSeconds} seconds (${formatDuration(newIntervalSeconds)})...`)
        
        // Call setMinRebaseInterval
        const tx = await seniorVault.setMinRebaseInterval(newIntervalSeconds, {
            maxFeePerGas: ethers.parseUnits('500', 'gwei'),
            maxPriorityFeePerGas: ethers.parseUnits('50', 'gwei')
        })
        
        const receipt = await tx.wait()
        console.log(`Rebase interval updated! TX: ${receipt.hash}`)
        
        return {
            success: true,
            transactionHash: receipt.hash,
            oldInterval: 'see transaction logs',
            newInterval: newIntervalSeconds,
            newIntervalFormatted: formatDuration(newIntervalSeconds),
            blockNumber: receipt.blockNumber
        }
    } catch (error) {
        console.error('Error setting rebase interval:', error)
        throw error
    }
}

// Helper function to format duration
function formatDuration(seconds: number): string {
    if (seconds < 60) {
        return `${seconds}s`
    } else if (seconds < 3600) {
        const minutes = Math.floor(seconds / 60)
        const secs = seconds % 60
        return secs > 0 ? `${minutes}m ${secs}s` : `${minutes}m`
    } else if (seconds < 86400) {
        const hours = Math.floor(seconds / 3600)
        const minutes = Math.floor((seconds % 3600) / 60)
        return minutes > 0 ? `${hours}h ${minutes}m` : `${hours}h`
    } else {
        const days = Math.floor(seconds / 86400)
        const hours = Math.floor((seconds % 86400) / 3600)
        return hours > 0 ? `${days}d ${hours}h` : `${days}d`
    }
}

export const updateVaultValue = async (
    adminPrivateKey: string,
    profitBps: number,
    vaultType: 'senior' | 'junior' | 'reserve' = 'senior'
) => {
    try {
        // Create provider and wallet
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        const adminWallet = new ethers.Wallet(adminPrivateKey, provider)
        
        // Determine vault address based on type
        const vaultAddress = vaultType === 'senior' 
            ? SENIOR_VAULT_ADDRESS 
            : vaultType === 'junior' 
            ? JUNIOR_VAULT_ADDRESS 
            : RESERVE_VAULT_ADDRESS
        
        // Create contract instance
        const vault = new ethers.Contract(vaultAddress, VAULT_ABI, adminWallet)
        const seniorVault = vault // Keep for compatibility with rest of code
        
        // Get current vault value for reference
        const currentValue = await seniorVault.vaultValue()
        const currentValueFormatted = Number(ethers.formatUnits(currentValue, 18))
        
        // Calculate new value
        const profitPercent = profitBps / 100
        const newValueEstimate = currentValueFormatted * (1 + profitPercent / 100)
        
        console.log(`\n📊 Updating ${vaultType.toUpperCase()} Vault`)
        console.log(`Current vault value: $${currentValueFormatted.toFixed(2)}`)
        console.log(`Updating with profit: ${profitPercent >= 0 ? '+' : ''}${profitPercent.toFixed(2)}%`)
        console.log(`Estimated new value: $${newValueEstimate.toFixed(2)}`)
        
        // Handle large gaps by splitting into multiple updates
        if (profitBps > 10000) {
            console.log(`⚠️  Profit too large (${profitBps} BPS). Splitting into multiple updates...`)
            
            let remainingBps = profitBps
            let currentVal = currentValueFormatted
            let updateCount = 0
            const transactions: any[] = []
            
            while (remainingBps > 10000) {
                updateCount++
                console.log(`\n📝 Update ${updateCount}: Applying +100% (10000 BPS)`)
                
                const tx = await seniorVault.updateVaultValue(10000, {
                    maxFeePerGas: ethers.parseUnits('500', 'gwei'),
                    maxPriorityFeePerGas: ethers.parseUnits('50', 'gwei')
                })
                const receipt = await tx.wait()
                currentVal = currentVal * 2 // 100% increase
                console.log(`✅ Updated! New value: $${currentVal.toFixed(2)}, TX: ${receipt.hash}`)
                
                transactions.push({ 
                    step: updateCount, 
                    bps: 10000, 
                    txHash: receipt.hash,
                    newValue: currentVal.toFixed(2)
                })
                
                // Recalculate remaining BPS based on new current value
                remainingBps = Math.round(((newValueEstimate - currentVal) / currentVal) * 10000)
                console.log(`   Remaining: ${remainingBps} BPS`)
            }
            
            // Final update with remaining BPS
            if (remainingBps > 0) {
                updateCount++
                const finalPercent = (remainingBps / 100).toFixed(2)
                console.log(`\n📝 Final update ${updateCount}: Applying +${finalPercent}% (${remainingBps} BPS)`)
                
                const tx = await seniorVault.updateVaultValue(remainingBps, {
                    maxFeePerGas: ethers.parseUnits('500', 'gwei'),
                    maxPriorityFeePerGas: ethers.parseUnits('50', 'gwei')
                })
                const receipt = await tx.wait()
                const finalValue = await seniorVault.vaultValue()
                const finalValueFormatted = Number(ethers.formatUnits(finalValue, 18))
                console.log(`✅ Final value: $${finalValueFormatted.toFixed(2)}, TX: ${receipt.hash}`)
                
                transactions.push({ 
                    step: updateCount, 
                    bps: remainingBps, 
                    txHash: receipt.hash,
                    newValue: finalValueFormatted.toFixed(2)
                })
                
                return {
                    success: true,
                    multipleUpdates: true,
                    totalUpdates: updateCount,
                    transactions,
                    profitBpsTotal: profitBps,
                    profitPercent: profitPercent.toFixed(2) + '%',
                    oldValue: currentValueFormatted.toFixed(2),
                    newValue: finalValueFormatted.toFixed(2)
                }
            }
        }
        
        // Validate profit range for single update
        if (profitBps < -5000 || profitBps > 10000) {
            throw new Error(`Profit BPS out of range. Must be between -5000 and 10000. Got: ${profitBps}`)
        }
        
        // Single update (normal case)
        console.log('Sending updateVaultValue transaction...')
        const tx = await seniorVault.updateVaultValue(profitBps, {
            maxFeePerGas: ethers.parseUnits('500', 'gwei'),
            maxPriorityFeePerGas: ethers.parseUnits('50', 'gwei')
        })
        
        const receipt = await tx.wait()
        console.log(`Vault value updated! TX: ${receipt.hash}`)
        
        // Get new vault value
        const newValue = await seniorVault.vaultValue()
        const newValueFormatted = Number(ethers.formatUnits(newValue, 18))
        
        return {
            success: true,
            transactionHash: receipt.hash,
            profitBps: profitBps,
            profitPercent: profitPercent.toFixed(2) + '%',
            oldValue: currentValueFormatted.toFixed(2),
            newValue: newValueFormatted.toFixed(2),
            blockNumber: receipt.blockNumber
        }
    } catch (error) {
        console.error('Error updating vault value:', error)
        throw error
    }
}

export const whitelistAddress = async (
    adminPrivateKey: string,
    addressToWhitelist: string
) => {
    try {
        // Create provider and wallet
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        const adminWallet = new ethers.Wallet(adminPrivateKey, provider)
        
        // Create contract instance
        const seniorVault = new ethers.Contract(SENIOR_VAULT_ADDRESS, VAULT_ABI, adminWallet)
        
        // Check if already whitelisted
        const isWhitelisted = await seniorVault.isWhitelistedDepositor(addressToWhitelist)
        
        if (isWhitelisted) {
            return {
                success: true,
                alreadyWhitelisted: true,
                address: addressToWhitelist,
                message: 'Address is already whitelisted'
            }
        }
        
        console.log(`Whitelisting address: ${addressToWhitelist}`)
        
        // Add to whitelist
        const tx = await seniorVault.addWhitelistedDepositor(addressToWhitelist, {
            maxFeePerGas: ethers.parseUnits('500', 'gwei'),
            maxPriorityFeePerGas: ethers.parseUnits('50', 'gwei')
        })
        
        const receipt = await tx.wait()
        console.log(`✅ Address whitelisted! TX: ${receipt.hash}`)
        
        return {
            success: true,
            transactionHash: receipt.hash,
            address: addressToWhitelist,
            blockNumber: receipt.blockNumber
        }
    } catch (error) {
        console.error('Error whitelisting address:', error)
        throw error
    }
}

/**
 * Update all vault values and execute Senior rebase
 * This ensures all vaults have accurate values before rebase
 */
export const updateAllVaultsAndRebase = async (adminPrivateKey: string) => {
    try {
        console.log('═══════════════════════════════════════════════════════════')
        console.log('🔄 UPDATING ALL VAULT VALUES BEFORE REBASE')
        console.log('═══════════════════════════════════════════════════════════\n')
        
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        const adminWallet = new ethers.Wallet(adminPrivateKey, provider)
        
        // Get LP price once
        const lpPriceData = await getLPTokenPrice()
        const lpPrice = Number(lpPriceData.lpTokenPriceInTUSD)
        console.log(`📊 LP Token Price: $${lpPrice.toFixed(4)}\n`)
        
        // ========================================
        // 1. Update Senior Vault
        // ========================================
        console.log('1️⃣ Updating Senior Vault...')
        const seniorVault = new ethers.Contract(SENIOR_VAULT_ADDRESS, VAULT_ABI, adminWallet)
        const seniorCalculated = await calculateVaultUSDValue(seniorVault, SENIOR_VAULT_ADDRESS, lpPrice, provider, true)
        const seniorCurrentValue = await seniorVault.vaultValue()
        const seniorCurrentValueNum = Number(ethers.formatUnits(seniorCurrentValue, 18))
        
        console.log(`   Current: $${seniorCurrentValueNum.toFixed(2)}`)
        console.log(`   Calculated: $${seniorCalculated.toFixed(2)}`)
        
        if (seniorCalculated >= 0.01) {
            const seniorValueWei = ethers.parseUnits(seniorCalculated.toFixed(18), 18)
            const seniorTx = await seniorVault.setVaultValue(seniorValueWei, { 
                gasLimit: 200000,
                maxFeePerGas: ethers.parseUnits('300', 'gwei'),
                maxPriorityFeePerGas: ethers.parseUnits('30', 'gwei')
            })
            console.log(`   TX: ${seniorTx.hash}`)
            console.log(`   Waiting for confirmation (30s timeout)...`)
            await seniorTx.wait(1, 30000) // 1 confirmation, 30 second timeout
            console.log(`   ✅ Updated to $${seniorCalculated.toFixed(2)}`)
        } else {
            console.log(`   ⏭️  Skipped (too small)`)
        }
        
        // ========================================
        // 2. Update Junior Vault
        // ========================================
        console.log('\n2️⃣ Updating Junior Vault...')
        const juniorVault = new ethers.Contract(JUNIOR_VAULT_ADDRESS, VAULT_ABI, adminWallet)
        const juniorCalculated = await calculateVaultUSDValue(juniorVault, JUNIOR_VAULT_ADDRESS, lpPrice, provider, false)
        const juniorCurrentValue = await juniorVault.vaultValue()
        const juniorCurrentValueNum = Number(ethers.formatUnits(juniorCurrentValue, 18))
        
        console.log(`   Current: $${juniorCurrentValueNum.toFixed(2)}`)
        console.log(`   Calculated: $${juniorCalculated.toFixed(2)}`)
        
        if (juniorCalculated >= 0.01) {
            const juniorValueWei = ethers.parseUnits(juniorCalculated.toFixed(18), 18)
            const juniorTx = await juniorVault.setVaultValue(juniorValueWei, { 
                gasLimit: 200000,
                maxFeePerGas: ethers.parseUnits('300', 'gwei'),
                maxPriorityFeePerGas: ethers.parseUnits('30', 'gwei')
            })
            console.log(`   TX: ${juniorTx.hash}`)
            console.log(`   Waiting for confirmation (30s timeout)...`)
            await juniorTx.wait(1, 30000) // 1 confirmation, 30 second timeout
            console.log(`   ✅ Updated to $${juniorCalculated.toFixed(2)}`)
        } else {
            console.log(`   ⏭️  Skipped (too small)`)
        }
        
        // ========================================
        // 3. Update Reserve Vault
        // ========================================
        console.log('\n3️⃣ Updating Reserve Vault...')
        const reserveVault = new ethers.Contract(RESERVE_VAULT_ADDRESS, VAULT_ABI, adminWallet)
        const reserveCalculated = await calculateVaultUSDValue(reserveVault, RESERVE_VAULT_ADDRESS, lpPrice, provider, false)
        const reserveCurrentValue = await reserveVault.vaultValue()
        const reserveCurrentValueNum = Number(ethers.formatUnits(reserveCurrentValue, 18))
        
        console.log(`   Current: $${reserveCurrentValueNum.toFixed(2)}`)
        console.log(`   Calculated: $${reserveCalculated.toFixed(2)}`)
        
        if (reserveCalculated >= 0.01) {
            const reserveValueWei = ethers.parseUnits(reserveCalculated.toFixed(18), 18)
            const reserveTx = await reserveVault.setVaultValue(reserveValueWei, { 
                gasLimit: 200000,
                maxFeePerGas: ethers.parseUnits('300', 'gwei'),
                maxPriorityFeePerGas: ethers.parseUnits('30', 'gwei')
            })
            console.log(`   TX: ${reserveTx.hash}`)
            console.log(`   Waiting for confirmation (30s timeout)...`)
            await reserveTx.wait(1, 30000) // 1 confirmation, 30 second timeout
            console.log(`   ✅ Updated to $${reserveCalculated.toFixed(2)}`)
        } else {
            console.log(`   ⏭️  Skipped (too small)`)
        }
        
        console.log('\n✅ All vault values updated!')
        console.log('═══════════════════════════════════════════════════════════\n')
        
        // ========================================
        // 4. Execute Rebase
        // ========================================
        console.log('⚡ Now executing Senior rebase...\n')
        const rebaseResult = await executeSeniorRebase(adminPrivateKey)
        
        return {
            success: true,
            vaultUpdates: {
                senior: {
                    before: seniorCurrentValueNum.toFixed(2),
                    after: seniorCalculated.toFixed(2)
                },
                junior: {
                    before: juniorCurrentValueNum.toFixed(2),
                    after: juniorCalculated.toFixed(2)
                },
                reserve: {
                    before: reserveCurrentValueNum.toFixed(2),
                    after: reserveCalculated.toFixed(2)
                }
            },
            rebase: rebaseResult
        }
    } catch (error) {
        console.error('Error in updateAllVaultsAndRebase:', error)
        throw error
    }
}

export const executeSeniorRebase = async (adminPrivateKey: string) => {
    try {
        // Create provider and wallet
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        const adminWallet = new ethers.Wallet(adminPrivateKey, provider)
        
        // Create contract instance
        const seniorVault = new ethers.Contract(SENIOR_VAULT_ADDRESS, VAULT_ABI, adminWallet)
        
        // Get rebase info before
        const [lastRebaseTime, minInterval, currentSupply, vaultValue] = await Promise.all([
            seniorVault.lastRebaseTime(),
            seniorVault.minRebaseInterval(),
            seniorVault.totalSupply(),
            seniorVault.vaultValue()
        ])
        
        const lastRebaseTimestamp = Number(lastRebaseTime)
        const minIntervalSeconds = Number(minInterval)
        const currentTimestamp = Math.floor(Date.now() / 1000)
        const timeSinceLastRebase = currentTimestamp - lastRebaseTimestamp
        const canRebase = timeSinceLastRebase >= minIntervalSeconds
        
        console.log('=== Rebase Check ===')
        console.log(`Current supply: ${ethers.formatUnits(currentSupply, 18)} snrUSD`)
        console.log(`Vault value: $${ethers.formatUnits(vaultValue, 18)}`)
        console.log(`Last rebase: ${new Date(lastRebaseTimestamp * 1000).toISOString()}`)
        console.log(`Time since: ${formatDuration(timeSinceLastRebase)}`)
        console.log(`Min interval: ${formatDuration(minIntervalSeconds)}`)
        console.log(`Can rebase: ${canRebase ? '✅ YES' : '❌ NO'}`)
        
        if (!canRebase) {
            const timeRemaining = minIntervalSeconds - timeSinceLastRebase
            throw new Error(`Rebase too soon! Must wait ${formatDuration(timeRemaining)} more.`)
        }
        
        // Get LP price
        console.log('\n📊 Fetching LP token price...')
        const lpPriceData = await getLPTokenPrice()
        const lpPriceNumber = Number(lpPriceData.lpTokenPriceInTUSD)
        const lpPriceWei = ethers.parseUnits(lpPriceNumber.toFixed(18), 18)
        console.log(`LP Price: $${lpPriceNumber.toFixed(4)}`)
        
        // Execute rebase with LP price
        console.log('\n⚡ Executing rebase with LP price...')
        const tx = await seniorVault.rebase(lpPriceWei, {
            gasLimit: 800000,
            maxFeePerGas: ethers.parseUnits('300', 'gwei'),
            maxPriorityFeePerGas: ethers.parseUnits('30', 'gwei')
        })
        
        console.log(`TX sent: ${tx.hash}`)
        console.log('Waiting for confirmation (60s timeout)...')
        const receipt = await tx.wait(1, 60000) // 1 confirmation, 60 second timeout
        console.log('✅ Rebase complete!')
        
        // Get new supply
        const newSupply = await seniorVault.totalSupply()
        
        return {
            success: true,
            transactionHash: receipt.hash,
            before: {
                supply: ethers.formatUnits(currentSupply, 18),
                vaultValue: ethers.formatUnits(vaultValue, 18),
                lastRebaseTime: lastRebaseTimestamp,
                lastRebaseTimeFormatted: new Date(lastRebaseTimestamp * 1000).toISOString()
            },
            after: {
                supply: ethers.formatUnits(newSupply, 18),
                supplyChange: ((Number(ethers.formatUnits(newSupply, 18)) - Number(ethers.formatUnits(currentSupply, 18))) / Number(ethers.formatUnits(currentSupply, 18)) * 100).toFixed(4) + '%'
            },
            blockNumber: receipt.blockNumber,
            gasUsed: receipt.gasUsed.toString()
        }
    } catch (error) {
        console.error('Error executing rebase:', error)
        throw error
    }
}
