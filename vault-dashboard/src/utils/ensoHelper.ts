// Enso DeFi API Helper
// Fetches optimal swap routes for deploying to Kodiak

const ENSO_API_KEY = '3ea9ecd8-5058-493c-8c73-42811e78ed2c';
const ENSO_BASE_URL = 'https://api.enso.finance/api/v1';
const BERACHAIN_CHAIN_ID = 80094;

interface EnsoRouteParams {
  fromAddress: string;
  tokenIn: string;
  tokenOut: string;
  amountIn: string; // in wei
  slippage?: string; // in basis points (e.g., "300" = 3%)
  routingStrategy?: 'router' | 'delegate';
}

interface EnsoRouteResponse {
  gas: string;
  amountOut: string;
  priceImpact: number;
  feeAmount: string[];
  minAmountOut: string;
  createdAt: number;
  tx: {
    to: string;
    from: string;
    data: string;
    value: string;
    gasPrice?: string;
    gasLimit?: string;
  };
  route: Array<{
    tokenIn: string[];
    tokenOut: string[];
    protocol: string;
    action: string;
  }>;
  ensoFeeAmount: string[];
}

/**
 * Get optimal swap route from Enso
 */
export async function getEnsoRoute(params: EnsoRouteParams): Promise<EnsoRouteResponse> {
  const url = new URL(`${ENSO_BASE_URL}/shortcuts/route`);
  
  url.searchParams.append('chainId', BERACHAIN_CHAIN_ID.toString());
  url.searchParams.append('fromAddress', params.fromAddress);
  url.searchParams.append('amountIn', params.amountIn);
  url.searchParams.append('tokenIn', params.tokenIn);
  url.searchParams.append('tokenOut', params.tokenOut);
  url.searchParams.append('slippage', params.slippage || '500'); // 5% default
  url.searchParams.append('routingStrategy', params.routingStrategy || 'router');

  const response = await fetch(url.toString(), {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${ENSO_API_KEY}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Enso API error: ${response.status} - ${error}`);
  }

  return await response.json();
}

/**
 * Get swap data for deploying to Kodiak WBTC-HONEY pool
 * @param honeyAmount Amount of HONEY to deploy (in ether, e.g., "1000")
 * @param hookAddress Address of the hook (will receive the tokens)
 * @returns Swap parameters for deployToKodiak
 */
export async function getKodiakDeploySwapData(
  honeyAmount: string,
  hookAddress: string
) {
  const HONEY = '0xFCBD14DC51f0A4d49d5E53C2E0950e0bC26d0Dce';
  const WBTC = '0x0555E30da8f98308EdB960aa94C0Db47230d2B9c';

  // Convert to wei
  const amountInWei = BigInt(parseFloat(honeyAmount) * 1e18).toString();
  
  // For WBTC-HONEY pool, we need to swap ~50% to WBTC
  const amountToSwap = (BigInt(amountInWei) / 2n).toString();

  console.log('🔍 Fetching Enso route...');
  console.log(`  Amount: ${honeyAmount} HONEY`);
  console.log(`  Swapping: ${parseFloat(amountToSwap) / 1e18} HONEY → WBTC`);

  try {
    // Get route for HONEY → WBTC swap
    const route = await getEnsoRoute({
      fromAddress: hookAddress, // Hook will execute the swap
      tokenIn: HONEY,
      tokenOut: WBTC,
      amountIn: amountToSwap,
      slippage: '500', // 5%
      routingStrategy: 'router',
    });

    console.log('✅ Enso route found!');
    console.log(`  Protocol: ${route.route[0]?.protocol || 'Multiple'}`);
    console.log(`  Expected WBTC out: ${parseFloat(route.amountOut) / 1e8} WBTC`);
    console.log(`  Price impact: ${route.priceImpact / 100}%`);
    console.log(`  Gas estimate: ${route.gas}`);

    // Extract swap parameters
    const swapParams = {
      // Swap to Token0 (WBTC)
      swapToToken0Aggregator: route.tx.to,
      swapToToken0Data: route.tx.data,
      
      // Token1 (HONEY) - no swap needed
      swapToToken1Aggregator: '0x0000000000000000000000000000000000000000',
      swapToToken1Data: '0x',
      
      // Additional info
      expectedWBTCOut: route.amountOut,
      minWBTCOut: route.minAmountOut,
      priceImpact: route.priceImpact,
      route: route.route,
    };

    return {
      success: true,
      swapParams,
      route,
    };
  } catch (error) {
    console.error('❌ Enso API error:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

/**
 * Get token price from Enso API
 */
export async function getTokenPrice(chainId: number, tokenAddress: string) {
  const url = `${ENSO_BASE_URL}/prices/${chainId}/${tokenAddress}`;
  
  const response = await fetch(url, {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${ENSO_API_KEY}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Enso Price API error: ${response.status} - ${error}`);
  }

  const data = await response.json();
  return {
    price: data.price,
    decimals: data.decimals,
    symbol: data.symbol,
    timestamp: data.timestamp,
    confidence: data.confidence,
  };
}

