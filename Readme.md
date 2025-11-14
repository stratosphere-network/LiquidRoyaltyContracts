# Liquid Royalty Protocol - Developer Guide

> **A three-vault structured investment protocol with dynamic rebase mechanics and two-way profit/loss sharing**

## 🆕 Version 3.0 - On-Chain Oracle & Kodiak Integration

**New Features**:
- ✅ **Pure On-Chain Oracle**: Calculate LP prices without Chainlink (stablecoin pools)
- ✅ **Single Flag System**: `_useCalculatedValue` controls entire system trustlessness
- ✅ **Kodiak Islands**: Single-sided liquidity + auto-compounding on Berachain
- ✅ **Validation System**: Prevent admin manipulation with on-chain checks
- ✅ **Hook Pattern**: Modular DeFi integration (easy to swap protocols)

**All three vaults** (Senior, Junior, Reserve) now support:
- Automatic vault value calculation
- Automatic LP price calculation (Senior only for rebase)
- Kodiak deployment with slippage protection
- Sweep idle stablecoin dust to earning positions

**Read More**: See [On-Chain Oracle & Kodiak Integration](#on-chain-oracle--kodiak-integration)

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture & Contracts](#architecture--contracts)
3. [Mathematical Specification](#mathematical-specification)
4. [Contract Deployments](#contract-deployments)
5. [Key Flows & Patterns](#key-flows--patterns)
6. [API Reference](#api-reference)
7. [Frontend Integration](#frontend-integration)
8. [Development Workflow](#development-workflow)
9. [Testing](#testing)
10. [Deployment & Upgrades](#deployment--upgrades)
11. [Common Operations](#common-operations)
12. [Troubleshooting](#troubleshooting)

---

## System Overview

### What is Liquid Royalty Protocol?

A three-vault structured investment system where:
- **Senior Vault (snrUSD)**: Stable, rebase token with 11-13% APY, pegged to $1
- **Junior Vault (jnrUSD)**: Higher risk/reward, receives 80% of Senior profits, provides backstop
- **Reserve Vault (resUSD)**: Primary backstop, receives 20% of Senior profits, emergency support

### Core Mechanics

**1. Dynamic Rebase (Monthly)**
- Senior vault rebases every 30 days
- APY dynamically selected: 13% → 12% → 11% (waterfall)
- System tries highest APY that maintains ≥100% backing
- Users' balances increase automatically via rebase index

**2. Three Operating Zones**

| Zone | Backing Ratio | Action | Frequency |
|------|--------------|--------|-----------|
| **Zone 1** | > 110% | Profit spillover to Junior (80%) & Reserve (20%) | When strategy performs very well |
| **Zone 2** | 100-110% | **No action** - Healthy buffer | **Most common (normal operation)** |
| **Zone 3** | < 100% | Backstop: Reserve → Junior → Senior (restore to 100.9%) | Rare (strategy underperforms) |

**3. Two-Way Value Flow**

```
          ┌─────────────────────────────────────┐
          │                                     │
          │         SENIOR VAULT                │
          │      (snrUSD, 11-13% APY)          │
          │                                     │
          └──────────┬──────────────┬───────────┘
                     │              │
         Profit      │              │      Backstop
         (>110%)     │              │      (<100%)
                     ▼              ▼
          ┌──────────────┐   ┌──────────────┐
          │   JUNIOR     │   │   RESERVE    │
          │   (80%)      │   │   (20%)      │
          │  jnrUSD      │   │   resUSD     │
          └──────────────┘   └──────────────┘
               ▲                    ▲
               │                    │
               └────────────────────┘
                  Backstop Flow
              (Reserve first, no cap!)
             (Junior second, no cap!)
```

---

## Architecture & Contracts

### Contract Structure

```
src/
├── abstract/              # Base implementations
│   ├── BaseVault.sol         # ERC4626 + Rebase logic
│   ├── AdminControlled.sol   # Access control
│   ├── UnifiedSeniorVault.sol # Senior logic with LP transfers
│   ├── JuniorVault.sol        # Junior logic with LP transfers
│   └── ReserveVault.sol       # Reserve logic with LP transfers
│
├── concrete/              # Deployed implementations
│   ├── UnifiedConcreteSeniorVault.sol
│   ├── ConcreteJuniorVault.sol
│   └── ConcreteReserveVault.sol
│
├── interfaces/           # Contract interfaces
│   ├── IVault.sol
│   ├── ISeniorVault.sol
│   ├── IJuniorVault.sol
│   └── IReserveVault.sol
│
└── libraries/            # Shared utilities
    ├── MathLib.sol       # Fixed-point math
    ├── RebaseLib.sol     # Rebase calculations
    ├── FeeLib.sol        # Fee calculations
    ├── SpilloverLib.sol  # Spillover logic
    └── LPPriceOracle.sol # On-chain LP price calculation
```

### Key Design Patterns

**1. Upgradeable Proxy Pattern (UUPS)**
- Each vault uses ERC1967Proxy
- Implementation contracts are upgradeable by admin
- Allows bug fixes and feature additions without changing addresses

**2. Rebase Token Pattern**
- User shares remain constant
- Rebase index increases each rebase
- Balance = shares × rebase_index
- Automatic balance growth (no claim needed)

**3. Two-Way Spillover Pattern**
- **Profit Spillover (Senior → Junior/Reserve)**: When backing > 110%
- **Backstop (Reserve/Junior → Senior)**: When backing < 100%
- Creates balanced risk/reward for all participants

**4. LP Token Transfer Pattern (NEW)**
- During spillover/backstop, LP tokens are transferred (not stablecoins)
- Admin provides current LP price during rebase
- Contracts calculate LP token amounts based on USD value needed

**5. On-Chain Oracle System (NEW)**
- Pure on-chain LP price calculation (no Chainlink needed for stablecoin pools)
- Automatic vault value calculation from LP holdings
- Single flag (`_useCalculatedValue`) controls entire system trustlessness
- Admin validation with configurable deviation threshold

**6. Kodiak Islands Integration (NEW)**
- Single-sided liquidity provision for vaults
- Secure `deployToKodiak()` function with slippage protection
- `sweepToKodiak()` for deploying idle stablecoin dust
- Hook pattern for modular DeFi integration

---

## On-Chain Oracle & Kodiak Integration

### Overview

**Problem**: Traditional DeFi vaults rely on off-chain keepers to calculate LP prices and vault values, creating centralization risks and requiring trust in admin inputs.

**Solution**: Our system implements a **pure on-chain oracle** that calculates LP prices directly from pool reserves, enabling fully trustless vault operations when working with stablecoin-paired pools.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    VAULT OPERATIONS                         │
│  (deposit, withdraw, rebase, spillover, backstop)           │
└────────────────┬────────────────────────────────────────────┘
                 │
                 │ Uses _useCalculatedValue flag
                 │
         ┌───────┴────────┐
         │                │
    ┌────▼─────┐    ┌────▼──────┐
    │ AUTOMATIC │    │  MANUAL   │
    │   MODE    │    │   MODE    │
    │ (flag=true)│   │(flag=false)│
    └────┬─────┘    └────┬──────┘
         │                │
         │                │
    ┌────▼────────────────▼──────┐
    │   LPPriceOracle.sol        │
    │  (Pure On-Chain Calc)      │
    └────┬───────────────────────┘
         │
         │ Reads from
         │
    ┌────▼───────────────────────┐
    │  Kodiak Island Contract    │
    │  • token0                  │
    │  • token1                  │
    │  • getUnderlyingBalances() │
    │  • totalSupply()           │
    └────────────────────────────┘
```

### LPPriceOracle - On-Chain Price Calculation

#### How It Works

For **stablecoin-paired pools** (e.g., USDC-BERA), we can calculate the LP token price purely on-chain:

**Formula**:
```solidity
// 1. Get pool reserves
(uint256 stablecoinAmount, uint256 otherTokenAmount) = island.getUnderlyingBalances();

// 2. Calculate other token's price using the stablecoin as reference
//    Since stablecoin = $1, we can derive the other token's price:
otherTokenPrice = stablecoinAmount / otherTokenAmount;

// 3. Calculate total pool value in USD
totalValue = stablecoinAmount + (otherTokenAmount × otherTokenPrice);

// 4. Calculate LP token price
lpPrice = totalValue / lpTotalSupply;
```

**Example**: Pool has 100K USDC + 10K BERA
```
BERA price = 100,000 / 10,000 = $10
Total value = $100,000 + (10,000 × $10) = $200,000
LP supply = 31,622.77 (geometric mean)
LP price = $200,000 / 31,622.77 = $6.32 ✅
```

#### Why This Works

1. **Stablecoin = $1**: USDC/USDT/USDE always = $1 USD (by design)
2. **Pool Ratio**: The ratio of reserves automatically reflects market price
3. **Arbitrage**: Keeps pool balanced via MEV bots
4. **No Oracle Needed**: All data is already on-chain in the Island contract

#### Implementation

```solidity
// src/libraries/LPPriceOracle.sol
library LPPriceOracle {
    /**
     * @notice Calculate LP price from Kodiak Island reserves
     * @param island Kodiak Island address
     * @param stablecoinIsToken0 True if token0 is the stablecoin
     * @return lpPrice LP token price in USD (18 decimals)
     */
    function calculateLPPrice(address island, bool stablecoinIsToken0) 
        internal view returns (uint256 lpPrice) 
    {
        IKodiakIsland islandContract = IKodiakIsland(island);
        
        // Get reserves and LP supply
        (uint256 amt0, uint256 amt1) = islandContract.getUnderlyingBalances();
        uint256 totalLP = islandContract.totalSupply();
        
        // Normalize decimals to 18
        uint256 amt0In18 = _normalize(amt0, token0.decimals());
        uint256 amt1In18 = _normalize(amt1, token1.decimals());
        
        uint256 totalValue;
        if (stablecoinIsToken0) {
            // Calculate token1 price from pool ratio
            uint256 token1Price = (amt0In18 * 1e18) / amt1In18;
            uint256 token1Value = (amt1In18 * token1Price) / 1e18;
            totalValue = amt0In18 + token1Value;
        } else {
            // Calculate token0 price from pool ratio
            uint256 token0Price = (amt1In18 * 1e18) / amt0In18;
            uint256 token0Value = (amt0In18 * token0Price) / 1e18;
            totalValue = token0Value + amt1In18;
        }
        
        // LP price = total value / total supply
        lpPrice = (totalValue * 1e18) / totalLP;
    }
    
    /**
     * @notice Calculate total vault value from LP + idle stablecoin
     * @return totalVaultValue Total vault value in USD (18 decimals)
     */
    function calculateTotalVaultValue(
        address hookAddress,
        address islandAddress,
        bool stablecoinIsToken0,
        address vaultAddress,
        address stablecoinAddress
    ) internal view returns (uint256 totalVaultValue) {
        // 1. Value from LP holdings in hook
        uint256 lpBalance = IKodiakVaultHook(hookAddress).getIslandLPBalance();
        uint256 lpValue = 0;
        if (lpBalance > 0) {
            uint256 lpPrice = calculateLPPrice(islandAddress, stablecoinIsToken0);
            lpValue = (lpBalance * lpPrice) / 1e18;
        }
        
        // 2. Value from idle stablecoin in vault
        uint256 idleBalance = IERC20(stablecoinAddress).balanceOf(vaultAddress);
        uint256 idleValue = _normalize(idleBalance, stablecoin.decimals());
        
        totalVaultValue = lpValue + idleValue;
    }
}
```

### The Flag System

#### What is `_useCalculatedValue`?

A **single boolean flag** that controls whether the system operates in **trustless automatic mode** or **keeper-managed manual mode**.

```solidity
// State variable in all vaults
bool internal _useCalculatedValue;  // true = automatic, false = manual
```

#### What It Controls

| Feature | Flag = true (AUTOMATIC) | Flag = false (MANUAL) |
|---------|------------------------|----------------------|
| **Vault Value** (`vaultValue()`) | Calculated on-chain from LP holdings | Uses admin-set `_vaultValue` |
| **LP Price** (`rebase()`) | Calculated on-chain from pool ratio | Admin must provide manually |
| **Trust Model** | 100% trustless | Requires trusted admin/keeper |
| **Gas Cost** | Slightly higher (calculations) | Slightly lower (reads storage) |
| **Use Case** | Stablecoin-paired pools | Volatile pairs or complex strategies |

#### Configuration

```solidity
// Configure oracle for automatic mode
vault.configureOracle(
    KODIAK_ISLAND_ADDRESS,  // Island contract
    true,                   // stablecoinIsToken0 (USDC is token0)
    500,                    // maxDeviationBps (5% max deviation)
    true,                   // enableValidation (validate admin inputs)
    true                    // 🔥 useCalculatedValue (THE FLAG!)
);
```

**Parameters Explained**:
- `island`: Kodiak Island contract address for the LP pool
- `stablecoinIsToken0`: Which token in the pair is the stablecoin (determines calculation)
- `maxDeviationBps`: Maximum allowed deviation when validating admin inputs (basis points, 500 = 5%)
- `enableValidation`: Enable on-chain validation of admin-provided values
- `useCalculatedValue`: **THE FLAG** - true for automatic, false for manual

#### Usage Examples

**Scenario 1: Fully Automatic (Recommended for Stablecoin Pools)**
```solidity
// Setup (one-time)
vault.configureOracle(ISLAND, true, 500, true, true);

// Daily operations
vault.deposit(1000e6, user);  // ✅ Auto-calculates vault value
vault.rebase();               // ✅ Auto-calculates LP price
// NO keeper bot needed! 🎉
```

**Scenario 2: Manual with Validation (Hybrid)**
```solidity
// Setup
vault.configureOracle(ISLAND, true, 500, true, false);  // flag = false

// Keeper bot calculates off-chain
uint256 offChainValue = keeper.calculateValue();
vault.setVaultValue(offChainValue);  // ✅ Validated against on-chain calc (±5%)

// Rebase with manual LP price
uint256 lpPrice = keeper.getLPPrice();
vault.rebase(lpPrice);
```

**Scenario 3: Query-Only (Best of Both Worlds)**
```solidity
// Check both values
uint256 calculated = vault.getCalculatedVaultValue();
uint256 stored = vault.getStoredVaultValue();
uint256 lpPrice = vault.getCalculatedLPPrice();

// Keeper decides based on deviation
if (abs(calculated - stored) / calculated < 0.01) {
    // <1% deviation, use automatic
    vault.rebase();
} else {
    // Use manual with override
    vault.rebase(lpPrice);
}
```

### Validation System

Even in **manual mode**, the on-chain oracle provides a **safety check**:

```solidity
function setVaultValue(uint256 newValue) public onlyAdmin {
    // If validation enabled, compare with on-chain calculation
    if (_oracleEnabled && _oracleIsland != address(0)) {
        uint256 calculatedValue = LPPriceOracle.calculateTotalVaultValue(...);
        
        // Calculate deviation
        uint256 deviation = abs(newValue - calculatedValue) / calculatedValue;
        
        // Revert if deviation too high
        if (deviation > _maxDeviationBps / 10000) {
            revert VaultValueDeviationTooHigh(newValue, calculatedValue, deviation);
        }
    }
    
    _vaultValue = newValue;  // ✅ Validated!
}
```

**Benefits**:
- Prevents admin from setting malicious values (>5% off)
- Catches errors in keeper bot calculations
- Provides on-chain audit trail
- Can be used even when flag=false

### Kodiak Islands Integration

#### What is Kodiak?

**Kodiak Islands** are concentrated liquidity vaults on Berachain (like Beefy or Yearn for Uniswap V3). They:
- Wrap Uniswap V3 positions into ERC20 LP tokens
- Auto-compound trading fees
- Auto-rebalance positions
- Provide single-sided liquidity support

#### Hook Pattern

We use a **hook pattern** to integrate with Kodiak without tight coupling:

```
┌──────────────┐         ┌───────────────────┐         ┌─────────────┐
│    Vault     │────────►│ KodiakVaultHook   │────────►│   Kodiak    │
│  (Senior/    │         │   (Adapter)       │         │   Island    │
│   Junior/    │         │                   │         │             │
│   Reserve)   │         │ • Swaps           │         │ • LP Tokens │
└──────────────┘         │ • LP management   │         │ • Balances  │
                         └───────────────────┘         └─────────────┘
```

**Benefits**:
- Vault doesn't need to know Kodiak details
- Easy to swap strategies (Aave, Compound, etc.)
- Isolated swap logic and aggregator management
- Can upgrade hook without upgrading vault

#### Deploy to Kodiak

**Admin-only function** to securely deploy vault funds to Kodiak:

```solidity
function deployToKodiak(
    uint256 amount,
    uint256 minLPTokens,      // Slippage protection
    address swapToToken0Aggregator,
    bytes calldata swapToToken0Data,
    address swapToToken1Aggregator,
    bytes calldata swapToToken1Data
) external onlyAdmin {
    // 1. Transfer stablecoins to hook
    _stablecoin.transfer(address(kodiakHook), amount);
    
    // 2. Hook swaps to balanced pair and mints LP
    kodiakHook.onAfterDepositWithSwaps(
        amount,
        swapToToken0Aggregator,
        swapToToken0Data,
        swapToToken1Aggregator,
        swapToToken1Data
    );
    
    // 3. Verify slippage protection
    uint256 lpReceived = kodiakHook.getIslandLPBalance() - lpBefore;
    require(lpReceived >= minLPTokens, "Slippage too high");
}
```

**Flow**:
1. Admin gets swap quote from Kodiak API (off-chain)
2. Kodiak API returns optimal swap routes and calldata
3. Admin calls `deployToKodiak()` with verified params
4. Vault transfers stablecoins to hook
5. Hook executes swaps via whitelisted aggregators
6. Hook mints Kodiak Island LP tokens
7. LP tokens held in hook, accounted in vault value

**Security**:
- Only admin can deploy
- Swap aggregators must be whitelisted
- Slippage protection (`minLPTokens`)
- Atomic operation (reverts on failure)

#### Sweep to Kodiak

**Convenience function** to deploy all idle stablecoin:

```solidity
function sweepToKodiak(
    uint256 minLPTokens,
    address swapToToken0Aggregator,
    bytes calldata swapToToken0Data,
    address swapToToken1Aggregator,
    bytes calldata swapToToken1Data
) external onlyAdmin {
    // Get all idle stablecoin
    uint256 idle = _stablecoin.balanceOf(address(this));
    
    // Deploy everything
    deployToKodiak(idle, minLPTokens, ...);
}
```

**Use Case**: After many user deposits, sweep accumulated "dust" into Kodiak to earn yield.

### Integration Across All Vaults

**All three vaults** (Senior, Junior, Reserve) have the oracle and Kodiak integration:

| Vault | Vault Value (Auto) | LP Price (Auto) | Kodiak Deployment |
|-------|-------------------|-----------------|-------------------|
| **Senior** | ✅ | ✅ (for rebase) | ✅ |
| **Junior** | ✅ | N/A (receives from Senior) | ✅ |
| **Reserve** | ✅ | N/A (receives from Senior) | ✅ |

**Why Junior/Reserve need it**:
- For their own deposit/withdrawal share calculations
- To deploy their own funds to Kodiak independently
- To calculate spillover value when receiving LP tokens

### Benefits Summary

#### 1. Trustlessness
- No reliance on off-chain keepers for price data
- Fully verifiable on-chain calculations
- Censorship-resistant operations

#### 2. Security
- Validation prevents admin manipulation
- Slippage protection on Kodiak deployments
- Whitelisted aggregators for swaps

#### 3. Flexibility
- Can switch between automatic/manual mode anytime
- Query calculated values even in manual mode
- Gradual migration path (test manual, then go automatic)

#### 4. Gas Efficiency
- On-chain calculation only when needed
- Can use stored values for better UX
- Batched operations supported

#### 5. Transparency
- All calculations auditable on-chain
- Deviation events logged
- Price history traceable

### Migration Guide

**Existing Vaults → Add Oracle System**

```solidity
// Step 1: Deploy with oracle support (already done!)
// All vaults now inherit oracle capabilities

// Step 2: Start in manual mode (safe)
vault.configureOracle(
    ISLAND,
    true,      // stablecoinIsToken0
    500,       // 5% max deviation
    true,      // enable validation
    false      // 👈 Start manual
);

// Step 3: Test validation
// Keeper continues setting values, but they're validated now
vault.setVaultValue(calculatedValue);  // ✅ Checked against on-chain

// Step 4: Test automatic queries
uint256 calc = vault.getCalculatedVaultValue();
uint256 stored = vault.getStoredVaultValue();
// Compare and verify accuracy

// Step 5: Switch to automatic when confident
vault.configureOracle(
    ISLAND,
    true,
    500,
    true,
    true       // 👈 Now automatic!
);

// Step 6: Simplify operations
vault.rebase();  // No parameters needed! 🎉
```

### Real-World Example

**USDC-BERA Pool on Kodiak (Berachain)**

```solidity
// Setup
seniorVault.setKodiakHook(KODIAK_HOOK_ADDRESS);
seniorVault.configureOracle(
    USDC_BERA_ISLAND,  // 0x123...
    true,              // USDC is token0
    500,               // 5% max deviation
    true,              // validation on
    true               // automatic mode ✅
);

// Admin deploys idle USDC to Kodiak
// (Gets swap quote from Kodiak API first)
seniorVault.deployToKodiak(
    100000e6,    // 100K USDC
    15000e18,    // Min 15K LP tokens (slippage protection)
    ROUTER_ADDRESS,
    swapData0,
    ROUTER_ADDRESS,
    swapData1
);

// User deposits
user.deposit(1000e6, userAddress);
// ✅ Shares calculated using on-chain vault value
// ✅ No keeper needed!

// Monthly rebase
admin.rebase();
// ✅ LP price calculated on-chain: $6.32
// ✅ Spillover LP transfers use correct amounts
// ✅ Fully trustless!
```

### Testing

See comprehensive test suite:
- `test/unit/LPPriceOracle.t.sol` - LP price calculation tests
- `test/unit/OracleIntegration.t.sol` - Oracle validation tests
- `test/unit/KodiakIntegration.t.sol` - Kodiak deployment tests
- `test/integration/KodiakOracleIntegration.t.sol` - End-to-end tests
- `test/e2e/KodiakOracleE2E.t.sol` - Full system tests

**Key Test Case** (100K USDC + 10K OTHER):
```solidity
function test_realPool_100K_USDC_10K_OTHER() public {
    // Setup mock Island
    island.setReserves(100000e6, 10000e18);  // 100K USDC, 10K OTHER
    island.setTotalSupply(31622.77e18);      // LP supply = sqrt(100K × 10K)
    
    // Calculate LP price
    uint256 lpPrice = LPPriceOracle.calculateLPPrice(address(island), true);
    
    // Verify: $6.32 ✅
    assertGt(lpPrice, 6.32e18);
    assertLt(lpPrice, 6.33e18);
}
```

---

## Mathematical Specification

### Core Formulas

**See `math_spec.md` for complete mathematical specification.**

#### User Balance (Rebase Index)
```
balance_i = shares_i × rebase_index
```

#### Dynamic APY Selection
```solidity
// Try 13% APY first
S_new_13 = S × 1.011050  // includes 2% performance fee
if (vault_value / S_new_13 >= 1.00) {
    use 13% APY
} else {
    // Try 12% APY
    S_new_12 = S × 1.010200
    if (vault_value / S_new_12 >= 1.00) {
        use 12% APY
    } else {
        // Use 11% APY (+ backstop if needed)
        S_new_11 = S × 1.009350
        use 11% APY
    }
}
```

#### Backing Ratio
```
R_senior = vault_value / total_supply
```

#### Three-Zone Logic
```solidity
if (R_senior > 1.10) {
    // ZONE 1: Profit Spillover
    excess = vault_value - (1.10 × total_supply)
    transfer_to_junior = excess × 0.80
    transfer_to_reserve = excess × 0.20
} else if (R_senior >= 1.00 && R_senior <= 1.10) {
    // ZONE 2: Healthy Buffer - NO ACTION
    // Most common state!
} else {
    // ZONE 3: Backstop
    deficit = (1.009 × total_supply) - vault_value
    pull_from_reserve = min(reserve_value, deficit)
    pull_from_junior = min(junior_value, deficit - pull_from_reserve)
}
```

### How Code Implements Math Spec

#### 1. Rebase Index Update (`RebaseLib.sol`)
```solidity
// Math Spec: I_new = I_old × (1 + r_selected × 1.02)
function updateIndex(uint256 currentIndex, uint256 selectedRate) 
    internal pure returns (uint256) 
{
    // selectedRate is one of: 10833, 10000, or 9167 (basis points)
    uint256 multiplier = 1e18 + (selectedRate * 102 / 10000);
    return (currentIndex * multiplier) / 1e18;
}
```

#### 2. Management Fee (`FeeLib.sol`)
```solidity
// Math Spec: F_mgmt = V_s × (0.01 / 12)
function calculateManagementFee(uint256 vaultValue) 
    internal pure returns (uint256) 
{
    return (vaultValue * 100) / 1200000; // 1% annual / 12 months
}
```

#### 3. Spillover Logic (`SpilloverLib.sol`)
```solidity
// Math Spec: E = V_s - (1.10 × S_new)
function calculateSpillover(uint256 vaultValue, uint256 newSupply) 
    internal pure returns (uint256 toJunior, uint256 toReserve) 
{
    uint256 target = (newSupply * 110) / 100;
    if (vaultValue > target) {
        uint256 excess = vaultValue - target;
        toJunior = (excess * 80) / 100;
        toReserve = excess - toJunior;
    }
}
```

#### 4. Backstop Logic (`UnifiedSeniorVault.sol`)
```solidity
// Math Spec: D = (1.009 × S_new) - V_s
//            X_r = min(V_r, D)
//            X_j = min(V_j, D - X_r)
function _executeBackstop(uint256 deficit, uint256 lpPrice) internal {
    // Pull from Reserve first (no cap)
    uint256 fromReserve = reserveVault.provideBackstop(deficit, lpPrice);
    uint256 remaining = deficit - fromReserve;
    
    if (remaining > 0) {
        // Pull from Junior if Reserve insufficient (no cap)
        uint256 fromJunior = juniorVault.provideBackstop(remaining, lpPrice);
    }
}
```

#### 5. LP Token Transfer (NEW)
```solidity
// During spillover, calculate LP tokens needed
function _transferToJunior(uint256 amountUSD, uint256 lpPrice) internal {
    // amountUSD = USD value to transfer (e.g., $10,000)
    // lpPrice = current LP token price (e.g., $6.32)
    uint256 lpTokens = (amountUSD * 1e18) / lpPrice;
    lpToken.transfer(address(juniorVault), lpTokens);
}

// During backstop, calculate LP tokens to receive
function _pullFromReserve(uint256 amountUSD, uint256 lpPrice) internal {
    // Reserve calculates and transfers LP tokens
    reserveVault.provideBackstop(amountUSD, lpPrice);
}
```

---

## Contract Deployments

### Polygon Mainnet (Chain ID: 137)

#### Vault Proxies (User-Facing Addresses)
```javascript
SENIOR_VAULT   = "0xc87086848c82089FE2Da4997Eac4EbF42591a579"
JUNIOR_VAULT   = "0xFf5462cECd8f9eC7eD737Ec0014449f559850f37"
RESERVE_VAULT  = "0x1bf9735Df7836a9e1f3EAdb53bD38D5f5BD3cd14"
```

#### Current Implementations
```javascript
SENIOR_IMPL  = "0x3F5369885125F420fD9de849451007bbd66e7377"
JUNIOR_IMPL  = "0xaDE61a9A8453fFE3F5032EFccD30990d2D145B1a"
RESERVE_IMPL = "0x6981c3057472D9d770784A1F13A706733f97A951"
```

#### Token Addresses
```javascript
// Mock tokens for testing
TSTUSDE = "0x0f5E6C7c2C559F3996923e41eC441Cd782fdb9d7"  // Test stablecoin
TSAIL   = "0x7F7eCd18978aB5Dc0767e84c8648ba96cD84D30e"  // Test SAIL

// Uniswap V2 LP
LP_TOKEN = "0xFC1569338f0efb7F7Dee9bd4AF62C9278C6C685C"
PAIR_ADDRESS = "0xFC1569338f0efb7F7Dee9bd4AF62C9278C6C685C"
```

#### Admin & Configuration
```javascript
ADMIN_ADDRESS = "0xE09883Cb3Fe2d973cEfE4BB28E3A3849E7e5f0A7"
REBASE_INTERVAL = 30 days (2592000 seconds)
```

### Configuration Files

**Backend Constants**: `wrapper/src/constants.ts`
```typescript
export const SENIOR_VAULT_ADDRESS = "0xc87086848c82089FE2Da4997Eac4EbF42591a579";
export const JUNIOR_VAULT_ADDRESS = "0xFf5462cECd8f9eC7eD737Ec0014449f559850f37";
export const RESERVE_VAULT_ADDRESS = "0x1bf9735Df7836a9e1f3EAdb53bD38D5f5BD3cd14";
export const LP_TOKEN_ADDRESS = "0xFC1569338f0efb7F7Dee9bd4AF62C9278C6C685C";
export const RPC_URL = "https://polygon-rpc.com";
```

**Frontend Config**: `simulation/src/config.ts`
```typescript
export const config = {
  apiUrl: 'http://localhost:3000',
  chainId: 137,
  networkName: 'Polygon',
  admin: {
    privateKey: process.env.VITE_ADMIN_PRIVATE_KEY,
    address: "0xE09883Cb3Fe2d973cEfE4BB28E3A3849E7e5f0A7"
  }
};
```

---

## Key Flows & Patterns

### 1. User Deposit Flow

**User deposits stablecoins → Gets vault tokens**

```
User
  ↓ deposits $1000 USDE
Senior Vault (ERC4626)
  ↓ calculates shares = $1000 / rebase_index
  ↓ mints shares to user
  ↓ stores USDE in vault
User receives snrUSD balance
  (balance = shares × rebase_index)
```

**Code Implementation**:
```solidity
// User calls deposit() on vault proxy
function deposit(uint256 assets, address receiver) public returns (uint256) {
    uint256 shares = previewDeposit(assets);
    _mint(receiver, shares);
    asset.transferFrom(msg.sender, address(this), assets);
    return shares;
}

// Balance calculated via rebase index
function balanceOf(address account) public view returns (uint256) {
    return (sharesOf[account] * rebaseIndex) / 1e18;
}
```

**Backend API**:
```typescript
POST /deposit-to-vault
{
  "privateKey": "0x...",
  "amountLPTokens": "100",
  "vaultType": "senior" | "junior" | "reserve"
}
```

### 1.5. Vault Value Synchronization ⚠️

**CRITICAL**: Vault values must be up-to-date before user deposits/withdrawals.

#### Why This Matters

The ERC4626 standard calculates shares based on the vault's reported `totalAssets()`:

```solidity
// Share calculation in ERC4626
shares = depositAmount × totalSupply / totalAssets()

// In our implementation
function totalAssets() public view returns (uint256) {
    return _vaultValue;  // Uses internal accounting, NOT actual token balance
}
```

#### The Problem

If `_vaultValue` is **out of sync** with actual holdings:

| Scenario | Impact | Example |
|----------|--------|---------|
| `_vaultValue` too low | Users get MORE shares than deserved | Vault has $1M actual, but `_vaultValue = $500K` → User deposits $100 and gets 2x the shares |
| `_vaultValue` too high | Users get FEWER shares (or **zero shares!**) | Vault has $0 actual, but `_vaultValue = $1M` → User deposits $100 and gets 0 shares |

**Real Bug We Fixed**:
```solidity
// Initial test setup had this problem:
_vaultValue = 1000e18  // Set via initialize
actual LP tokens = 0    // No tokens yet!

// When user deposits 100 tokens:
shares = 100 × 0 / 1000 = 0 shares  ❌ USER GETS NOTHING!
```

#### The Solution

**Keeper bot updates vault values regularly**:

```typescript
// Keeper bot runs every hour
async function keeperBot() {
    // 1. Calculate current USD value of all LP positions
    const seniorLPBalance = await lpToken.balanceOf(seniorVault);
    const lpPrice = await getLPTokenPrice(); // From Uniswap
    const seniorValueUSD = seniorLPBalance × lpPrice;
    
    // 2. Update on-chain vault value
    await seniorVault.setVaultValue(seniorValueUSD);
    
    // 3. Repeat for Junior and Reserve vaults
}
```

**When to Update**:
- ✅ Every 1-4 hours (regular sync)
- ✅ Before monthly rebase (critical!)
- ✅ After large LP position changes
- ✅ When backing ratio deviates > 1%

**Test Strategy** (See `test/unit/concrete/ConcreteJuniorVault.t.sol`):
```solidity
// Helper function for tests that need backstop/spillover
function _initializeVaultWithValue() internal {
    vm.prank(keeper);
    vault.setVaultValue(INITIAL_VALUE);  // Sync vault value
    lpToken.mint(address(vault), INITIAL_VALUE);  // Actual tokens
    vault.addWhitelistedLPToken(address(lpToken));  // Enable transfers
}

// Tests start with _vaultValue = 0 to mimic fresh vault
// Then explicitly set value before operations that need it
```

**Production Best Practice**:
```solidity
// Add staleness protection
modifier notStale() {
    require(
        block.timestamp - lastVaultValueUpdate < 24 hours,
        "Vault value stale - deposits/withdrawals paused"
    );
    _;
}

function deposit(uint256 assets) public notStale returns (uint256) {
    // ... deposit logic
}
```

**See Also**:
- Section 3: "Rebase Flow" (lines 392-491) - Updates all vault values before rebase
- Section 6: "Real-World Solutions" - Keeper bot architecture

### 2. Vault Investment Flow (Admin Only)

**Vault invests in LP → Earns yield**

```
Admin calls investVaultInLP()
  ↓
Vault transfers stablecoins to Uniswap
  ↓ addLiquidity(TSTUSDE, TSAIL)
Vault receives LP tokens
  ↓ stores LP tokens
Vault value increases over time
  (via LP token appreciation + trading fees)
```

**Code Implementation**:
```solidity
function investInLP(uint256 amount, address lpProtocol) external onlyAdmin {
    // Approve tokens
    asset.approve(lpProtocol, amount);
    
    // Add liquidity (gets LP tokens back)
    IUniswapV2Router(lpProtocol).addLiquidity(...);
    
    // Update vault state
    emit Invested(amount, lpProtocol);
}
```

### 3. Rebase Flow (Admin Monthly)

**The most critical operation - updates all vault values and executes rebase**

```
Admin triggers rebase
  ↓
Backend fetches LP token price ($6.32)
  ↓
1️⃣ Update Senior vault value
   (LP holdings × LP price)
  ↓
2️⃣ Update Junior vault value
  ↓
3️⃣ Update Reserve vault value
  ↓
4️⃣ Execute Senior rebase(lpPrice)
  ├─ Calculate dynamic APY (13% → 12% → 11%)
  ├─ Deduct management fee
  ├─ Calculate new supply (with 2% performance fee)
  ├─ Determine zone (1, 2, or 3)
  │
  ├─ IF Zone 1 (>110%): Profit Spillover
  │   ├─ Calculate excess = value - (110% × supply)
  │   ├─ Transfer 80% LP tokens to Junior
  │   ├─ Transfer 20% LP tokens to Reserve
  │   └─ Senior returns to exactly 110%
  │
  ├─ IF Zone 2 (100-110%): No Action
  │   └─ Everyone keeps their value
  │
  └─ IF Zone 3 (<100%): Backstop
      ├─ Calculate deficit = (100.9% × supply) - value
      ├─ Pull LP tokens from Reserve (no cap!)
      ├─ If insufficient, pull from Junior (no cap!)
      └─ Senior restored to 100.9%
  ↓
Update rebase index
  (users' balances auto-increase)
```

**Code Implementation**:

```solidity
// Entry point - called by admin
function rebase(uint256 lpPrice) external onlyAdmin {
    require(canRebase(), "Too soon");
    
    // Step 1: Calculate fees
    uint256 vaultValue = getVaultValue();
    uint256 mgmtFee = calculateManagementFee(vaultValue);
    uint256 netValue = vaultValue - mgmtFee;
    
    // Step 2: Dynamic APY selection
    uint256 currentSupply = totalSupply();
    (uint256 selectedRate, uint256 newSupply) = 
        selectDynamicAPY(netValue, currentSupply);
    
    // Step 3: Calculate backing ratio
    uint256 backingRatio = (netValue * 1e18) / newSupply;
    
    // Step 4: Three-zone decision
    if (backingRatio > 1.10e18) {
        // Zone 1: Profit spillover
        _executeProfitSpillover(netValue, newSupply, lpPrice);
    } else if (backingRatio >= 1.00e18) {
        // Zone 2: No action
    } else {
        // Zone 3: Backstop
        _executeBackstop(netValue, newSupply, lpPrice);
    }
    
    // Step 5: Update rebase index
    rebaseIndex = (rebaseIndex * (1e18 + selectedRate * 102 / 10000)) / 1e18;
    lastRebaseTime = block.timestamp;
    
    emit RebaseExecuted(selectedRate, newSupply, backingRatio);
}
```

**Backend Flow** (`wrapper/src/utils.ts`):

```typescript
export const updateAllVaultsAndRebase = async (adminPrivateKey: string) => {
  // 1. Get LP price from Uniswap
  const lpPrice = await getLPTokenPrice();
  
  // 2. Update all vault values
  await setVaultValue('senior', seniorValue, adminPrivateKey);
  await setVaultValue('junior', juniorValue, adminPrivateKey);
  await setVaultValue('reserve', reserveValue, adminPrivateKey);
  
  // 3. Execute rebase with LP price
  await seniorVault.rebase(lpPrice, {
    gasLimit: 800000,
    maxFeePerGas: ethers.parseUnits('300', 'gwei'),
    maxPriorityFeePerGas: ethers.parseUnits('50', 'gwei')
  });
};
```

**Frontend Trigger** (`simulation/src/components/Dashboard.tsx`):

```typescript
const handleRebase = async () => {
  try {
    setRebaseStatus('Updating vault values...');
    const result = await apiService.updateAllVaultsAndRebase(adminPrivateKey);
    setRebaseStatus('✅ Rebase complete!');
  } catch (error) {
    setRebaseStatus(`❌ Error: ${error.message}`);
  }
};
```

### 4. Withdrawal Flow

**User withdraws → Receives stablecoins**

```
User initiates withdrawal
  ↓ calls withdraw($500)
Vault calculates shares to burn
  shares = $500 / rebase_index
  ↓
Check cooldown (7 days)
  ↓ if < 7 days: 5% penalty
  ↓ if ≥ 7 days: no penalty
Burn shares from user
  ↓
Check vault liquidity
  ↓ if sufficient liquid USDE: transfer
  ↓ if insufficient: exit LP position
Transfer USDE to user
```

**Code Implementation**:
```solidity
function withdraw(uint256 assets, address receiver, address owner) 
    public returns (uint256) 
{
    uint256 shares = previewWithdraw(assets);
    
    // Check cooldown
    if (block.timestamp - cooldownStart[owner] < COOLDOWN_PERIOD) {
        // Apply 5% penalty
        assets = (assets * 95) / 100;
    }
    
    _burn(owner, shares);
    asset.transfer(receiver, assets);
    return shares;
}
```

### 5. Spillover Flow (Zone 1)

**Senior backing > 110% → Share excess with Junior/Reserve**

```
Rebase detects backing > 110%
  ↓
Calculate excess value
  excess = vault_value - (1.10 × supply)
  ↓
Calculate LP tokens to transfer
  lp_to_junior = (excess × 0.80) / lp_price
  lp_to_reserve = (excess × 0.20) / lp_price
  ↓
Transfer LP tokens
  ├─ 80% LP tokens → Junior vault
  └─ 20% LP tokens → Reserve vault
  ↓
Senior returns to exactly 110% backing
```

**Code Implementation**:
```solidity
function _executeProfitSpillover(
    uint256 vaultValue, 
    uint256 newSupply,
    uint256 lpPrice
) internal {
    uint256 target = (newSupply * 110) / 100;
    uint256 excess = vaultValue - target;
    
    // Calculate USD amounts
    uint256 toJuniorUSD = (excess * 80) / 100;
    uint256 toReserveUSD = excess - toJuniorUSD;
    
    // Transfer LP tokens based on USD value
    _transferToJunior(toJuniorUSD, lpPrice);
    _transferToReserve(toReserveUSD, lpPrice);
}

function _transferToJunior(uint256 amountUSD, uint256 lpPrice) internal {
    // Convert USD to LP tokens
    uint256 lpTokens = (amountUSD * 1e18) / lpPrice;
    lpToken.transfer(address(juniorVault), lpTokens);
    juniorVault.receiveSpillover(lpTokens);
}
```

### 6. Backstop Flow (Zone 3)

**Senior backing < 100% → Pull funds from Reserve/Junior**

```
Rebase detects backing < 100%
  ↓
Calculate deficit to restore to 100.9%
  deficit = (1.009 × supply) - vault_value
  ↓
WATERFALL: Reserve → Junior (NO CAPS!)
  ↓
1. Pull from Reserve first
   amount_from_reserve = min(reserve_value, deficit)
   ↓ Reserve calculates LP tokens = amount / lp_price
   ↓ Reserve transfers LP tokens to Senior
   ↓
2. If deficit remains, pull from Junior
   remaining = deficit - amount_from_reserve
   amount_from_junior = min(junior_value, remaining)
   ↓ Junior calculates LP tokens
   ↓ Junior transfers LP tokens to Senior
   ↓
Senior restored to 100.9% backing
```

**Code Implementation**:
```solidity
function _executeBackstop(
    uint256 vaultValue,
    uint256 newSupply,
    uint256 lpPrice
) internal {
    uint256 target = (newSupply * 1009) / 1000; // 100.9%
    uint256 deficit = target - vaultValue;
    
    // Pull from Reserve first (no cap!)
    uint256 fromReserve = reserveVault.provideBackstop(deficit, lpPrice);
    uint256 remaining = deficit - fromReserve;
    
    if (remaining > 0) {
        // Pull from Junior if needed (no cap!)
        uint256 fromJunior = juniorVault.provideBackstop(remaining, lpPrice);
    }
}
```

**In Reserve/Junior Vaults**:
```solidity
function provideBackstop(uint256 amountUSD, uint256 lpPrice) 
    external onlySeniorVault returns (uint256) 
{
    // Calculate how much we can provide
    uint256 available = getVaultValue();
    uint256 toProvide = available < amountUSD ? available : amountUSD;
    
    // Calculate LP tokens to transfer
    uint256 lpTokens = (toProvide * 1e18) / lpPrice;
    
    // Transfer LP tokens to Senior
    lpToken.transfer(msg.sender, lpTokens);
    
    return toProvide;
}
```

---

## API Reference

### Backend Server (`wrapper/`)

**Base URL**: `http://localhost:3000`

#### Health & System Info

```http
GET /health
Response: { status: "ok", timestamp: "..." }
```

#### Pool & Price Data

```http
GET /reserves
Response: {
  success: true,
  data: {
    tsailReserve: "1000000",
    tusdReserve: "950000",
    pairAddress: "0x..."
  }
}

GET /lp-price
Response: {
  success: true,
  data: {
    lpTokenPrice: "6.3254",
    tsailPrice: "0.95"
  }
}
```

#### Vault Data

```http
GET /vaults/total-supply
Response: {
  success: true,
  data: {
    seniorVault: { supply: "1000000" },
    juniorVault: { supply: "500000" },
    reserveVault: { supply: "300000" }
  }
}

GET /vaults/value
Response: {
  success: true,
  data: {
    seniorVault: { value: "1050000" },
    juniorVault: { value: "525000" },
    reserveVault: { value: "315000" }
  }
}

GET /vaults/lp-holdings
Response: {
  success: true,
  data: {
    seniorVault: { lpTokens: "150000", valueUSD: "949000" },
    juniorVault: { lpTokens: "80000", valueUSD: "506000" },
    reserveVault: { lpTokens: "50000", valueUSD: "316000" }
  }
}
```

#### Vault Metrics

```http
GET /senior/backing-ratio
Response: {
  success: true,
  data: {
    seniorVault: {
      backingRatio: "105.23",
      onChainValue: "1050000",
      supply: "1000000"
    }
  }
}

GET /junior/token-price
Response: {
  success: true,
  data: {
    juniorVault: {
      tokenPrice: "1.05",  // Unstaking ratio
      supply: "500000",
      value: "525000"
    }
  }
}

GET /reserve/token-price
Response: {
  success: true,
  data: {
    reserveVault: {
      tokenPrice: "1.05",
      supply: "300000",
      value: "315000"
    }
  }
}
```

#### User Operations

```http
POST /stake-and-invest-complete
Body: {
  "userPrivateKey": "0x...",
  "adminPrivateKey": "0x...",
  "vaultType": "senior",
  "amountTSTUSDE": "1000",
  "slippageTolerance": 0.5
}
Response: {
  success: true,
  txHash: "0x...",
  shares: "952.38"
}

POST /deposit-to-vault
Body: {
  "privateKey": "0x...",
  "amountLPTokens": "100",
  "vaultType": "senior"
}

POST /invest-vault-in-lp
Body: {
  "privateKey": "0x...",  // Admin only
  "vaultType": "senior",
  "lpProtocolAddress": "0x...",
  "amount": "10000"
}
```

#### Admin Operations

```http
POST /vault/update-value
Body: {
  "privateKey": "0x...",  // Admin
  "profitBps": 500,  // 5% profit
  "vaultType": "senior"
}

POST /vault/rebase
Body: {
  "privateKey": "0x..."  // Admin
}

POST /vault/update-and-rebase
Body: {
  "privateKey": "0x..."  // Admin
}
Response: {
  success: true,
  updates: [...],
  rebaseTx: "0x...",
  selectedAPY: "13%",
  zone: 2
}
```

---

## Frontend Integration

### Structure (`simulation/`)

```
simulation/
├── src/
│   ├── components/
│   │   ├── Dashboard.tsx       # Main vault metrics display
│   │   ├── BotCard.tsx         # Bot simulation cards
│   │   └── TransactionFeed.tsx # Live transaction feed
│   ├── services/
│   │   └── api.ts             # Backend API client
│   ├── config.ts              # Configuration
│   └── App.tsx                # Main app component
```

### Key Components

#### Dashboard Component

Displays:
- Senior backing ratio (on-chain vs. calculated)
- Junior/Reserve unstaking ratios
- LP holdings for all vaults
- Admin rebase controls

```typescript
// Fetching vault data
const fetchVaultData = async () => {
  const [backing, supply, lpHoldings] = await Promise.all([
    apiService.getSeniorBackingRatio(),
    apiService.getVaultsTotalSupply(),
    apiService.getVaultsLPHoldings()
  ]);
  
  setBackingRatio(backing.data.seniorVault.backingRatio);
  setLPHoldings(lpHoldings.data);
};
```

#### Bot Simulation

Two bots simulate user behavior:
- **Whale**: Large deposits (5000-10000 USDE)
- **Farmer**: Smaller deposits (500-2000 USDE)

```typescript
const simulateBot = async (bot) => {
  const amount = generateRandomAmount(bot.type);
  await apiService.stakeAndInvestComplete(
    bot.privateKey,
    ADMIN_PRIVATE_KEY,
    'senior',
    amount
  );
};
```

---

## Development Workflow

### Setup

```bash
# 1. Clone repository
git clone <repo-url>
cd LiquidRoyaltyContracts

# 2. Install dependencies
forge install              # Solidity dependencies
cd wrapper && npm install  # Backend
cd simulation && npm install  # Frontend

# 3. Set up environment variables
cp .env.example .env
# Edit .env with your private keys and RPC URLs
```

### Environment Variables

```bash
# .env (root)
PRIVATE_KEY=0x...                    # Deployer private key
POLYGON_RPC_URL=https://polygon-rpc.com

# wrapper/.env
ADMIN_PRIVATE_KEY=0x...
POLYGON_RPC_URL=https://polygon-rpc.com

# simulation/.env
VITE_API_URL=http://localhost:3000
VITE_ADMIN_PRIVATE_KEY=0x...
```

### Running the System

**1. Start Backend**
```bash
cd wrapper
npm run dev
# Server runs on http://localhost:3000
```

**2. Start Frontend**
```bash
cd simulation
npm run dev
# Opens browser at http://localhost:5173
```

**3. Access Frontend**
- Open `http://localhost:5173`
- View vault metrics, perform operations
- Use admin controls for rebase

### Local Development Cycle

```bash
# 1. Make contract changes
vim src/abstract/UnifiedSeniorVault.sol

# 2. Compile contracts
forge build

# 3. Run tests
forge test -vvv

# 4. Deploy new implementation
forge script script/DeployLPRebaseImplementations.s.sol --rpc-url $POLYGON_RPC_URL --broadcast

# 5. Upgrade proxy
forge script script/UpgradeLPRebaseProxies.s.sol --rpc-url $POLYGON_RPC_URL --broadcast

# 6. Restart backend (auto-restarts with nodemon)
# 7. Refresh frontend
```

---

## Testing

### Unit Tests

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-path test/unit/UnifiedSeniorVault.t.sol

# Run with verbosity
forge test -vvv

# Run with gas reporting
forge test --gas-report
```

### Test Structure

```
test/
├── unit/                    # Unit tests for individual contracts
│   ├── UnifiedSeniorVault.t.sol
│   ├── ConcreteJuniorVault.t.sol
│   ├── FeeLib.t.sol
│   └── RebaseLib.t.sol
├── e2e/                     # End-to-end integration tests
│   ├── FullRebaseCycleE2E.t.sol
│   ├── SpilloverE2E.t.sol
│   └── BackstopE2E.t.sol
```

### Writing Tests

```solidity
// test/unit/MyVault.t.sol
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/concrete/UnifiedConcreteSeniorVault.sol";

contract MyVaultTest is Test {
    UnifiedConcreteSeniorVault vault;
    
    function setUp() public {
        vault = new UnifiedConcreteSeniorVault();
        vault.initialize(...);
    }
    
    function testRebaseWithProfitSpillover() public {
        // Arrange
        vm.prank(admin);
        vault.setVaultValue(1150000e18);
        
        // Act
        uint256 lpPrice = 6.32e18;
        vault.rebase(lpPrice);
        
        // Assert
        assertEq(vault.getBackingRatio(), 110e16); // 110%
    }
}
```

### Manual Testing via Cast

```bash
# Check vault value
cast call $SENIOR_VAULT "getVaultValue()" --rpc-url $POLYGON_RPC_URL

# Check backing ratio
cast call $SENIOR_VAULT "getBackingRatio()" --rpc-url $POLYGON_RPC_URL

# Execute rebase (as admin)
LP_PRICE="6325400000000000000"  # $6.3254 in wei
cast send $SENIOR_VAULT "rebase(uint256)" $LP_PRICE \
  --rpc-url $POLYGON_RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY \
  --gas-limit 800000
```

---

## Deployment & Upgrades

### Deploying New Implementations

```bash
# 1. Compile contracts
forge build

# 2. Deploy new implementations
forge script script/DeployLPRebaseImplementations.s.sol \
  --rpc-url $POLYGON_RPC_URL \
  --broadcast \
  --verify

# Output:
# Senior Impl:  0x3F5369885125F420fD9de849451007bbd66e7377
# Junior Impl:  0xaDE61a9A8453fFE3F5032EFccD30990d2D145B1a
# Reserve Impl: 0x6981c3057472D9d770784A1F13A706733f97A951
```

### Upgrading Proxies

```bash
# 1. Update script/UpgradeLPRebaseProxies.s.sol with new implementation addresses
vim script/UpgradeLPRebaseProxies.s.sol

# 2. Run upgrade script
forge script script/UpgradeLPRebaseProxies.s.sol \
  --rpc-url $POLYGON_RPC_URL \
  --broadcast

# 3. Verify upgrade
cast call $SENIOR_VAULT "implementation()" --rpc-url $POLYGON_RPC_URL
```

### Deploying Fresh Vaults (Complete Reset)

```bash
# 1. Deploy new proxy contracts
forge script script/DeployVaults.s.sol \
  --rpc-url $POLYGON_RPC_URL \
  --broadcast

# 2. Configure vault cross-references
bash configure-vault-links.sh

# 3. Whitelist LP token in all vaults
bash whitelist-correct-lp.sh

# 4. Update backend constants
vim wrapper/src/constants.ts
# Update SENIOR_VAULT_ADDRESS, JUNIOR_VAULT_ADDRESS, RESERVE_VAULT_ADDRESS

# 5. Restart backend
cd wrapper && npm run dev
```

### Generating ABIs

```bash
# After deploying or upgrading contracts
bash src/scripts/generate_abis.sh

# Copies ABIs to:
# - abi/
# - wrapper/abi/
```

---

## Common Operations

### As Admin

#### 1. Perform Monthly Rebase

**Via Frontend**:
1. Open `http://localhost:5173`
2. Navigate to "Admin Rebase" section
3. Enter admin private key
4. Click "Update All Vaults & Rebase"

**Via Backend API**:
```bash
curl -X POST http://localhost:3000/vault/update-and-rebase \
  -H "Content-Type: application/json" \
  -d '{"privateKey":"0x..."}'
```

**Via Cast (Direct)**:
```bash
LP_PRICE="6325400000000000000"
cast send $SENIOR_VAULT "rebase(uint256)" $LP_PRICE \
  --rpc-url $POLYGON_RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY \
  --gas-limit 800000
```

#### 2. Update Vault Value (Manual)

```bash
# Update Senior vault to $1,050,000
cast send $SENIOR_VAULT "setVaultValue(uint256)" "1050000000000000000000000" \
  --rpc-url $POLYGON_RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY
```

#### 3. Whitelist LP Token

```bash
cast send $SENIOR_VAULT "addWhitelistedLP(address)" $LP_TOKEN \
  --rpc-url $POLYGON_RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY
```

#### 4. Invest Vault in LP

```bash
# Via backend
curl -X POST http://localhost:3000/invest-vault-in-lp \
  -H "Content-Type: application/json" \
  -d '{
    "privateKey":"0x...",
    "vaultType":"senior",
    "lpProtocolAddress":"0x...",
    "amount":"10000"
  }'
```

### As User

#### 1. Deposit to Vault

```typescript
// Via frontend/backend
const result = await apiService.stakeAndInvestComplete(
  userPrivateKey,
  adminPrivateKey,
  'senior',
  '1000'  // $1000
);
```

#### 2. Check Balance

```bash
cast call $SENIOR_VAULT "balanceOf(address)" $USER_ADDRESS \
  --rpc-url $POLYGON_RPC_URL
```

#### 3. Initiate Cooldown

```solidity
// User calls on vault contract
function initiateCooldown() external {
    cooldownStart[msg.sender] = block.timestamp;
}
```

#### 4. Withdraw (After Cooldown)

```solidity
function withdraw(uint256 amount) external {
    require(block.timestamp - cooldownStart[msg.sender] >= 7 days);
    _withdraw(amount, msg.sender, msg.sender);
}
```

---

## Troubleshooting

### Common Issues

#### 1. Backend Compilation Errors

**Problem**: `SyntaxError: Identifier 'X' has already been declared`

**Solution**: Check for duplicate code blocks in `wrapper/src/utils.ts` or `wrapper/src/index.ts`
```bash
cd wrapper
# Kill all Node processes
pkill -f node
# Restart
npm run dev
```

#### 2. Frontend Build Errors

**Problem**: `Transform failed with 1 error: ERROR: Unexpected "}"`

**Solution**: Check `simulation/src/config.ts` and `simulation/src/services/api.ts` for syntax errors
```bash
cd simulation
npm run dev
```

#### 3. Transaction Reverts with Empty Data

**Problem**: `transaction execution reverted (data=null)`

**Causes**:
- Contract proxy not pointing to correct implementation
- Admin not set correctly
- LP token not whitelisted
- Insufficient gas

**Debug**:
```bash
# Check implementation
cast call $SENIOR_VAULT "implementation()" --rpc-url $POLYGON_RPC_URL

# Check admin
cast call $SENIOR_VAULT "admin()" --rpc-url $POLYGON_RPC_URL

# Check LP whitelist
cast call $SENIOR_VAULT "isLPWhitelisted(address)" $LP_TOKEN --rpc-url $POLYGON_RPC_URL

# Try with higher gas
cast send ... --gas-limit 1000000
```

#### 4. Rebase Transaction Fails

**Problem**: Rebase fails even with correct setup

**Checklist**:
1. ✅ All vaults have updated values?
2. ✅ LP price is current and in wei (18 decimals)?
3. ✅ Vaults have LP tokens to transfer?
4. ✅ Senior vault has correct Junior/Reserve addresses?
5. ✅ Sufficient gas (use 800000)?

```bash
# Verify vault links
cast call $SENIOR_VAULT "juniorVault()" --rpc-url $POLYGON_RPC_URL
cast call $SENIOR_VAULT "reserveVault()" --rpc-url $POLYGON_RPC_URL
```

#### 5. Backend Can't Connect to RPC

**Problem**: `Error: could not detect network`

**Solution**: Check RPC URL and rate limits
```typescript
// wrapper/src/constants.ts
export const RPC_URL = "https://polygon.llamarpc.com"; // Try alternative RPC
```

#### 6. Nodemon Keeps Crashing

**Problem**: `[nodemon] app crashed - waiting for file changes`

**Solution**:
```bash
cd wrapper
# Check nodemon.json syntax
cat nodemon.json
# Should be valid JSON with no extra braces

# Kill all instances
pkill -f nodemon
# Restart
npm run dev
```

### Debugging Tips

**1. Use Cast for Direct Queries**
```bash
# Check any public variable
cast call $CONTRACT "variableName()" --rpc-url $RPC_URL

# Check any public function
cast call $CONTRACT "functionName(params)" --rpc-url $RPC_URL
```

**2. Check Transaction Traces**
```bash
# Get transaction receipt
cast receipt $TX_HASH --rpc-url $POLYGON_RPC_URL

# Get detailed logs
cast receipt $TX_HASH --rpc-url $POLYGON_RPC_URL -v
```

**3. Test in Isolation**
```solidity
// Write minimal test case
function testIsolatedIssue() public {
    // Reproduce exact scenario
    vault.rebase(lpPrice);
}
```

**4. Enable Debug Logging**
```typescript
// wrapper/src/utils.ts
console.log('🔍 DEBUG:', {
  vaultValue,
  lpPrice,
  backingRatio
});
```

---

## Additional Resources

### Documentation
- **Math Specification**: See `math_spec.md` for complete mathematical details
- **Solidity Docs**: https://docs.soliditylang.org/
- **Foundry Book**: https://book.getfoundry.sh/
- **ERC4626 Standard**: https://eips.ethereum.org/EIPS/eip-4626

### Smart Contract Patterns
- **UUPS Proxy**: https://eips.ethereum.org/EIPS/eip-1822
- **Rebase Tokens**: Study Ampleforth, Olympus DAO
- **Structured Tranches**: Barnbridge, Saffron Finance

### Network Resources
- **Polygon RPC**: https://polygon-rpc.com
- **Polygon Explorer**: https://polygonscan.com
- **Gas Tracker**: https://polygonscan.com/gastracker

---

## Quick Reference Card

### Deployed Addresses (Polygon Mainnet)
```
Senior:  0xc87086848c82089FE2Da4997Eac4EbF42591a579
Junior:  0xFf5462cECd8f9eC7eD737Ec0014449f559850f37
Reserve: 0x1bf9735Df7836a9e1f3EAdb53bD38D5f5BD3cd14
LP Token: 0xFC1569338f0efb7F7Dee9bd4AF62C9278C6C685C
Admin:   0xE09883Cb3Fe2d973cEfE4BB28E3A3849E7e5f0A7
```

### Key Commands
```bash
# Backend
cd wrapper && npm run dev

# Frontend  
cd simulation && npm run dev

# Compile contracts
forge build

# Run tests
forge test -vvv

# Deploy implementation
forge script script/DeployLPRebaseImplementations.s.sol --rpc-url $POLYGON_RPC_URL --broadcast

# Upgrade proxy
forge script script/UpgradeLPRebaseProxies.s.sol --rpc-url $POLYGON_RPC_URL --broadcast

# Manual rebase
cast send $SENIOR_VAULT "rebase(uint256)" "6325400000000000000" \
  --rpc-url $POLYGON_RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY \
  --gas-limit 800000
```

### Three Operating Zones
```
>110%    : Profit spillover (Junior 80%, Reserve 20%)
100-110% : Healthy buffer (NO ACTION) ← Most common
<100%    : Backstop (Reserve → Junior → Senior)
```

### Dynamic APY Selection
```
Try 13% first (greedy)
  ↓ if backing < 100%, try 12%
  ↓ if backing < 100%, use 11% (+ backstop if needed)
Always maximize APY while maintaining peg!
```

---

## Support & Contact

For questions, issues, or contributions:
- Create an issue in the repository
- Contact the dev team
- Review `math_spec.md` for mathematical details

---

**Last Updated**: November 12, 2025
**Version**: 3.0.0 (On-Chain Oracle & Kodiak Integration)

