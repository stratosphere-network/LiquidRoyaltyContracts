# Admin Operations by Category

## Operations Categorized by Function

| Category | Operation | Vault | Frequency | Risk Level | Command Pattern |
|----------|-----------|-------|-----------|------------|-----------------|
| **Core Protocol** | Rebase Senior Vault | Senior | Monthly | Critical | `rebase(uint256 lpPrice)` |
| **Core Protocol** | Mint Management Fee | Junior/Reserve | Per Schedule | Medium | `mintManagementFee()` |
| **Core Protocol** | Update Vault Value | Junior/Reserve | Weekly | Medium | `updateValue(uint256 newValue)` |
| **Liquidity Management** | Deploy HONEY to Kodiak | Senior/Junior/Reserve | After Deposits | Medium | `deployToKodiak(...)` |
| **Liquidity Management** | Invest Assets in Kodiak | Reserve | As Needed | Medium | `investInKodiak(...)` |
| **Liquidity Management** | Rescue HONEY Dust | All Hooks | Weekly | Low | `rescueHoneyToVault()` |
| **Liquidity Management** | Swap WBTC Dust to Vault | All Hooks | Weekly | Low | `swapAndRescue(...)` |
| **Access Control** | Whitelist New Aggregator | All Hooks | Once per Aggregator | High | `setAggregatorWhitelisted(address, bool)` |
| **Access Control** | Whitelist New LP Token | All Vaults | Once per Token | High | `addWhitelistedLPToken(address)` |
| **Access Control** | Add Whitelisted LP Recipient | All Vaults | As Needed | Medium | `addWhitelistedLP(address)` |
| **Access Control** | Add Seeder | All Vaults | As Needed | Medium | `addSeeder(address)` |
| **Access Control** | Change Admin | All Vaults | Rare | Critical | `changeAdmin(address)` |
| **User Deposits** | Approve LP Deposit | Senior/Junior | Daily | Medium | `approveLPDeposit(uint256, uint256)` |
| **User Deposits** | Reject LP Deposit | Senior/Junior | As Needed | Medium | `rejectLPDeposit(uint256, string)` |
| **Initial Setup** | Seed Vault with LP Tokens | All Vaults | Once | Critical | `seedVault(address, uint256, address, uint256)` |
| **Initial Setup** | Seed Reserve with Token | Reserve | Once | Critical | `seedReserveWithToken(...)` |
| **Initial Setup** | Set Treasury | All Vaults | Once | Critical | `setTreasury(address)` |
| **Initial Setup** | Set Fee Schedule | Junior/Reserve | Once | Medium | `setMgmtFeeSchedule(uint256)` |
| **Initial Setup** | Set Kodiak Router | Reserve | Once | High | `setKodiakRouter(address)` |
| **Emergency** | Pause Vault | All Vaults | Emergency Only | Critical | `pause()` |
| **Emergency** | Unpause Vault | All Vaults | After Fix | Critical | `unpause()` |
| **Upgrades** | Upgrade Vault Implementation | All Proxies | When Needed | Critical | `upgradeToAndCall(address, bytes)` |
| **Configuration** | Set Router | All Hooks | Once/Rare | High | `setRouter(address)` |
| **Configuration** | Set Island | All Hooks | Once/Rare | High | `setIsland(address)` |
| **Configuration** | Set WBERA | All Hooks | Once/Rare | Medium | `setWBERA(address)` |
| **Configuration** | Set Slippage | All Hooks | Rare | Medium | `setSlippage(uint256, uint256)` |
| **Configuration** | Set Safety Multiplier | All Hooks | Rare | Medium | `setSafetyMultiplier(uint256)` |

---

## Operations by Risk Level

### Critical Risk (Requires Multisig)

| Operation | Why Critical | Mitigation |
|-----------|-------------|------------|
| Rebase Senior Vault | Triggers spillover/backstop, affects all vaults | Verify LP price from multiple sources, test in simulation |
| Change Admin | Transfers protocol control | Use multisig, verify address multiple times |
| Pause Vault | Stops all user activity | Only for emergencies, have recovery plan |
| Unpause Vault | Resumes user activity | Verify fix is complete, monitor closely |
| Upgrade Implementation | Changes contract logic | Audit code, test thoroughly, storage layout check |
| Seed Vault | Initial capitalization | Verify provider approval, check price accuracy |
| Set Treasury | Controls fee destination | Use multisig address, verify before setting |

