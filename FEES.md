# 💰 Protocol Fee Structure

> **Complete reference for all fees charged across Senior, Junior, and Reserve vaults**

---

## Quick Reference - All Fees

| Vault | Fee Type | Rate | When Charged | Paid In | Recipient |
|-------|----------|------|--------------|---------|-----------|
| **SENIOR** | Management Fee | **1% annually** (0.0833%/month) | Monthly rebase | snrUSD (minted) | Treasury |
| **SENIOR** | Performance Fee | **~2% of yield** | Monthly rebase | snrUSD (minted) | Treasury |
| **SENIOR** | Withdrawal Fee | **1%** | Every withdrawal | HONEY (deducted) | Treasury |
| **SENIOR** | Early Withdrawal Penalty | **20%** | Before 7-day cooldown | HONEY (deducted) | Treasury |
| **JUNIOR** | Performance Fee | **1% of supply** | Configurable schedule | jnrUSD (minted) | Treasury |
| **JUNIOR** | Withdrawal Fee | **1%** | Every withdrawal | HONEY (deducted) | Treasury |
| **RESERVE** | Performance Fee | **1% of supply** | Configurable schedule | resUSD (minted) | Treasury |
| **RESERVE** | Withdrawal Fee | **1%** | Every withdrawal | HONEY (deducted) | Treasury |

---

## Senior Vault Fees

### 1. Management Fee
- **Rate**: 1% annually (0.0833% per month)
- **Charged**: During monthly rebase
- **Method**: Mints additional snrUSD to treasury
- **Impact**: Treasury shares grow with rebase, no direct reduction to user balances
- **Formula**: `feeTokens = vaultValue × (1% / 12)`
- **Example**: $1M vault → ~833 snrUSD minted per month

### 2. Performance Fee
- **Rate**: ~2% of yield (2% on top of user APY)
- **Charged**: During monthly rebase
- **Method**: Included in rebase multiplier (1.02x)
- **Impact**: Slight dilution across all holders
- **Formula**: `userAPY + (userAPY × 2%)`
- **Example**: Users get 11% APY → Treasury gets 0.22% APY

### 3. Withdrawal Fee
- **Rate**: 1% of withdrawn amount
- **Charged**: Every withdrawal (regardless of cooldown status)
- **Method**: Deducted from HONEY before transfer
- **Impact**: User receives 99% of amount (after penalties if applicable)
- **Formula**: `fee = withdrawAmount × 1%`
- **Example**: Withdraw 1000 HONEY → 10 HONEY fee → user gets 990 HONEY

### 4. Early Withdrawal Penalty
- **Rate**: 20% of withdrawn amount
- **Charged**: Only if withdrawn before 7-day cooldown complete
- **Method**: Deducted from HONEY before withdrawal fee
- **Impact**: User receives only 79.2% of amount (with 1% fee on remainder)
- **Formula**: `penalty = withdrawAmount × 20%`
- **Example**: Withdraw 1000 HONEY early → 200 penalty + 8 fee → user gets 792 HONEY
- **Note**: Can be avoided by completing 7-day cooldown

---

## Junior Vault Fees

### 1. Performance Fee
- **Rate**: 1% of total supply
- **Charged**: On configurable schedule (default: 30 days)
- **Method**: Mints new jnrUSD tokens to treasury
- **Impact**: All holders diluted by 1% per minting
- **Formula**: `feeTokens = totalSupply × 1%`
- **Example**: 100k jnrUSD supply → mint 1k jnrUSD to treasury
- **Schedule Options**:
  - Daily: 86400 seconds
  - Weekly: 604800 seconds
  - Monthly: 2592000 seconds (recommended)
  - Quarterly: 7776000 seconds

### 2. Withdrawal Fee
- **Rate**: 1% of withdrawn amount
- **Charged**: Every withdrawal/redemption
- **Method**: Deducted from HONEY before transfer
- **Impact**: User receives 99% of their share value in HONEY
- **Formula**: `fee = (shares × unstakingRatio) × 1%`
- **Example**: Redeem 1000 jnrUSD at 1.2 ratio → 1200 HONEY - 12 fee = 1188 HONEY
- **Note**: No early withdrawal penalty for Junior vault

