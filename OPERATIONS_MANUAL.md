# 🔧 Operations Manual - Senior Tranche Protocol

## Operations Reference Table

| Operation | Role | Frequency | Command | Notes |
|-----------|------|-----------|---------|-------|
| **Rebase Senior Vault** | Admin | Monthly | `cast send $SENIOR_VAULT "rebase(uint256)" $LP_PRICE_USD --private-key $PRIVATE_KEY --rpc-url $RPC_URL --gas-limit 3000000 --legacy` | Get LP price from Enso API. Triggers spillover/backstop. Mints 1% management fee to treasury. Critical for system health. |
| **Mint Performance Fee (Junior/Reserve)** | Admin | Per schedule | `cast send $JUNIOR_VAULT "mintPerformanceFee()" --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` | Mints 1% of circulating supply to treasury. Only works if schedule elapsed since last mint. |
| **Update Junior Vault Value** | Admin | As needed | `cast send $JUNIOR_VAULT "updateValue(uint256)" $NEW_VALUE_USD --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` | Update after significant market moves or LP price changes. Affects unstaking ratio. |
| **Update Reserve Vault Value** | Admin | As needed | `cast send $RESERVE_VAULT "updateValue(uint256)" $NEW_VALUE_USD --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` | Update after significant market moves or LP price changes. Affects unstaking ratio. |
| **Deploy HONEY to Kodiak** | Admin | After deposits | `cast send $SENIOR_VAULT "deployToKodiak(uint256,uint256,address,bytes,address,bytes)" $HONEY_AMOUNT $MIN_LP $ENSO_ROUTER $SWAP_DATA0 $ENSO_ROUTER $SWAP_DATA1 --private-key $PRIVATE_KEY --rpc-url $RPC_URL --gas-limit 2000000 --legacy` | Get swap data from Enso API. Converts HONEY to LP. Increases yield. |
| **Rescue HONEY Dust from Hook** | Admin | Weekly | `cast send $HOOK_ADDRESS "rescueHoneyToVault()" --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` | Recovers leftover HONEY from swaps. Small amounts. |
| **Swap WBTC Dust to Vault** | Admin | Weekly | `cast send $HOOK_ADDRESS "swapAndRescue(uint256,address,bytes)" $WBTC_AMOUNT $ENSO_ROUTER $SWAP_DATA --private-key $PRIVATE_KEY --rpc-url $RPC_URL --gas-limit 1000000 --legacy` | Get swap data from Enso. Converts WBTC dust to HONEY. |
| **Transfer LP Between Vaults** | Admin | During rebase | Automatic during `rebase()` | Spillover: Senior → Junior → Reserve. Backstop: Reserve → Junior → Senior. |
| **Whitelist New Aggregator** | Admin | Once per aggregator | `cast send $HOOK_ADDRESS "setAggregatorWhitelisted(address,bool)" $AGGREGATOR true --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` | Required before using new swap aggregator. Security measure. |
| **Whitelist New LP Token** | Admin | Once per token | `cast send $VAULT_ADDRESS "addWhitelistedLPToken(address)" $LP_TOKEN --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` | Required to accept new Kodiak Island LP tokens. |
| **Add Whitelisted LP Recipient** | Admin | As needed | `cast send $VAULT_ADDRESS "addWhitelistedLP(address)" $RECIPIENT --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` | Required for hook or new recipient to receive LP tokens. |
| **Add Whitelisted Depositor** | Admin | As needed | `cast send $SENIOR_VAULT "addWhitelistedDepositor(address)" $USER --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` | Senior vault only. Restricts who can deposit. |
| **Pause Vault** | Admin | Emergency | `cast send $VAULT_ADDRESS "pause()" --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` | Stops all deposits/withdrawals. Use for emergencies only. |
| **Unpause Vault** | Admin | After fix | `cast send $VAULT_ADDRESS "unpause()" --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` | Resumes normal operations after emergency. |
| **Change Admin** | Admin | Rare | `cast send $VAULT_ADDRESS "changeAdmin(address)" $NEW_ADMIN --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` | Transfer admin control. Use multisig recommended. |
| **Update Treasury** | Admin | Rare | `cast send $VAULT_ADDRESS "setTreasury(address)" $NEW_TREASURY --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` | Change treasury address for withdrawal fees and performance fees. Required for fee collection. |
| **Set Fee Schedule (Junior/Reserve)** | Admin | Once or rare | `cast send $JUNIOR_VAULT "setMgmtFeeSchedule(uint256)" $SECONDS --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` | Configure how often performance fees can be minted. Examples: 86400 (1 day), 604800 (7 days), 2592000 (30 days). |
| **Seed Vault with LP Tokens** | Admin | Initial setup | `cast send $VAULT_ADDRESS "seedVault(address,uint256,address,uint256)" $LP_TOKEN $AMOUNT $PROVIDER $LP_PRICE --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` | Bootstrap vaults with pre-deployed LP. Provider must approve LP transfer first. Calculates value and mints shares. |
| **Upgrade Vault Implementation** | Admin | When needed | `cast send $PROXY "upgradeToAndCall(address,bytes)" $NEW_IMPL "0x" --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` | Deploy new implementation first. UUPS upgrade. Test thoroughly! |
| **Deposit (User)** | User | Anytime | `vault.deposit(amount, receiver)` via frontend or cast | Requires HONEY approval first. 7-day cooldown starts. |
| **Withdraw (User)** | User | After cooldown | `vault.withdraw(amount, receiver, owner)` via frontend | Requires 7-day cooldown completed. May liquidate LP. |
| **Redeem (User)** | User | After cooldown | `vault.redeem(shares, receiver, owner)` via frontend | Burns shares, gets HONEY. Alternative to withdraw. |
| **Initiate Cooldown (User)** | User | Before withdraw | `vault.initiateCooldown()` via frontend | Required 7 days before withdrawal. Senior vault only. |