### High Risk (Requires Careful Review)

| Operation | Why High Risk | Mitigation |
|-----------|--------------|------------|
| Whitelist Aggregator | Security attack vector | Audit aggregator contract, test swaps |
| Whitelist LP Token | Enables new assets | Verify token contract, check liquidity |
| Set Kodiak Router | Controls trading route | Verify router address, test functionality |
| Set Router/Island (Hook) | Changes DeFi integration | Verify addresses, test deposit/withdraw |

### Medium Risk (Standard Admin)

| Operation | Notes |
|-----------|-------|
| Approve LP Deposit | Verify LP price, check depositor |
| Mint Management Fee | Automated by schedule, dilutes holders |
| Update Vault Value | Affects unstaking ratio, use accurate prices |
| Deploy to Kodiak | Check swap data, verify aggregator whitelisted |
| Add Seeder | Limited to seeding function only |

### Low Risk (Routine Maintenance)

| Operation | Notes |
|-----------|-------|
| Rescue HONEY Dust | Small amounts, minimal impact |
| Swap WBTC Dust | Cleanup operation, low value |
| Reject LP Deposit | Returns funds to user |

---

## Operations by Frequency

### One-Time (Initial Setup)

```
1. Set Treasury (all vaults)
2. Set Fee Schedule (Junior/Reserve)
3. Set Kodiak Router (Reserve)
4. Whitelist Enso Aggregator (all hooks)
5. Whitelist Kodiak Island LP (all vaults)
6. Seed Vaults (initial capitalization)
7. Set Router/Island/WBERA (all hooks)
```

### Monthly Operations

```
1. Rebase Senior Vault (1st of month, 12:00 UTC)
2. Mint Performance Fee if schedule = monthly
```

### Weekly Operations

```
1. Update Junior/Reserve Values (Monday 08:00 UTC)
2. Rescue Dust from Hooks (Friday 16:00 UTC)
```

### Daily Operations

```
1. Approve/Reject Pending LP Deposits (10:00 & 16:00 UTC)
2. Health Checks (06:00 & 18:00 UTC)
```

### As-Needed Operations

```
1. Deploy Capital to Kodiak (after large deposits)
2. Add Seeder (new seed provider)
3. Whitelist New LP Token (new pool)
4. Whitelist New Aggregator (new DEX)
```

### Emergency Only

```
1. Pause Vault (critical bug detected)
2. Unpause Vault (after fix verified)
3. Upgrade Implementation (security patch)
```

---

## Operations by Vault Type

### Senior Vault Only

| Operation | Function | Notes |
|-----------|----------|-------|
| Rebase | `rebase(uint256)` | Triggers spillover/backstop, mints fees |
| No Token Seeding | N/A | Senior only accepts HONEY or LP |

### Junior/Reserve Vaults Only

| Operation | Function | Notes |
|-----------|----------|-------|
| Mint Management Fee | `mintManagementFee()` | 1% supply inflation to treasury |
| Set Fee Schedule | `setMgmtFeeSchedule(uint256)` | Controls mint frequency |
| Update Value | `updateValue(uint256)` | Affects unstaking ratio |

### Reserve Vault Only

| Operation | Function | Notes |
|-----------|----------|-------|
| Seed with Token | `seedReserveWithToken(...)` | Accept WBTC/non-stablecoin |
| Invest in Kodiak | `investInKodiak(...)` | Convert WBTC to LP |
| Set Kodiak Router | `setKodiakRouter(address)` | Required for investInKodiak |

### All Vaults

| Operation | Function | Notes |
|-----------|----------|-------|
| Deploy to Kodiak | `deployToKodiak(...)` | Convert HONEY to LP |
| Seed with LP | `seedVault(...)` | Bootstrap with existing LP |
| Whitelist LP Token | `addWhitelistedLPToken(address)` | Enable new LP acceptance |
| Add Seeder | `addSeeder(address)` | Grant seeding permission |
| Set Treasury | `setTreasury(address)` | Configure fee recipient |
| Pause/Unpause | `pause()` / `unpause()` | Emergency controls |
| Change Admin | `changeAdmin(address)` | Transfer control |
| Approve/Reject LP Deposit | `approveLPDeposit(...)` / `rejectLPDeposit(...)` | Process user LP deposits |

