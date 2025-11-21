# 🚀 Complete Vault Deployment Guide - Production Ready

> **This guide documents the exact steps to deploy Senior, Junior, and Reserve vaults with custom names and full configuration.**

---

## 📋 What You'll Deploy

- **Senior Vault**: "Senior Tranche" / Symbol: "snrUSD"
- **Junior Vault**: "Junior Tranche" / Symbol: "jnr"  
- **Reserve Vault**: "Alar" / Symbol: "alar"

---

## ✅ Prerequisites

Before starting, ensure you have:

```bash
# 1. Check Foundry is installed
forge --version

# 2. You have .env file with:
# PRIVATE_KEY=0x...
# RPC_URL=https://...

# 3. Your wallet has gas tokens
```

### Required Addresses

Have these addresses ready before deployment:

- ✅ **USDE** (Stablecoin): Your stablecoin token address
- ✅ **Sail.r** (Non-stablecoin): Your volatile token address  
- ✅ **Kodiak Island LP**: The LP token address
- ✅ **Kodiak Router**: The router address for swaps
- ✅ **Treasury**: Where fees will be sent
- ✅ **Seeders** (optional): Addresses that can seed vaults

**Example from our deployment:**
```bash
STABLECOIN_ADDRESS=0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34  # USDE
SAILR_ADDRESS=0x59a61B8d3064A51a95a5D6393c03e2152b1a2770      # Sail.r
KODIAK_ISLAND_ADDRESS=0xB350944Be03cf5f795f48b63eAA542df6A3c8505  # LP Token
KODIAK_ROUTER_ADDRESS=0x679a7C63FC83b6A4D9C1F931891d705483d4791F # Router
TREASURY=0x23fd5f6e2b07970c9b00d1da8e85c201711b7b74
```

---

## 🏗️ Phase 1: Deploy Implementation Contracts

These are the "blueprint" contracts that proxies will use.

### Step 1: Compile Contracts

```bash
cd /home/amschel/stratosphere/LiquidRoyaltyContracts
forge build
```

**Expected**: No errors, successful compilation

---

### Step 2: Deploy Senior Implementation

```bash
forge create \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --legacy \
  src/concrete/UnifiedConcreteSeniorVault.sol:UnifiedConcreteSeniorVault
```

**Save the address:**
```bash
export SENIOR_IMPL=0x...  # Copy "Deployed to:" address
```

**Example from our deployment:**
```
SENIOR_IMPL=0xbc65274F211b6E3A8bf112b1519935b31403a84F
```

---

### Step 3: Deploy Junior Implementation

```bash
forge create \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --legacy \
  src/concrete/ConcreteJuniorVault.sol:ConcreteJuniorVault
```

**Save the address:**
```bash
export JUNIOR_IMPL=0x...
```

**Example:**
```
JUNIOR_IMPL=0x09788C38906Ed9fE422Bc4AEcA6F24F27924a962
```

---

### Step 4: Deploy Reserve Implementation

```bash
forge create \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --legacy \
  src/concrete/ConcreteReserveVault.sol:ConcreteReserveVault
```

**Save the address:**
```bash
export RESERVE_IMPL=0x...
```

**Example:**
```
RESERVE_IMPL=0x7d1005d24E49883d38B375d762dfbfEFbd5d3A5C
```

---

## 📦 Phase 2: Deploy Vault Proxies

Now we deploy the actual vaults as upgradeable proxies.

### Step 5: Create Setup Script

This makes it easier to manage all addresses:

```bash
cd /home/amschel/stratosphere/LiquidRoyaltyContracts

cat > setup_env.sh << 'EOF'
#!/bin/bash
# Implementation addresses
export SENIOR_IMPL=0x...  # YOUR SENIOR IMPL
export JUNIOR_IMPL=0x...  # YOUR JUNIOR IMPL
export RESERVE_IMPL=0x... # YOUR RESERVE IMPL

# Token addresses
export STABLECOIN_ADDRESS=0x...  # YOUR STABLECOIN
export SAILR_ADDRESS=0x...       # YOUR VOLATILE TOKEN
export KODIAK_ISLAND_ADDRESS=0x... # YOUR LP TOKEN

echo "✅ Environment variables set!"
EOF

chmod +x setup_env.sh
```

**Edit the script with your actual addresses!**

---

### Step 6: Deploy Junior Vault Proxy (First!)

⚠️ **Order matters!** Deploy Junior → Reserve → Senior

