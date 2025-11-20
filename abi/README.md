# 📦 ABI Directory

This directory contains all JSON ABIs for the Senior Tranche Protocol contracts.

---

## 🏦 **Deployable Contracts (Use These in Production)**

### Vault Implementations
- **`UnifiedConcreteSeniorVault.json`** (50 KB) - Senior vault (snrUSD rebasing token)
  - Proxy: `0x65691bd1972e906459954306aDa0f622a47d4744`
  - Implementation: `0x19E4440225dcCe37855916dc338A46b1966b689d`
  - Features: Rebase, cooldown, pending LP deposits

- **`ConcreteJuniorVault.json`** (56 KB) - Junior vault (jnrUSD ERC4626)
  - Proxy: `0x3A1b3b300dEE06Caf0b691F1771d1Aa26d70B067`
  - Implementation: `0xa0729705e1A1fD4a7C2C450AaB69cc25d30B8061`
  - Features: ERC4626, spillover, pending LP deposits

- **`ConcreteReserveVault.json`** (55 KB) - Reserve vault (resUSD ERC4626)
  - Proxy: `0x2C75291479788C568A6750185CaDedf43aBFC553`
  - Implementation: `0x3Bf2a71e9226867fc5503e6bAA3E9bF31a1D2676`
  - Features: ERC4626, backstop, token management (6 functions)

### Hooks
- **`KodiakVaultHook.json`** (16 KB) - LP management for Kodiak Island
  - Senior Hook: `0x949Ba11180BDF15560D7Eba9864c929FA4a32bA2`
  - Junior Hook: `0x9e7753A490628C65219c467A792b708A89209168`
  - Reserve Hook: `0x88FA91FCF1771AC3C07b3f6684239A4A0B234299`

---

## 📋 **Interfaces (For Type Safety)**

- **`ISeniorVault.json`** (13 KB) - Senior vault interface
- **`IVault.json`** (3.8 KB) - Base vault interface
- **`IJuniorVault.json`** (7.3 KB) - Junior vault interface
- **`IReserveVault.json`** (8.3 KB) - Reserve vault interface
- **`IKodiakVaultHook.json`** (3.4 KB) - Hook interface
- **`IKodiakIsland.json`** (6.6 KB) - Kodiak Island interface
- **`IKodiakIslandRouter.json`** (5.5 KB) - Kodiak Router interface

---

## 🏗️ **Abstract Contracts (For Understanding Inheritance)**

- **`BaseVault.json`** (46 KB) - Core ERC4626 logic (inherited by Junior/Reserve)
- **`UnifiedSeniorVault.json`** (49 KB) - Senior vault base
- **`JuniorVault.json`** (55 KB) - Junior vault abstract (adds pending LP deposits)
- **`ReserveVault.json`** (55 KB) - Reserve vault abstract (adds token management)

---

## 🪙 **Token Standards**

- **`ERC20.json`** (5.5 KB) - Standard ERC20 interface
- **`MockERC20.json`** (6.6 KB) - Mock ERC20 for testing

---

## 📊 **Feature Comparison**

| Contract | Size | Pending LP Deposits | Token Management | Special Features |
|----------|------|-------------------|------------------|-----------------|
| **Senior** | 50 KB | ✅ YES | ❌ No | Rebase, 7-day cooldown, 20% early penalty |
| **Junior** | 56 KB | ✅ YES | ❌ No | ERC4626, spillover receiver, management fee |
| **Reserve** | 55 KB | ❌ **NO** | ✅ **6 functions** | Backstop provider, WBTC management |

---

## 🔧 **Usage in Frontend**

### Viem (Recommended)
```typescript
import seniorVaultABI from './abi/UnifiedConcreteSeniorVault.json';
import juniorVaultABI from './abi/ConcreteJuniorVault.json';
import reserveVaultABI from './abi/ConcreteReserveVault.json';
import kodiakHookABI from './abi/KodiakVaultHook.json';

// Use with Viem
import { createPublicClient, http } from 'viem';
import { berachain } from 'viem/chains';

const client = createPublicClient({
  chain: berachain,
  transport: http('https://rpc.berachain.com')
});

const seniorVault = {
  address: '0x65691bd1972e906459954306aDa0f622a47d4744',
  abi: seniorVaultABI,
};

// Read vault value
const vaultValue = await client.readContract({
  ...seniorVault,
  functionName: 'vaultValue',
});
```

