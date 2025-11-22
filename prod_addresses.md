# Production Deployment Addresses

> **Deployed on Berachain Testnet**  
> Deployment Date: November 21, 2025  
> Last Upgraded: November 22, 2025 (Code cleanup - removed unused depositor whitelist)

---

## Implementation Contracts

These are the upgradeable blueprint contracts (Current Version - v2):

| Contract | Address |
|----------|---------|
| **Senior Implementation** | `0xC9Eb65414650927dd9e8839CA7c696437e982547` |
| **Junior Implementation** | `0xdFCdD986F2a5E412671afC81537BA43D1f6A328b` |
| **Alar Implementation** | `0x657613E8265e07e542D42802515677A1199989B2` |

---

## Vault Proxy Contracts

These are the actual vault contracts users interact with (v3 - New Senior Vault):

| Vault | Name | Symbol | Address |
|-------|------|--------|---------|
| **Senior Vault** | Senior Tranche | `snrUSD` | `0x49298F4314eb127041b814A2616c25687Db6b650` |
| **Junior Vault** | Junior Tranche | `jnr` | `0x3a0A97dCa5E6caCc258490D5eCe453412f8e1883` |
| **Reserve Vault** | Alar | `alar` | `0x7754272C866892CAd4a414C76f060645BDc27203` |

---

## Hook Contracts

Hooks manage Kodiak LP tokens for each vault (v3 - New Senior Hook):

| Hook | Address |
|------|---------|
| **Senior Hook** | `0x1108E5FF12Cf7904bFe46BFaa70d41E321c54dfa` |
| **Junior Hook** | `0xC6A224385e14dED076D86c69a91E42142698D1f1` |
| **Reserve Hook** | `0xBe01A06f99f8366f8803A61332e110d1235E5f3C` |

---

## Token Addresses

External tokens used by the protocol:

| Token | Purpose | Address |
|-------|---------|---------|
| **USDE** | Stablecoin | `0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34` |
| **Sail.r** | Volatile Asset | `0x59a61B8d3064A51a95a5D6393c03e2152b1a2770` |
| **Kodiak LP Token** | LP Island | `0xB350944Be03cf5f795f48b63eAA542df6A3c8505` |

---

## Infrastructure Addresses

| Component | Address |
|-----------|---------|
| **Kodiak Router** | `0x679a7C63FC83b6A4D9C1F931891d705483d4791F` |
| **Treasury** | `0x23fd5f6e2b07970c9b00d1da8e85c201711b7b74` |

---

## Authorized Seeders

These addresses can seed vaults with initial liquidity (All Vaults):

1. `0x10f4f9325b3f170f4E2c049567C19c4e877D48FA`
2. `0xd81055ac2782453ccc7fd4f0bc811eef17d12dd7`
3. `0xe17bc155aacf979cf6dff688ad284834b711fce0`
4. `0x5cc2946b8b73f4b9674bc12cb208c7417c40f774`

---

## Quick Reference for Scripts

Copy-paste ready environment variables:

```bash
# Implementations (v2 - Upgraded Nov 22, 2025)
export SENIOR_IMPL=0xC9Eb65414650927dd9e8839CA7c696437e982547
export JUNIOR_IMPL=0xdFCdD986F2a5E412671afC81537BA43D1f6A328b
export RESERVE_IMPL=0x657613E8265e07e542D42802515677A1199989B2

# Vault Proxies (v3 - New Senior Vault)
export SENIOR_VAULT=0x49298F4314eb127041b814A2616c25687Db6b650
export JUNIOR_VAULT=0x3a0A97dCa5E6CaCC258490d5ece453412f8E1883
export RESERVE_VAULT=0x7754272C866892CAd4a414C76f060645BDc27203

# Hooks (v3 - New Senior Hook)
export SENIOR_HOOK=0x1108E5FF12Cf7904bFe46BFaa70d41E321c54dfa
export JUNIOR_HOOK=0xC6A224385e14dED076D86c69a91E42142698D1f1
export RESERVE_HOOK=0xBe01A06f99f8366f8803A61332e110d1235E5f3C

# Tokens
export STABLECOIN_ADDRESS=0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34
export SAILR_ADDRESS=0x59a61B8d3064A51a95a5D6393c03e2152b1a2770
export KODIAK_ISLAND_ADDRESS=0xB350944Be03cf5f795f48b63eAA542df6A3c8505

# Infrastructure
export KODIAK_ROUTER_ADDRESS=0x679a7C63FC83b6A4D9C1F931891d705483d4791F
export TREASURY=0x23fd5f6e2b07970c9b00d1da8e85c201711b7b74

# Seeders (All Vaults)
export SEEDER1=0x10f4f9325b3f170f4E2c049567C19c4e877D48FA
export SEEDER2=0xd81055ac2782453ccc7fd4f0bc811eef17d12dd7
export SEEDER3=0xe17bc155aacf979cf6dff688ad284834b711fce0
export SEEDER4=0x5cc2946b8b73f4b9674bc12cb208c7417c40f774
```

---

## Verification Links

**Block Explorer**: Berascan (berascan.com)

