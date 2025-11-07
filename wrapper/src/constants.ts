export const TSAIL_ADDRESS = '0xa384A42bAf163014dF91a6ab92EFc2Bb8369CFAD'
export const TUSD_ADDRESS = '0xa61617fa0ad692Ba4a5784c34156E530107B3252'
export const LP_PAIR_ADDRESS = '0xFC1548069A74F7F9427EE718ECEcB6560A5562C6'
export const CHAIN_ID = 137
export const ADMIN_ADDRESS = '0xE09883Cb3Fe2d973cEfE4BB28E3A3849E7e5f0A7'

// Vault addresses (proxy addresses from deployment on Polygon)
export const SENIOR_VAULT_ADDRESS = '0xc87086848c82089FE2Da4997Eac4EbF42591a579'
export const JUNIOR_VAULT_ADDRESS = '0x2133D49CF9C50A2A54E7254395c671f715f6Ed70'
export const RESERVE_VAULT_ADDRESS = '0xCA3F6035db58e2A56783557B2B46EA8da84291e0'

// Polygon RPC endpoint (you can replace with your own RPC)
export const RPC_URL = 'https://polygon-rpc.com'

export const PAIR_ABI = [
    'function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast)',
    'function token0() external view returns (address)',
    'function token1() external view returns (address)',
    'function totalSupply() external view returns (uint256)'
]

// Minimal ABI for totalSupply, totalAssets, vaultValue, deposit, and rebase config
export const VAULT_ABI = [
    'function totalSupply() external view returns (uint256)',
    'function totalAssets() external view returns (uint256)',
    'function vaultValue() external view returns (uint256)',
    'function deposit(uint256 assets, address receiver) external returns (uint256 shares)',
    'function minRebaseInterval() external view returns (uint256)',
    'function setMinRebaseInterval(uint256 newInterval) external',
    'function lastRebaseTime() external view returns (uint256)',
    'function rebaseIndex() external view returns (uint256)',
    'function epoch() external view returns (uint256)',
    'function updateVaultValue(int256 profitBps) external',
    'function setVaultValue(uint256 newValue) external',
    'function rebase(uint256 lpPrice) external',
    'function addWhitelistedDepositor(address depositor) external',
    'function isWhitelistedDepositor(address depositor) external view returns (bool)',
    'function getLPHoldings() external view returns (tuple(address lpToken, uint256 amount)[])',
    'function getLPTokenHoldings() external view returns (tuple(address lpToken, uint256 amount)[])',
    'function investInLP(address lp, uint256 amount) external',
    'function addWhitelistedLP(address lp) external',
    'function addWhitelistedLPToken(address lpToken) external'
]

// ERC20 ABI for balanceOf, allowance, approve, and transfer
export const ERC20_ABI = [
    'function balanceOf(address account) external view returns (uint256)',
    'function allowance(address owner, address spender) external view returns (uint256)',
    'function approve(address spender, uint256 amount) external returns (bool)',
    'function transfer(address to, uint256 amount) external returns (bool)'
]

// Uniswap V2 Router address (Polygon)
// QuickSwap Router (old): 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff (USING THIS ONE - matches your LP pair factory)
// QuickSwap Router V2 (used by Uniswap app): 0xedf6066a2b290C185783862C7F4776A2C8077AD1
// SushiSwap: 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506
export const UNISWAP_V2_ROUTER = '0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff'

// Uniswap V2 Router ABI (minimal)
export const ROUTER_ABI = [
    'function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts)',
    'function getAmountsOut(uint amountIn, address[] memory path) external view returns (uint[] memory amounts)',
    'function addLiquidity(address tokenA, address tokenB, uint amountADesired, uint amountBDesired, uint amountAMin, uint amountBMin, address to, uint deadline) external returns (uint amountA, uint amountB, uint liquidity)'
]