---

## Quick Operation Workflows

### 🔄 Monthly Rebase Workflow

```bash
# 1. Get LP price from Enso
LP_PRICE=$(curl -s "https://api.enso.finance/api/v1/price?chainId=80094&address=$KODIAK_ISLAND_ADDRESS" | jq -r '.price')

# 2. Convert to wei (18 decimals)
LP_PRICE_WEI=$(echo "$LP_PRICE * 10^18" | bc)

# 3. Execute rebase
cast send $SENIOR_VAULT "rebase(uint256)" $LP_PRICE_WEI \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --gas-limit 3000000 \
  --legacy

# 4. Check backing ratio
cast call $SENIOR_VAULT "backingRatio()(uint256)" --rpc-url $RPC_URL
```

---

### 💰 Deploy Capital to Kodiak Workflow

```bash
# 1. Check vault HONEY balance
HONEY_BALANCE=$(cast call $HONEY_ADDRESS "balanceOf(address)(uint256)" $SENIOR_VAULT --rpc-url $RPC_URL)

# 2. Decide how much to deploy (e.g., 10k HONEY)
DEPLOY_AMOUNT=10000000000000000000000  # 10k with 18 decimals

# 3. Get swap data from Enso API
./get_enso_route.sh $DEPLOY_AMOUNT $SENIOR_VAULT

# 4. Extract data from response
SWAP_DATA_0=$(jq -r '.tx.data' enso_route_output.json)
AGGREGATOR=$(jq -r '.tx.to' enso_route_output.json)

# 5. Deploy to Kodiak
cast send $SENIOR_VAULT \
  "deployToKodiak(uint256,uint256,address,bytes,address,bytes)" \
  $DEPLOY_AMOUNT \
  0 \
  $AGGREGATOR \
  $SWAP_DATA_0 \
  $AGGREGATOR \
  "0x" \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --gas-limit 2000000 \
  --legacy

# 6. Verify LP in hook
cast call $KODIAK_ISLAND_ADDRESS "balanceOf(address)(uint256)" $SENIOR_HOOK --rpc-url $RPC_URL
```

---

### 🧹 Weekly Dust Recovery Workflow

```bash
# 1. Check HONEY dust in hook
HONEY_DUST=$(cast call $HONEY_ADDRESS "balanceOf(address)(uint256)" $SENIOR_HOOK --rpc-url $RPC_URL)

# 2. Rescue HONEY to vault
if [ "$HONEY_DUST" -gt "0" ]; then
  cast send $SENIOR_HOOK "rescueHoneyToVault()" \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL \
    --legacy
fi

# 3. Check WBTC dust in hook
WBTC_DUST=$(cast call $WBTC_ADDRESS "balanceOf(address)(uint256)" $SENIOR_HOOK --rpc-url $RPC_URL)

# 4. Get swap data for WBTC → HONEY
./vault-dashboard/src/utils/get_wbtc_swap.sh $WBTC_DUST $SENIOR_HOOK

# 5. Swap and rescue WBTC
if [ "$WBTC_DUST" -gt "0" ]; then
  SWAP_DATA=$(jq -r '.tx.data' wbtc_swap_output.json)
  AGGREGATOR=$(jq -r '.tx.to' wbtc_swap_output.json)
  
  cast send $SENIOR_HOOK \
    "swapAndRescue(uint256,address,bytes)" \
    $WBTC_DUST \
    $AGGREGATOR \
    $SWAP_DATA \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 1000000 \
    --legacy
fi

# 6. Repeat for Junior and Reserve hooks
```

