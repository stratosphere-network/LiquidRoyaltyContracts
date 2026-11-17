# Meta Senior Path1 (Berachain) + snrUSD CCIP pools

## Live targets

| Item | Berachain (80094) | Base (8453) |
|------|-------------------|-------------|
| snrUSD proxy | `0xC38421E5577250EBa177Bc5bC832E747bea13Ee0` | `0xdB3A54CBC468e8D99d7522579174E0733D548507` |
| Current / reference impl | `0xa4e99ae599e2f656917335a5b09a06c420954768` | `0xF37E9D84e844440a081359716871C1064D88B2b3` |
| Admin Safe | `0xd60c3A29Fbe444cF9d3AA240F4a9263BC83bde61` | `0xc6EAa8A2D727bCb74316D4C93Ca25D164B0Ad91e` |

## Live impl vs vendored `MetaSeniorVault`

Live Berachain implementation `0xa4e99ae5…` predates the vendored `StrategyManagerVault` copy in this repo. On-chain bytecode does **not** expose:

- `vaultOpenToPublic()`, `setVaultOpenToPublic(bool)`
- `depositCap()`, `setDepositCap(uint256)`
- `whitelistedUsers(address)`, `setWhitelistedUser(address,bool)`

Confirmed live storage (sequential layout):

| Slot | Field | Live value |
|------|--------|------------|
| 0 | `feeAddress` | `0x23FD5F6e2B07970c9B00D1da8E85c201711B7b74` |
| 3 | `subVaultList` length | 2 |
| 5 | `unstakingFeeBps` | 30 |
| 6–8 | (appended in vendored layout) | zero on live — safe to use for `whitelistedUsers` mapping, `vaultOpenToPublic`, `depositCap` |

Live deposit/redeem/initiateCooldown have **no** public-gate. Path1 adds gates that default to closed when those slots are untouched.

**ReentrancyGuard / slot 0:** Live already keeps `feeAddress` at slot 0 (OZ 5.5-style namespaced guard). Do not introduce a linear `_status` at slot 0.

### Mandatory upgrade calldata

Do **not** call `upgradeToAndCall(impl, "")`. That leaves `vaultOpenToPublic == false` and would block all user deposits/redeems on ~224k-share live vault.

Required Safe call:

```text
upgradeToAndCall(<new Path1 impl>, initializePath1())
```

Path1 scope: CCT `mint` / `burn` / `burnFrom` (no USDe movement), `grantMintAndBurnRoles`, and opening the vault. No Base sleeve / keeper NAV reporting in this implementation (a cross-chain subvault may land later).

`initializePath1()` sets `vaultOpenToPublic = true`, `depositCap = 0`, and emits `VaultOpenToPublicSet(true)` / `DepositCapSet(0,0)`.

Deploy a **new** implementation after this PR is merged; do not upgrade to an older Path1 build (e.g. abandoned `0xE226…`). Proxy remains on live impl `0xa4e99…` until the Safe runs the call above.

Run `forge script script/DeployMetaSeniorPath1Impl.s.sol` on Berachain RPC to print combined Safe calldata with the freshly simulated impl address.

## Official CCIP (TokenPoolFactory 2.0.0)

| | Berachain | Base |
|---|-----------|------|
| Factory | `0x961971D9Ef1D61e2EEAC94c50De96D600797DFE9` | `0x8cE19F73e85a68490e08c89b510215Ca71B0F2B8` |
| RMN | `0x25943b8C30C47F4eF09CcF2BAE315EbaF591881d` | `0xC842c69d54F83170C42C4d556B4F6B2ca53Dd3E8` |
| TokenAdminRegistry | `0x0944C3Fb1dB7D165336569221995B31cBE6c8A55` | `0x6f6C373d09C07425BaAE72317863d7F6bb731e37` |
| RegistryModuleOwnerCustom | `0x160603D7C0Ac00409276bf6707430712Caf5b555` | `0xAFEd606Bd2CAb6983fC6F10167c98aaC2173D77f` |
| Router | `0x71a275704c283486fBa26dad3dd0DB78804426eF` | `0x881e3A65B4d4a04dD529061dd0071cf975F58bCD` |
| Remote selector | Base `15971525489660198786` | Berachain `1294465214383781161` |

