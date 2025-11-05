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

export const getVaultsValueInUSD = async () => {
    try {
        // Create provider
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        
        // Create contract instances for each vault
        const seniorVault = new ethers.Contract(SENIOR_VAULT_ADDRESS, VAULT_ABI, provider)
        const juniorVault = new ethers.Contract(JUNIOR_VAULT_ADDRESS, VAULT_ABI, provider)
        const reserveVault = new ethers.Contract(RESERVE_VAULT_ADDRESS, VAULT_ABI, provider)
        
        // Fetch total assets from all vaults in parallel + LP token price
        const [seniorAssets, juniorAssets, reserveAssets, lpPriceData] = await Promise.all([
            seniorVault.totalAssets(),
            juniorVault.totalAssets(),
            reserveVault.totalAssets(),
            getLPTokenPrice()
        ])
        
        // Format the assets (LP token amounts)
        const seniorAssetsFormatted = Number(ethers.formatUnits(seniorAssets, 18))
        const juniorAssetsFormatted = Number(ethers.formatUnits(juniorAssets, 18))
        const reserveAssetsFormatted = Number(ethers.formatUnits(reserveAssets, 18))
        
        // Get LP token price as number
        const lpPrice = Number(lpPriceData.lpTokenPriceInTUSD)
        
        // Calculate USD values: totalAssets * LP token price
        const seniorValueUSD = seniorAssetsFormatted * lpPrice
        const juniorValueUSD = juniorAssetsFormatted * lpPrice
        const reserveValueUSD = reserveAssetsFormatted * lpPrice
        const totalValueUSD = seniorValueUSD + juniorValueUSD + reserveValueUSD
        
        return {
            lpTokenPrice: lpPrice.toFixed(6),
            seniorVault: {
                address: SENIOR_VAULT_ADDRESS,
                totalAssets: seniorAssetsFormatted.toFixed(6),
                valueUSD: seniorValueUSD.toFixed(2),
                totalAssetsRaw: seniorAssets.toString()
            },
            juniorVault: {
                address: JUNIOR_VAULT_ADDRESS,
                totalAssets: juniorAssetsFormatted.toFixed(6),
                valueUSD: juniorValueUSD.toFixed(2),
                totalAssetsRaw: juniorAssets.toString()
            },
            reserveVault: {
                address: RESERVE_VAULT_ADDRESS,
                totalAssets: reserveAssetsFormatted.toFixed(6),
                valueUSD: reserveValueUSD.toFixed(2),
                totalAssetsRaw: reserveAssets.toString()
            },
            total: {
                totalAssets: (seniorAssetsFormatted + juniorAssetsFormatted + reserveAssetsFormatted).toFixed(6),
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
        
        // Fetch total supply, total assets, and LP token price in parallel
        const [seniorSupply, seniorAssets, lpPriceData] = await Promise.all([
            seniorVault.totalSupply(),
            seniorVault.totalAssets(),
            getLPTokenPrice()
        ])
        
        // Format values
        const seniorSupplyFormatted = Number(ethers.formatUnits(seniorSupply, 18))
        const seniorAssetsFormatted = Number(ethers.formatUnits(seniorAssets, 18))
        const lpPrice = Number(lpPriceData.lpTokenPriceInTUSD)
        
        // Calculate senior vault value in USD
        const seniorValueUSD = seniorAssetsFormatted * lpPrice
        
        // Calculate backing ratio: (valueUSD / totalSupply) + 100 for percentage
        const backingRatioValue = seniorSupplyFormatted > 0 ? (seniorValueUSD / seniorSupplyFormatted) : 0
        const backingRatio = backingRatioValue + 100
        
        return {
            seniorVault: {
                address: SENIOR_VAULT_ADDRESS,
                totalSupply: seniorSupplyFormatted.toFixed(6),
                totalAssets: seniorAssetsFormatted.toFixed(6),
                valueUSD: seniorValueUSD.toFixed(2),
                backingRatio: backingRatio.toFixed(2) + '%'
            },
            lpTokenPrice: lpPrice.toFixed(6),
            backingRatioRaw: backingRatio.toFixed(6)
        }
    } catch (error) {
        console.error('Error calculating senior backing ratio:', error)
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
        
        // Fetch total supply, total assets, and LP token price in parallel
        const [juniorSupply, juniorAssets, lpPriceData] = await Promise.all([
            juniorVault.totalSupply(),
            juniorVault.totalAssets(),
            getLPTokenPrice()
        ])
        
        // Format values
        const juniorSupplyFormatted = Number(ethers.formatUnits(juniorSupply, 18))
        const juniorAssetsFormatted = Number(ethers.formatUnits(juniorAssets, 18))
        const lpPrice = Number(lpPriceData.lpTokenPriceInTUSD)
        
        // Calculate junior vault value in USD: totalAssets * LP price
        const juniorValueUSD = juniorAssetsFormatted * lpPrice
        
        // Calculate junior token price: valueUSD / totalSupply
        const juniorTokenPrice = juniorSupplyFormatted > 0 ? juniorValueUSD / juniorSupplyFormatted : 0
        
        return {
            juniorVault: {
                address: JUNIOR_VAULT_ADDRESS,
                totalSupply: juniorSupplyFormatted.toFixed(6),
                totalAssets: juniorAssetsFormatted.toFixed(6),
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

export const zapAndStake = async (
    userPrivateKey: string,
    amountTUSD: string,
    vaultType: 'junior' | 'senior' | 'reserve',
    slippageTolerance: number = 0.5
) => {
    try {
        // Get admin private key from environment
        const adminPrivateKey = process.env.PRIVATE_KEY
        if (!adminPrivateKey) {
            throw new Error('Admin private key not found in environment')
        }

        // Create provider and wallets
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        const userWallet = new ethers.Wallet(userPrivateKey, provider)
        const adminWallet = new ethers.Wallet(adminPrivateKey, provider)

        console.log(`User address: ${userWallet.address}`)
        console.log(`Admin address: ${adminWallet.address}`)

        const amountTUSDWei = ethers.parseUnits(amountTUSD, 18)

        let transferReceipt = null

        // Step 1: User sends TUSD to admin (skip if user is admin)
        if (userWallet.address.toLowerCase() === adminWallet.address.toLowerCase()) {
            console.log(`Step 1: User is admin, skipping transfer...`)
            // Check admin has enough TUSD
            const tusdContract = new ethers.Contract(TUSD_ADDRESS, ERC20_ABI, adminWallet)
            const adminBalance = await tusdContract.balanceOf(adminWallet.address)
            if (adminBalance < amountTUSDWei) {
                throw new Error(`Insufficient TUSD balance. Have: ${ethers.formatUnits(adminBalance, 18)}, Need: ${amountTUSD}`)
            }
        } else {
            console.log(`Step 1: User sending ${amountTUSD} TUSD to admin...`)
            const tusdContractUser = new ethers.Contract(TUSD_ADDRESS, ERC20_ABI, userWallet)
            
            const userBalance = await tusdContractUser.balanceOf(userWallet.address)
            if (userBalance < amountTUSDWei) {
                throw new Error(`Insufficient TUSD balance. Have: ${ethers.formatUnits(userBalance, 18)}, Need: ${amountTUSD}`)
            }

            const transferTx = await tusdContractUser.transfer(adminWallet.address, amountTUSDWei, {
                maxFeePerGas: ethers.parseUnits('500', 'gwei'),
                maxPriorityFeePerGas: ethers.parseUnits('50', 'gwei')
            })
            transferReceipt = await transferTx.wait()
            console.log(`TUSD transferred to admin. TX: ${transferReceipt.hash}`)
        }

        // Determine vault address
        const vaultAddress = vaultType === 'junior' 
            ? JUNIOR_VAULT_ADDRESS 
            : vaultType === 'senior' 
            ? SENIOR_VAULT_ADDRESS 
            : RESERVE_VAULT_ADDRESS

        // Create contract instances for admin
        const tusdContract = new ethers.Contract(TUSD_ADDRESS, ERC20_ABI, adminWallet)
        const tsailContract = new ethers.Contract(TSAIL_ADDRESS, ERC20_ABI, adminWallet)
        const routerContract = new ethers.Contract(UNISWAP_V2_ROUTER, ROUTER_ABI, adminWallet)
        const pairContract = new ethers.Contract(LP_PAIR_ADDRESS, PAIR_ABI, provider)
        const lpContract = new ethers.Contract(LP_PAIR_ADDRESS, ERC20_ABI, adminWallet)
        const vaultContract = new ethers.Contract(vaultAddress, VAULT_ABI, adminWallet)

        // Step 2: Split TUSD - half stays as TUSD, half swaps to TSAIL
        const halfTUSD = amountTUSDWei / BigInt(2)
        console.log(`Step 2: Splitting ${amountTUSD} TUSD: ${ethers.formatUnits(halfTUSD, 18)} TUSD + ${ethers.formatUnits(halfTUSD, 18)} to swap`)

        // Step 3: Swap half TUSD to TSAIL
        console.log('Step 3: Admin swapping half TUSD to TSAIL...')
        
        // Check TUSD allowance for router
        console.log('3.1: Checking TUSD allowance for router...')
        const tusdAllowance = await tusdContract.allowance(adminWallet.address, UNISWAP_V2_ROUTER)
        console.log(`   Allowance: ${ethers.formatUnits(tusdAllowance, 18)}, Need: ${ethers.formatUnits(halfTUSD, 18)}`)
        
        if (tusdAllowance < halfTUSD) {
            console.log('3.2: Approving TUSD for swap...')
            const approveTx = await tusdContract.approve(UNISWAP_V2_ROUTER, amountTUSDWei, {
                maxFeePerGas: ethers.parseUnits('500', 'gwei'),
                maxPriorityFeePerGas: ethers.parseUnits('50', 'gwei')
            })
            console.log('   Waiting for approval confirmation...')
            await approveTx.wait()
            console.log('   TUSD approved!')
        } else {
            console.log('3.2: TUSD already approved, skipping...')
        }

        // Get reserves and calculate expected TSAIL output
        console.log('3.3: Getting pool reserves...')
        const [reserve0, reserve1] = await pairContract.getReserves()
        const token0 = await pairContract.token0()
        const isTsailToken0 = token0.toLowerCase() === TSAIL_ADDRESS.toLowerCase()
        
        const tusdReserve = isTsailToken0 ? reserve1 : reserve0
        const tsailReserve = isTsailToken0 ? reserve0 : reserve1
        console.log(`   TUSD Reserve: ${ethers.formatUnits(tusdReserve, 18)}`)
        console.log(`   TSAIL Reserve: ${ethers.formatUnits(tsailReserve, 18)}`)
        
        const amountInWithFee = halfTUSD * BigInt(997)
        const numerator = amountInWithFee * tsailReserve
        const denominator = (tusdReserve * BigInt(1000)) + amountInWithFee
        const expectedTSAIL = numerator / denominator
        const minTSAIL = (expectedTSAIL * BigInt(Math.floor((100 - slippageTolerance) * 100))) / BigInt(10000)
        console.log(`   Expected TSAIL out: ${ethers.formatUnits(expectedTSAIL, 18)}`)
        console.log(`   Min TSAIL (with slippage): ${ethers.formatUnits(minTSAIL, 18)}`)

        const deadline = Math.floor(Date.now() / 1000) + 600
        const swapPath = [TUSD_ADDRESS, TSAIL_ADDRESS]
        
        console.log('3.4: Sending swap transaction...')
        const swapTx = await routerContract.swapExactTokensForTokens(
            halfTUSD,
            minTSAIL,
            swapPath,
            adminWallet.address,
            deadline,
            {
                maxFeePerGas: ethers.parseUnits('500', 'gwei'),
                maxPriorityFeePerGas: ethers.parseUnits('50', 'gwei')
            }
        )
        console.log(`   Swap TX sent: ${swapTx.hash}`)
        console.log('   Waiting for confirmation...')
        await swapTx.wait()
        console.log(`✅ Swapped ${ethers.formatUnits(halfTUSD, 18)} TUSD to ~${ethers.formatUnits(expectedTSAIL, 18)} TSAIL`)

        // Step 4: Add liquidity
        console.log('Step 4: Admin adding liquidity...')
        
        // Get actual TSAIL balance after swap - but we only want to use what we just swapped
        const tsailBalance = await tsailContract.balanceOf(adminWallet.address)
        console.log(`TSAIL balance: ${ethers.formatUnits(tsailBalance, 18)}`)
        
        // Calculate how much TSAIL we just got from the swap (approximately)
        // We swapped halfTUSD, so we got roughly expectedTSAIL
        const swappedTSAIL = expectedTSAIL
        console.log(`TSAIL from swap (to use): ${ethers.formatUnits(swappedTSAIL, 18)}`)

        // Approve TSAIL for router (only approve what we need)
        const tsailAllowance = await tsailContract.allowance(adminWallet.address, UNISWAP_V2_ROUTER)
        const tsailNeeded = swappedTSAIL * BigInt(2) // double to be safe
        if (tsailAllowance < tsailNeeded) {
            console.log('Approving TSAIL for liquidity...')
            const approveTx = await tsailContract.approve(UNISWAP_V2_ROUTER, tsailNeeded, {
                maxFeePerGas: ethers.parseUnits('500', 'gwei'),
                maxPriorityFeePerGas: ethers.parseUnits('50', 'gwei')
            })
            await approveTx.wait()
        }

        // Fetch FRESH reserves after the swap (they changed!)
        console.log('4.1: Fetching fresh reserves after swap...')
        const [newReserve0, newReserve1] = await pairContract.getReserves()
        const newTusdReserve = isTsailToken0 ? newReserve1 : newReserve0
        const newTsailReserve = isTsailToken0 ? newReserve0 : newReserve1
        console.log(`   New TUSD Reserve: ${ethers.formatUnits(newTusdReserve, 18)}`)
        console.log(`   New TSAIL Reserve: ${ethers.formatUnits(newTsailReserve, 18)}`)

        // Calculate optimal amounts based on CURRENT pool ratio (after swap)
        // Use halfTUSD and swappedTSAIL (not the full balance)
        const optimalTUSD = (swappedTSAIL * newTusdReserve) / newTsailReserve
        const optimalTSAIL = (halfTUSD * newTsailReserve) / newTusdReserve
        
        let finalTUSD: bigint = halfTUSD
        let finalTSAIL: bigint = swappedTSAIL
        
        if (optimalTUSD <= halfTUSD) {
            finalTUSD = optimalTUSD
        } else {
            finalTSAIL = optimalTSAIL
        }
        
        console.log(`Final amounts for liquidity: TUSD=${ethers.formatUnits(finalTUSD, 18)}, TSAIL=${ethers.formatUnits(finalTSAIL, 18)}`)

        const minTUSD = (finalTUSD * BigInt(Math.floor((100 - slippageTolerance - 2) * 100))) / BigInt(10000)
        const minTSAILForLiquidity = (finalTSAIL * BigInt(Math.floor((100 - slippageTolerance - 2) * 100))) / BigInt(10000)

        // Calculate expected LP tokens to be minted using FRESH reserves
        // Formula: min(amountA * totalSupply / reserveA, amountB * totalSupply / reserveB)
        const totalSupply = await pairContract.totalSupply()
        const expectedLPFromTUSD = (finalTUSD * totalSupply) / newTusdReserve
        const expectedLPFromTSAIL = (finalTSAIL * totalSupply) / newTsailReserve
        const expectedLP = expectedLPFromTUSD < expectedLPFromTSAIL ? expectedLPFromTUSD : expectedLPFromTSAIL
        
        console.log(`Expected LP tokens to mint: ${ethers.formatUnits(expectedLP, 18)}`)
        console.log(`  From TUSD ratio: ${ethers.formatUnits(expectedLPFromTUSD, 18)}`)
        console.log(`  From TSAIL ratio: ${ethers.formatUnits(expectedLPFromTSAIL, 18)}`)

        const liquidityTx = await routerContract.addLiquidity(
            TUSD_ADDRESS,
            TSAIL_ADDRESS,
            finalTUSD,
            finalTSAIL,
            minTUSD,
            minTSAILForLiquidity,
            adminWallet.address,
            deadline,
            {
                maxFeePerGas: ethers.parseUnits('500', 'gwei'),
                maxPriorityFeePerGas: ethers.parseUnits('50', 'gwei')
            }
        )
        const liquidityReceipt = await liquidityTx.wait()
        console.log('Liquidity added successfully, TX:', liquidityReceipt.hash)

        // Step 5: Get LP token balance and deposit to vault
        console.log('Step 5: Admin depositing LP tokens to vault (shares to user)...')
        
        // Use the calculated expected LP tokens (with 0.5% buffer for safety)
        const lpBalance = (expectedLP * BigInt(995)) / BigInt(1000)
        console.log(`Using estimated LP tokens: ${ethers.formatUnits(lpBalance, 18)}`)
        
        if (lpBalance <= BigInt(0)) {
            throw new Error('Calculated LP tokens is zero!')
        }

        // Approve vault to spend LP tokens
        const lpAllowance = await lpContract.allowance(adminWallet.address, vaultAddress)
        if (lpAllowance < lpBalance) {
            console.log('Approving LP tokens for vault...')
            const approveTx = await lpContract.approve(vaultAddress, lpBalance, {
                maxFeePerGas: ethers.parseUnits('500', 'gwei'),
                maxPriorityFeePerGas: ethers.parseUnits('50', 'gwei')
            })
            await approveTx.wait()
        }

        // Deposit LP tokens to vault with user as receiver
        const depositTx = await vaultContract.deposit(lpBalance, userWallet.address, {
            maxFeePerGas: ethers.parseUnits('500', 'gwei'),
            maxPriorityFeePerGas: ethers.parseUnits('50', 'gwei')
        })
        const depositReceipt = await depositTx.wait()
        console.log(`Deposited to ${vaultType} vault, shares sent to user ${userWallet.address}`)

        return {
            success: true,
            steps: {
                transfer: transferReceipt ? {
                    from: userWallet.address,
                    to: adminWallet.address,
                    amount: amountTUSD,
                    transactionHash: transferReceipt.hash
                } : {
                    from: userWallet.address,
                    to: adminWallet.address,
                    amount: amountTUSD,
                    skipped: true,
                    reason: 'User is admin'
                },
                swap: {
                    tusdIn: ethers.formatUnits(halfTUSD, 18),
                    tsailOut: ethers.formatUnits(tsailBalance, 18)
                },
                liquidity: {
                    tusdAmount: ethers.formatUnits(finalTUSD, 18),
                    tsailAmount: ethers.formatUnits(finalTSAIL, 18),
                    lpTokens: ethers.formatUnits(lpBalance, 18)
                },
                vault: {
                    type: vaultType,
                    address: vaultAddress,
                    recipient: userWallet.address,
                    lpDeposited: ethers.formatUnits(lpBalance, 18),
                    transactionHash: depositReceipt.hash
                }
            },
            totalTUSDUsed: amountTUSD,
            finalTransactionHash: depositReceipt.hash
        }
    } catch (error) {
        console.error('Error in zap and stake:', error)
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
        
        // Fetch total assets, vault values, and LP token price in parallel
        const [
            seniorAssets, juniorAssets, reserveAssets,
            seniorValue, juniorValue, reserveValue,
            lpPriceData
        ] = await Promise.all([
            seniorVault.totalAssets(),
            juniorVault.totalAssets(),
            reserveVault.totalAssets(),
            seniorVault.vaultValue(),
            juniorVault.vaultValue(),
            reserveVault.vaultValue(),
            getLPTokenPrice()
        ])
        
        // Format values
        const seniorAssetsFormatted = Number(ethers.formatUnits(seniorAssets, 18))
        const juniorAssetsFormatted = Number(ethers.formatUnits(juniorAssets, 18))
        const reserveAssetsFormatted = Number(ethers.formatUnits(reserveAssets, 18))
        
        const seniorValueFormatted = Number(ethers.formatUnits(seniorValue, 18))
        const juniorValueFormatted = Number(ethers.formatUnits(juniorValue, 18))
        const reserveValueFormatted = Number(ethers.formatUnits(reserveValue, 18))
        
        const lpPrice = Number(lpPriceData.lpTokenPriceInTUSD)
        
        // Calculate current USD values (totalAssets * LP price)
        const seniorCurrentUSD = seniorAssetsFormatted * lpPrice
        const juniorCurrentUSD = juniorAssetsFormatted * lpPrice
        const reserveCurrentUSD = reserveAssetsFormatted * lpPrice
        
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

export const getRebaseConfig = async () => {
    try {
        // Create provider
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        
        // Create contract instance for senior vault
        const seniorVault = new ethers.Contract(SENIOR_VAULT_ADDRESS, VAULT_ABI, provider)
        
        // Fetch rebase configuration
        const [minInterval, lastRebaseTime] = await Promise.all([
            seniorVault.minRebaseInterval(),
            seniorVault.lastRebaseTime()
        ])
        
        // Format values
        const minIntervalSeconds = Number(minInterval)
        const lastRebaseTimestamp = Number(lastRebaseTime)
        const currentTimestamp = Math.floor(Date.now() / 1000)
        const timeSinceLastRebase = currentTimestamp - lastRebaseTimestamp
        const timeUntilNextRebase = Math.max(0, minIntervalSeconds - timeSinceLastRebase)
        const canRebaseNow = timeSinceLastRebase >= minIntervalSeconds
        
        return {
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
    profitBps: number
) => {
    try {
        // Create provider and wallet
        const provider = new ethers.JsonRpcProvider(RPC_URL)
        const adminWallet = new ethers.Wallet(adminPrivateKey, provider)
        
        // Create contract instance
        const seniorVault = new ethers.Contract(SENIOR_VAULT_ADDRESS, VAULT_ABI, adminWallet)
        
        // Get current vault value for reference
        const currentValue = await seniorVault.vaultValue()
        const currentValueFormatted = Number(ethers.formatUnits(currentValue, 18))
        
        // Calculate new value
        const profitPercent = profitBps / 100
        const newValueEstimate = currentValueFormatted * (1 + profitPercent / 100)
        
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
        
        // Execute rebase
        console.log('\n⚡ Executing rebase...')
        const tx = await seniorVault.rebase({
            maxFeePerGas: ethers.parseUnits('500', 'gwei'),
            maxPriorityFeePerGas: ethers.parseUnits('50', 'gwei')
        })
        
        console.log(`TX sent: ${tx.hash}`)
        console.log('Waiting for confirmation...')
        const receipt = await tx.wait()
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