---

### 📊 Value Update Workflow (Junior/Reserve)

```bash
# 1. Calculate current value
# Total = HONEY in vault + WBTC in vault (in USD) + LP in hook (in USD)

VAULT_HONEY=$(cast call $HONEY_ADDRESS "balanceOf(address)(uint256)" $JUNIOR_VAULT --rpc-url $RPC_URL)
HOOK_LP=$(cast call $KODIAK_ISLAND_ADDRESS "balanceOf(address)(uint256)" $JUNIOR_HOOK --rpc-url $RPC_URL)

# Get prices from Enso
WBTC_PRICE=$(curl -s "https://api.enso.finance/api/v1/price?chainId=80094&address=$WBTC_ADDRESS" | jq -r '.price')
LP_PRICE=$(curl -s "https://api.enso.finance/api/v1/price?chainId=80094&address=$KODIAK_ISLAND_ADDRESS" | jq -r '.price')

# Calculate total value in USD (implement in script)
TOTAL_VALUE_USD=...

# 2. Convert to wei
TOTAL_VALUE_WEI=$(echo "$TOTAL_VALUE_USD * 10^18" | bc)

# 3. Update vault value
cast send $JUNIOR_VAULT "updateValue(uint256)" $TOTAL_VALUE_WEI \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# 4. Check unstaking ratio
cast call $JUNIOR_VAULT "unstakingRatio()(uint256)" --rpc-url $RPC_URL
```

---

### 💸 Performance Fee Minting Workflow (Junior/Reserve)

```bash
# 1. Check if fee can be minted
CAN_MINT=$(cast call $JUNIOR_VAULT "canMintPerformanceFee()(bool)" --rpc-url $RPC_URL)

if [ "$CAN_MINT" = "true" ]; then
  echo "✅ Fee schedule elapsed, can mint"
  
  # 2. Check time since last mint
  LAST_MINT=$(cast call $JUNIOR_VAULT "getLastMintTime()(uint256)" --rpc-url $RPC_URL)
  echo "Last minted at: $LAST_MINT"
  
  # 3. Mint performance fee (1% of supply)
  cast send $JUNIOR_VAULT "mintPerformanceFee()" \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL \
    --legacy
  
  # 4. Verify treasury received tokens
  TREASURY=$(cast call $JUNIOR_VAULT "treasury()(address)" --rpc-url $RPC_URL)
  TREASURY_BAL=$(cast call $JUNIOR_VAULT "balanceOf(address)(uint256)" $TREASURY --rpc-url $RPC_URL)
  echo "Treasury balance: $TREASURY_BAL"
else
  # Check time until next mint
  TIME_UNTIL=$(cast call $JUNIOR_VAULT "getTimeUntilNextMint()(uint256)" --rpc-url $RPC_URL)
  echo "⏳ Cannot mint yet. Time remaining: $TIME_UNTIL seconds"
fi

# 5. Repeat for Reserve vault
```

---

### 🏦 Initial Treasury & Fee Setup Workflow

```bash
# IMPORTANT: Run this ONCE after deployment or upgrade

# 1. Set treasury address on all vaults
TREASURY_ADDRESS=0x...  # Your treasury wallet

cast send $SENIOR_VAULT "setTreasury(address)" $TREASURY_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

cast send $JUNIOR_VAULT "setTreasury(address)" $TREASURY_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

cast send $RESERVE_VAULT "setTreasury(address)" $TREASURY_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# 2. Configure performance fee schedule for Junior (e.g., 30 days)
cast send $JUNIOR_VAULT "setMgmtFeeSchedule(uint256)" 2592000 \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# 3. Configure performance fee schedule for Reserve (e.g., 30 days)
cast send $RESERVE_VAULT "setMgmtFeeSchedule(uint256)" 2592000 \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# 4. Verify configuration
echo "Senior Treasury: $(cast call $SENIOR_VAULT "treasury()(address)" --rpc-url $RPC_URL)"
echo "Junior Fee Schedule: $(cast call $JUNIOR_VAULT "getMgmtFeeSchedule()(uint256)" --rpc-url $RPC_URL)"
echo "Reserve Fee Schedule: $(cast call $RESERVE_VAULT "getMgmtFeeSchedule()(uint256)" --rpc-url $RPC_URL)"
```

