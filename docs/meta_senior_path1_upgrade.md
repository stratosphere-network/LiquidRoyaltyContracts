# Meta Senior Path1 (Berachain) + snrUSD CCIP pools

## Live targets

| Item | Berachain (80094) | Base (8453) |
|------|-------------------|-------------|
| snrUSD proxy | `0xC38421E5577250EBa177Bc5bC832E747bea13Ee0` | `0xdB3A54CBC468e8D99d7522579174E0733D548507` |
| Current / reference impl | `0xa4e99ae599e2f656917335a5b09a06c420954768` | `0xF37E9D84e844440a081359716871C1064D88B2b3` |
| Admin Safe | `0xd60c3A29Fbe444cF9d3AA240F4a9263BC83bde61` | `0xc6EAa8A2D727bCb74316D4C93Ca25D164B0Ad91e` |

## Official CCIP (TokenPoolFactory 2.0.0 `getStaticConfig`)

| | Berachain | Base |
|---|-----------|------|
| Factory | `0x961971D9Ef1D61e2EEAC94c50De96D600797DFE9` | `0x8cE19F73e85a68490e08c89b510215Ca71B0F2B8` |
| RMN | `0x25943b8C30C47F4eF09CcF2BAE315EbaF591881d` | `0xC842c69d54F83170C42C4d556B4F6B2ca53Dd3E8` |
| TokenAdminRegistry | `0x0944C3Fb1dB7D165336569221995B31cBE6c8A55` | `0x6f6C373d09C07425BaAE72317863d7F6bb731e37` |
| RegistryModuleOwnerCustom | `0x160603D7C0Ac00409276bf6707430712Caf5b555` | `0xAFEd606Bd2CAb6983fC6F10167c98aaC2173D77f` |
| Router | `0x71a275704c283486fBa26dad3dd0DB78804426eF` | `0x881e3A65B4d4a04dD529061dd0071cf975F58bCD` |
| Remote selector | Base `15971525489660198786` | Berachain `1294465214383781161` |

## Deploy commands (no keys; dry-run)

```bash
export PATH="$HOME/.foundry/bin:$PATH"
cd LiquidRoyaltyContracts

# Path1 implementation only
forge script script/DeployMetaSeniorPath1Impl.s.sol:DeployMetaSeniorPath1Impl \
  --rpc-url https://berachain.drpc.org

# Storage read against live proxy (fork)
forge script script/ValidateMetaSeniorStorageLayout.s.sol:ValidateMetaSeniorStorageLayout \
  --rpc-url https://berachain.drpc.org

# CCIP pool (dry-run; Moss sets SNRUSD_POOL_BROADCAST=true + DEPLOYER_PRIVATE_KEY to broadcast)
# Export pool init code once from vendored chainlink-ccip:
(cd lib/chainlink-ccip/chains/evm && FOUNDRY_PROFILE=ccip forge inspect BurnMintTokenPool bytecode | sed -n '1p') > /tmp/pool.hex
export BURN_MINT_POOL_INIT_CODE=$(cast parse-bytes "$(cat /tmp/pool.hex)")

forge script script/ccip/DeploySnrUsdBurnMintTokenPool.s.sol:DeploySnrUsdBurnMintTokenPool \
  --rpc-url https://berachain.drpc.org

forge script script/ccip/DeploySnrUsdBurnMintTokenPool.s.sol:DeploySnrUsdBurnMintTokenPool \
  --rpc-url https://mainnet.base.org

# Safe batches (after pools are deployed)
BERA_POOL_ADDRESS=0x... BASE_POOL_ADDRESS=0x... \
  forge script script/ccip/GenerateSnrUsdCcipSafeBatches.s.sol:GenerateSnrUsdCcipSafeBatches
```

## Storage layout check

```bash
forge inspect MetaSeniorVault storage-layout --json > /tmp/meta-senior-base.json
forge inspect MetaSeniorVaultPath1 storage-layout --json > /tmp/meta-senior-path1.json
```

All slots from `MetaSeniorVault` must match between files; Path1 adds tail slots only (`_reportedBaseSleeveAssets`, guards, AccessControl roles).

## Alan / Moss decisions

- `initializePath1` guards: default proposal `maxBaseSleeveDeltaBps=500` (5%), `baseSleeveMaxStaleness=36 hours` — adjust before upgrade calldata.
- Whether `setBaseSleeveAssets` reporter is OPERATOR only or also a dedicated keeper EOA.
- Pool addresses for Safe JSON (`BERA_POOL_ADDRESS`, `BASE_POOL_ADDRESS`) after Create2 deploy.
- Confirm remote `applyChainUpdates` from factory deploy is sufficient or add manual pool admin steps for FTF-disabled limits.