### Vault Proxies (v3 - New Senior Vault)
- [Senior Vault](https://berascan.com/address/0x49298F4314eb127041b814A2616c25687Db6b650)
- [Junior Vault](https://berascan.com/address/0x3a0A97dCa5E6CaCC258490d5ece453412f8E1883)
- [Reserve Vault](https://berascan.com/address/0x7754272C866892CAd4a414C76f060645BDc27203)

### Implementations (v2 - Current)
- [Senior Implementation](https://berascan.com/address/0xC9Eb65414650927dd9e8839CA7c696437e982547)
- [Junior Implementation](https://berascan.com/address/0xdFCdD986F2a5E412671afC81537BA43D1f6A328b)
- [Reserve Implementation](https://berascan.com/address/0x657613E8265e07e542D42802515677A1199989B2)

---

## Deployment Status

- [x] All implementations deployed (v2 - Nov 22, 2025)
- [x] All proxies deployed with custom names
- [x] New Senior Vault deployed (v3 - Nov 22, 2025)
- [x] New Senior Hook deployed and connected
- [x] Junior and Reserve reconnected to new Senior Vault
- [x] All hooks configured with Kodiak Island & Router
- [x] LP tokens whitelisted
- [x] Treasury configured
- [x] Fee schedules set (30 days)
- [x] 4 Seeders authorized on all vaults
- [x] Reserve vault Kodiak Router set
- [x] All v2 implementations verified on Berascan

**System Status**: Fully Operational (v3 - New Senior Vault)

---

## Upgrade History

### v3 - November 22, 2025
**New Senior Vault Deployment (Admin Recovery)**

**What Happened:**
- **Issue**: v2 upgrade corrupted Senior Vault's admin/deployer storage (`0x0`)
- **Cause**: Storage layout mismatch during UUPS upgrade
- **Solution**: Deployed fresh Senior Vault proxy with v2 implementation

**New Deployments:**
- New Senior Vault Proxy: `0x49298F4314eb127041b814A2616c25687Db6b650` 🆕
- New Senior Hook: `0x1108E5FF12Cf7904bFe46BFaa70d41E321c54dfa` 🆕

**Configuration Applied:**
- ✅ Admin set to deployer wallet
- ✅ Junior and Reserve vaults connected
- ✅ Treasury configured
- ✅ New Kodiak hook set and whitelisted
- ✅ LP token whitelisted
- ✅ 4 seeders authorized
- ✅ Junior and Reserve updated to point to new Senior Vault

**Old (Broken) Addresses:**
- ❌ Old Senior Vault: `0xBC65274F211b6e3a8bf112B1519935B31403A84f` (DO NOT USE)
- ❌ Old Senior Hook: `0xa5Af193E027bE91EFF4CC042cC79E0782F5472AC` (DO NOT USE)

### v2 - November 22, 2025
**Code Cleanup & Optimization**

**What Changed:**
- Removed unused depositor whitelist system from `BaseVault.sol` (~40 lines)
- Removed unused depositor whitelist from `UnifiedSeniorVault.sol`
- Fixed variable shadowing issues in `UnifiedSeniorVault.sol`
- Removed duplicate `getLPBalance()` function
- Removed buggy `getLPHoldings()` function

**Impact:**
- Cleaner, more maintainable code
- No functional changes - all existing features work the same
- Lower deployment gas costs for future deployments
- Junior and Reserve successfully upgraded via UUPS pattern
- **Senior Vault upgrade corrupted storage** (fixed in v3)

**New Implementation Addresses:**
- Senior: `0xC9Eb65414650927dd9e8839CA7c696437e982547` ✅ Verified
- Junior: `0xdFCdD986F2a5E412671afC81537BA43D1f6A328b` ✅ Verified
- Reserve: `0x657613E8265e07e542D42802515677A1199989B2` ✅ Verified

### v1 - November 21, 2025
Initial deployment with full functionality

---

## Notes

- **Network**: Berachain Testnet
- **Current Version**: v3 (New Senior Vault - Nov 22, 2025)
- **Deployment Method**: Foundry scripts with UUPS proxies
- **Admin**: Same as deployer wallet (`0x6fa2149E69DbCBDCf6F16F755E08c10E53c40605`)
- **Architecture**: Unified vault system with spillover mechanics
- **Fee Structure**: 
  - Senior: 1% management + ~2% performance + 1% withdrawal + 20% early penalty
  - Junior/Reserve: 1% of supply (30-day schedule) + 1% withdrawal
- **Important**: Use **NEW** Senior Vault address (`0x49298...`), not old one (`0xBC652...`)

---

## Security

- All vaults have admin configured
- Treasury address set on all vaults
- All connections verified
- All configurations tested
- UUPS upgrade mechanism secured (only admin can upgrade)
- All upgrades tested and verified on Berascan

---

## How the Upgrade Works

The vault system uses the UUPS (Universal Upgradeable Proxy Standard) pattern:

1. **Proxy Addresses Never Change** - Users always interact with the same addresses
2. **Implementation Can Be Upgraded** - The underlying logic can be improved
3. **State Persists** - All balances, shares, and configuration remain intact
4. **Admin-Only Upgrades** - Only the admin wallet can upgrade implementations

**Example Upgrade Command:**
```bash
cast send $SENIOR_VAULT \
  "upgradeToAndCall(address,bytes)" \
  $NEW_IMPLEMENTATION_ADDRESS \
  0x \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL
```

---

