# Contract Addresses

## Proxies (User-Facing)

| Vault   | Name           | Symbol | Proxy Address                                |
| ------- | -------------- | ------ | -------------------------------------------- |
| Senior  | Senior Tranche | snrUSD | `0x49298F4314eb127041b814A2616c25687Db6b650` |
| Junior  | Junior Tranche | jnr    | `0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883` |
| Reserve | Alar           | alar   | `0x7754272c866892CaD4a414C76f060645bDc27203` |

## Implementations

| Vault   | Implementation Address                       |
| ------- | -------------------------------------------- |
| Senior  | `0x5995ea3ddb97e9a68F8E9a1eAb48b6faff63AF66` |
| Junior  | `0x0a3eBFd1266d44C09d4663c77b702EE315225d6b` |
| Reserve | `0xA035c5531B9775eB80b47157dE56f9c1C167614D` |

## Kodiak Hooks

| Vault   | Hook Address                                 |
| ------- | -------------------------------------------- |
| Senior  | `0x00b00A42FbE8216E9c87FE7e273CF668d16b0e63` |
| Junior  | `0x3587f67eFCDF48C4483348C8822e31bF14C94010` |
| Reserve | `0xCF8f7B13AC286f05475DfAd9A0B953FA73C34546` |

Junior hook- 0x631B6766797E350e897cE1bC7954CF5cB8ef90aB
Alar hook- 0x608807b420f33873B26a5C7A43CAeE790a0CD6da

## Indexer API (Goldsky)

✅ **LIVE GraphQL endpoints** for querying all vault data:

### Senior Vault

```
https://api.goldsky.com/api/public/project_cmjgbb5x4ix5j0104hdx03a5u/subgraphs/liquid-royalty-senior/v2.0.0/gn
```

### Junior Vault

```
https://api.goldsky.com/api/public/project_cmjgbb5x4ix5j0104hdx03a5u/subgraphs/liquid-royalty-junior/v2.0.0/gn
```

### Reserve Vault

```
https://api.goldsky.com/api/public/project_cmjgbb5x4ix5j0104hdx03a5u/subgraphs/liquid-royalty-reserve/v2.0.0/gn
```

**Features:**

- All vault deposits & withdrawals
- Rebase events & APY changes
- Spillover & backstop transactions
- User balances & activity history
- Protocol statistics & analytics

**Docs:** See [/subgraph/README.md](../subgraph/README.md)
