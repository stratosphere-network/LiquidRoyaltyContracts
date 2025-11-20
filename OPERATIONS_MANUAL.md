# 🔧 Operations Manual - Senior Tranche Protocol

## Operations Reference Table

| Operation | Role | Frequency | Command | Notes |
|-----------|------|-----------|---------|-------|
| **Rebase Senior Vault** | Admin | Monthly | `cast send $SENIOR_VAULT "rebase(uint256)" $LP_PRICE_USD --private-key $PRIVATE_KEY --rpc-url $RPC_URL --gas-limit 3000000 --legacy` | Get LP price from Enso API. Triggers spillover/backstop. Mints 1% management fee to treasury. Critical for system health. |
| **Mint Management Fee (Junior/Reserve)** | Admin | Per schedule | `cast send $JUNIOR_VAULT "mintManagementFee()" --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` | Mints 1% of circulating supply to treasury. Only works if schedule elapsed since last mint. |
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
| **Seed Reserve with Token (WBTC)** | Admin | Initial setup | `cast send $RESERVE_VAULT "seedReserveWithToken(address,uint256,address,uint256)" $TOKEN $AMOUNT $PROVIDER $TOKEN_PRICE --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` | Reserve only! Seeds with non-stablecoin (WBTC). Token stays in vault. Provider must approve first. |
| **Invest Reserve Assets in Kodiak** | Admin | As needed | `cast send $RESERVE_VAULT "investInKodiak(...)" --private-key $PRIVATE_KEY --rpc-url $RPC_URL --gas-limit 2000000 --legacy` | Reserve only! Converts WBTC→LP. Get swap data from Enso. Similar to deployToKodiak. |
| **Set Kodiak Router (Reserve)** | Admin | Once | `cast send $RESERVE_VAULT "setKodiakRouter(address)" $KODIAK_ROUTER --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` | Reserve only! Required before investInKodiak. Sets router for swaps. |
| **Upgrade Vault Implementation** | Admin | When needed | `cast send $PROXY "upgradeToAndCall(address,bytes)" $NEW_IMPL "0x" --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` | Deploy new implementation first. UUPS upgrade. Test thoroughly! |
| **Deposit (User)** | User | Anytime | `vault.deposit(amount, receiver)` via frontend or cast | Requires HONEY approval first. 7-day cooldown starts. |
| **Deposit LP (User) - NEW!** | User | Anytime | `vault.depositLP(lpToken, amount)` via frontend | LP goes to hook, creates pending deposit. 48h expiry. Admin must approve. |
| **Approve LP Deposit** | Admin | As needed | `cast send $VAULT "approveLPDeposit(uint256,uint256)" $DEPOSIT_ID $LP_PRICE --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` | Check LP price from Enso first. Mints shares to depositor. Must be within 48h. |
| **Reject LP Deposit** | Admin | As needed | `cast send $VAULT "rejectLPDeposit(uint256,string)" $DEPOSIT_ID "reason" --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` | Returns LP to depositor. Can provide reason. |
| **Cancel Pending Deposit (User)** | User | Before approval | `vault.cancelPendingDeposit(depositId)` via frontend | Gets LP back. Only depositor can call. |
| **Claim Expired Deposit** | Anyone | After 48h | `vault.claimExpiredDeposit(depositId)` via frontend | Returns LP to original depositor. Good Samaritan mechanism. |
| **View Pending Deposits** | Anyone | Anytime | `vault.getPendingDeposit(depositId)` or `vault.getUserDepositIds(user)` | Monitor deposit queue. Check status, expiry, amounts. |
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
CAN_MINT=$(cast call $JUNIOR_VAULT "canMintManagementFee()(bool)" --rpc-url $RPC_URL)

if [ "$CAN_MINT" = "true" ]; then
  echo "✅ Fee schedule elapsed, can mint"
  
  # 2. Check time since last mint
  LAST_MINT=$(cast call $JUNIOR_VAULT "getLastMintTime()(uint256)" --rpc-url $RPC_URL)
  echo "Last minted at: $LAST_MINT"
  
  # 3. Mint performance fee (1% of supply)
  cast send $JUNIOR_VAULT "mintManagementFee()" \
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

### 🏦 Reserve Vault-Specific Operations