### Ethers.js
```javascript
import { ethers } from 'ethers';
import seniorVaultABI from './abi/UnifiedConcreteSeniorVault.json';

const provider = new ethers.JsonRpcProvider('https://rpc.berachain.com');
const seniorVault = new ethers.Contract(
  '0x65691bd1972e906459954306aDa0f622a47d4744',
  seniorVaultABI,
  provider
);

const vaultValue = await seniorVault.vaultValue();
```

### Web3.js
```javascript
import Web3 from 'web3';
import seniorVaultABI from './abi/UnifiedConcreteSeniorVault.json';

const web3 = new Web3('https://rpc.berachain.com');
const seniorVault = new web3.eth.Contract(
  seniorVaultABI,
  '0x65691bd1972e906459954306aDa0f622a47d4744'
);

const vaultValue = await seniorVault.methods.vaultValue().call();
```

---

## 🔑 **Key Functions by Contract**

### Senior Vault (UnifiedConcreteSeniorVault)
```solidity
// Deposits & Withdrawals
function deposit(uint256 assets, address receiver) returns (uint256 shares);
function withdraw(uint256 assets, address receiver, address owner) returns (uint256 shares);
function initiateCooldown();

// Pending LP Deposits (NEW!)
function depositLP(address lpToken, uint256 amount) returns (uint256 depositId);
function approveLPDeposit(uint256 depositId, uint256 lpPrice); // Admin
function rejectLPDeposit(uint256 depositId, string reason); // Admin
function cancelPendingDeposit(uint256 depositId); // User
function claimExpiredDeposit(uint256 depositId); // Anyone
function getPendingDeposit(uint256 depositId) returns (...);
function getUserDepositIds(address user) returns (uint256[]);

// Rebase
function rebase(uint256 lpPrice); // Admin

// View Functions
function balanceOf(address account) returns (uint256);
function totalSupply() returns (uint256);
function vaultValue() returns (uint256);
function backingRatio() returns (uint256);
```

### Junior Vault (ConcreteJuniorVault)
```solidity
// ERC4626 Standard
function deposit(uint256 assets, address receiver) returns (uint256 shares);
function withdraw(uint256 assets, address receiver, address owner) returns (uint256 shares);
function mint(uint256 shares, address receiver) returns (uint256 assets);
function redeem(uint256 shares, address receiver, address owner) returns (uint256 assets);

// Pending LP Deposits (NEW!)
function depositLP(address lpToken, uint256 amount) returns (uint256 depositId);
function approveLPDeposit(uint256 depositId, uint256 lpPrice); // Admin
function rejectLPDeposit(uint256 depositId, string reason); // Admin
function cancelPendingDeposit(uint256 depositId); // User
function claimExpiredDeposit(uint256 depositId); // Anyone
function getPendingDeposit(uint256 depositId) returns (...);
function getUserDepositIds(address user) returns (uint256[]);

// Management Fee
function mintManagementFee(); // Admin
function setMgmtFeeSchedule(uint256 newSchedule); // Admin
function canMintManagementFee() returns (bool);
function getTimeUntilNextMint() returns (uint256);

// View Functions
function totalAssets() returns (uint256);
function unstakingRatio() returns (uint256);
```

