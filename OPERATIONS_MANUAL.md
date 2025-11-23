# Admin Operations by Category

## Core Protocol Operations

| Operation | Vault | Frequency | Risk | Command |
|-----------|-------|-----------|------|---------|
| Rebase Senior Vault | Senior | Monthly | Critical | `cast send $SENIOR_VAULT "rebase(uint256)" $LP_PRICE --private-key $PRIVATE_KEY --rpc-url $RPC_URL --gas-limit 3000000 --legacy` |
| Mint Management Fee | Junior/Reserve | Per Schedule | Medium | `cast send $VAULT "mintManagementFee()" --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` |
| Update Vault Value | Junior/Reserve | Weekly | Medium | `cast send $VAULT "updateValue(uint256)" $NEW_VALUE --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` |

---

## Liquidity Management Operations

| Operation | Vault | Frequency | Risk | Command |
|-----------|-------|-----------|------|---------|
| Deploy HONEY to Kodiak | All | After Deposits | Medium | `cast send $VAULT "deployToKodiak(uint256,uint256,address,bytes,address,bytes)" $AMOUNT $MIN_LP $AGG0 $DATA0 $AGG1 $DATA1 --private-key $PRIVATE_KEY --rpc-url $RPC_URL --gas-limit 2000000 --legacy` |
| Invest Assets in Kodiak | Reserve | As Needed | Medium | `cast send $RESERVE_VAULT "investInKodiak(address,address,uint256,uint256,address,bytes,address,bytes)" $ISLAND $TOKEN $AMOUNT $MIN_LP $AGG0 $DATA0 $AGG1 $DATA1 --private-key $PRIVATE_KEY --rpc-url $RPC_URL --gas-limit 2000000 --legacy` |
| Rescue HONEY Dust from Hook | All Hooks | Weekly | Low | `cast send $HOOK "rescueHoneyToVault()" --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` |
| Swap WBTC Dust to Vault | All Hooks | Weekly | Low | `cast send $HOOK "swapAndRescue(uint256,address,bytes)" $AMOUNT $AGG $DATA --private-key $PRIVATE_KEY --rpc-url $RPC_URL --gas-limit 1000000 --legacy` |

---

## Access Control Operations

| Operation | Vault | Frequency | Risk | Command |
|-----------|-------|-----------|------|---------|
| Whitelist New Aggregator | All Hooks | Once per Aggregator | High | `cast send $HOOK "setAggregatorWhitelisted(address,bool)" $AGGREGATOR true --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` |
| Whitelist New LP Token | All Vaults | Once per Token | High | `cast send $VAULT "addWhitelistedLPToken(address)" $LP_TOKEN --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` |
| Add Whitelisted LP Recipient | All Vaults | As Needed | Medium | `cast send $VAULT "addWhitelistedLP(address)" $RECIPIENT --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` |
| Add Seeder | All Vaults | As Needed | Medium | `cast send $VAULT "addSeeder(address)" $SEEDER --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` |
| Change Admin | All Vaults | Rare | Critical | `cast send $VAULT "changeAdmin(address)" $NEW_ADMIN --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` |

---

## User Deposit Operations

| Operation | Vault | Frequency | Risk | Command |
|-----------|-------|-----------|------|---------|
| Approve LP Deposit | Senior/Junior | Daily | Medium | `cast send $VAULT "approveLPDeposit(uint256,uint256)" $DEPOSIT_ID $LP_PRICE --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` |
| Reject LP Deposit | Senior/Junior | As Needed | Medium | `cast send $VAULT "rejectLPDeposit(uint256,string)" $DEPOSIT_ID "reason" --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` |

---

## Initial Setup Operations

| Operation | Vault | Frequency | Risk | Command |
|-----------|-------|-----------|------|---------|
| Seed Vault with LP Tokens | All Vaults | Once | Critical | `cast send $VAULT "seedVault(address,uint256,address,uint256)" $LP_TOKEN $AMOUNT $PROVIDER $LP_PRICE --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` |
| Seed Reserve with Token | Reserve | Once | Critical | `cast send $RESERVE_VAULT "seedReserveWithToken(address,uint256,address,uint256)" $TOKEN $AMOUNT $PROVIDER $TOKEN_PRICE --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` |
| Set Treasury | All Vaults | Once | Critical | `cast send $VAULT "setTreasury(address)" $TREASURY --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` |
| Set Fee Schedule | Junior/Reserve | Once | Medium | `cast send $VAULT "setMgmtFeeSchedule(uint256)" $INTERVAL --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` |
| Set Kodiak Router | Reserve | Once | High | `cast send $RESERVE_VAULT "setKodiakRouter(address)" $ROUTER --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` |