```bash
source setup_env.sh && source .env && \
forge script script/DeployJuniorProxy.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --legacy \
  --slow
```

**Save the output:**
```bash
export JUNIOR_VAULT=0x...  # Copy from script output
```

**Add to setup_env.sh:**
```bash
echo "export JUNIOR_VAULT=0x..." >> setup_env.sh
```

**Example:**
```
JUNIOR_VAULT=0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883
```

---

### Step 7: Deploy Reserve Vault Proxy (Second!)

```bash
source setup_env.sh && source .env && \
forge script script/DeployReserveProxy.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --legacy \
  --slow
```

**Save the output:**
```bash
export RESERVE_VAULT=0x...
```

**Add to setup_env.sh:**
```bash
echo "export RESERVE_VAULT=0x..." >> setup_env.sh
```

**Example:**
```
RESERVE_VAULT=0x7754272c866892CaD4a414C76f060645bDc27203
```

---

### Step 8: Deploy Senior Vault Proxy (Last!)

```bash
source setup_env.sh && source .env && \
forge script script/DeploySeniorProxy.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --legacy \
  --slow
```

**Save the output:**
```bash
export SENIOR_VAULT=0x...
```

**Add to setup_env.sh:**
```bash
echo "export SENIOR_VAULT=0x..." >> setup_env.sh
```

**Example:**
```
SENIOR_VAULT=0x78a352318C4aD88ca14f84b200962E797e80D033
```

---

## 🔐 Phase 3: Set Admin Access (CRITICAL!)

⚠️ **IMPORTANT**: The vaults initialize with `admin = address(0)`. You MUST set the admin before doing anything else!

### Step 9: Set Admin on All Vaults

```bash
# Get your deployer address
DEPLOYER=$(cast wallet address --private-key $PRIVATE_KEY)

# Set admin on Senior Vault
source setup_env.sh && source .env && \
cast send $SENIOR_VAULT \
  "setAdmin(address)" \
  $DEPLOYER \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# Set admin on Junior Vault
source setup_env.sh && source .env && \
cast send $JUNIOR_VAULT \
  "setAdmin(address)" \
  $DEPLOYER \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# Set admin on Reserve Vault
source setup_env.sh && source .env && \
cast send $RESERVE_VAULT \
  "setAdmin(address)" \
  $DEPLOYER \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

**Verify admin is set:**
```bash
source setup_env.sh && source .env && \
echo "Your address:" && cast wallet address --private-key $PRIVATE_KEY && \
echo "Senior admin:" && cast call $SENIOR_VAULT "admin()(address)" --rpc-url $RPC_URL && \
echo "Junior admin:" && cast call $JUNIOR_VAULT "admin()(address)" --rpc-url $RPC_URL && \
echo "Reserve admin:" && cast call $RESERVE_VAULT "admin()(address)" --rpc-url $RPC_URL
```

**They should all match your deployer address!**

---

## 🔗 Phase 4: Connect Vaults to Each Other

Vaults need to know about each other for spillover mechanics.

### Step 10: Connect Senior to Junior & Reserve

```bash
source setup_env.sh && source .env && \
cast send $SENIOR_VAULT \
  "updateJuniorReserve(address,address)" \
  $JUNIOR_VAULT \
  $RESERVE_VAULT \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

---

### Step 11: Connect Junior to Senior

```bash
source setup_env.sh && source .env && \
cast send $JUNIOR_VAULT \
  "setSeniorVault(address)" \
  $SENIOR_VAULT \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

---

### Step 12: Connect Reserve to Senior

```bash
source setup_env.sh && source .env && \
cast send $RESERVE_VAULT \
  "setSeniorVault(address)" \
  $SENIOR_VAULT \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

**Verify connections:**
```bash
source setup_env.sh && source .env && \
echo "Senior → Junior:" && cast call $SENIOR_VAULT "juniorVault()(address)" --rpc-url $RPC_URL && \
echo "Senior → Reserve:" && cast call $SENIOR_VAULT "reserveVault()(address)" --rpc-url $RPC_URL && \
echo "Junior → Senior:" && cast call $JUNIOR_VAULT "seniorVault()(address)" --rpc-url $RPC_URL && \
echo "Reserve → Senior:" && cast call $RESERVE_VAULT "seniorVault()(address)" --rpc-url $RPC_URL
```

---

## 🪝 Phase 5: Deploy and Connect Hooks

Each vault needs a hook to manage Kodiak LP tokens.

### Step 13: Deploy All Three Hooks