The Reserve vault has unique capabilities for handling non-stablecoin assets (like WBTC) in addition to standard HONEY deposits.

#### Option A: Seed Reserve with Non-Stablecoin Token (e.g., WBTC)

This is unique to Reserve vault. The token stays IN the vault (not transferred to hook immediately).

```bash
# Example: Seed Reserve with 1 WBTC at $50,000/WBTC

# 1. Get token price from Enso or oracle
TOKEN_PRICE=$(curl -s "https://api.enso.finance/api/v1/price?chainId=80094&address=$WBTC_ADDRESS" | jq -r '.price')
TOKEN_PRICE_WEI=$(echo "$TOKEN_PRICE * 10^18" | bc)

# 2. Seed provider must approve Reserve vault to transfer tokens
SEED_PROVIDER=0x...  # Address that holds the WBTC
TOKEN_AMOUNT=100000000  # 1 WBTC (8 decimals)

cast send $WBTC_ADDRESS \
  "approve(address,uint256)" \
  $RESERVE_VAULT \
  $TOKEN_AMOUNT \
  --private-key $SEED_PROVIDER_KEY \
  --rpc-url $RPC_URL \
  --legacy

# 3. Admin seeds the Reserve vault with WBTC
cast send $RESERVE_VAULT \
  "seedReserveWithToken(address,uint256,address,uint256)" \
  $WBTC_ADDRESS \
  $TOKEN_AMOUNT \
  $SEED_PROVIDER \
  $TOKEN_PRICE_WEI \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# 4. Verify WBTC is in Reserve vault (NOT in hook yet)
cast call $WBTC_ADDRESS "balanceOf(address)(uint256)" $RESERVE_VAULT --rpc-url $RPC_URL

# 5. Verify shares were minted to seed provider
cast call $RESERVE_VAULT "balanceOf(address)(uint256)" $SEED_PROVIDER --rpc-url $RPC_URL

# 6. Verify vault value increased
cast call $RESERVE_VAULT "vaultValue()(uint256)" --rpc-url $RPC_URL
```

#### Option B: Invest Reserve's Non-Stablecoin Assets into Kodiak

After seeding with WBTC (or if Reserve holds WBTC from other sources), convert it to LP tokens.

```bash
# Use investInKodiak to convert WBTC → balanced WBTC/HONEY → LP

# 1. Check Reserve's WBTC balance
WBTC_BALANCE=$(cast call $WBTC_ADDRESS "balanceOf(address)(uint256)" $RESERVE_VAULT --rpc-url $RPC_URL)

# 2. Get swap calldata from Enso API
# This swaps WBTC to balanced WBTC/HONEY and adds liquidity
# Similar to deployToKodiak but for WBTC instead of HONEY

INVEST_AMOUNT=50000000  # 0.5 WBTC

# Get Enso route for WBTC → pool tokens
curl -X GET "https://api.enso.finance/api/v1/shortcuts/route" \
  -H "Authorization: Bearer $ENSO_API_KEY" \
  -d "chainId=80094" \
  -d "fromAddress=$RESERVE_VAULT" \
  -d "receiver=$RESERVE_HOOK" \
  -d "spender=$KODIAK_ROUTER_ADDRESS" \
  -d "amountIn=$INVEST_AMOUNT" \
  -d "tokenIn=$WBTC_ADDRESS" \
  -d "tokenOut=$KODIAK_ISLAND_ADDRESS" \
  > enso_wbtc_route.json

# Extract swap data
SWAP_DATA=$(jq -r '.tx.data' enso_wbtc_route.json)
AGGREGATOR=$(jq -r '.tx.to' enso_wbtc_route.json)
EXPECTED_LP=$(jq -r '.amountOut' enso_wbtc_route.json)
MIN_LP=$(echo "$EXPECTED_LP * 0.98" | bc)  # 2% slippage

# 3. Invest WBTC into Kodiak
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

# 4. Verify LP tokens in Reserve hook
cast call $KODIAK_ISLAND_ADDRESS "balanceOf(address)(uint256)" $RESERVE_HOOK --rpc-url $RPC_URL

# 5. Verify WBTC balance decreased in Reserve vault
cast call $WBTC_ADDRESS "balanceOf(address)(uint256)" $RESERVE_VAULT --rpc-url $RPC_URL
```

