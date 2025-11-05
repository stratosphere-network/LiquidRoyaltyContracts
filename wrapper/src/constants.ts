export const TSAIL_ADDRESS = '0x3ee4686e8165d1358f67b6635f62fb8ca6ac0b08'
export const TUSD_ADDRESS = '0xeddc540d74155791c9d43c95eb635c1b52fe0a6d'
export const LP_PAIR_ADDRESS = '0x2cd6179f1cb01636b7f497f13ea5b2fa1cedcc68'
export const CHAIN_ID = 137
export const ADMIN_ADDRESS = '0xE09883Cb3Fe2d973cEfE4BB28E3A3849E7e5f0A7'

// Vault addresses (proxy addresses from deployment on Polygon)
export const SENIOR_VAULT_ADDRESS = '0x0b0d6b5d6656504c826ad34bd56ae683efc94395'
export const JUNIOR_VAULT_ADDRESS = '0x210603159a8f18e820e44c390b7046d507ee7fb5'
export const RESERVE_VAULT_ADDRESS = '0x7a6e684176d94863fd9e9e48673ed3a8f94265b9'

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
    'function updateVaultValue(int256 profitBps) external',
    'function rebase() external',
    'function addWhitelistedDepositor(address depositor) external',
    'function isWhitelistedDepositor(address depositor) external view returns (bool)'
]

// ERC20 ABI for balanceOf, allowance, approve, and transfer
export const ERC20_ABI = [
    'function balanceOf(address account) external view returns (uint256)',
    'function allowance(address owner, address spender) external view returns (uint256)',
    'function approve(address spender, uint256 amount) external returns (bool)',
    'function transfer(address to, uint256 amount) external returns (bool)'
]

// Uniswap V2 Router address (Polygon)
// QuickSwap Router (old): 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff
// QuickSwap Router V2 (used by Uniswap app): 0xedf6066a2b290C185783862C7F4776A2C8077AD1
// SushiSwap: 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506
export const UNISWAP_V2_ROUTER = '0xedf6066a2b290C185783862C7F4776A2C8077AD1'

// Uniswap V2 Router ABI (minimal)
export const ROUTER_ABI = [
    'function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts)',
    'function getAmountsOut(uint amountIn, address[] memory path) external view returns (uint[] memory amounts)',
    'function addLiquidity(address tokenA, address tokenB, uint amountADesired, uint amountBDesired, uint amountAMin, uint amountBMin, address to, uint deadline) external returns (uint amountA, uint amountB, uint liquidity)'
]