---

### 🌱 Seed Vault with LP Tokens Workflow

```bash
# Use this to bootstrap vaults with pre-deployed LP tokens

# 1. Get LP price from Enso or DEX
LP_PRICE=$(curl -s "https://api.enso.finance/api/v1/price?chainId=80094&address=$KODIAK_ISLAND_ADDRESS" | jq -r '.price')
LP_PRICE_WEI=$(echo "$LP_PRICE * 10^18" | bc)

# 2. Approve LP token transfer (from seed provider wallet)
SEED_PROVIDER=0x...  # Address that holds the LP tokens
LP_AMOUNT=1000000000000000000  # Amount of LP tokens (18 decimals)

cast send $KODIAK_ISLAND_ADDRESS \
  "approve(address,uint256)" \
  $SENIOR_VAULT \
  $LP_AMOUNT \
  --private-key $SEED_PROVIDER_KEY \
  --rpc-url $RPC_URL \
  --legacy

# 3. Seed the vault
cast send $SENIOR_VAULT \
  "seedVault(address,uint256,address,uint256)" \
  $KODIAK_ISLAND_ADDRESS \
  $LP_AMOUNT \
  $SEED_PROVIDER \
  $LP_PRICE_WEI \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# 4. Verify shares were minted
cast call $SENIOR_VAULT "balanceOf(address)(uint256)" $SEED_PROVIDER --rpc-url $RPC_URL

# 5. Verify LP in hook
cast call $KODIAK_ISLAND_ADDRESS "balanceOf(address)(uint256)" $SENIOR_HOOK --rpc-url $RPC_URL

# 6. Repeat for Junior and Reserve if needed
```

---

## Fee Structure Summary

### Senior Vault Fees
- **Management Fee**: 1% annually, minted as snrUSD to treasury during monthly rebase
- **Performance Fee**: ~2% of yield, minted as snrUSD to treasury during monthly rebase  
- **Withdrawal Fee**: 1% of withdrawn amount (sent to treasury in HONEY)
- **Early Withdrawal Penalty**: 20% if withdrawn before cooldown (sent to treasury in HONEY)

### Junior & Reserve Vault Fees
- **Performance Fee**: 1% of circulating supply, minted on configurable schedule (e.g., monthly, quarterly)
- **Withdrawal Fee**: 1% of withdrawn amount (sent to treasury in HONEY)

### Fee Collection
All fees are automatically sent to the configured treasury address. Make sure to set treasury using `setTreasury()` after deployment!

---

## Monitoring & Health Checks

### Health Check Commands

```bash
# Source deployment addresses
source deployed_tokens.txt

# Check Senior vault health
echo "=== SENIOR VAULT ==="
echo "Backing Ratio: $(cast call $SENIOR_VAULT "backingRatio()(uint256)" --rpc-url $RPC_URL)"
echo "Total Supply: $(cast call $SENIOR_VAULT "totalSupply()(uint256)" --rpc-url $RPC_URL)"
echo "Vault Value: $(cast call $SENIOR_VAULT "vaultValue()(uint256)" --rpc-url $RPC_URL)"
echo "HONEY Balance: $(cast call $HONEY_ADDRESS "balanceOf(address)(uint256)" $SENIOR_VAULT --rpc-url $RPC_URL)"
echo "Hook LP Balance: $(cast call $KODIAK_ISLAND_ADDRESS "balanceOf(address)(uint256)" $SENIOR_HOOK --rpc-url $RPC_URL)"

# Check Junior vault health
echo -e "\n=== JUNIOR VAULT ==="
echo "Unstaking Ratio: $(cast call $JUNIOR_VAULT "unstakingRatio()(uint256)" --rpc-url $RPC_URL)"
echo "Total Supply: $(cast call $JUNIOR_VAULT "totalSupply()(uint256)" --rpc-url $RPC_URL)"
echo "Vault Value: $(cast call $JUNIOR_VAULT "vaultValue()(uint256)" --rpc-url $RPC_URL)"
echo "Hook LP Balance: $(cast call $KODIAK_ISLAND_ADDRESS "balanceOf(address)(uint256)" $JUNIOR_HOOK --rpc-url $RPC_URL)"

# Check Reserve vault health
echo -e "\n=== RESERVE VAULT ==="
echo "Unstaking Ratio: $(cast call $RESERVE_VAULT "unstakingRatio()(uint256)" --rpc-url $RPC_URL)"
echo "Total Supply: $(cast call $RESERVE_VAULT "totalSupply()(uint256)" --rpc-url $RPC_URL)"
echo "Vault Value: $(cast call $RESERVE_VAULT "vaultValue()(uint256)" --rpc-url $RPC_URL)"
echo "Hook LP Balance: $(cast call $KODIAK_ISLAND_ADDRESS "balanceOf(address)(uint256)" $RESERVE_HOOK --rpc-url $RPC_URL)"
```

