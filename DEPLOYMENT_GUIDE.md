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
cast call $JUNIOR_VAULT "kodiakHook()(address)" --rpc-url $RPC_URL
cast call $JUNIOR_VAULT "vaultValue()(uint256)" --rpc-url $RPC_URL
cast call $JUNIOR_VAULT "totalSupply()(uint256)" --rpc-url $RPC_URL

# Check Reserve vault configuration
cast call $RESERVE_VAULT "seniorVault()(address)" --rpc-url $RPC_URL
cast call $RESERVE_VAULT "kodiakHook()(address)" --rpc-url $RPC_URL
cast call $RESERVE_VAULT "vaultValue()(uint256)" --rpc-url $RPC_URL
cast call $RESERVE_VAULT "totalSupply()(uint256)" --rpc-url $RPC_URL
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