```bash
source setup_env.sh && source .env && \
forge script script/DeployHooks.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --legacy \
  --slow
```

**Save all three addresses from output:**
```bash
export SENIOR_HOOK=0x...
export JUNIOR_HOOK=0x...
export RESERVE_HOOK=0x...
```

**Add to setup_env.sh:**
```bash
cat >> setup_env.sh << 'EOF'
export SENIOR_HOOK=0x...
export JUNIOR_HOOK=0x...
export RESERVE_HOOK=0x...
EOF
```

**Example:**
```
SENIOR_HOOK=0xa5Af193E027bE91EFF4CC042cC79E0782F5472AC
JUNIOR_HOOK=0xC6A224385e14dED076D86c69a91E42142698D1f1
RESERVE_HOOK=0xBe01A06f99f8366f8803A61332e110d1235E5f3C
```

---

### Step 14: Connect Hooks to Vaults

⚠️ **Note**: This automatically whitelists hooks as LP recipients!

```bash
# Connect Senior Hook
source setup_env.sh && source .env && \
cast send $SENIOR_VAULT \
  "setKodiakHook(address)" \
  $SENIOR_HOOK \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# Connect Junior Hook
source setup_env.sh && source .env && \
cast send $JUNIOR_VAULT \
  "setKodiakHook(address)" \
  $JUNIOR_HOOK \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# Connect Reserve Hook
source setup_env.sh && source .env && \
cast send $RESERVE_VAULT \
  "setKodiakHook(address)" \
  $RESERVE_HOOK \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

**Verify connections:**
```bash
source setup_env.sh && source .env && \
echo "Senior Hook:" && cast call $SENIOR_VAULT "kodiakHook()(address)" --rpc-url $RPC_URL && \
echo "Junior Hook:" && cast call $JUNIOR_VAULT "kodiakHook()(address)" --rpc-url $RPC_URL && \
echo "Reserve Hook:" && cast call $RESERVE_VAULT "kodiakHook()(address)" --rpc-url $RPC_URL
```

---

## ⚙️ Phase 6: Configure Hooks with Kodiak

### Step 15: Add Kodiak Addresses to Setup Script

```bash
cat >> setup_env.sh << 'EOF'
# Kodiak configuration
export KODIAK_ROUTER_ADDRESS=0x...  # YOUR ROUTER
export TREASURY=0x...               # YOUR TREASURY
EOF
```

---

### Step 16: Configure Senior Hook

```bash
source setup_env.sh && source .env && \
cast send $SENIOR_HOOK \
  "setIsland(address)" \
  $KODIAK_ISLAND_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

source setup_env.sh && source .env && \
cast send $SENIOR_HOOK \
  "setRouter(address)" \
  $KODIAK_ROUTER_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

---

### Step 17: Configure Junior Hook

```bash
source setup_env.sh && source .env && \
cast send $JUNIOR_HOOK \
  "setIsland(address)" \
  $KODIAK_ISLAND_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

source setup_env.sh && source .env && \
cast send $JUNIOR_HOOK \
  "setRouter(address)" \
  $KODIAK_ROUTER_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

---

### Step 18: Configure Reserve Hook

```bash
source setup_env.sh && source .env && \
cast send $RESERVE_HOOK \
  "setIsland(address)" \
  $KODIAK_ISLAND_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

source setup_env.sh && source .env && \
cast send $RESERVE_HOOK \
  "setRouter(address)" \
  $KODIAK_ROUTER_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

**Verify hook configuration:**
```bash
source setup_env.sh && source .env && \
echo "Senior Hook Island:" && cast call $SENIOR_HOOK "island()(address)" --rpc-url $RPC_URL && \
echo "Senior Hook Router:" && cast call $SENIOR_HOOK "router()(address)" --rpc-url $RPC_URL
```

---

## 🎯 Phase 7: Whitelist LP Tokens

### Step 19: Whitelist Kodiak LP Token on All Vaults

```bash
source setup_env.sh && source .env && \
cast send $SENIOR_VAULT \
  "addWhitelistedLPToken(address)" \
  $KODIAK_ISLAND_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

source setup_env.sh && source .env && \
cast send $JUNIOR_VAULT \
  "addWhitelistedLPToken(address)" \
  $KODIAK_ISLAND_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

source setup_env.sh && source .env && \
cast send $RESERVE_VAULT \
  "addWhitelistedLPToken(address)" \
  $KODIAK_ISLAND_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

**Verify:**
```bash
source setup_env.sh && source .env && \
cast call $SENIOR_VAULT "isWhitelistedLPToken(address)(bool)" $KODIAK_ISLAND_ADDRESS --rpc-url $RPC_URL
```

---

## 💰 Phase 8: Configure Treasury & Fees

### Step 20: Set Treasury Address (Where Fees Go)

```bash
source setup_env.sh && source .env && \
cast send $SENIOR_VAULT \
  "setTreasury(address)" \
  $TREASURY \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