---

## Reserve Vault Fees

### 1. Performance Fee
- **Rate**: 1% of total supply
- **Charged**: On configurable schedule (default: 30 days)
- **Method**: Mints new resUSD tokens to treasury
- **Impact**: All holders diluted by 1% per minting
- **Formula**: `feeTokens = totalSupply × 1%`
- **Example**: 50k resUSD supply → mint 500 resUSD to treasury
- **Schedule Options**: Same as Junior vault (daily, weekly, monthly, quarterly)

### 2. Withdrawal Fee
- **Rate**: 1% of withdrawn amount
- **Charged**: Every withdrawal/redemption
- **Method**: Deducted from HONEY before transfer
- **Impact**: User receives 99% of their share value in HONEY
- **Formula**: `fee = (shares × unstakingRatio) × 1%`
- **Example**: Redeem 1000 resUSD at 1.5 ratio → 1500 HONEY - 15 fee = 1485 HONEY
- **Note**: No early withdrawal penalty for Reserve vault

---

## Fee Calculation Examples

### Example 1: Senior Vault - Early Withdrawal (Worst Case)

```
User withdraws 1000 snrUSD BEFORE 7-day cooldown:

Step 1: Early Withdrawal Penalty (20%)
  Gross amount:     1000 HONEY
  Penalty (20%):    -200 HONEY
  After penalty:     800 HONEY

Step 2: Withdrawal Fee (1%)
  Before fee:        800 HONEY
  Fee (1%):          -8 HONEY
  Net to user:       792 HONEY

Result:
  Treasury receives: 208 HONEY (20.8% total)
  User receives:     792 HONEY (79.2% total)
```

### Example 2: Senior Vault - Normal Withdrawal (After Cooldown)

```
User withdraws 1000 snrUSD AFTER 7-day cooldown:

Step 1: No Penalty (cooldown complete)
  Gross amount:     1000 HONEY
  Penalty:            0 HONEY
  After penalty:    1000 HONEY

Step 2: Withdrawal Fee (1%)
  Before fee:       1000 HONEY
  Fee (1%):          -10 HONEY
  Net to user:       990 HONEY

Result:
  Treasury receives: 10 HONEY (1% total)
  User receives:     990 HONEY (99% total)
```

### Example 3: Junior Vault - Withdrawal

```
User redeems 1000 jnrUSD at 1.2 unstaking ratio:

Step 1: Calculate gross HONEY
  Shares:           1000 jnrUSD
  Unstaking ratio:  1.2
  Gross HONEY:      1200 HONEY

Step 2: Withdrawal Fee (1%)
  Before fee:       1200 HONEY
  Fee (1%):          -12 HONEY
  Net to user:      1188 HONEY

Result:
  Treasury receives: 12 HONEY (1% of gross)
  User receives:     1188 HONEY (99% of gross)
  
Note: No early withdrawal penalty for Junior vault
```

### Example 4: Reserve Vault - Withdrawal

```
User redeems 1000 resUSD at 1.5 unstaking ratio:

Step 1: Calculate gross HONEY
  Shares:           1000 resUSD
  Unstaking ratio:  1.5
  Gross HONEY:      1500 HONEY

Step 2: Withdrawal Fee (1%)
  Before fee:       1500 HONEY
  Fee (1%):          -15 HONEY
  Net to user:      1485 HONEY

Result:
  Treasury receives: 15 HONEY (1% of gross)
  User receives:     1485 HONEY (99% of gross)
  
Note: No early withdrawal penalty for Reserve vault
```

### Example 5: Performance Fee Minting (Junior/Reserve)

```
Junior vault after 30 days (schedule met):

Current State:
  Total supply:     100,000 jnrUSD
  Treasury balance: 5,000 jnrUSD
  Other holders:    95,000 jnrUSD

Performance Fee Minting:
  Fee rate:         1%
  Mint amount:      100,000 × 1% = 1,000 jnrUSD

After Minting:
  Total supply:     101,000 jnrUSD
  Treasury balance: 6,000 jnrUSD (5,000 + 1,000)
  Other holders:    95,000 jnrUSD (unchanged)
  
Impact:
  Treasury ownership: 5% → 5.94% (gained 0.94%)
  Other holders:      95% → 94.06% (diluted by 0.94%)
  
Annual Impact (if monthly):
  Monthly dilution:   1%
  Annual dilution:    ~12.68% (compounded)
```

