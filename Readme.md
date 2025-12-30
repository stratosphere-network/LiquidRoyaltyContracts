# Tranching Protocol - New Implementations

## Deployed Implementation Addresses (Mainnet)

| Vault | Implementation Address |
|-------|------------------------|
| **Senior** | `0x6baD25B18d4c63f9e0023C64Ed02A18E7c861d1d` |
| **Junior** | `0x6Db72eD03EfeA49D00c601Fd4738c06a250Fe0Dd` |
| **Reserve** | `0x13baAB17dB247d0c837e1DD341f05C21ecD55E67` |

## Proxy Addresses

| Vault | Proxy Address |
|-------|---------------|
| **Senior** | `0x49298F4314eb127041b814A2616c25687Db6b650` |
| **Junior** | `0xBaad9F161197A2c26BdC92F8DDFE651c3383CE4E` |
| **Reserve** | `0x7754272c866892CaD4a414C76f060645bDc27203` |

## Upgrade Instructions

See [docs/senior_upgrade.md](docs/senior_upgrade.md) for detailed upgrade steps.

### Quick Upgrade (via Multisig)

**Senior Vault:**
```
To:       0x49298F4314eb127041b814A2616c25687Db6b650
Function: upgradeToAndCall(address,bytes)
Param 1:  0x6baD25B18d4c63f9e0023C64Ed02A18E7c861d1d
Param 2:  0x54a08606

```

**Junior Vault:**
```
To:       0xBaad9F161197A2c26BdC92F8DDFE651c3383CE4E
Function: upgradeToAndCall(address,bytes)
Param 1:  0x6Db72eD03EfeA49D00c601Fd4738c06a250Fe0Dd
Param 2:  0x
```

**Reserve Vault:**
```
To:       0x7754272c866892CaD4a414C76f060645bDc27203
Function: upgradeToAndCall(address,bytes)
Param 1:  0x13baAB17dB247d0c837e1DD341f05C21ecD55E67
Param 2:  0x
```
