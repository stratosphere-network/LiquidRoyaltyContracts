# 🚀 Deployment Guide - Berachain

Complete step-by-step guide for deploying the Liquid Royalty Protocol on Berachain with Kodiak integration.

---

## Prerequisites

1. **Token Addresses**
   - Stablecoin address (e.g., HONEY)
   - Other pool token address (e.g., WBTC)

2. **Kodiak Setup** (Do this BEFORE deployment)
   - Create V3 pool on Kodiak Finance
   - Create Kodiak Island (LP pool)
   - Get Kodiak Island address (LP token)
   - Get Kodiak Island Router address

3. **Environment**
   - Foundry installed
   - `.env` file configured with `PRIVATE_KEY` and `RPC_URL`
   - Deployer wallet funded with BERA for gas

---

## Step 1: Deploy Vault Implementations

Deploy the implementation contracts for all 3 vaults.

### Senior Vault Implementation
```bash
forge create src/concrete/UnifiedConcreteSeniorVault.sol:UnifiedConcreteSeniorVault \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --legacy \
  --broadcast
```

### Junior Vault Implementation
```bash
forge create src/concrete/ConcreteJuniorVault.sol:ConcreteJuniorVault \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --legacy \
  --broadcast
```

### Reserve Vault Implementation
```bash
forge create src/concrete/ConcreteReserveVault.sol:ConcreteReserveVault \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --legacy \
  --broadcast
```

**Save the deployed addresses** to environment variables:
```bash
export SENIOR_IMPL=0x...
export JUNIOR_IMPL=0x...
export RESERVE_IMPL=0x...
```

---

## Step 2: Deploy Vault Proxies

Deploy the proxy contracts that users will interact with.

### Set Required Variables
```bash
export STABLECOIN_ADDRESS=0x...  # HONEY address
export SENIOR_IMPL=0x...
export JUNIOR_IMPL=0x...
export RESERVE_IMPL=0x...
```

### Deploy Junior Vault Proxy
```bash
forge script script/DeployJuniorProxy.s.sol:DeployJuniorProxy \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --legacy
```

### Deploy Reserve Vault Proxy
```bash
forge script script/DeployReserveProxy.s.sol:DeployReserveProxy \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --legacy
```

### Deploy Senior Vault Proxy
```bash
export JUNIOR_VAULT=0x...   # From previous step
export RESERVE_VAULT=0x...  # From previous step

forge script script/DeploySeniorProxy.s.sol:DeploySeniorProxy \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --legacy
```

**Save the proxy addresses:**
```bash
export JUNIOR_VAULT=0x...
export RESERVE_VAULT=0x...
export SENIOR_VAULT=0x...
```

---

## Step 3: Configure Vaults

Set admin and connect the vaults together.

```bash
export JUNIOR_VAULT=0x...
export RESERVE_VAULT=0x...
export SENIOR_VAULT=0x...

forge script script/ConfigureVaults.s.sol:ConfigureVaults \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --legacy
```

This script will:
- ✅ Set deployer as admin on all vaults
- ✅ Update Junior & Reserve to point to Senior vault
- ✅ Initialize vault values to 0

---

## Step 4: Deploy Kodiak Hooks

Deploy one hook contract for each vault.

```bash
export SENIOR_VAULT=0x...
export JUNIOR_VAULT=0x...
export RESERVE_VAULT=0x...
export STABLECOIN_ADDRESS=0x...

forge script script/DeployHooks.s.sol:DeployHooks \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --legacy
```

**Save the hook addresses:**
```bash
export SENIOR_HOOK=0x...
export JUNIOR_HOOK=0x...
export RESERVE_HOOK=0x...
```

---

## Step 5: Configure Hooks

Set Kodiak Router and Island on all hooks.

```bash
export SENIOR_HOOK=0x...
export JUNIOR_HOOK=0x...
export RESERVE_HOOK=0x...
export KODIAK_ROUTER_ADDRESS=0x...  # Kodiak Island Router
export KODIAK_ISLAND_ADDRESS=0x...  # Kodiak Island (LP token)

forge script script/ConfigureHooks.s.sol:ConfigureHooks \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --legacy
```