### BurnMintTokenPool deploy (wJNR pattern)

- Deployer EOA: `0x271e6335145685345078b08Bd1C2168Ea4D9b086`
- `USER_SALT = keccak256("LiquidRoyalty:snrUSD:BurnMintTokenPool:v1")` (distinct from wJNR salt)
- `effectiveSalt = keccak256(abi.encodePacked(USER_SALT, DEPLOYER))`
- Creation code: `script/bytecode/BurnMintTokenPool.v2.0.0.bin` (**23986** bytes, Chainlink npm 2.0.0 — see `script/bytecode/README.md`)
- Remote wiring at deploy: predicted remote pool address, empty `remotePoolInitCode`, rate limit capacity `1000 ether`, rate `11574074074074074` (~1000e18/86400), FTF disabled (factory default)
- `futureOwner`: Bera Safe / Base Safe (see table above)

```bash
export PATH="$HOME/.foundry/bin:$PATH"
cd LiquidRoyaltyContracts

forge script script/ccip/DeploySnrUsdBurnMintTokenPool.s.sol:DeploySnrUsdBurnMintTokenPool \
  --rpc-url https://berachain.drpc.org

forge script script/ccip/DeploySnrUsdBurnMintTokenPool.s.sol:DeploySnrUsdBurnMintTokenPool \
  --rpc-url https://mainnet.base.org
```

Dry-run by default; set `SNRUSD_POOL_BROADCAST=true` and `DEPLOYER_PRIVATE_KEY` only for Moss broadcast.

## Alan / Moss execution order

1. Moss deploys Path1 impl (Berachain) and both TokenPools (CREATE2; remotes wired at factory deploy — no default `applyChainUpdates` in Safe batches).
2. **Berachain admin Safe:** `upgradeToAndCall(new Path1 impl, initializePath1())` **before** any `grantRole(MINTER/BURNER)` on Meta Senior — live impl has no `MINTER_ROLE` / `BURNER_ROLE`.
3. Both Safes run CCIP batches (`script/ccip/GenerateSnrUsdCcipSafeBatches.s.sol` output):
   - Pool `acceptOwnership`
   - Token `grantRole(MINTER)` + `grantRole(BURNER)` to pool only (not Safe)
   - `registerAccessControlDefaultAdmin` on RegistryModule (correct for these AccessControl vaults; wJNR used `registerAdminViaGetCCIPAdmin` because wJNR exposes `getCCIPAdmin()`)
   - TAR `acceptAdminRole`, `setPool`
   - Base `grantRole` can run anytime after Base pool exists (Base snrUSD already has mint/burn roles on the token)

Optional later owner tx: inbound `setRateLimitConfig` (e.g. 1,100) like wJNR — not in default Safe JSON.

## Deploy commands (no keys; dry-run)

```bash
# Path1 implementation only (prints REQUIRED upgradeToAndCall + initializePath1 calldata)
forge script script/DeployMetaSeniorPath1Impl.s.sol:DeployMetaSeniorPath1Impl \
  --rpc-url https://berachain.drpc.org

forge script script/ValidateMetaSeniorStorageLayout.s.sol:ValidateMetaSeniorStorageLayout \
  --rpc-url https://berachain.drpc.org

BERA_POOL_ADDRESS=0x... BASE_POOL_ADDRESS=0x... \
  forge script script/ccip/GenerateSnrUsdCcipSafeBatches.s.sol:GenerateSnrUsdCcipSafeBatches
```

## Tests

```bash
forge test --match-contract MetaSenior -vv
```

Fork test `test_fork_upgrade_preservesCoreState` upgrades with `initializePath1`, asserts exact `totalSupply` / `feeAddress` / `unstakingFeeBps` / `totalAssets`, slots 0/3/5 unchanged, `vaultOpenToPublic()`, and a small user deposit after upgrade.

## Storage layout check

```bash
forge inspect MetaSeniorVault storage-layout --json > /tmp/meta-senior-base.json
forge inspect MetaSeniorVaultPath1 storage-layout --json > /tmp/meta-senior-path1.json
```

All slots from `MetaSeniorVault` must match. Path1 adds no new layout variables (only `MINTER_ROLE` / `BURNER_ROLE` via AccessControl after grant).