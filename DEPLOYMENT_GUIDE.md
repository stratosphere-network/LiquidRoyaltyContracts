# 🚀 Complete Deployment Guide - Senior Tranche Protocol

> **The definitive guide to deploy the entire vault system from scratch with ZERO mistakes.**

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Pre-Deployment Checklist](#pre-deployment-checklist)
4. [Deployment Steps](#deployment-steps)
5. [Configuration Steps](#configuration-steps)
6. [Bootstrap & Seeding](#bootstrap--seeding)
7. [Verification](#verification)
8. [Post-Deployment](#post-deployment)
9. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

```bash
# 1. Foundry (latest)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 2. Node.js (for frontend)
node --version  # v18 or higher

# 3. jq (for JSON processing)
sudo apt install jq  # Ubuntu/Debian
brew install jq      # macOS

# 4. Git
git --version
```

### Required Accounts & Keys

- [ ] **Deployer wallet** with native gas tokens (BERA on Berachain)
- [ ] **Admin wallet** address (can be same as deployer)
- [ ] **Treasury wallet** address
- [ ] **RPC URL** for your network
- [ ] **Private key** for deployer (KEEP SECURE!)

### Required Token Addresses

Before deploying, you MUST have:
- [ ] **Stablecoin address** (e.g., HONEY on Berachain)
- [ ] **Volatile asset address** (e.g., WBTC on Berachain)
- [ ] **Kodiak Island address** (the LP pool you'll use)
- [ ] **Kodiak Router address**

---

## Environment Setup

### Step 1: Clone and Setup Repository

```bash
# Clone the repo
git clone <your-repo-url>
cd LiquidRoyaltyContracts

# Install dependencies
forge install
npm install --prefix vault-dashboard
```

### Step 2: Create Environment File

```bash
# Copy template
cp env.template .env

# Edit .env file
nano .env
```

### Step 3: Fill in ALL Environment Variables

```bash
# .env file - FILL EVERYTHING!

# Network
RPC_URL=https://rpc.berachain.com
CHAIN_ID=80094

# Deployer & Admin
PRIVATE_KEY=0x...  # Deployer private key (KEEP SECRET!)
ADMIN_ADDRESS=0x...  # Admin wallet address
TREASURY_ADDRESS=0x...  # Treasury wallet address

# Existing Token Addresses (MUST EXIST ON-CHAIN!)
HONEY_ADDRESS=0x...  # Stablecoin
WBTC_ADDRESS=0x...   # Volatile asset for LP
KODIAK_ISLAND_ADDRESS=0x...  # The LP pool
KODIAK_ROUTER_ADDRESS=0x...  # Kodiak router

# Initial Values (USD in wei, 18 decimals)
SENIOR_INITIAL_VALUE=1000000000000000000000000   # 1M USD
JUNIOR_INITIAL_VALUE=500000000000000000000000    # 500k USD
RESERVE_INITIAL_VALUE=100000000000000000000000   # 100k USD

# Enso API (for swaps)
ENSO_API_KEY=your_api_key_here  # Optional but recommended
```

### Step 4: Verify Network Connection

```bash
# Test RPC connection
cast block-number --rpc-url $RPC_URL

# Check deployer balance
cast balance $(cast wallet address --private-key $PRIVATE_KEY) --rpc-url $RPC_URL

# Verify token addresses exist
cast code $HONEY_ADDRESS --rpc-url $RPC_URL  # Should return bytecode
cast code $WBTC_ADDRESS --rpc-url $RPC_URL
cast code $KODIAK_ISLAND_ADDRESS --rpc-url $RPC_URL
```

---

## Pre-Deployment Checklist

**STOP! Do NOT proceed until ALL boxes are checked:**

### Network Verification
- [ ] RPC URL is accessible
- [ ] Network chain ID is correct
- [ ] Deployer has enough gas tokens (≥0.1 native token recommended)

### Address Verification
- [ ] HONEY address is correct and verified on block explorer
- [ ] WBTC address is correct and verified
- [ ] Kodiak Island address is correct
- [ ] Kodiak Router address is correct
- [ ] Admin address is correct
- [ ] Treasury address is correct

### Code Verification
- [ ] All contracts compile: `forge build`
- [ ] No linter errors: `forge fmt --check`
- [ ] Tests pass: `forge test`

### Deployment Scripts Ready
- [ ] `DeploySeniorProxy.s.sol` exists
- [ ] `DeployJuniorProxy.s.sol` exists
- [ ] `DeployReserveProxy.s.sol` exists
- [ ] `DeployHooks.s.sol` exists
- [ ] `ConfigureVaults.s.sol` exists

---

## Deployment Steps

### Phase 1: Deploy Vault Implementations and Proxies

#### 1.1 Deploy Senior Vault

```bash
# Deploy Senior implementation + proxy
forge script script/DeploySeniorProxy.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --legacy \
  --slow

# Save the output!
# Look for:
# - Senior Implementation: 0x...
# - Senior Proxy: 0x...

# Export addresses
export SENIOR_IMPL=0x...  # From deployment output
export SENIOR_VAULT=0x...  # Proxy address
```

**Verification:**
```bash
# Check proxy is deployed
cast code $SENIOR_VAULT --rpc-url $RPC_URL

# Check admin is set correctly
cast call $SENIOR_VAULT "admin()(address)" --rpc-url $RPC_URL
# Should return your ADMIN_ADDRESS

# Check initial value
cast call $SENIOR_VAULT "vaultValue()(uint256)" --rpc-url $RPC_URL
# Should return 1000000000000000000000000 (1M with 18 decimals)
```

#### 1.2 Deploy Junior Vault

```bash
# Deploy Junior implementation + proxy
forge script script/DeployJuniorProxy.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --legacy \
  --slow

# Export addresses
export JUNIOR_IMPL=0x...
export JUNIOR_VAULT=0x...
```

**Verification:**
```bash
cast code $JUNIOR_VAULT --rpc-url $RPC_URL
cast call $JUNIOR_VAULT "admin()(address)" --rpc-url $RPC_URL
cast call $JUNIOR_VAULT "vaultValue()(uint256)" --rpc-url $RPC_URL
```

#### 1.3 Deploy Reserve Vault

```bash
# Deploy Reserve implementation + proxy
forge script script/DeployReserveProxy.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --legacy \
  --slow

# Export addresses
export RESERVE_IMPL=0x...
export RESERVE_VAULT=0x...
```

**Verification:**
```bash
cast code $RESERVE_VAULT --rpc-url $RPC_URL
cast call $RESERVE_VAULT "admin()(address)" --rpc-url $RPC_URL
cast call $RESERVE_VAULT "vaultValue()(uint256)" --rpc-url $RPC_URL
```

#### 1.4 Update Vault References

⚠️ **CRITICAL:** Vaults need to know about each other!

```bash
# Update Senior vault with Junior and Reserve addresses
cast send $SENIOR_VAULT \
  "updateJuniorReserve(address,address)" \
  $JUNIOR_VAULT \
  $RESERVE_VAULT \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# Update Junior vault with Senior address
cast send $JUNIOR_VAULT \
  "setSeniorVault(address)" \
  $SENIOR_VAULT \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# Update Reserve vault with Senior address
cast send $RESERVE_VAULT \
  "setSeniorVault(address)" \
  $SENIOR_VAULT \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

**Verification:**
```bash
# Check Senior knows Junior and Reserve
cast call $SENIOR_VAULT "juniorVault()(address)" --rpc-url $RPC_URL
cast call $SENIOR_VAULT "reserveVault()(address)" --rpc-url $RPC_URL

# Check Junior knows Senior
cast call $JUNIOR_VAULT "seniorVault()(address)" --rpc-url $RPC_URL

# Check Reserve knows Senior
cast call $RESERVE_VAULT "seniorVault()(address)" --rpc-url $RPC_URL
```

### Phase 2: Deploy Hooks

#### 2.1 Deploy All Three Hooks

```bash
# Deploy hooks for all vaults
forge script script/DeployHooks.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --legacy \
  --slow

# Export hook addresses
export SENIOR_HOOK=0x...
export JUNIOR_HOOK=0x...
export RESERVE_HOOK=0x...
```

**Verification:**
```bash
# Check hooks are deployed
cast code $SENIOR_HOOK --rpc-url $RPC_URL
cast code $JUNIOR_HOOK --rpc-url $RPC_URL
cast code $RESERVE_HOOK --rpc-url $RPC_URL

# Check hooks know their vaults
cast call $SENIOR_HOOK "vault()(address)" --rpc-url $RPC_URL
cast call $JUNIOR_HOOK "vault()(address)" --rpc-url $RPC_URL
cast call $RESERVE_HOOK "vault()(address)" --rpc-url $RPC_URL
```

#### 2.2 Connect Hooks to Vaults

```bash
# Senior vault → Senior hook
cast send $SENIOR_VAULT \
  "setKodiakHook(address)" \
  $SENIOR_HOOK \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# Junior vault → Junior hook
cast send $JUNIOR_VAULT \
  "setKodiakHook(address)" \
  $JUNIOR_HOOK \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# Reserve vault → Reserve hook
cast send $RESERVE_VAULT \
  "setKodiakHook(address)" \
  $RESERVE_HOOK \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

**Verification:**
```bash
# Check vaults know their hooks
cast call $SENIOR_VAULT "kodiakHook()(address)" --rpc-url $RPC_URL
cast call $JUNIOR_VAULT "kodiakHook()(address)" --rpc-url $RPC_URL
cast call $RESERVE_VAULT "kodiakHook()(address)" --rpc-url $RPC_URL
```

---

## Configuration Steps

### Phase 3: Configure Hooks

#### 3.1 Set Kodiak Island and Router

```bash
# Configure Senior Hook
cast send $SENIOR_HOOK \
  "setIsland(address)" \
  $KODIAK_ISLAND_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

cast send $SENIOR_HOOK \
  "setRouter(address)" \
  $KODIAK_ROUTER_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# Configure Junior Hook
cast send $JUNIOR_HOOK \
  "setIsland(address)" \
  $KODIAK_ISLAND_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

cast send $JUNIOR_HOOK \
  "setRouter(address)" \
  $KODIAK_ROUTER_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# Configure Reserve Hook
cast send $RESERVE_HOOK \
  "setIsland(address)" \
  $KODIAK_ISLAND_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

cast send $RESERVE_HOOK \
  "setRouter(address)" \
  $KODIAK_ROUTER_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

**Verification:**
```bash
# Check hooks know Island and Router
cast call $SENIOR_HOOK "island()(address)" --rpc-url $RPC_URL
cast call $SENIOR_HOOK "router()(address)" --rpc-url $RPC_URL
```

#### 3.2 Whitelist Enso Aggregator

⚠️ **IMPORTANT:** You need to whitelist the aggregator you'll use for swaps!

```bash
# Get Enso router address (or your preferred aggregator)
export ENSO_ROUTER=0x...  # Enso's router on your network

# Whitelist on all hooks
cast send $SENIOR_HOOK \
  "setAggregatorWhitelisted(address,bool)" \
  $ENSO_ROUTER \
  true \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

cast send $JUNIOR_HOOK \
  "setAggregatorWhitelisted(address,bool)" \
  $ENSO_ROUTER \
  true \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

cast send $RESERVE_HOOK \
  "setAggregatorWhitelisted(address,bool)" \
  $ENSO_ROUTER \
  true \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

**Verification:**
```bash
cast call $SENIOR_HOOK "whitelistedAggregators(address)(bool)" $ENSO_ROUTER --rpc-url $RPC_URL
# Should return: true
```

#### 3.3 Configure Hook Parameters (Optional but Recommended)

```bash
# Set safety multiplier for LP liquidation (default 250 = 2.5x)
cast send $SENIOR_HOOK \
  "setSafetyMultiplier(uint256)" \
  250 \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# Set slippage protection (optional, default 0)
cast send $SENIOR_HOOK \
  "setSlippage(uint256,uint256)" \
  0 \
  0 \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

### Phase 4: Configure Vaults

#### 4.1 Whitelist Depositors (Optional - Senior Only)

If you want to restrict who can deposit:

```bash
# Whitelist specific addresses for Senior vault
cast send $SENIOR_VAULT \
  "addWhitelistedDepositor(address)" \
  <USER_ADDRESS> \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# Junior and Reserve are open by default
```

#### 4.2 Whitelist Kodiak Island LP Token

```bash
# Get Island LP token address (should be same as KODIAK_ISLAND_ADDRESS)
export LP_TOKEN=$KODIAK_ISLAND_ADDRESS

# Whitelist on Senior
cast send $SENIOR_VAULT \
  "addWhitelistedLPToken(address)" \
  $LP_TOKEN \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# Whitelist on Junior
cast send $JUNIOR_VAULT \
  "addWhitelistedLPToken(address)" \
  $LP_TOKEN \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# Whitelist on Reserve
cast send $RESERVE_VAULT \
  "addWhitelistedLPToken(address)" \
  $LP_TOKEN \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

**Verification:**
```bash
cast call $SENIOR_VAULT "isWhitelistedLPToken(address)(bool)" $LP_TOKEN --rpc-url $RPC_URL
# Should return: true
```

#### 4.3 Whitelist Hooks as LPs

⚠️ **CRITICAL:** Hooks need to be whitelisted as LP recipients!

```bash
# Whitelist Senior Hook on Senior Vault
cast send $SENIOR_VAULT \
  "addWhitelistedLP(address)" \
  $SENIOR_HOOK \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# Whitelist Junior Hook on Junior Vault
cast send $JUNIOR_VAULT \
  "addWhitelistedLP(address)" \
  $JUNIOR_HOOK \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# Whitelist Reserve Hook on Reserve Vault
cast send $RESERVE_VAULT \
  "addWhitelistedLP(address)" \
  $RESERVE_HOOK \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

**Verification:**
```bash
cast call $SENIOR_VAULT "isWhitelistedLP(address)(bool)" $SENIOR_HOOK --rpc-url $RPC_URL
# Should return: true
```

#### 4.4 Set Treasury Address

⚠️ **CRITICAL:** Configure treasury to receive fees!

```bash
# Set treasury on all vaults (use your treasury wallet)
export TREASURY_ADDRESS=0x...  # Your treasury address

# Senior vault
cast send $SENIOR_VAULT \
  "setTreasury(address)" \
  $TREASURY_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# Junior vault
cast send $JUNIOR_VAULT \
  "setTreasury(address)" \
  $TREASURY_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# Reserve vault
cast send $RESERVE_VAULT \
  "setTreasury(address)" \
  $TREASURY_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

**Verification:**
```bash
cast call $SENIOR_VAULT "treasury()(address)" --rpc-url $RPC_URL
cast call $JUNIOR_VAULT "treasury()(address)" --rpc-url $RPC_URL
cast call $RESERVE_VAULT "treasury()(address)" --rpc-url $RPC_URL
# All should return: $TREASURY_ADDRESS
```

#### 4.5 Configure Performance Fee Schedule (Junior/Reserve Only)

```bash
# Set fee schedule for Junior vault (example: 30 days = 2592000 seconds)
cast send $JUNIOR_VAULT \
  "setMgmtFeeSchedule(uint256)" \
  2592000 \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# Set fee schedule for Reserve vault (example: 30 days)
cast send $RESERVE_VAULT \
  "setMgmtFeeSchedule(uint256)" \
  2592000 \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

**Common Fee Schedules:**
- 1 day: `86400`
- 7 days: `604800`
- 30 days: `2592000`
- 90 days: `7776000`

**Verification:**
```bash
cast call $JUNIOR_VAULT "getMgmtFeeSchedule()(uint256)" --rpc-url $RPC_URL
cast call $RESERVE_VAULT "getMgmtFeeSchedule()(uint256)" --rpc-url $RPC_URL
# Should return: 2592000 (or your chosen schedule)
```

---

## Bootstrap & Seeding

### Phase 5: Initial Liquidity (Optional but Recommended)

#### Option A: Manual Bootstrap (Simple)

```bash
# 1. Make sure you have HONEY tokens
DEPLOYER=$(cast wallet address --private-key $PRIVATE_KEY)
cast call $HONEY_ADDRESS "balanceOf(address)(uint256)" $DEPLOYER --rpc-url $RPC_URL

# 2. Approve Senior vault
cast send $HONEY_ADDRESS \
  "approve(address,uint256)" \
  $SENIOR_VAULT \
  1000000000000000000000 \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# 3. Deposit to Senior vault
cast send $SENIOR_VAULT \
  "deposit(uint256,address)" \
  1000000000000000000000 \
  $DEPLOYER \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# 4. Repeat for Junior and Reserve
```

#### Option B: Bootstrap with Pre-deployed LP (Advanced)

If you already deployed LP tokens to hooks:

```bash
forge script script/BootstrapLiquidity.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --legacy \
  --slow
```

#### Option C: Seed Vault with Existing LP Tokens (Recommended)

If you or another address already holds LP tokens from Kodiak:

```bash
# 1. Get current LP price
LP_PRICE=$(curl -s "https://api.enso.finance/api/v1/price?chainId=80094&address=$KODIAK_ISLAND_ADDRESS" | jq -r '.price')
LP_PRICE_WEI=$(echo "$LP_PRICE * 10^18" | bc)

# 2. Set seed provider and amount
SEED_PROVIDER=0x...  # Address that holds LP tokens
LP_AMOUNT=1000000000000000000  # 1 LP token (18 decimals)

# 3. Approve vault to transfer LP tokens (from seed provider wallet)
cast send $KODIAK_ISLAND_ADDRESS \
  "approve(address,uint256)" \
  $SENIOR_VAULT \
  $LP_AMOUNT \
  --private-key $SEED_PROVIDER_KEY \
    --rpc-url $RPC_URL \
  --legacy

# 4. Seed the vault (from admin wallet)
cast send $SENIOR_VAULT \
  "seedVault(address,uint256,address,uint256)" \
  $KODIAK_ISLAND_ADDRESS \
  $LP_AMOUNT \
  $SEED_PROVIDER \
  $LP_PRICE_WEI \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# 5. Verify LP tokens transferred to hook
cast call $KODIAK_ISLAND_ADDRESS "balanceOf(address)(uint256)" $SENIOR_HOOK --rpc-url $RPC_URL

# 6. Verify shares minted to seed provider
cast call $SENIOR_VAULT "balanceOf(address)(uint256)" $SEED_PROVIDER --rpc-url $RPC_URL

# 7. Repeat for Junior and Reserve vaults if needed
```

### Phase 6: Deploy Initial Liquidity to Kodiak

⚠️ **IMPORTANT:** You need Enso API to generate swap calldata!

```bash
# 1. Get swap calldata from Enso
# Use the Enso API or vault-dashboard helper:
cd vault-dashboard
npm run generate-swap-data -- --amount 10000 --hook $SENIOR_HOOK

# 2. Deploy to Kodiak (with swap data from Enso)
cast send $SENIOR_VAULT \
  "deployToKodiak(uint256,uint256,address,bytes,address,bytes)" \
  10000000000000000000000 \
  <MIN_LP_TOKENS> \
  <AGGREGATOR_ADDRESS> \
  <SWAP_TO_TOKEN0_DATA> \
  <AGGREGATOR_ADDRESS> \
  <SWAP_TO_TOKEN1_DATA> \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --gas-limit 2000000 \
  --legacy

# 3. Verify LP tokens in hook
cast call $KODIAK_ISLAND_ADDRESS "balanceOf(address)(uint256)" $SENIOR_HOOK --rpc-url $RPC_URL
```

---

## Verification

### Phase 7: Complete System Verification

#### 7.1 Verify All Addresses

```bash
echo "=== VAULT ADDRESSES ==="
echo "Senior Vault: $SENIOR_VAULT"
echo "Junior Vault: $JUNIOR_VAULT"
echo "Reserve Vault: $RESERVE_VAULT"
echo ""
echo "=== HOOK ADDRESSES ==="
echo "Senior Hook: $SENIOR_HOOK"
echo "Junior Hook: $JUNIOR_HOOK"
echo "Reserve Hook: $RESERVE_HOOK"
echo ""
echo "=== TOKEN ADDRESSES ==="
echo "HONEY: $HONEY_ADDRESS"
echo "WBTC: $WBTC_ADDRESS"
echo "Kodiak Island: $KODIAK_ISLAND_ADDRESS"
```

#### 7.2 Verify Vault Configuration

```bash
# Check Senior vault configuration
cast call $SENIOR_VAULT "juniorVault()(address)" --rpc-url $RPC_URL
cast call $SENIOR_VAULT "reserveVault()(address)" --rpc-url $RPC_URL
cast call $SENIOR_VAULT "treasury()(address)" --rpc-url $RPC_URL
cast call $SENIOR_VAULT "kodiakHook()(address)" --rpc-url $RPC_URL
cast call $SENIOR_VAULT "vaultValue()(uint256)" --rpc-url $RPC_URL
cast call $SENIOR_VAULT "totalSupply()(uint256)" --rpc-url $RPC_URL
cast call $SENIOR_VAULT "backingRatio()(uint256)" --rpc-url $RPC_URL

# Check Junior vault configuration
cast call $JUNIOR_VAULT "seniorVault()(address)" --rpc-url $RPC_URL
cast call $JUNIOR_VAULT "treasury()(address)" --rpc-url $RPC_URL
cast call $JUNIOR_VAULT "kodiakHook()(address)" --rpc-url $RPC_URL
cast call $JUNIOR_VAULT "vaultValue()(uint256)" --rpc-url $RPC_URL
cast call $JUNIOR_VAULT "totalSupply()(uint256)" --rpc-url $RPC_URL
cast call $JUNIOR_VAULT "getMgmtFeeSchedule()(uint256)" --rpc-url $RPC_URL
cast call $JUNIOR_VAULT "getLastMintTime()(uint256)" --rpc-url $RPC_URL
cast call $JUNIOR_VAULT "canMintPerformanceFee()(bool)" --rpc-url $RPC_URL

# Check Reserve vault configuration
cast call $RESERVE_VAULT "seniorVault()(address)" --rpc-url $RPC_URL
cast call $RESERVE_VAULT "treasury()(address)" --rpc-url $RPC_URL
cast call $RESERVE_VAULT "kodiakHook()(address)" --rpc-url $RPC_URL
cast call $RESERVE_VAULT "vaultValue()(uint256)" --rpc-url $RPC_URL
cast call $RESERVE_VAULT "totalSupply()(uint256)" --rpc-url $RPC_URL
cast call $RESERVE_VAULT "getMgmtFeeSchedule()(uint256)" --rpc-url $RPC_URL
cast call $RESERVE_VAULT "getLastMintTime()(uint256)" --rpc-url $RPC_URL
cast call $RESERVE_VAULT "canMintPerformanceFee()(bool)" --rpc-url $RPC_URL
```

#### 7.3 Verify Hook Configuration

```bash
# Check Senior hook
cast call $SENIOR_HOOK "vault()(address)" --rpc-url $RPC_URL
cast call $SENIOR_HOOK "island()(address)" --rpc-url $RPC_URL
cast call $SENIOR_HOOK "router()(address)" --rpc-url $RPC_URL
cast call $SENIOR_HOOK "assetToken()(address)" --rpc-url $RPC_URL
cast call $SENIOR_HOOK "safetyMultiplier()(uint256)" --rpc-url $RPC_URL
cast call $SENIOR_HOOK "whitelistedAggregators(address)(bool)" $ENSO_ROUTER --rpc-url $RPC_URL
cast call $SENIOR_HOOK "getIslandLPBalance()(uint256)" --rpc-url $RPC_URL

# Repeat for Junior and Reserve hooks
```

#### 7.4 Run Verification Script

```bash
forge script script/VerifyDeployment.s.sol \
  --rpc-url $RPC_URL \
  --legacy
```

---

## Post-Deployment

### Phase 8: Save Deployment Data

#### 8.1 Update `deployed_tokens.txt`

```bash
cat > deployed_tokens.txt << EOF
# Deployment Date: $(date)
# Network: Berachain Artio (Chain ID: 80094)

========================================
VAULT ADDRESSES
========================================
export SENIOR_VAULT=$SENIOR_VAULT
export JUNIOR_VAULT=$JUNIOR_VAULT
export RESERVE_VAULT=$RESERVE_VAULT

========================================
IMPLEMENTATION ADDRESSES
========================================
export SENIOR_IMPL=$SENIOR_IMPL
export JUNIOR_IMPL=$JUNIOR_IMPL
export RESERVE_IMPL=$RESERVE_IMPL

========================================
HOOK ADDRESSES
========================================
export SENIOR_HOOK=$SENIOR_HOOK
export JUNIOR_HOOK=$JUNIOR_HOOK
export RESERVE_HOOK=$RESERVE_HOOK

========================================
TOKEN ADDRESSES
========================================
export HONEY_ADDRESS=$HONEY_ADDRESS
export WBTC_ADDRESS=$WBTC_ADDRESS
export KODIAK_ISLAND_ADDRESS=$KODIAK_ISLAND_ADDRESS
export KODIAK_ROUTER_ADDRESS=$KODIAK_ROUTER_ADDRESS
export ENSO_ROUTER=$ENSO_ROUTER

========================================
CONFIGURATION
========================================
export ADMIN_ADDRESS=$ADMIN_ADDRESS
export TREASURY_ADDRESS=$TREASURY_ADDRESS

EOF
```

#### 8.2 Generate ABIs

```bash
# Generate all JSON ABIs
forge build
./extract_abis.sh
./extract_more_abis.sh

# ABIs are now in /abi/*.json
```

#### 8.3 Update Frontend Configuration

```bash
# Update vault-dashboard/src/contracts/addresses.ts
cat > vault-dashboard/src/contracts/addresses.ts << EOF
export const ADDRESSES = {
  SENIOR_VAULT: '${SENIOR_VAULT}',
  JUNIOR_VAULT: '${JUNIOR_VAULT}',
  RESERVE_VAULT: '${RESERVE_VAULT}',
  
  SENIOR_HOOK: '${SENIOR_HOOK}',
  JUNIOR_HOOK: '${JUNIOR_HOOK}',
  RESERVE_HOOK: '${RESERVE_HOOK}',
  
  HONEY: '${HONEY_ADDRESS}',
  WBTC: '${WBTC_ADDRESS}',
  KODIAK_ISLAND: '${KODIAK_ISLAND_ADDRESS}',
  
  ENSO_AGGREGATOR: '${ENSO_ROUTER}',
} as const;
EOF
```

#### 8.4 Deploy Frontend

```bash
cd vault-dashboard

# Install dependencies
npm install

# Build
npm run build

# Deploy (adjust for your hosting)
npm run deploy
```

### Phase 9: Test Basic Operations

#### 9.1 Test Deposit

```bash
# Approve HONEY
cast send $HONEY_ADDRESS \
  "approve(address,uint256)" \
  $SENIOR_VAULT \
  1000000000000000000 \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# Deposit to Senior
cast send $SENIOR_VAULT \
  "deposit(uint256,address)" \
  1000000000000000000 \
  $(cast wallet address --private-key $PRIVATE_KEY) \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# Check balance
cast call $SENIOR_VAULT "balanceOf(address)(uint256)" $(cast wallet address --private-key $PRIVATE_KEY) --rpc-url $RPC_URL
```

#### 9.2 Test Withdrawal (After Cooldown)

```bash
# Initiate cooldown
cast send $SENIOR_VAULT \
  "initiateCooldown()" \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# Wait 7 days or adjust cooldown for testing...

# Withdraw
cast send $SENIOR_VAULT \
  "withdraw(uint256,address,address)" \
  500000000000000000 \
  $(cast wallet address --private-key $PRIVATE_KEY) \
  $(cast wallet address --private-key $PRIVATE_KEY) \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --gas-limit 1500000 \
  --legacy
```

#### 9.3 Test Rebase (Admin Only)

```bash
# Get LP price from Enso or DEX
LP_PRICE=60000000000000000000000  # $60k with 18 decimals

# Execute rebase
cast send $SENIOR_VAULT \
  "rebase(uint256)" \
  $LP_PRICE \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --gas-limit 3000000 \
  --legacy

# Check new backing ratio
cast call $SENIOR_VAULT "backingRatio()(uint256)" --rpc-url $RPC_URL
```

---

## Fee Structure Overview

### Understanding Vault Fees

The protocol implements a comprehensive fee structure to ensure sustainability and proper treasury management:

#### Senior Vault Fees

1. **Management Fee (1% annually)**
   - Charged during monthly rebase
   - Minted as additional snrUSD to treasury
   - Does NOT reduce user balances

2. **Performance Fee (~2% of yield)**
   - Charged during monthly rebase
   - Minted as additional snrUSD to treasury
   - Based on yield generated

3. **Withdrawal Fee (1%)**
   - Charged on all withdrawals
   - Deducted from withdrawn amount
   - Sent to treasury in HONEY

4. **Early Withdrawal Penalty (20%)**
   - Charged if withdrawing before 7-day cooldown
   - Deducted from withdrawn amount
   - Sent to treasury in HONEY

**Example Senior Withdrawal:**
- User withdraws 1000 snrUSD before cooldown
- Early penalty: 1000 × 20% = 200 HONEY
- After penalty: 800 HONEY
- Withdrawal fee: 800 × 1% = 8 HONEY
- User receives: 792 HONEY
- Treasury receives: 208 HONEY total

#### Junior & Reserve Vault Fees

1. **Performance Fee (1% of supply)**
   - Minted on configurable schedule (e.g., monthly)
   - Admin calls `mintPerformanceFee()`
   - Mints 1% of current supply to treasury
   - Schedule enforced on-chain

2. **Withdrawal Fee (1%)**
   - Charged on all withdrawals
   - Deducted from withdrawn amount
   - Sent to treasury in HONEY

**Example Junior Withdrawal:**
- User withdraws 1000 jnrHONEY
- Current unstaking ratio: 1.2 (user gets 1200 HONEY)
- Withdrawal fee: 1200 × 1% = 12 HONEY
- User receives: 1188 HONEY
- Treasury receives: 12 HONEY

### Fee Schedule Recommendations

| Vault Type | Fee Type | Frequency | Recommended |
|------------|----------|-----------|-------------|
| Senior | Management | Monthly (automatic) | Non-configurable |
| Senior | Performance | Monthly (automatic) | Non-configurable |
| Senior | Withdrawal | Per withdrawal | Non-configurable |
| Senior | Early Penalty | Per early withdrawal | Non-configurable (20%) |
| Junior | Performance | Configurable | 30 days (2592000 sec) |
| Reserve | Performance | Configurable | 30 days (2592000 sec) |
| Junior | Withdrawal | Per withdrawal | Non-configurable |
| Reserve | Withdrawal | Per withdrawal | Non-configurable |

### Monitoring Fee Collection

```bash
# Check treasury balance
TREASURY=$(cast call $SENIOR_VAULT "treasury()(address)" --rpc-url $RPC_URL)

# Check snrUSD balance (from management/performance fees)
cast call $SENIOR_VAULT "balanceOf(address)(uint256)" $TREASURY --rpc-url $RPC_URL

# Check HONEY balance (from withdrawal fees)
cast call $HONEY_ADDRESS "balanceOf(address)(uint256)" $TREASURY --rpc-url $RPC_URL

# Check if Junior can mint performance fee
cast call $JUNIOR_VAULT "canMintPerformanceFee()(bool)" --rpc-url $RPC_URL

# Check time until next Junior fee mint
cast call $JUNIOR_VAULT "getTimeUntilNextMint()(uint256)" --rpc-url $RPC_URL
```

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: "InsufficientBalance" during deployment

**Problem:** Deployer doesn't have enough gas tokens.

**Solution:**
```bash
# Check balance
cast balance $(cast wallet address --private-key $PRIVATE_KEY) --rpc-url $RPC_URL

# Get more tokens from faucet or bridge
```

#### Issue 2: "InvalidRecipient" or "ZeroAddress" errors

**Problem:** One of the addresses in .env is wrong or not set.

**Solution:**
```bash
# Verify all addresses
echo $HONEY_ADDRESS
echo $WBTC_ADDRESS
echo $KODIAK_ISLAND_ADDRESS

# Check if they're deployed
cast code $HONEY_ADDRESS --rpc-url $RPC_URL
```

#### Issue 3: "OnlyAdmin" errors

**Problem:** Using wrong private key or admin not set correctly.

**Solution:**
```bash
# Check who admin is
cast call $SENIOR_VAULT "admin()(address)" --rpc-url $RPC_URL

# Make sure it matches your deployer
cast wallet address --private-key $PRIVATE_KEY
```

#### Issue 4: "KodiakHookNotSet"

**Problem:** Vault doesn't have hook configured.

**Solution:**
```bash
# Set hook
cast send $SENIOR_VAULT \
  "setKodiakHook(address)" \
  $SENIOR_HOOK \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

#### Issue 5: "Aggregator not whitelisted"

**Problem:** Trying to use aggregator that's not whitelisted.

**Solution:**
```bash
# Whitelist aggregator
cast send $SENIOR_HOOK \
  "setAggregatorWhitelisted(address,bool)" \
  $ENSO_ROUTER \
  true \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

#### Issue 6: "InsufficientLiquidity" during withdrawal

**Problem:** No HONEY or LP tokens in vault/hook.

**Solution:**
```bash
# Check balances
cast call $HONEY_ADDRESS "balanceOf(address)(uint256)" $SENIOR_VAULT --rpc-url $RPC_URL
cast call $KODIAK_ISLAND_ADDRESS "balanceOf(address)(uint256)" $SENIOR_HOOK --rpc-url $RPC_URL

# Deploy liquidity if needed
```

#### Issue 7: Deployment transaction stuck

**Problem:** Gas price too low or network congestion.

**Solution:**
```bash
# Add --gas-price flag
--gas-price 1000000000  # 1 gwei

# Or use --slow flag for automatic adjustment
--slow
```

#### Issue 8: "ZeroAddress" when minting performance fee

**Problem:** Treasury not configured on vault.

**Solution:**
```bash
# Set treasury address
cast send $JUNIOR_VAULT \
  "setTreasury(address)" \
  $TREASURY_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

#### Issue 9: "FeeScheduleNotMet" when minting performance fee

**Problem:** Not enough time elapsed since last mint.

**Solution:**
```bash
# Check how much time until next mint
cast call $JUNIOR_VAULT "getTimeUntilNextMint()(uint256)" --rpc-url $RPC_URL

# Wait until schedule is met, or adjust schedule (if really needed)
cast send $JUNIOR_VAULT \
  "setMgmtFeeSchedule(uint256)" \
  86400 \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

---

## Final Checklist

**Before announcing launch, verify ALL:**

### Smart Contracts
- [ ] All 3 vaults deployed and verified on block explorer
- [ ] All 3 hooks deployed and verified
- [ ] Vaults know about each other (Senior ↔ Junior ↔ Reserve)
- [ ] Vaults connected to their hooks
- [ ] Hooks configured with Island and Router
- [ ] Aggregators whitelisted on hooks
- [ ] LP tokens whitelisted on vaults
- [ ] Hooks whitelisted as LPs on vaults
- [ ] Treasury address set on all 3 vaults
- [ ] Performance fee schedule set on Junior vault
- [ ] Performance fee schedule set on Reserve vault

### Initial State
- [ ] Vault values set correctly
- [ ] Initial liquidity deposited (optional)
- [ ] LP tokens deployed to hooks (optional)
- [ ] Admin can execute rebase
- [ ] Users can deposit
- [ ] Users can withdraw (after cooldown)

### Frontend
- [ ] Dashboard deployed and accessible
- [ ] Correct contract addresses configured
- [ ] ABIs copied to frontend
- [ ] Can connect wallet
- [ ] Can see vault balances
- [ ] Can deposit via UI
- [ ] Can withdraw via UI

### Documentation
- [ ] `deployed_tokens.txt` updated
- [ ] ABIs generated in `/abi`
- [ ] Frontend addresses updated
- [ ] README updated with new addresses

### Security
- [ ] Admin private key secured
- [ ] Treasury address confirmed
- [ ] Multisig considered for admin operations
- [ ] Backup of all private keys
- [ ] Block explorer links saved

---

## Useful Commands Reference

```bash
# Quick status check
source deployed_tokens.txt
cast call $SENIOR_VAULT "backingRatio()(uint256)" --rpc-url $RPC_URL
cast call $SENIOR_VAULT "totalSupply()(uint256)" --rpc-url $RPC_URL
cast call $SENIOR_VAULT "vaultValue()(uint256)" --rpc-url $RPC_URL

# Check LP balances
cast call $KODIAK_ISLAND_ADDRESS "balanceOf(address)(uint256)" $SENIOR_HOOK --rpc-url $RPC_URL
cast call $KODIAK_ISLAND_ADDRESS "balanceOf(address)(uint256)" $JUNIOR_HOOK --rpc-url $RPC_URL
cast call $KODIAK_ISLAND_ADDRESS "balanceOf(address)(uint256)" $RESERVE_HOOK --rpc-url $RPC_URL

# Check HONEY balances
cast call $HONEY_ADDRESS "balanceOf(address)(uint256)" $SENIOR_VAULT --rpc-url $RPC_URL
cast call $HONEY_ADDRESS "balanceOf(address)(uint256)" $JUNIOR_VAULT --rpc-url $RPC_URL
cast call $HONEY_ADDRESS "balanceOf(address)(uint256)" $RESERVE_VAULT --rpc-url $RPC_URL

# Check user balance
USER=0x...
cast call $SENIOR_VAULT "balanceOf(address)(uint256)" $USER --rpc-url $RPC_URL
cast call $JUNIOR_VAULT "balanceOf(address)(uint256)" $USER --rpc-url $RPC_URL
cast call $RESERVE_VAULT "balanceOf(address)(uint256)" $USER --rpc-url $RPC_URL
```

---

## Support and Resources

- **Smart Contract Documentation:** [CONTRACT_ARCHITECTURE.md](./CONTRACT_ARCHITECTURE.md)
- **Mathematical Specification:** [math_spec.md](./math_spec.md)
- **ABI Documentation:** [abi/README.md](./abi/README.md)
- **Frontend Guide:** [vault-dashboard/README.md](./vault-dashboard/README.md)

---

**🎉 Congratulations! Your vault system is now fully deployed and operational! 🚀**

Remember to:
1. Keep private keys secure
2. Monitor vault health regularly
3. Execute rebases on schedule
4. Keep frontend updated
5. Communicate with users about cooldown periods

Good luck! 💪

---

## Appendix A: Reserve Vault Unique Features

### Overview

The **Reserve vault** has unique capabilities that Senior and Junior vaults don't have. It can accept non-stablecoin assets (like WBTC) and manage them separately before converting to LP tokens.

### Reserve-Specific Functions

#### 1. `seedReserveWithToken()` - Seed with Non-Stablecoin Assets

**Purpose**: Bootstrap Reserve vault with non-stablecoin tokens (e.g., WBTC) that stay in the vault initially.

**Flow**:
1. Token holder approves Reserve vault
2. Admin calls `seedReserveWithToken()` with token amount and price
3. Tokens transferred to Reserve vault (NOT to hook!)
4. Value calculated: `valueAdded = amount × tokenPrice / 1e18`
5. Shares minted to provider based on current share price
6. Vault value updated to include token value

**When to Use**: When you want to bootstrap Reserve with volatile assets that can later be converted to LP.

**Example**:
```bash
# Seed Reserve with 1 WBTC at $50,000
SEED_PROVIDER=0x...  # Address with WBTC
WBTC_AMOUNT=100000000  # 1 WBTC (8 decimals)
WBTC_PRICE=50000000000000000000000  # $50k in 18 decimals

# Step 1: Provider approves
cast send $WBTC_ADDRESS "approve(address,uint256)" $RESERVE_VAULT $WBTC_AMOUNT \
  --private-key $SEED_PROVIDER_KEY --rpc-url $RPC_URL --legacy

# Step 2: Admin seeds
cast send $RESERVE_VAULT \
  "seedReserveWithToken(address,uint256,address,uint256)" \
  $WBTC_ADDRESS $WBTC_AMOUNT $SEED_PROVIDER $WBTC_PRICE \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy

# Step 3: Verify
cast call $WBTC_ADDRESS "balanceOf(address)(uint256)" $RESERVE_VAULT --rpc-url $RPC_URL
cast call $RESERVE_VAULT "balanceOf(address)(uint256)" $SEED_PROVIDER --rpc-url $RPC_URL
```

#### 2. `investInKodiak()` - Convert Assets to LP Tokens

**Purpose**: Take non-stablecoin tokens from Reserve vault and convert them to Kodiak LP tokens.

**Flow**:
1. Admin gets swap calldata from Enso API
2. Admin calls `investInKodiak()` with token, amount, and swap parameters
3. Reserve vault transfers tokens to hook
4. Hook executes swaps: Token → balanced pool tokens
5. Hook adds liquidity to Kodiak Island
6. LP tokens stay in hook

**Difference from `deployToKodiak()`**:
- `deployToKodiak()`: HONEY → LP (all vaults have this)
- `investInKodiak()`: WBTC/other → LP (Reserve ONLY)
- Same swap pattern, different input token

**Example**:
```bash
# Invest 0.5 WBTC into Kodiak LP
INVEST_AMOUNT=50000000  # 0.5 WBTC

# Step 1: Get Enso swap route
curl -X GET "https://api.enso.finance/api/v1/shortcuts/route" \
  -H "Authorization: Bearer $ENSO_API_KEY" \
  -d "chainId=80094" \
  -d "tokenIn=$WBTC_ADDRESS" \
  -d "tokenOut=$KODIAK_ISLAND_ADDRESS" \
  -d "amountIn=$INVEST_AMOUNT" \
  > enso_route.json

SWAP_DATA=$(jq -r '.tx.data' enso_route.json)
AGGREGATOR=$(jq -r '.tx.to' enso_route.json)
MIN_LP=$(jq -r '.amountOut' enso_route.json | xargs -I{} echo "{} * 0.98" | bc)

# Step 2: Invest
cast send $RESERVE_VAULT \
  "investInKodiak(address,address,uint256,uint256,address,bytes,address,bytes)" \
  $KODIAK_ISLAND_ADDRESS \
  $WBTC_ADDRESS \
  $INVEST_AMOUNT \
  $MIN_LP \
  $AGGREGATOR \
  $SWAP_DATA \
  $AGGREGATOR \
  "0x" \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --gas-limit 2000000 \
  --legacy

# Step 3: Verify LP received
cast call $KODIAK_ISLAND_ADDRESS "balanceOf(address)(uint256)" $RESERVE_HOOK --rpc-url $RPC_URL
```

#### 3. `setKodiakRouter()` / `kodiakRouter()` - Router Management

**Purpose**: Configure Kodiak Island Router address (required for `investInKodiak()`).

**Example**:
```bash
# Set router
cast send $RESERVE_VAULT "setKodiakRouter(address)" $KODIAK_ROUTER_ADDRESS \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy

# Verify
cast call $RESERVE_VAULT "kodiakRouter()(address)" --rpc-url $RPC_URL
```

### Complete Reserve Workflow

```bash
# Full lifecycle: WBTC → Reserve → LP → Yield

# 1. Set treasury (for fees)
cast send $RESERVE_VAULT "setTreasury(address)" $TREASURY_ADDRESS \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy

# 2. Set Kodiak router (for investInKodiak)
cast send $RESERVE_VAULT "setKodiakRouter(address)" $KODIAK_ROUTER_ADDRESS \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy

# 3. Set performance fee schedule (30 days)
cast send $RESERVE_VAULT "setMgmtFeeSchedule(uint256)" 2592000 \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy

# 4. Seed with WBTC (tokens stay in vault)
# Provider approves first
cast send $WBTC_ADDRESS "approve(address,uint256)" $RESERVE_VAULT $WBTC_AMOUNT \
  --private-key $SEED_PROVIDER_KEY --rpc-url $RPC_URL --legacy

# Admin seeds
cast send $RESERVE_VAULT \
  "seedReserveWithToken(address,uint256,address,uint256)" \
  $WBTC_ADDRESS $WBTC_AMOUNT $SEED_PROVIDER $WBTC_PRICE_WEI \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy

# 5. Invest WBTC into Kodiak LP (swaps + adds liquidity)
# Get swap data from Enso first
cast send $RESERVE_VAULT \
  "investInKodiak(...)" \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL --gas-limit 2000000 --legacy

# 6. Check final state
echo "Reserve WBTC: $(cast call $WBTC_ADDRESS "balanceOf(address)(uint256)" $RESERVE_VAULT --rpc-url $RPC_URL)"
echo "Reserve hook LP: $(cast call $KODIAK_ISLAND_ADDRESS "balanceOf(address)(uint256)" $RESERVE_HOOK --rpc-url $RPC_URL)"
echo "Seed provider resUSD: $(cast call $RESERVE_VAULT "balanceOf(address)(uint256)" $SEED_PROVIDER --rpc-url $RPC_URL)"
```

### Comparison: Reserve vs Senior/Junior

| Feature | Senior/Junior | Reserve |
|---------|---------------|---------|
| **Standard Deposits** | ✅ HONEY deposits | ✅ HONEY deposits |
| **Standard LP Seeding** | ✅ `seedVault()` with LP | ✅ `seedVault()` with LP |
| **Token Seeding** | ❌ Not available | ✅ `seedReserveWithToken()` with WBTC/others |
| **Deploy to Kodiak** | ✅ `deployToKodiak()` (HONEY→LP) | ✅ `deployToKodiak()` (HONEY→LP) |
| **Invest Assets** | ❌ Not available | ✅ `investInKodiak()` (WBTC/other→LP) |
| **Kodiak Router** | ❌ Not needed | ✅ Required (via `setKodiakRouter()`) |
| **Withdrawal Fee** | ✅ 1% | ✅ 1% |
| **Performance Fee** | ✅ 1% of supply (configurable) | ✅ 1% of supply (configurable) |
| **Early Penalty** | ❌ No (Senior only) | ❌ No |

### When to Use Each Reserve Function

**Use `seedReserveWithToken()`**:
- Initial bootstrap with non-stablecoin assets
- You have WBTC but want to delay LP conversion
- Want to hold volatile assets temporarily

**Use `investInKodiak()`**:
- Convert held WBTC/tokens to productive LP
- Similar to `deployToKodiak()` but for non-stablecoin
- After seeding with `seedReserveWithToken()`

**Use `seedVault()` (standard)**:
- You already have Kodiak LP tokens
- Quickest way to bootstrap with yield-bearing assets

**Use `deployToKodiak()` (standard)**:
- You have HONEY stablecoins in vault
- Convert idle HONEY to productive LP

---

## Appendix B: Complete Fee Structure

### Fee Overview

All protocol fees are sent to the configured **treasury address**. The treasury receives:
- **Token-denominated fees** (snrUSD, jnrUSD, resUSD) via minting
- **Stablecoin fees** (HONEY) via withdrawal deductions

### Fee Comparison Table

| Vault | Fee Type | Rate | When Charged | Collection Method | Recipient |
|-------|----------|------|--------------|-------------------|-----------|
| **Senior** | Management Fee | 1% annual | Monthly rebase | Mints snrUSD to treasury | Treasury |
| **Senior** | Performance Fee | ~2% of yield | Monthly rebase | Mints snrUSD to treasury | Treasury |
| **Senior** | Withdrawal Fee | 1% | Every withdrawal | Deducted from HONEY | Treasury |
| **Senior** | Early Penalty | 20% | Withdrawal before 7-day cooldown | Deducted from HONEY | Treasury |
| **Junior** | Performance Fee | 1% of supply | Configurable schedule | Mints jnrUSD to treasury | Treasury |
| **Junior** | Withdrawal Fee | 1% | Every withdrawal | Deducted from HONEY | Treasury |
| **Reserve** | Performance Fee | 1% of supply | Configurable schedule | Mints resUSD to treasury | Treasury |
| **Reserve** | Withdrawal Fee | 1% | Every withdrawal | Deducted from HONEY | Treasury |

### Fee Calculation Examples

#### Senior Vault - Early Withdrawal (Worst Case)
```
User withdraws 1000 snrUSD BEFORE cooldown:

Step 1: Early Withdrawal Penalty (20%)
  Gross: 1000 HONEY
  Penalty: 200 HONEY
  After penalty: 800 HONEY

Step 2: Withdrawal Fee (1%)
  Before fee: 800 HONEY
  Fee: 8 HONEY
  Net: 792 HONEY

Result:
  Treasury receives: 208 HONEY (20.8%)
  User receives: 792 HONEY (79.2%)
```

#### Senior Vault - Normal Withdrawal (After Cooldown)
```
User withdraws 1000 snrUSD AFTER 7-day cooldown:

Step 1: No Penalty (cooldown complete)
  Gross: 1000 HONEY
  Penalty: 0 HONEY

Step 2: Withdrawal Fee (1%)
  Before fee: 1000 HONEY
  Fee: 10 HONEY
  Net: 990 HONEY

Result:
  Treasury receives: 10 HONEY (1%)
  User receives: 990 HONEY (99%)
```

#### Junior/Reserve Vault - Withdrawal
```
User redeems 1000 jnrUSD at 1.2 unstaking ratio:

Gross HONEY: 1000 × 1.2 = 1200 HONEY

Withdrawal Fee (1%):
  Fee: 12 HONEY
  Net: 1188 HONEY

Result:
  Treasury receives: 12 HONEY (1%)
  User receives: 1188 HONEY (99%)

Note: No early withdrawal penalty for Junior/Reserve
```

#### Performance Fee Minting (Junior/Reserve)
```
Current supply: 100,000 jnrUSD
Time elapsed: 30 days (schedule met)

Mint Calculation:
  Fee rate: 1%
  Mint amount: 1,000 jnrUSD

Result:
  Treasury receives: 1,000 newly minted jnrUSD
  New total supply: 101,000 jnrUSD
  Dilution: 1% (all holders)

If minted monthly for 1 year:
  Annual dilution: ~12.68% (compounded)
```

### Fee Configuration Checklist

**Initial Setup (Required)**:
```bash
# 1. Set treasury on ALL vaults (CRITICAL!)
cast send $SENIOR_VAULT "setTreasury(address)" $TREASURY_ADDRESS --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy
cast send $JUNIOR_VAULT "setTreasury(address)" $TREASURY_ADDRESS --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy
cast send $RESERVE_VAULT "setTreasury(address)" $TREASURY_ADDRESS --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy

# 2. Set performance fee schedule for Junior/Reserve
cast send $JUNIOR_VAULT "setMgmtFeeSchedule(uint256)" 2592000 --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy  # 30 days
cast send $RESERVE_VAULT "setMgmtFeeSchedule(uint256)" 2592000 --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy  # 30 days
```

**Monitoring**:
```bash
# Check treasury balances
TREASURY=$(cast call $SENIOR_VAULT "treasury()(address)" --rpc-url $RPC_URL)

echo "Treasury snrUSD: $(cast call $SENIOR_VAULT "balanceOf(address)(uint256)" $TREASURY --rpc-url $RPC_URL)"
echo "Treasury jnrUSD: $(cast call $JUNIOR_VAULT "balanceOf(address)(uint256)" $TREASURY --rpc-url $RPC_URL)"
echo "Treasury resUSD: $(cast call $RESERVE_VAULT "balanceOf(address)(uint256)" $TREASURY --rpc-url $RPC_URL)"
echo "Treasury HONEY: $(cast call $HONEY_ADDRESS "balanceOf(address)(uint256)" $TREASURY --rpc-url $RPC_URL)"

# Check if performance fees can be minted
echo "Junior can mint: $(cast call $JUNIOR_VAULT "canMintPerformanceFee()(bool)" --rpc-url $RPC_URL)"
echo "Reserve can mint: $(cast call $RESERVE_VAULT "canMintPerformanceFee()(bool)" --rpc-url $RPC_URL)"
```

### Fee Revenue Projections

Based on realistic vault sizes:

**Senior Vault** ($1M TVL):
- Management fee: ~$833/month (0.0833% of TVL)
- Performance fee: ~$167/month (assuming 11% APY → 0.22% to treasury)
- Withdrawal fees: Variable (depends on withdrawals)
- **Total: ~$1,000/month + withdrawal fees**

**Junior Vault** ($500k TVL):
- Performance fee: $5,000/month (1% of supply monthly)
- Withdrawal fees: Variable
- **Total: $5,000/month + withdrawal fees**

**Reserve Vault** ($100k TVL):
- Performance fee: $1,000/month (1% of supply monthly)
- Withdrawal fees: Variable
- **Total: $1,000/month + withdrawal fees**

**Combined**: ~$7,000/month + withdrawal fees from all vaults

---

## Appendix C: Recent Upgrades

### November 19, 2025 - Reserve Vault Complete Upgrade

**What Changed:**
- Added `seedReserveWithToken()` - Seed Reserve with WBTC/other non-stablecoin
- Added `investInKodiak()` - Convert Reserve's WBTC/tokens to LP
- Added `setKodiakRouter()` / `kodiakRouter()` - Router management for Reserve

**Why This Matters:**
Reserve vault can now accept non-stablecoin assets (WBTC) and manage them separately before converting to yield-bearing LP tokens. This provides more flexibility in bootstrapping and asset management.

**New Workflow Enabled:**
```
WBTC holder → seedReserveWithToken() → WBTC in Reserve vault
                ↓
Reserve admin → investInKodiak() → WBTC converted to LP
                ↓
           LP tokens earning yield in hook
```

### November 18, 2025 - Fee & Performance Upgrade

**What Changed:**
- Added `seedVault()` function to bootstrap vaults with LP tokens (all vaults)
- Added `setTreasury()` and `treasury()` to configure fee recipient (all vaults)
- Increased early withdrawal penalty from 5% to 20% (Senior only)
- Added 1% withdrawal fee on all vaults (sent to treasury in HONEY)
- Changed Senior management fee: now mints snrUSD instead of reducing vault value
- Added performance fee minting for Junior/Reserve:
  - `mintPerformanceFee()` - Mint 1% of supply to treasury
  - `setMgmtFeeSchedule()` - Configure minting schedule
  - `getMgmtFeeSchedule()` - View schedule
  - `getLastMintTime()` - Last mint timestamp
  - `canMintPerformanceFee()` - Check if eligible to mint
  - `getTimeUntilNextMint()` - Time remaining

**Migration Steps:**
If you deployed vaults before these upgrades:
1. Deploy new implementations (Senior, Junior, Reserve)
2. Call `upgradeToAndCall()` on each proxy
3. Call `setTreasury()` on all 3 vaults
4. Call `setMgmtFeeSchedule()` on Junior and Reserve
5. Call `setKodiakRouter()` on Reserve (if using `investInKodiak()`)

**New ABIs:**
Make sure to regenerate ABIs and update frontend after these upgrades!

---