---

## Fee Revenue Projections

Based on realistic Total Value Locked (TVL):

### Monthly Revenue

| Vault | TVL | Management Fee | Performance Fee | Withdrawal Fees | Monthly Total |
|-------|-----|----------------|-----------------|-----------------|---------------|
| Senior | $1,000,000 | ~$833 | ~$167 | Variable | ~$1,000 + withdrawals |
| Junior | $500,000 | N/A | ~$5,000 | Variable | ~$5,000 + withdrawals |
| Reserve | $100,000 | N/A | ~$1,000 | Variable | ~$1,000 + withdrawals |
| **TOTAL** | **$1,600,000** | **~$833** | **~$6,167** | **Variable** | **~$7,000 + withdrawals** |

### Annual Revenue

| Vault | Management Fee | Performance Fee | Withdrawal Fees | Annual Total |
|-------|----------------|-----------------|-----------------|--------------|
| Senior | ~$10,000 | ~$2,000 | Variable | ~$12,000 + withdrawals |
| Junior | N/A | ~$60,000 | Variable | ~$60,000 + withdrawals |
| Reserve | N/A | ~$12,000 | Variable | ~$12,000 + withdrawals |
| **TOTAL** | **~$10,000** | **~$74,000** | **Variable** | **~$84,000 + withdrawals** |

**Notes**:
- Withdrawal fees depend on user activity (variable)
- Projections assume stable TVL
- Senior performance fee based on 11% APY
- Junior/Reserve performance fees assume monthly minting

---

## Fee Comparison Summary

### By Fee Type

| Fee Type | Senior | Junior | Reserve |
|----------|--------|--------|---------|
| **Management Fee** | ✅ 1% annual | ❌ None | ❌ None |
| **Performance Fee** | ✅ ~2% of yield | ✅ 1% of supply | ✅ 1% of supply |
| **Withdrawal Fee** | ✅ 1% | ✅ 1% | ✅ 1% |
| **Early Penalty** | ✅ 20% | ❌ None | ❌ None |

### By Payment Method

| Payment Method | Senior | Junior | Reserve |
|----------------|--------|--------|---------|
| **Token Minting** | Management + Performance fees | Performance fee only | Performance fee only |
| **HONEY Deduction** | Withdrawal fee + Early penalty | Withdrawal fee only | Withdrawal fee only |

### Total User Cost (Best Case)

| Vault | Deposit | Hold 1 Year | Withdraw (After Cooldown) | Total Cost |
|-------|---------|-------------|---------------------------|------------|
| **Senior** | Free | ~3% (mgmt + perf dilution) | 1% | ~4% |
| **Junior** | Free | ~12.68% (perf dilution if monthly) | 1% | ~13.68% |
| **Reserve** | Free | ~12.68% (perf dilution if monthly) | 1% | ~13.68% |

### Total User Cost (Worst Case - Senior Early Withdrawal)

| Vault | Deposit | Hold 1 Month | Withdraw (Before Cooldown) | Total Cost |
|-------|---------|--------------|---------------------------|------------|
| **Senior** | Free | ~0.25% (mgmt + perf dilution) | 20.8% | ~21.05% |

**Note**: Early withdrawal penalty is avoidable by completing 7-day cooldown!

---

## Important Notes

### 1. Treasury Configuration Required
⚠️ **CRITICAL**: All vaults require `setTreasury()` to be called before fees can be collected!

```bash
cast send $SENIOR_VAULT "setTreasury(address)" $TREASURY_ADDRESS --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy
cast send $JUNIOR_VAULT "setTreasury(address)" $TREASURY_ADDRESS --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy
cast send $RESERVE_VAULT "setTreasury(address)" $TREASURY_ADDRESS --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy
```

### 2. Performance Fee Schedule (Junior/Reserve)
Junior and Reserve vaults require `setMgmtFeeSchedule()` to enable performance fee minting:

```bash
cast send $JUNIOR_VAULT "setMgmtFeeSchedule(uint256)" 2592000 --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy  # 30 days
cast send $RESERVE_VAULT "setMgmtFeeSchedule(uint256)" 2592000 --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy  # 30 days
```

### 3. No Fee Waivers
All fees are hardcoded in smart contracts and cannot be waived or adjusted:
- Management fee: Hardcoded at 1% annual
- Performance fee: Hardcoded at 2% (Senior) or 1% (Junior/Reserve)
- Withdrawal fee: Hardcoded at 1%
- Early penalty: Hardcoded at 20% (but avoidable via cooldown)

### 4. Fee Accumulation
- **Token fees** (mgmt, performance): Accumulate as vault tokens (snrUSD, jnrUSD, resUSD)
- **HONEY fees** (withdrawal, penalty): Accumulate as HONEY stablecoin
- Treasury can hold multiple token types

### 5. Cooldown Benefits (Senior Only)
Users can **completely avoid** the 20% early withdrawal penalty by:
1. Calling `initiateCooldown()`
2. Waiting 7 days
3. Withdrawing (only 1% withdrawal fee applies)

### 6. Fee Transparency
All fees emit on-chain events for tracking:
- `WithdrawalFeeCharged(user, fee, netAmount)`
- `PerformanceFeeMinted(treasury, amount, timestamp)`
- `MgmtFeeScheduleUpdated(oldSchedule, newSchedule)`

---

## Fee Monitoring Commands

### Check Treasury Balances

```bash
# Get treasury address
TREASURY=$(cast call $SENIOR_VAULT "treasury()(address)" --rpc-url $RPC_URL)

# Check token balances
echo "Treasury snrUSD: $(cast call $SENIOR_VAULT "balanceOf(address)(uint256)" $TREASURY --rpc-url $RPC_URL)"
echo "Treasury jnrUSD: $(cast call $JUNIOR_VAULT "balanceOf(address)(uint256)" $TREASURY --rpc-url $RPC_URL)"
echo "Treasury resUSD: $(cast call $RESERVE_VAULT "balanceOf(address)(uint256)" $TREASURY --rpc-url $RPC_URL)"
echo "Treasury HONEY: $(cast call $HONEY_ADDRESS "balanceOf(address)(uint256)" $TREASURY --rpc-url $RPC_URL)"
```

### Check Performance Fee Status (Junior/Reserve)

```bash
# Check if fees can be minted
echo "Junior can mint: $(cast call $JUNIOR_VAULT "canMintPerformanceFee()(bool)" --rpc-url $RPC_URL)"
echo "Reserve can mint: $(cast call $RESERVE_VAULT "canMintPerformanceFee()(bool)" --rpc-url $RPC_URL)"

# Check time until next mint
echo "Junior time until next: $(cast call $JUNIOR_VAULT "getTimeUntilNextMint()(uint256)" --rpc-url $RPC_URL) seconds"
echo "Reserve time until next: $(cast call $RESERVE_VAULT "getTimeUntilNextMint()(uint256)" --rpc-url $RPC_URL) seconds"

# Check current schedule
echo "Junior schedule: $(cast call $JUNIOR_VAULT "getMgmtFeeSchedule()(uint256)" --rpc-url $RPC_URL) seconds"
echo "Reserve schedule: $(cast call $RESERVE_VAULT "getMgmtFeeSchedule()(uint256)" --rpc-url $RPC_URL) seconds"
```

---

## Related Documentation

- **Operations Manual**: [OPERATIONS_MANUAL.md](./OPERATIONS_MANUAL.md) - Day-to-day fee operations
- **Deployment Guide**: [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) - Fee configuration during deployment
- **Contract Architecture**: [CONTRACT_ARCHITECTURE.md](./CONTRACT_ARCHITECTURE.md) - Fee implementation details
- **Mathematical Spec**: [math_spec.md](./math_spec.md) - Fee calculation formulas

---

**Last Updated**: November 19, 2025  
**Version**: 1.0.0  
**Fee Structure Version**: Final (all features complete)