#### Complete Reserve Workflow Example

```bash
# Full workflow: WBTC → Reserve → Kodiak LP

# Step 1: Initial setup - set treasury and Kodiak router
cast send $RESERVE_VAULT "setTreasury(address)" $TREASURY_ADDRESS \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy

cast send $RESERVE_VAULT "setKodiakRouter(address)" $KODIAK_ROUTER_ADDRESS \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy

# Step 2: Seed Reserve with 1 WBTC
SEED_PROVIDER=0x...
WBTC_AMOUNT=100000000  # 1 WBTC
WBTC_PRICE_WEI=50000000000000000000000  # $50k with 18 decimals

# Provider approves (from provider wallet)
cast send $WBTC_ADDRESS "approve(address,uint256)" $RESERVE_VAULT $WBTC_AMOUNT \
  --private-key $SEED_PROVIDER_KEY --rpc-url $RPC_URL --legacy

# Admin seeds (from admin wallet)
cast send $RESERVE_VAULT \
  "seedReserveWithToken(address,uint256,address,uint256)" \
  $WBTC_ADDRESS $WBTC_AMOUNT $SEED_PROVIDER $WBTC_PRICE_WEI \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy

# Step 3: Check balances
echo "Reserve WBTC: $(cast call $WBTC_ADDRESS "balanceOf(address)(uint256)" $RESERVE_VAULT --rpc-url $RPC_URL)"
echo "Seed provider resUSD: $(cast call $RESERVE_VAULT "balanceOf(address)(uint256)" $SEED_PROVIDER --rpc-url $RPC_URL)"

# Step 4: Later, invest 0.5 WBTC into Kodiak
# (Get swap calldata from Enso as shown above)
cast send $RESERVE_VAULT \
  "investInKodiak(address,address,uint256,uint256,address,bytes,address,bytes)" \
  $KODIAK_ISLAND_ADDRESS $WBTC_ADDRESS 50000000 $MIN_LP \
  $AGGREGATOR $SWAP_DATA $AGGREGATOR "0x" \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL --gas-limit 2000000 --legacy

# Step 5: Verify final state
echo "Reserve WBTC remaining: $(cast call $WBTC_ADDRESS "balanceOf(address)(uint256)" $RESERVE_VAULT --rpc-url $RPC_URL)"
echo "Reserve hook LP: $(cast call $KODIAK_ISLAND_ADDRESS "balanceOf(address)(uint256)" $RESERVE_HOOK --rpc-url $RPC_URL)"
```

#### Key Differences: Reserve vs Senior/Junior

| Feature | Senior/Junior | Reserve |
|---------|---------------|---------|
| **Standard Seeding** | `seedVault()` with LP tokens | Same: `seedVault()` with LP tokens |
| **Token Seeding** | Not available | ✅ `seedReserveWithToken()` with WBTC/other tokens |
| **Deploy to Kodiak** | `deployToKodiak()` (HONEY → LP) | Same: `deployToKodiak()` (HONEY → LP) |
| **Invest Assets** | Not available | ✅ `investInKodiak()` (WBTC → LP) |
| **Kodiak Router** | Not needed | ✅ Required for `investInKodiak()` |

#### Reserve-Specific Functions

```solidity
// Seed with non-stablecoin token (stays in vault)
function seedReserveWithToken(
    address token,           // e.g., WBTC address
    uint256 amount,          // Amount of tokens (in token's decimals)
    address seedProvider,    // Who provides the tokens
    uint256 tokenPrice       // Token price in USD (18 decimals)
)

// Invest non-stablecoin to Kodiak LP
function investInKodiak(
    address island,                      // Kodiak Island (pool) address
    address token,                       // Token to invest (e.g., WBTC)
    uint256 amount,                      // Amount to invest
    uint256 minLPTokens,                 // Slippage protection
    address swapToToken0Aggregator,      // DEX aggregator
    bytes calldata swapToToken0Data,     // Swap calldata
    address swapToToken1Aggregator,      // DEX aggregator
    bytes calldata swapToToken1Data      // Swap calldata
)

// Set Kodiak Router (required for investInKodiak)
function setKodiakRouter(address router)

// View Kodiak Router
function kodiakRouter() view returns (address)
```