---

## Emergency Procedures

### 🚨 Emergency Pause

```bash
# Pause all vaults immediately
cast send $SENIOR_VAULT "pause()" --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy
cast send $JUNIOR_VAULT "pause()" --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy
cast send $RESERVE_VAULT "pause()" --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy

# Verify paused
cast call $SENIOR_VAULT "paused()(bool)" --rpc-url $RPC_URL
```

### 🔧 Recovery After Emergency

```bash
# 1. Fix the issue (upgrade, patch, etc.)

# 2. Verify fix in tests
forge test

# 3. Unpause vaults
cast send $SENIOR_VAULT "unpause()" --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy
cast send $JUNIOR_VAULT "unpause()" --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy
cast send $RESERVE_VAULT "unpause()" --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy

# 4. Monitor closely for 24h
```

---

## Scheduled Operations Calendar

| Operation | Frequency | Recommended Time | Priority |
|-----------|-----------|-----------------|----------|
| Rebase Senior Vault | Monthly | 1st of month, 12:00 UTC | 🔴 Critical |
| Mint Performance Fee (Junior/Reserve) | Per schedule | Based on fee schedule | 🟡 Important |
| Update Junior/Reserve Values | Weekly | Monday 08:00 UTC | 🟡 Important |
| Deploy Capital to Kodiak | As needed | After large deposits | 🟢 Normal |
| Dust Recovery | Weekly | Friday 16:00 UTC | 🟢 Normal |
| Health Check | Daily | 06:00 & 18:00 UTC | 🟡 Important |
| Frontend Updates | After upgrades | Immediately | 🔴 Critical |
| Security Review | Monthly | First Monday | 🟡 Important |

---

## Key Metrics to Monitor

| Metric | Healthy Range | Warning | Critical | Action |
|--------|--------------|---------|----------|--------|
| **Senior Backing Ratio** | 100% - 120% | 90% - 100% | < 90% | Emergency rebalance |
| **Junior Unstaking Ratio** | 1.0 - 1.5 | 0.8 - 1.0 | < 0.8 | Stop withdrawals, investigate |
| **Reserve Unstaking Ratio** | 1.0 - 2.0 | 0.8 - 1.0 | < 0.8 | Stop withdrawals, investigate |
| **LP Utilization** | 60% - 90% | 40% - 60% | < 40% | Deploy more to Kodiak |
| **Gas Usage** | < 2M per tx | 2M - 3M | > 3M | Optimize or increase limits |

---

## Automation Recommendations

### Automate with Cron Jobs

```bash
# Add to crontab: crontab -e

# Monthly rebase on 1st of month at 12:00 UTC
0 12 1 * * /path/to/scripts/monthly_rebase.sh >> /var/log/senior_rebase.log 2>&1

# Weekly value update on Mondays at 08:00 UTC
0 8 * * 1 /path/to/scripts/update_values.sh >> /var/log/senior_values.log 2>&1

# Weekly dust recovery on Fridays at 16:00 UTC
0 16 * * 5 /path/to/scripts/dust_recovery.sh >> /var/log/senior_dust.log 2>&1

# Health check twice daily
0 6,18 * * * /path/to/scripts/health_check.sh >> /var/log/senior_health.log 2>&1
```

---

## Tools & Scripts Reference

| Script | Location | Purpose |
|--------|----------|---------|
| `get_enso_route.sh` | `/` | Fetch swap data from Enso API |
| `check_island_tokens.sh` | `/` | Check LP balances in hooks |
| `check_upgrade_status.sh` | `/` | Verify upgrade completion |
| `whitelist_enso_aggregator.sh` | `/` | Whitelist Enso on all hooks |
| `deploy_to_kodiak.sh` | `/` | Interactive Kodiak deployment |

---

## Contact & Support

- **Technical Issues:** Check [TROUBLESHOOTING section in DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md#troubleshooting)
- **Architecture Questions:** See [CONTRACT_ARCHITECTURE.md](./CONTRACT_ARCHITECTURE.md)
- **Math & Logic:** See [math_spec.md](./math_spec.md)

---

**✅ Keep this manual handy for day-to-day operations!**

