# Production Deployment Addresses

> **Berachain Testnet** | Deployed: November 22, 2025

---


## Vaults (User-Facing)

| Vault | Name | Symbol | Address |
|-------|------|--------|---------|
| **Senior** | Senior Tranche | `snrUSD` | `0x49298F4314eb127041b814A2616c25687Db6b650` |
| **Junior** | Junior Tranche | `jnr` | `0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883` |
| **Reserve** | Alar | `alar` | `0x7754272c866892CaD4a414C76f060645bDc27203` |

---

## Implementations (Upgradeable Logic - V2)

| Contract | Address |
|----------|---------|
| **Senior** | `0x70d73f47072BA8Ed0BB2f1d312250176E2F95f5b` |
| **Junior** | `0xAf10B593EdB7fe2ccB20b685B08A0C1393d4B3B1` |
| **Reserve** | `0x7c787367d920D00E9ad4a7d287a675cD62dd53B1` |

---

## Hooks (LP Management)

| Hook | Address |
|------|---------|
| **Senior** | `0x27b84fcbdb17D108bE6C5f0F12FCAe4F9C78Ed1B` |
| **Junior** | `0xC6A224385e14dED076D86c69a91E42142698D1f1` |
| **Reserve** | `0xBe01A06f99f8366f8803A61332e110d1235E5f3C` |

---

## Tokens

| Token | Address |
|-------|---------|
| **USDE** (Stablecoin) | `0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34` |
| **Sail.r** (Volatile) | `0x59a61B8d3064A51a95a5D6393c03e2152b1a2770` |
| **Kodiak LP** | `0xB350944Be03cf5f795f48b63eAA542df6A3c8505` |

---

## Infrastructure

| Component | Address |
|-----------|---------|
| **Kodiak Router** | `0x679a7C63FC83b6A4D9C1F931891d705483d4791F` |
| **Treasury** | `0x23FD5F6e2B07970c9B00D1da8E85c201711B7b74` |
| **Admin** | `0x6fa2149E69DbCBDCf6F16F755E08c10E53c40605` |

---

## Seeders

| # | Address |
|---|---------|
| 1 | `0x10f4f9325b3f170f4E2c049567C19c4e877D48FA` |
| 2 | `0xd81055ac2782453ccc7fd4f0bc811eef17d12dd7` |
| 3 | `0xe17bc155aacf979cf6dff688ad284834b711fce0` |
| 4 | `0x5cc2946b8b73f4b9674bc12cb208c7417c40f774` |

---

## Environment Variables (Copy-Paste Ready)

```bash
# Vaults
export SENIOR_VAULT=0x49298F4314eb127041b814A2616c25687Db6b650
export JUNIOR_VAULT=0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883
export RESERVE_VAULT=0x7754272c866892CaD4a414C76f060645bDc27203

# Implementations (V2 - upgraded)
export SENIOR_IMPL=0x3b93f0EF9944B12bC5d9C2cE232AA2ce926C80eb
export JUNIOR_IMPL=0xabA69764135547E42A671E17df41756A7412b88f
export RESERVE_IMPL=0xC1E87f7f4eBe07780D660E3AdFBB6149ccA1c9A6

# Old Implementations (V1 - for rollback)
export SENIOR_IMPL_V1=0xC9Eb65414650927dd9e8839CA7c696437e982547
export JUNIOR_IMPL_V1=0xdFCdD986F2a5E412671afC81537BA43D1f6A328b
export RESERVE_IMPL_V1=0x657613E8265e07e542D42802515677A1199989B2

# Hooks
export SENIOR_HOOK=0x27b84fcbdb17D108bE6C5f0F12FCAe4F9C78Ed1B
export JUNIOR_HOOK=0xC6A224385e14dED076D86c69a91E42142698D1f1
export RESERVE_HOOK=0xBe01A06f99f8366f8803A61332e110d1235E5f3C

# Tokens
export STABLECOIN_ADDRESS=0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34
export SAILR_ADDRESS=0x59a61B8d3064A51a95a5D6393c03e2152b1a2770
export KODIAK_ISLAND_ADDRESS=0xB350944Be03cf5f795f48b63eAA542df6A3c8505

# Infrastructure
export KODIAK_ROUTER_ADDRESS=0x679a7C63FC83b6A4D9C1F931891d705483d4791F
export TREASURY=0x23FD5F6e2B07970c9B00D1da8E85c201711B7b74

# Seeders
export SEEDER1=0x10f4f9325b3f170f4E2c049567C19c4e877D48FA
export SEEDER2=0xd81055ac2782453ccc7fd4f0bc811eef17d12dd7
export SEEDER3=0xe17bc155aacf979cf6dff688ad284834b711fce0
export SEEDER4=0x5cc2946b8b73f4b9674bc12cb208c7417c40f774
```

---

## Block Explorer Links

- [Senior Vault](https://berascan.com/address/0x49298F4314eb127041b814A2616c25687Db6b650)
- [Junior Vault](https://berascan.com/address/0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883)
- [Reserve Vault](https://berascan.com/address/0x7754272c866892CaD4a414C76f060645bDc27203)

---

## Upgrade History

### V2 - Role Management (November 23, 2025)
**Added:** Liquidity Manager, Price Feed Manager, Contract Updater roles
- Senior: [0x3b93f0EF9944B12bC5d9C2cE232AA2ce926C80eb](https://berascan.com/address/0x3b93f0ef9944b12bc5d9c2ce232aa2ce926c80eb)
- Junior: [0xabA69764135547E42A671E17df41756A7412b88f](https://berascan.com/address/0xaba69764135547e42a671e17df41756a7412b88f)
- Reserve: [0xC1E87f7f4eBe07780D660E3AdFBB6149ccA1c9A6](https://berascan.com/address/0xc1e87f7f4ebe07780d660e3adfbb6149cca1c9a6)

### V1 - Initial Deployment (November 22, 2025)
- Senior: `0xC9Eb65414650927dd9e8839CA7c696437e982547`
- Junior: `0xdFCdD986F2a5E412671afC81537BA43D1f6A328b`
- Reserve: `0x657613E8265e07e542D42802515677A1199989B2`

---