---

## 💰 Complete Fee Structure

### Fee Collection Overview

All protocol fees are collected by the treasury address configured via `setTreasury()`. The treasury receives:
- **Token-denominated fees** (snrUSD, jnrUSD, resUSD) from minting operations
- **Stablecoin fees** (HONEY) from withdrawal operations

### Fee Structure by Vault

| Vault | Fee Type | Rate | Collection Method | Frequency | Recipient | Purpose |
|-------|----------|------|-------------------|-----------|-----------|---------|
| **SENIOR** | Management Fee | 1% annually | Mints snrUSD during rebase | Monthly | Treasury | Protocol operational costs |
| **SENIOR** | Performance Fee | ~2% of yield | Mints snrUSD during rebase | Monthly | Treasury | Reward for yield generation |
| **SENIOR** | Withdrawal Fee | 1% | Deducted from withdrawn HONEY | Per withdrawal | Treasury | Protocol sustainability |
| **SENIOR** | Early Withdrawal Penalty | 20% | Deducted from withdrawn HONEY | Per early withdrawal | Treasury | Prevents bank runs |
| **JUNIOR** | Performance Fee | 1% of supply | Mints jnrUSD to treasury | Configurable schedule | Treasury | Reward for risk bearing |
| **JUNIOR** | Withdrawal Fee | 1% | Deducted from withdrawn HONEY | Per withdrawal | Treasury | Protocol sustainability |
| **RESERVE** | Performance Fee | 1% of supply | Mints resUSD to treasury | Configurable schedule | Treasury | Reward for backstop provision |
| **RESERVE** | Withdrawal Fee | 1% | Deducted from withdrawn HONEY | Per withdrawal | Treasury | Protocol sustainability |

### Fee Calculation Examples

#### Senior Vault - Complete Withdrawal Example
```
Scenario: User withdraws 1000 snrUSD BEFORE 7-day cooldown

Step 1: Early Withdrawal Penalty (20%)
  Gross amount: 1000 HONEY
  Penalty: 1000 × 20% = 200 HONEY
  After penalty: 800 HONEY

Step 2: Withdrawal Fee (1%)
  Amount after penalty: 800 HONEY
  Withdrawal fee: 800 × 1% = 8 HONEY
  Net to user: 792 HONEY

Treasury Receives:
  - Early penalty: 200 HONEY
  - Withdrawal fee: 8 HONEY
  - Total: 208 HONEY (20.8% of original)

User Receives: 792 HONEY (79.2% of original)
```

#### Senior Vault - Withdrawal After Cooldown
```
Scenario: User withdraws 1000 snrUSD AFTER 7-day cooldown

Step 1: No Early Penalty (cooldown complete)
  Gross amount: 1000 HONEY
  Penalty: 0 HONEY
  After penalty: 1000 HONEY

Step 2: Withdrawal Fee (1%)
  Amount after penalty: 1000 HONEY
  Withdrawal fee: 1000 × 1% = 10 HONEY
  Net to user: 990 HONEY

Treasury Receives: 10 HONEY (1% total)
User Receives: 990 HONEY (99% of original)
```

#### Junior/Reserve Vault - Withdrawal Example
```
Scenario: User redeems 1000 jnrUSD shares
Unstaking ratio: 1.2 (each share worth 1.2 HONEY)
Gross HONEY: 1000 × 1.2 = 1200 HONEY

Withdrawal Fee (1%):
  Fee: 1200 × 1% = 12 HONEY
  Net to user: 1188 HONEY

Treasury Receives: 12 HONEY (1% of gross)
User Receives: 1188 HONEY (99% of gross)

Note: No early withdrawal penalty for Junior/Reserve vaults
```

#### Performance Fee Minting (Junior/Reserve)
```
Scenario: 30 days passed since last mint
Current jnrUSD supply: 100,000 tokens

Performance Fee Calculation:
  Current supply: 100,000 jnrUSD
  Fee rate: 1%
  Fee amount: 100,000 × 1% = 1,000 jnrUSD

Result:
  - Treasury receives: 1,000 newly minted jnrUSD
  - New total supply: 101,000 jnrUSD
  - Dilution: 1% (all existing holders diluted equally)

Annual Impact (if minted monthly):
  - Monthly: 1%
  - Annual (compounded): ~12.68%
```