/**
 * Get WBTC price in USD from Enso
 */
export async function getWBTCPrice(): Promise<number> {
  const WBTC_ADDRESS = '0x0555E30da8f98308EdB960aa94C0Db47230d2B9c';
  try {
    const priceData = await getTokenPrice(BERACHAIN_CHAIN_ID, WBTC_ADDRESS);
    return priceData.price;
  } catch (error) {
    console.error('Error fetching WBTC price:', error);
    return 97000; // Fallback to ~$97k if API fails
  }
}

/**
 * Estimate min LP tokens to receive
 * Based on current pool state and amount being deposited
 */
export function estimateMinLPTokens(
  honeyAmount: string,
  currentLPPrice: string, // in HONEY per LP
  slippageBps: number = 2000 // 20% default (increased for better success rate)
): string {
  const amountUSD = parseFloat(honeyAmount); // Assuming HONEY = $1
  const lpPrice = parseFloat(currentLPPrice);
  
  const expectedLP = amountUSD / lpPrice;
  const minLP = expectedLP * (1 - slippageBps / 10000);
  
  return minLP.toFixed(18);
}

/**
 * Calculate min LP tokens using live Kodiak Island price from Enso
 * @param honeyAmount Amount of HONEY to deploy
 * @param slippageBps Slippage tolerance in basis points (default 2000 = 20%)
 * @returns Min LP tokens (formatted for display)
 */
export async function calculateMinLPTokensLive(
  honeyAmount: string,
  slippageBps: number = 2000
): Promise<{
  minLPTokens: string;
  expectedLPTokens: string;
  lpPrice: number;
  confidence: number;
}> {
  const KODIAK_ISLAND_ADDRESS = '0xf6b16E73d3b0e2784AAe8C4cd06099BE65d092Bf';
  
  try {
    // Get live LP token price
    const priceData = await getTokenPrice(BERACHAIN_CHAIN_ID, KODIAK_ISLAND_ADDRESS);
    
    console.log('📊 Kodiak Island LP Price:', {
      price: priceData.price,
      symbol: priceData.symbol,
      confidence: priceData.confidence,
      timestamp: new Date(priceData.timestamp * 1000).toLocaleString(),
    });
    
    // Calculate expected LP tokens
    const amountUSD = parseFloat(honeyAmount); // Assuming HONEY = $1
    const lpPrice = priceData.price;
    const expectedLP = amountUSD / lpPrice;
    
    // Apply slippage
    const minLP = expectedLP * (1 - slippageBps / 10000);
    
    return {
      minLPTokens: minLP.toFixed(18),
      expectedLPTokens: expectedLP.toFixed(18),
      lpPrice: lpPrice,
      confidence: priceData.confidence || 1,
    };
  } catch (error) {
    console.error('❌ Error fetching LP price:', error);
    throw error;
  }
}

/**
 * Get swap data for WBTC → HONEY dust recovery
 * @param wbtcAmount Amount of WBTC to swap (in WBTC units, e.g., "0.00000528")
 * @param hookAddress Address of the hook (will execute the swap)
 * @returns Swap data to pass to adminSwapAndReturnToVault
 */
export async function getWBTCToHoneySwapData(
  wbtcAmount: string,
  hookAddress: string
) {
  const HONEY = '0xFCBD14DC51f0A4d49d5E53C2E0950e0bC26d0Dce';
  const WBTC = '0x0555E30da8f98308EdB960aa94C0Db47230d2B9c';

  // Convert to WBTC wei (8 decimals)
  const amountInWei = BigInt(Math.floor(parseFloat(wbtcAmount) * 1e8)).toString();

  console.log('🔍 Fetching WBTC → HONEY swap route...');
  console.log(`  Amount: ${wbtcAmount} WBTC`);
  console.log(`  Hook: ${hookAddress}`);

  try {
    // Get route for WBTC → HONEY swap
    const route = await getEnsoRoute({
      fromAddress: hookAddress, // Hook will execute the swap
      tokenIn: WBTC,
      tokenOut: HONEY,
      amountIn: amountInWei,
      slippage: '500', // 5%
      routingStrategy: 'router',
    });

    console.log('✅ Enso route found!');
    console.log(`  Protocol: ${route.route[0]?.protocol || 'Multiple'}`);
    console.log(`  Expected HONEY out: ${parseFloat(route.amountOut) / 1e18} HONEY`);
    console.log(`  Price impact: ${route.priceImpact / 100}%`);
    console.log(`  Gas estimate: ${route.gas}`);

    return {
      success: true,
      swapData: route.tx.data,
      aggregator: route.tx.to,
      expectedHoneyOut: route.amountOut,
      minHoneyOut: route.minAmountOut,
      priceImpact: route.priceImpact,
      route: route.route,
    };
  } catch (error) {
    console.error('❌ Enso API error:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