---

## Emergency Operations

| Operation | Vault | Frequency | Risk | Command |
|-----------|-------|-----------|------|---------|
| Pause Vault | All Vaults | Emergency Only | Critical | `cast send $VAULT "pause()" --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` |
| Unpause Vault | All Vaults | After Fix | Critical | `cast send $VAULT "unpause()" --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` |

---

## Upgrade Operations

| Operation | Vault | Frequency | Risk | Command |
|-----------|-------|-----------|------|---------|
| Upgrade Vault Implementation | All Proxies | When Needed | Critical | `cast send $PROXY "upgradeToAndCall(address,bytes)" $NEW_IMPL "0x" --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` |

---

## Hook Configuration Operations

| Operation | Vault | Frequency | Risk | Command |
|-----------|-------|-----------|------|---------|
| Set Router | All Hooks | Once/Rare | High | `cast send $HOOK "setRouter(address)" $ROUTER --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` |
| Set Island | All Hooks | Once/Rare | High | `cast send $HOOK "setIsland(address)" $ISLAND --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` |
| Set WBERA | All Hooks | Once/Rare | Medium | `cast send $HOOK "setWBERA(address)" $WBERA --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` |
| Set Slippage | All Hooks | Rare | Medium | `cast send $HOOK "setSlippage(uint256,uint256)" $MIN_SHARES_BPS $MIN_ASSET_BPS --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` |
| Set Safety Multiplier | All Hooks | Rare | Medium | `cast send $HOOK "setSafetyMultiplier(uint256)" $MULTIPLIER --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy` |

---

## Operation Risk Summary

| Risk Level | Count | Operations |
|------------|-------|------------|
| **Critical** | 7 | Rebase, Pause, Unpause, Upgrade, Seed Vault, Seed Reserve, Set Treasury, Change Admin |
| **High** | 4 | Whitelist Aggregator, Whitelist LP Token, Set Kodiak Router, Set Router/Island |
| **Medium** | 10 | Mint Fee, Update Value, Deploy to Kodiak, Invest in Kodiak, Add LP Recipient, Add Seeder, Approve Deposit, Reject Deposit, Set Fee Schedule, Set Slippage, Set Safety Multiplier, Set WBERA |
| **Low** | 2 | Rescue Dust, Swap Dust |

---

## Operation Frequency Summary

| Frequency | Count | Operations |
|-----------|-------|------------|
| **Monthly** | 1 | Rebase Senior Vault |
| **Weekly** | 3 | Update Values (Jr/Res), Rescue Dust, Swap Dust |
| **Daily** | 1 | Approve/Reject LP Deposits |
| **As Needed** | 5 | Deploy to Kodiak, Invest in Kodiak, Add Seeder, Add LP Recipient, Reject Deposit |
| **Once (Setup)** | 9 | Seed Vault, Seed Reserve, Set Treasury, Set Fee Schedule, Set Router, Whitelist Aggregator, Whitelist LP Token, Set Island, Set WBERA, Set Kodiak Router |
| **Rare** | 4 | Change Admin, Set Slippage, Set Safety Multiplier, Upgrade |
| **Emergency** | 2 | Pause, Unpause |

---

## Quick Reference: Addresses

```bash
# Vault Proxies
SENIOR_VAULT=0x49298F4314eb127041b814A2616c25687Db6b650
JUNIOR_VAULT=0x3a0A97dCa5E6CaCC258490d5ece453412f8E1883
RESERVE_VAULT=0x7754272C866892CAd4a414C76f060645BDc27203

# Hooks
SENIOR_HOOK=0x1108E5FF12Cf7904bFe46BFaa70d41E321c54dfa
JUNIOR_HOOK=0xC6A224385e14dED076D86c69a91E42142698D1f1
RESERVE_HOOK=0xBe01A06f99f8366f8803A61332e110d1235E5f3C

# Infrastructure
ENSO_AGGREGATOR=0x38147794FF247e5Fc179eDbAE6C37fff88f68C52
KODIAK_ISLAND=0xB350944Be03cf5f795f48b63eAA542df6A3c8505
KODIAK_ROUTER=0x4E8d96EEDE486eDFc47e78e4E75B84e4f5D8a1F1
```