### Senior Vault Fees

#### 1. Management Fee (1% Annual)
- **When**: Charged during monthly `rebase()` call
- **How**: Mints additional snrUSD tokens to treasury
- **Formula**: `feeTokens = vaultValue × (1% / 12)`
- **Impact**: Does NOT reduce user balances; treasury shares grow with rebase
- **Example**: $1M vault → ~$833 worth of snrUSD minted per month

#### 2. Performance Fee (~2% of Yield)
- **When**: Charged during monthly `rebase()` call
- **How**: Included in rebase multiplier (1.02x)
- **Formula**: User gets APY%, treasury gets APY% × 2%
- **Impact**: Slight dilution; treasury shares grow with rebase
- **Example**: 11% APY to users → 0.22% APY to treasury

#### 3. Withdrawal Fee (1%)
- **When**: Every withdrawal, regardless of cooldown
- **How**: Deducted from withdrawn HONEY before transfer
- **Formula**: `fee = withdrawAmount × 1%`
- **Impact**: User receives 99% of withdrawn amount (after penalties if applicable)
- **Example**: Withdraw 1000 HONEY → 10 HONEY fee → user gets 990 HONEY

#### 4. Early Withdrawal Penalty (20%)
- **When**: Withdrawal before 7-day cooldown complete
- **How**: Deducted from withdrawn HONEY before withdrawal fee
- **Formula**: `penalty = withdrawAmount × 20%`
- **Impact**: User receives only 79.2% of amount (with 1% withdrawal fee on remainder)
- **Example**: Withdraw 1000 HONEY early → 200 penalty + 8 fee → user gets 792 HONEY
- **Note**: Encourages long-term holding and prevents bank runs

### Junior & Reserve Vault Fees

#### 1. Performance Fee (1% of Supply)
- **When**: Callable by admin after schedule elapsed (e.g., 30 days)
- **How**: Mints new vault tokens equal to 1% of current supply
- **Formula**: `feeTokens = totalSupply × 1%`
- **Impact**: All holders diluted by 1% per minting
- **Schedule**: Configurable (1 day, 7 days, 30 days, 90 days, etc.)
- **Check**: `canMintManagementFee()` returns true when ready
- **Example**: 100k jnrUSD supply → mint 1k jnrUSD to treasury

#### 2. Withdrawal Fee (1%)
- **When**: Every withdrawal/redemption
- **How**: Deducted from withdrawn HONEY before transfer
- **Formula**: `fee = (shares × unstakingRatio) × 1%`
- **Impact**: User receives 99% of their share value
- **Example**: Redeem 1000 jnrUSD at 1.2 ratio → 1200 HONEY - 12 fee = 1188 HONEY

### Fee Schedule Configuration

#### Setting Performance Fee Schedule (Junior/Reserve)
```bash
# Common schedules (in seconds):
# Daily: 86400
# Weekly: 604800
# Monthly: 2592000
# Quarterly: 7776000

# Set Junior to monthly
cast send $JUNIOR_VAULT "setMgmtFeeSchedule(uint256)" 2592000 \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# Set Reserve to monthly
cast send $RESERVE_VAULT "setMgmtFeeSchedule(uint256)" 2592000 \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

### Monitoring Fee Collection

```bash
# Check treasury address
TREASURY=$(cast call $SENIOR_VAULT "treasury()(address)" --rpc-url $RPC_URL)

# Check token balances in treasury
echo "Treasury snrUSD: $(cast call $SENIOR_VAULT "balanceOf(address)(uint256)" $TREASURY --rpc-url $RPC_URL)"
echo "Treasury jnrUSD: $(cast call $JUNIOR_VAULT "balanceOf(address)(uint256)" $TREASURY --rpc-url $RPC_URL)"
echo "Treasury resUSD: $(cast call $RESERVE_VAULT "balanceOf(address)(uint256)" $TREASURY --rpc-url $RPC_URL)"
echo "Treasury HONEY: $(cast call $HONEY_ADDRESS "balanceOf(address)(uint256)" $TREASURY --rpc-url $RPC_URL)"