---

## Step 6: Connect Hooks to Vaults

Link each hook to its corresponding vault.

```bash
export SENIOR_VAULT=0x...
export JUNIOR_VAULT=0x...
export RESERVE_VAULT=0x...
export SENIOR_HOOK=0x...
export JUNIOR_HOOK=0x...
export RESERVE_HOOK=0x...

forge script script/ConnectHooksToVaults.s.sol:ConnectHooksToVaults \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --legacy
```

---

## Step 7: Configure Oracle

**IMPORTANT**: First check which token is token0 in the Kodiak Island:

```bash
export KODIAK_ISLAND_ADDRESS=0x...
cast call $KODIAK_ISLAND_ADDRESS "token0()" --rpc-url $RPC_URL
```

Compare the result with your stablecoin address to determine if stablecoin is token0 or token1.

### Deploy Oracle Configuration
```bash
export SENIOR_VAULT=0x...
export JUNIOR_VAULT=0x...
export RESERVE_VAULT=0x...
export KODIAK_ISLAND_ADDRESS=0x...

forge script script/ConfigureOracle.s.sol:ConfigureOracle \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --legacy
```

**Note**: The script assumes stablecoin is token1. If it's token0, edit the script and change `false` to `true` in the `configureOracle` calls.

Oracle settings:
- Max deviation: 5%
- Validation: Enabled
- Mode: Automatic LP price calculation

---

## Step 8: Whitelist LP Token

Allow vaults to transfer LP tokens between each other (required for spillover/backstop).

```bash
export SENIOR_VAULT=0x...
export JUNIOR_VAULT=0x...
export RESERVE_VAULT=0x...
export KODIAK_ISLAND_ADDRESS=0x...

forge script script/WhitelistLPToken.s.sol:WhitelistLPToken \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --legacy
```

---

## ✅ Verification

Verify the deployment is correct:

```bash
export SENIOR_VAULT=0x...
export JUNIOR_VAULT=0x...
export RESERVE_VAULT=0x...
export SENIOR_HOOK=0x...
export JUNIOR_HOOK=0x...
export RESERVE_HOOK=0x...

forge script script/VerifyDeployment.s.sol:VerifyDeployment \
  --rpc-url $RPC_URL
```

---

## 🎯 Deployment Complete!

Your vaults are now deployed and configured. Check `DEPLOYMENT_SUMMARY.md` for all contract addresses.

### Next Steps

1. **Test Deposits**
   - Approve HONEY for vaults
   - Test deposit/withdraw operations

2. **Test Oracle**
   - Check LP price calculations
   - Verify vault value calculations

3. **Security**
   - Transfer admin to multi-sig wallet
   - Set up monitoring

4. **Documentation**
   - Save all addresses securely
   - Document admin procedures

---

## 📝 Quick Reference

All deployment scripts are in the `/script` directory:
- `DeployJuniorProxy.s.sol`
- `DeployReserveProxy.s.sol`
- `DeploySeniorProxy.s.sol`
- `ConfigureVaults.s.sol`
- `DeployHooks.s.sol`
- `ConfigureHooks.s.sol`
- `ConnectHooksToVaults.s.sol`
- `ConfigureOracle.s.sol`
- `WhitelistLPToken.s.sol`
- `VerifyDeployment.s.sol`

---

## 🆘 Troubleshooting

### Common Issues

1. **"OnlyAdmin" Error**
   - Admin not set yet
   - Run ConfigureVaults script first

2. **Type Conversion Error**
   - Use `payable()` cast for hook addresses
   - Already fixed in provided scripts

3. **Oracle Configuration**
   - Check if stablecoin is token0 or token1
   - Edit ConfigureOracle.s.sol if needed

4. **Gas Estimation Failed**
   - Check RPC_URL is correct
   - Ensure wallet has BERA for gas

---

For detailed deployment information, see `DEPLOYMENT_SUMMARY.md`