source setup_env.sh && source .env && \
cast send $JUNIOR_VAULT \
  "setTreasury(address)" \
  $TREASURY \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

source setup_env.sh && source .env && \
cast send $RESERVE_VAULT \
  "setTreasury(address)" \
  $TREASURY \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

**Verify:**
```bash
source setup_env.sh && source .env && \
echo "Senior treasury:" && cast call $SENIOR_VAULT "treasury()(address)" --rpc-url $RPC_URL && \
echo "Junior treasury:" && cast call $JUNIOR_VAULT "treasury()(address)" --rpc-url $RPC_URL && \
echo "Reserve treasury:" && cast call $RESERVE_VAULT "treasury()(address)" --rpc-url $RPC_URL
```

---

### Step 21: Configure Fee Schedules (Junior & Reserve)

Set to 30 days (2592000 seconds):

```bash
source setup_env.sh && source .env && \
cast send $JUNIOR_VAULT \
  "setMgmtFeeSchedule(uint256)" \
  2592000 \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

source setup_env.sh && source .env && \
cast send $RESERVE_VAULT \
  "setMgmtFeeSchedule(uint256)" \
  2592000 \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

**Fee schedule options:**
- 1 day: `86400`
- 7 days: `604800`
- 30 days: `2592000`
- 90 days: `7776000`

**Verify:**
```bash
source setup_env.sh && source .env && \
echo "Junior fee schedule:" && cast call $JUNIOR_VAULT "getMgmtFeeSchedule()(uint256)" --rpc-url $RPC_URL && \
echo "Reserve fee schedule:" && cast call $RESERVE_VAULT "getMgmtFeeSchedule()(uint256)" --rpc-url $RPC_URL
```

---

## 🌱 Phase 9: Add Seeders (Optional)

If you have specific addresses that should be able to seed vaults:

### Step 22: Add Seeders to All Vaults

```bash
# Add seeder addresses to setup script
cat >> setup_env.sh << 'EOF'
export SEEDER1=0x...
export SEEDER2=0x...
EOF
```

**Add Seeder 1:**
```bash
source setup_env.sh && source .env && \
cast send $SENIOR_VAULT "addSeeder(address)" $SEEDER1 --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy && \
cast send $JUNIOR_VAULT "addSeeder(address)" $SEEDER1 --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy && \
cast send $RESERVE_VAULT "addSeeder(address)" $SEEDER1 --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy
```

**Add Seeder 2 (if needed):**
```bash
source setup_env.sh && source .env && \
cast send $SENIOR_VAULT "addSeeder(address)" $SEEDER2 --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy && \
cast send $JUNIOR_VAULT "addSeeder(address)" $SEEDER2 --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy && \
cast send $RESERVE_VAULT "addSeeder(address)" $SEEDER2 --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy
```

---

## 🔧 Phase 10: Reserve-Specific Configuration

The Reserve vault has unique functionality for non-stablecoin assets.

### Step 23: Set Kodiak Router on Reserve Vault

```bash
source setup_env.sh && source .env && \
cast send $RESERVE_VAULT \
  "setKodiakRouter(address)" \
  $KODIAK_ROUTER_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

**Why?** Reserve can accept Sail.r tokens and convert them to LP using `investInKodiak()`.

**Verify:**
```bash
source setup_env.sh && source .env && \
cast call $RESERVE_VAULT "kodiakRouter()(address)" --rpc-url $RPC_URL
```

---

## ✅ Final Verification

### Step 24: Complete System Check

```bash
source setup_env.sh && source .env && \
echo "=== VAULT NAMES & SYMBOLS ===" && \
echo "Senior:" && cast call $SENIOR_VAULT "name()(string)" --rpc-url $RPC_URL && cast call $SENIOR_VAULT "symbol()(string)" --rpc-url $RPC_URL && \
echo "Junior:" && cast call $JUNIOR_VAULT "name()(string)" --rpc-url $RPC_URL && cast call $JUNIOR_VAULT "symbol()(string)" --rpc-url $RPC_URL && \
echo "Reserve:" && cast call $RESERVE_VAULT "name()(string)" --rpc-url $RPC_URL && cast call $RESERVE_VAULT "symbol()(string)" --rpc-url $RPC_URL
```