# Check if performance fees can be minted
echo "Junior can mint: $(cast call $JUNIOR_VAULT "canMintManagementFee()(bool)" --rpc-url $RPC_URL)"
echo "Reserve can mint: $(cast call $RESERVE_VAULT "canMintManagementFee()(bool)" --rpc-url $RPC_URL)"

# Check time until next mint
echo "Junior time until next: $(cast call $JUNIOR_VAULT "getTimeUntilNextMint()(uint256)" --rpc-url $RPC_URL) seconds"
echo "Reserve time until next: $(cast call $RESERVE_VAULT "getTimeUntilNextMint()(uint256)" --rpc-url $RPC_URL) seconds"
```

### Important Notes

1. **Treasury Must Be Set**: All vaults require `setTreasury()` to be called before fees can be collected
2. **Performance Fee Schedule**: Junior/Reserve require `setMgmtFeeSchedule()` to enable performance fee minting
3. **Fee Accumulation**: Withdrawal fees accumulate in treasury as HONEY, performance fees as vault tokens
4. **No Fee Waiving**: All fees are hardcoded and cannot be waived (except early penalty via cooldown)
5. **Transparent**: All fees are emitted via events for on-chain tracking

---

## 📥 Pending LP Deposit Operations (NEW!)

### Overview

**Senior and Junior vaults** support pending LP deposits from users. LP tokens are transferred to the vault's hook immediately, creating a pending deposit that waits for admin approval.

**⚠️ Note**: **Reserve vault does NOT support pending LP deposits**. Reserve focuses on token management and standard HONEY deposits only. For initial LP seeding in Reserve, use `seedVault()` (admin-only).

### User Workflow - Deposit LP Tokens

```bash
# Example: User deposits 10 LP tokens to Senior vault

# 1. User approves vault to transfer LP
cast send $KODIAK_ISLAND_ADDRESS \
  "approve(address,uint256)" \
  $SENIOR_VAULT \
  10000000000000000000 \
  --private-key $USER_KEY \
  --rpc-url $RPC_URL \
  --legacy

# 2. User deposits LP tokens
cast send $SENIOR_VAULT \
  "depositLP(address,uint256)" \
  $KODIAK_ISLAND_ADDRESS \
  10000000000000000000 \
  --private-key $USER_KEY \
  --rpc-url $RPC_URL \
  --legacy

# Transaction will emit PendingLPDepositCreated event with depositId

# 3. User can check their deposit IDs
cast call $SENIOR_VAULT \
  "getUserDepositIds(address)(uint256[])" \
  $USER_ADDRESS \
  --rpc-url $RPC_URL

# 4. User can check specific deposit details
cast call $SENIOR_VAULT \
  "getPendingDeposit(uint256)(address,address,uint256,uint256,uint256,uint8)" \
  $DEPOSIT_ID \
  --rpc-url $RPC_URL
# Returns: depositor, lpToken, amount, timestamp, expiresAt, status
```

### Admin Workflow - Approve LP Deposits

```bash
# Daily/Regular task: Review and approve pending LP deposits

# 1. Monitor for new deposits (check events or frontend)
# Deposits emit PendingLPDepositCreated events

# 2. Get deposit details
DEPOSIT_ID=0  # From event or user query
cast call $SENIOR_VAULT \
  "getPendingDeposit(uint256)(address,address,uint256,uint256,uint256,uint8)" \
  $DEPOSIT_ID \
  --rpc-url $RPC_URL

# Parse output:
# depositor: 0x...
# lpToken: 0x...
# amount: 10000000000000000000 (10 LP)
# timestamp: 1700000000
# expiresAt: 1700172800 (48h later)
# status: 0 (PENDING)

# 3. Get current LP price from Enso API
LP_PRICE=$(curl -s "https://api.enso.finance/api/v1/price?chainId=80094&address=$KODIAK_ISLAND_ADDRESS" | jq -r '.price')
LP_PRICE_WEI=$(echo "$LP_PRICE * 10^18" | bc)

echo "LP Price: $LP_PRICE USD"
echo "LP Price (wei): $LP_PRICE_WEI"

# 4. Calculate expected shares to be minted
# For Senior: shares = amount * lpPrice / 1e18
# For Junior/Reserve: shares = (amount * lpPrice / 1e18) / sharePrice

