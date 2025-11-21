# 🚀 Production Deployment Addresses

> **Deployed on Berachain Testnet**  
> Deployment Date: November 21, 2025

---

## 📦 Implementation Contracts

These are the upgradeable blueprint contracts:

| Contract | Address |
|----------|---------|
| **Senior Implementation** | `0xbc65274F211b6E3A8bf112b1519935b31403a84F` |
| **Junior Implementation** | `0x09788C38906Ed9fE422Bc4AEcA6F24F27924a962` |
| **Alar Implementation** | `0x7d1005d24E49883d38B375d762dfbfEFbd5d3A5C` |

---

## 🏦 Vault Proxy Contracts

These are the actual vault contracts users interact with:

| Vault | Name | Symbol | Address |
|-------|------|--------|---------|
| **Senior Vault** | Senior Tranche | `snrUSD` | `0x78a352318C4aD88ca14f84b200962E797e80D033` |
| **Junior Vault** | Junior Tranche | `jnr` | `0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883` |
| **Reserve Vault** | Alar | `alar` | `0x7754272c866892CaD4a414C76f060645bDc27203` |

---

## 🪝 Hook Contracts

Hooks manage Kodiak LP tokens for each vault:

| Hook | Address |
|------|---------|
| **Senior Hook** | `0xa5Af193E027bE91EFF4CC042cC79E0782F5472AC` |
| **Junior Hook** | `0xC6A224385e14dED076D86c69a91E42142698D1f1` |
| **Reserve Hook** | `0xBe01A06f99f8366f8803A61332e110d1235E5f3C` |

---

## 🪙 Token Addresses

External tokens used by the protocol:

| Token | Purpose | Address |
|-------|---------|---------|
| **USDE** | Stablecoin | `0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34` |
| **Sail.r** | Volatile Asset | `0x59a61B8d3064A51a95a5D6393c03e2152b1a2770` |
| **Kodiak LP Token** | LP Island | `0xB350944Be03cf5f795f48b63eAA542df6A3c8505` |

---

## 🔧 Infrastructure Addresses

| Component | Address |
|-----------|---------|
| **Kodiak Router** | `0x679a7C63FC83b6A4D9C1F931891d705483d4791F` |
| **Treasury** | `0x23fd5f6e2b07970c9b00d1da8e85c201711b7b74` |

---

## 🌱 Authorized Seeders

These addresses can seed vaults with initial liquidity:

1. `0x10f4f9325b3f170f4E2c049567C19c4e877D48FA`
2. `0xd81055ac2782453ccc7fd4f0bc811eef17d12dd7`

---

## 📋 Quick Reference for Scripts

Copy-paste ready environment variables:

```bash
# Implementations
export SENIOR_IMPL=0xbc65274F211b6E3A8bf112b1519935b31403a84F
export JUNIOR_IMPL=0x09788C38906Ed9fE422Bc4AEcA6F24F27924a962
export RESERVE_IMPL=0x7d1005d24E49883d38B375d762dfbfEFbd5d3A5C

# Vault Proxies
export SENIOR_VAULT=0x78a352318C4aD88ca14f84b200962E797e80D033
export JUNIOR_VAULT=0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883
export RESERVE_VAULT=0x7754272c866892CaD4a414C76f060645bDc27203

# Hooks
export SENIOR_HOOK=0xa5Af193E027bE91EFF4CC042cC79E0782F5472AC
export JUNIOR_HOOK=0xC6A224385e14dED076D86c69a91E42142698D1f1
export RESERVE_HOOK=0xBe01A06f99f8366f8803A61332e110d1235E5f3C

# Tokens
export STABLECOIN_ADDRESS=0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34
export SAILR_ADDRESS=0x59a61B8d3064A51a95a5D6393c03e2152b1a2770
export KODIAK_ISLAND_ADDRESS=0xB350944Be03cf5f795f48b63eAA542df6A3c8505

# Infrastructure
export KODIAK_ROUTER_ADDRESS=0x679a7C63FC83b6A4D9C1F931891d705483d4791F
export TREASURY=0x23fd5f6e2b07970c9b00d1da8e85c201711b7b74

# Seeders
export SEEDER1=0x10f4f9325b3f170f4E2c049567C19c4e877D48FA
export SEEDER2=0xd81055ac2782453ccc7fd4f0bc811eef17d12dd7
```

---

## 🔗 Verification Links

**Block Explorer**: [Add your block explorer URL]

- [Senior Vault](https://explorer.berachain.com/address/0x78a352318C4aD88ca14f84b200962E797e80D033)
- [Junior Vault](https://explorer.berachain.com/address/0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883)
- [Reserve Vault](https://explorer.berachain.com/address/0x7754272c866892CaD4a414C76f060645bDc27203)

---

## ✅ Deployment Status

- [x] All implementations deployed
- [x] All proxies deployed with custom names
- [x] All hooks deployed and connected
- [x] Vaults connected to each other
- [x] Hooks configured with Kodiak Island & Router
- [x] LP tokens whitelisted
- [x] Treasury configured
- [x] Fee schedules set (30 days)
- [x] Seeders authorized
- [x] Reserve vault Kodiak Router set

**System Status**: 🟢 Fully Operational

---

## 📝 Notes

- **Network**: Berachain Testnet
- **Deployment Method**: Foundry scripts with UUPS proxies
- **Admin**: Same as deployer wallet
- **Architecture**: Unified vault system with spillover mechanics
- **Fee Structure**: 
  - Senior: 1% management + ~2% performance + 1% withdrawal + 20% early penalty
  - Junior/Reserve: 1% of supply (30-day schedule) + 1% withdrawal

---

## 🔐 Security

- ✅ Admin set on all vaults
- ✅ Treasury configured
- ✅ All connections verified
- ✅ All configurations tested
- ⚠️ **Private keys must remain secure**
- ⚠️ **Verify all transactions before signing**

---

**Last Updated**: November 21, 2025  
**Documentation**: See `DEPLOY_STEP_BY_STEP.md` for complete deployment process