### Reserve Vault (ConcreteReserveVault)
```solidity
// ERC4626 Standard
function deposit(uint256 assets, address receiver) returns (uint256 shares);
function withdraw(uint256 assets, address receiver, address owner) returns (uint256 shares);

// Token Management (Reserve-Specific) ⭐
function seedReserveWithToken(address token, uint256 amount, address provider, uint256 tokenPrice); // Seeder
function investInKodiak(address island, address token, uint256 amount, ...); // Admin
function swapStablecoinToToken(address tokenOut, uint256 amountIn, bytes swapData, address aggregator); // Admin
function rescueAndSwapHookTokenToStablecoin(address tokenIn, uint256 amountIn, bytes swapData, address aggregator); // Admin
function rescueTokenFromHook(address token, uint256 amount); // Admin
function exitLPToToken(uint256 lpAmount, address tokenOut, bytes swapData, address aggregator); // Admin
function setKodiakRouter(address router); // Admin

// Management Fee
function mintManagementFee(); // Admin
function setMgmtFeeSchedule(uint256 newSchedule); // Admin

// View Functions
function totalAssets() returns (uint256);
function unstakingRatio() returns (uint256);
function kodiakRouter() returns (address);
```

### Kodiak Vault Hook
```solidity
// Deposit & Withdraw
function onAfterDepositWithSwaps(uint256 assets, ...); // Vault only
function liquidateLPForAmount(uint256 unstake_usd); // Vault only

// Admin Management
function setIsland(address island);
function setRouter(address router);
function setSafetyMultiplier(uint256 multiplier);
function setAggregatorWhitelisted(address aggregator, bool status);

// Token Management
function adminSwapAndReturnToVault(address tokenIn, uint256 amountIn, bytes swapData, address aggregator);
function adminRescueTokens(address token, address to, uint256 amount);
function adminLiquidateAllToToken(address tokenOut, bytes swapData, address aggregator);

// View Functions
function getIslandLPBalance() returns (uint256);
function vault() returns (address);
function island() returns (address);
function router() returns (address);
```

---

## 📝 **ABI Generation Command**

To regenerate ABIs after contract changes:

```bash
# Build contracts
forge build --force

# Extract ABIs
./extract_abis.sh
```

Or manually:
```bash
jq '.abi' out/UnifiedConcreteSeniorVault.sol/UnifiedConcreteSeniorVault.json > abi/UnifiedConcreteSeniorVault.json
```

---

## 🚀 **Production Addresses (Berachain Artio)**

| Contract | Address | ABI File |
|----------|---------|----------|
| **Senior Vault (Proxy)** | `0x65691bd1972e906459954306aDa0f622a47d4744` | `UnifiedConcreteSeniorVault.json` |
| **Junior Vault (Proxy)** | `0x3A1b3b300dEE06Caf0b691F1771d1Aa26d70B067` | `ConcreteJuniorVault.json` |
| **Reserve Vault (Proxy)** | `0x2C75291479788C568A6750185CaDedf43aBFC553` | `ConcreteReserveVault.json` |
| **Senior Hook** | `0x949Ba11180BDF15560D7Eba9864c929FA4a32bA2` | `KodiakVaultHook.json` |
| **Junior Hook** | `0x9e7753A490628C65219c467A792b708A89209168` | `KodiakVaultHook.json` |
| **Reserve Hook** | `0x88FA91FCF1771AC3C07b3f6684239A4A0B234299` | `KodiakVaultHook.json` |
| **HONEY (Stablecoin)** | `0xFCBD14DC51f0A4d49d5E53C2E0950e0bC26d0Dce` | `ERC20.json` |
| **WBTC** | `0x0555E30da8f98308EdB960aa94C0Db47230d2B9c` | `ERC20.json` |
| **Kodiak Island (LP)** | `0xf6b16E73d3b0e2784AAe8C4cd06099BE65d092Bf` | `IKodiakIsland.json` |
| **Kodiak Router** | `0x679a7C63FC83b6A4D9C1F931891d705483d4791F` | `IKodiakIslandRouter.json` |

---

## 📚 **Related Documentation**

- **Architecture**: See `CONTRACT_ARCHITECTURE.md`
- **Operations**: See `OPERATIONS_MANUAL.md`
- **Deployment**: See `DEPLOYMENT_GUIDE.md`
- **Addresses**: See `deployed_tokens.txt`

---

**Last Updated**: November 20, 2025  
**Version**: 1.3.0 - Post-refactoring with pending LP deposits  
**Network**: Berachain Artio Testnet (Chain ID: 80094)