LP_AMOUNT=10000000000000000000  # From step 2
VALUE_USD=$(echo "$LP_AMOUNT * $LP_PRICE / 10^18" | bc)
echo "Value to add: $VALUE_USD USD"

# 5. Approve deposit (mints shares to depositor)
cast send $SENIOR_VAULT \
  "approveLPDeposit(uint256,uint256)" \
  $DEPOSIT_ID \
  $LP_PRICE_WEI \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# 6. Verify shares were minted
DEPOSITOR=0x...  # From step 2
cast call $SENIOR_VAULT "balanceOf(address)(uint256)" $DEPOSITOR --rpc-url $RPC_URL

# 7. Verify LP stayed in hook
cast call $KODIAK_ISLAND_ADDRESS "balanceOf(address)(uint256)" $SENIOR_HOOK --rpc-url $RPC_URL
```

### Admin Workflow - Reject LP Deposits

```bash
# When you need to reject a deposit (wrong LP, suspicious, etc.)

# 1. Get deposit details
cast call $SENIOR_VAULT \
  "getPendingDeposit(uint256)(address,address,uint256,uint256,uint256,uint8)" \
  $DEPOSIT_ID \
  --rpc-url $RPC_URL

# 2. Reject with reason
cast send $SENIOR_VAULT \
  "rejectLPDeposit(uint256,string)" \
  $DEPOSIT_ID \
  "LP token not whitelisted" \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# Reasons for rejection:
# - "LP token not whitelisted"
# - "Amount too small"
# - "Suspicious address"
# - "LP price unavailable"
# - etc.

# 3. Verify LP returned to depositor
DEPOSITOR=0x...  # From step 1
cast call $KODIAK_ISLAND_ADDRESS "balanceOf(address)(uint256)" $DEPOSITOR --rpc-url $RPC_URL
```

### User Workflow - Cancel Pending Deposit

```bash
# User can cancel anytime before admin approval

# 1. Get user's deposit IDs
cast call $SENIOR_VAULT \
  "getUserDepositIds(address)(uint256[])" \
  $USER_ADDRESS \
  --rpc-url $RPC_URL

# 2. Check deposit status
cast call $SENIOR_VAULT \
  "getPendingDeposit(uint256)(address,address,uint256,uint256,uint256,uint8)" \
  $DEPOSIT_ID \
  --rpc-url $RPC_URL

# 3. Cancel (if status is PENDING)
cast send $SENIOR_VAULT \
  "cancelPendingDeposit(uint256)" \
  $DEPOSIT_ID \
  --private-key $USER_KEY \
  --rpc-url $RPC_URL \
  --legacy

# 4. Verify LP returned
cast call $KODIAK_ISLAND_ADDRESS "balanceOf(address)(uint256)" $USER_ADDRESS --rpc-url $RPC_URL
```

### Anyone Workflow - Claim Expired Deposits

```bash
# Good Samaritan: Return expired deposits to original depositors

# 1. Check if deposit is expired (after 48h)
cast call $SENIOR_VAULT \
  "getPendingDeposit(uint256)(address,address,uint256,uint256,uint256,uint8)" \
  $DEPOSIT_ID \
  --rpc-url $RPC_URL

# Check expiresAt timestamp vs current time
CURRENT_TIME=$(date +%s)
EXPIRES_AT=...  # From above call

if [ $CURRENT_TIME -gt $EXPIRES_AT ]; then
  echo "Deposit expired, can claim"
else
  echo "Deposit not yet expired"
  exit 1
fi

# 2. Claim expired deposit (anyone can call)
cast send $SENIOR_VAULT \
  "claimExpiredDeposit(uint256)" \
  $DEPOSIT_ID \
  --private-key $ANY_KEY \
  --rpc-url $RPC_URL \
  --legacy

# LP will be returned to original depositor automatically
```

### Batch Processing - Approve Multiple Deposits

```bash
# Script to approve multiple pending deposits at once

# Get all pending deposit IDs (implement event indexing or loop through IDs)
NEXT_ID=$(cast call $SENIOR_VAULT "getNextDepositId()(uint256)" --rpc-url $RPC_URL)

# Get LP price once
LP_PRICE=$(curl -s "https://api.enso.finance/api/v1/price?chainId=80094&address=$KODIAK_ISLAND_ADDRESS" | jq -r '.price')
LP_PRICE_WEI=$(echo "$LP_PRICE * 10^18" | bc)