---

## Operations by Actor

### Admin (EOA or Multisig)

All operations except user-facing functions. Admin has full control over:
- Protocol configuration
- Fee management
- Access control
- Emergency procedures
- Upgrades

### Seeder (Whitelisted Address)

| Operation | Function | Notes |
|-----------|----------|-------|
| Seed Vault | `seedVault(...)` | Bootstrap vaults with LP |
| Seed Reserve with Token | `seedReserveWithToken(...)` | Reserve only, WBTC |

### User (Anyone)

| Operation | Function | Notes |
|-----------|----------|-------|
| Deposit HONEY | `deposit(uint256, address)` | Standard ERC4626 |
| Deposit LP | `depositLP(address, uint256)` | Creates pending deposit |
| Cancel Pending Deposit | `cancelPendingDeposit(uint256)` | Before admin approval |
| Withdraw | `withdraw(...)` | After cooldown (Senior) or anytime (Jr/Res) |
| Redeem | `redeem(...)` | Burn shares for HONEY |
| Initiate Cooldown | `initiateCooldown()` | Senior only, 7 days |

### Anyone (Good Samaritan)

| Operation | Function | Notes |
|-----------|----------|-------|
| Claim Expired Deposit | `claimExpiredDeposit(uint256)` | Return LP after 48h expiry |

---

## Recommended Access Control Setup

### Production Deployment

```
Admin Role:     Gnosis Safe 3/5 Multisig
Deployer Role:  Gnosis Safe 3/5 Multisig (same as Admin)
Treasury:       Gnosis Safe 2/3 Multisig (different signers)
Seeders:        2-3 trusted EOAs or contracts
Hook Admin:     Same multisig as Vault Admin
```

### Operation Approval Requirements

| Risk Level | Signers Required | Timelock |
|------------|------------------|----------|
| Critical | 4/5 | 48 hours |
| High | 3/5 | 24 hours |
| Medium | 2/5 | None |
| Low | 1/5 | None |

---

## Automation Candidates

### Safe to Automate (with monitoring)

```
1. Daily LP Deposit Approval (if LP whitelisted)
2. Weekly Dust Recovery
3. Weekly Value Updates (with oracle price feeds)
4. Health Checks
5. Alert on expiring deposits
```

### Should Not Automate

```
1. Rebase (requires manual price verification)
2. Whitelist operations (security risk)
3. Admin changes (governance decision)
4. Emergency pause/unpause (manual judgment)
5. Upgrades (requires thorough testing)
```

---

## Quick Reference: Function Signatures

### Vault Functions
```solidity
// Core
rebase(uint256 lpPrice)
mintManagementFee()
updateValue(uint256 newValue)

// Liquidity
deployToKodiak(uint256 amount, uint256 minLP, address agg0, bytes data0, address agg1, bytes data1)
investInKodiak(address island, address token, uint256 amount, uint256 minLP, address agg0, bytes data0, address agg1, bytes data1)

// Seeding
seedVault(address lpToken, uint256 amount, address provider, uint256 lpPrice)
seedReserveWithToken(address token, uint256 amount, address provider, uint256 tokenPrice)

// Access Control
addSeeder(address seeder)
addWhitelistedLPToken(address lpToken)
addWhitelistedLP(address recipient)
changeAdmin(address newAdmin)
setTreasury(address treasury)

// Configuration
setMgmtFeeSchedule(uint256 interval)
setKodiakRouter(address router)

// User Deposits
approveLPDeposit(uint256 depositId, uint256 lpPrice)
rejectLPDeposit(uint256 depositId, string reason)

// Emergency
pause()
unpause()
```

### Hook Functions
```solidity
setRouter(address router)
setIsland(address island)
setWBERA(address wbera)
setAggregatorWhitelisted(address target, bool isWhitelisted)
setSlippage(uint256 minSharesPerAssetBps, uint256 minAssetOutBps)
setSafetyMultiplier(uint256 multiplier)
rescueHoneyToVault()
swapAndRescue(uint256 amount, address aggregator, bytes data)
```

---

**Use this categorization to:**
- Plan your admin workflows
- Set up proper access controls
- Identify automation opportunities
- Assess operational risks
- Train new operators