**Expected output:**
```
Senior:
"Senior Tranche"
"snrUSD"
Junior:
"Junior Tranche"
"jnr"
Reserve:
"Alar"
"alar"
```

---

## 🎉 Deployment Complete!

### What You've Deployed:

✅ **3 Vault Implementations** (upgradeable blueprints)
✅ **3 Vault Proxies** (actual vaults with custom names)
✅ **3 Hooks** (Kodiak LP managers)
✅ **All Connections** (vaults know each other)
✅ **All Configuration** (treasury, fees, LP tokens)

---

## 📋 Your Deployed Addresses

Save these in a safe place:

```bash
# Example from our deployment:
SENIOR_VAULT=0x78a352318C4aD88ca14f84b200962E797e80D033
JUNIOR_VAULT=0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883
RESERVE_VAULT=0x7754272c866892CaD4a414C76f060645bDc27203

SENIOR_HOOK=0xa5Af193E027bE91EFF4CC042cC79E0782F5472AC
JUNIOR_HOOK=0xC6A224385e14dED076D86c69a91E42142698D1f1
RESERVE_HOOK=0xBe01A06f99f8366f8803A61332e110d1235E5f3C
```

---

## 🚀 What's Next?

### Users Can Now:
1. **Deposit USDE** into any vault
2. **Deposit LP tokens** (with pending approval system)
3. **Withdraw** (7-day cooldown for Senior)

### As Admin, You Can:
1. **Execute rebases** (update vault values with LP prices)
2. **Deploy liquidity to Kodiak** (`deployToKodiak()`)
3. **Mint management fees** (Junior/Reserve, per schedule)
4. **Seed vaults** with initial LP tokens
5. **Manage parameters** (treasury, fees, whitelists)

---

## 📖 Key Architectural Details

### Why This Order?
1. **Junior → Reserve → Senior**: Senior needs Junior & Reserve addresses during initialization
2. **Set Admin First**: All functions require admin, must be set immediately after deployment
3. **Connect Vaults**: Spillover mechanics require vaults to know each other
4. **Hooks Auto-Whitelist**: `setKodiakHook()` automatically whitelists the hook as LP recipient

### Reserve Vault Special Features
- Can accept **Sail.r** (non-stablecoin) directly via `seedReserveWithToken()`
- Can convert Sail.r to LP via `investInKodiak()`
- Needs `kodiakRouter` set on the vault itself (not just the hook)

### Fee Structure
- **Senior**: 1% management + ~2% performance (monthly), 1% withdrawal, 20% early penalty
- **Junior**: 1% of supply (configurable schedule), 1% withdrawal
- **Reserve**: 1% of supply (configurable schedule), 1% withdrawal

---

## 🐛 Common Issues & Solutions

### Issue 1: "OnlyAdmin" Error
**Problem**: Admin not set yet  
**Solution**: Run Step 9 to set admin on all vaults

### Issue 2: "LPAlreadyWhitelisted" Error
**Problem**: Trying to whitelist hooks manually  
**Solution**: Hooks are auto-whitelisted by `setKodiakHook()`, skip manual whitelisting

### Issue 3: Wrong Vault Names
**Problem**: Names don't match custom values  
**Solution**: Check `script/DeployJuniorProxy.s.sol` and `script/DeployReserveProxy.s.sol` - they should pass name/symbol to initialize

### Issue 4: Can't Call Functions
**Problem**: Functions revert with "execution reverted"  
**Solution**: Verify you're the admin and all connections are set up

---

## 🔒 Security Checklist

Before going live:

- [ ] Private keys are secure and backed up
- [ ] Admin address is correct and accessible
- [ ] Treasury address is correct
- [ ] All vault connections verified
- [ ] All hook configurations verified
- [ ] LP tokens whitelisted
- [ ] Fee schedules set correctly
- [ ] Block explorer verification done (optional)
- [ ] Test deposit/withdrawal on testnet first

---

## 📚 Additional Resources

- **Architecture**: See `CONTRACT_ARCHITECTURE.md`
- **Operations**: See `OPERATIONS_MANUAL.md`
- **Full Guide**: See `DEPLOYMENT_GUIDE.md`
- **Math Spec**: See `math_spec.md`

---

**🎊 Congratulations! Your vault system is fully deployed and operational!**