# Loop through potential deposit IDs
for DEPOSIT_ID in $(seq 0 $((NEXT_ID - 1))); do
  # Check if deposit is PENDING
  STATUS=$(cast call $SENIOR_VAULT \
    "getPendingDeposit(uint256)(address,address,uint256,uint256,uint256,uint8)" \
    $DEPOSIT_ID \
    --rpc-url $RPC_URL | tail -1)
  
  if [ "$STATUS" = "0" ]; then
    # Status is PENDING, approve it
    echo "Approving deposit $DEPOSIT_ID..."
    cast send $SENIOR_VAULT \
      "approveLPDeposit(uint256,uint256)" \
      $DEPOSIT_ID \
      $LP_PRICE_WEI \
      --private-key $PRIVATE_KEY \
      --rpc-url $RPC_URL \
      --legacy
    
    sleep 2  # Rate limiting
  fi
done
```

### Monitoring & Health Checks

```bash
# Check for pending deposits across all vaults

echo "=== SENIOR VAULT PENDING DEPOSITS ==="
SENIOR_NEXT_ID=$(cast call $SENIOR_VAULT "getNextDepositId()(uint256)" --rpc-url $RPC_URL)
echo "Total deposits created: $SENIOR_NEXT_ID"

# Count by status (implement via events or loop)

echo -e "\n=== JUNIOR VAULT PENDING DEPOSITS ==="
JUNIOR_NEXT_ID=$(cast call $JUNIOR_VAULT "getNextDepositId()(uint256)" --rpc-url $RPC_URL)
echo "Total deposits created: $JUNIOR_NEXT_ID"

# Note: Reserve vault does NOT support pending LP deposits

# Check for expiring deposits (within 1 hour of expiry)
# Implement via event indexing or database
```

### Important Notes

1. **48-Hour Window**: Admin must approve or reject within 48 hours
2. **LP Price Source**: Always use Enso API or trusted oracle for LP price
3. **Gas Costs**: 
   - User pays for: `depositLP`, `cancelPendingDeposit`
   - Admin pays for: `approveLPDeposit`, `rejectLPDeposit`
   - Anyone pays for: `claimExpiredDeposit` (Good Samaritan)
4. **Security**: Validate LP token address before approving
5. **Monitoring**: Set up alerts for new deposits and expiring deposits
6. **Automation**: Consider automating approval for whitelisted LPs

### Deposit States Reference

```
Status Value | State Name | Description
-------------|------------|------------
0            | PENDING    | Waiting for admin action
1            | APPROVED   | Admin approved, shares minted
2            | REJECTED   | Admin rejected, LP returned
3            | EXPIRED    | 48h passed, LP claimable
4            | CANCELLED  | User cancelled, LP returned
```

### Events to Monitor

```solidity
// Track these events for deposit management
PendingLPDepositCreated(depositId, depositor, lpToken, amount, expiresAt)
PendingLPDepositApproved(depositId, depositor, lpPrice, sharesMinted)
PendingLPDepositRejected(depositId, depositor, reason)
PendingLPDepositCancelled(depositId, depositor)
PendingLPDepositExpired(depositId, depositor)
```

### Integration with Frontend

The frontend should:
1. Allow users to deposit LP tokens easily
2. Show pending deposits for connected wallet
3. Display countdown to expiry
4. Allow users to cancel pending deposits
5. Notify users when deposits are approved/rejected
6. Show admin dashboard for approval queue

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
| **Process Pending LP Deposits (NEW!)** | **Daily** | **10:00 & 16:00 UTC** | **🟡 Important** |
| Mint Performance Fee (Junior/Reserve) | Per schedule | Based on fee schedule | 🟡 Important |
| Update Junior/Reserve Values | Weekly | Monday 08:00 UTC | 🟡 Important |
| Deploy Capital to Kodiak | As needed | After large deposits | 🟢 Normal |
| Dust Recovery | Weekly | Friday 16:00 UTC | 🟢 Normal |
| Health Check | Daily | 06:00 & 18:00 UTC | 🟡 Important |
| **Check Expiring Deposits (NEW!)** | **Daily** | **Every 6 hours** | **🟢 Normal** |
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

