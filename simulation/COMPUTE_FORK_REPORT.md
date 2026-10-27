# COMPUTE.r Senior/Junior — corrected Kodi transferrer fork simulation

**RPC:** `https://rpc.berachain.com` (latest block at run time)  
**Primary script:** `simulation/FullScenario.t.sol`  
**Command:**

```bash
cd simulation && forge test --match-path FullScenario.t.sol -vv
```

## Live addresses

| Role | Address |
|------|---------|
| Senior vault | `0xeb04926d24b9526D847498153C88d80296F1bb73` |
| Junior vault | `0x3499a7FFB37Dbd4d0d94c203614C093314FD937f` |
| Island LP (KODI-COMPUTE.r-USDe) | `0x40E8Fa74792274d9d9A328D41324E9d5199C0A16` |
| USDe (token0) | `0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34` |
| COMPUTE.r (token1) | `0xB8CD0b8E056A91c00FD388EdDb37E6E445844B21` |
| Operator EOA (`OPERATOR_ROLE`) | `0xE90986e67A9cbEbcF67084cbBF8E24FAa0a43Bcb` |
| Admin multisig (`hasRole(0x00…00, admin)` = true on both vaults) | `0xd60c3A29Fbe444cF9d3AA240F4a9263BC83bde61` |
| Senior `liquidityManagerVault()` (Gnosis Safe, 2/4) | `0x246f89F3b451133bB9a84c3f0871C9198b90AA04` |
| Junior `liquidityManagerVault()` (Gnosis Safe, 2/4) | `0xacf0B6eFd883b3cE5A7cC9177005f12f049C9C2e` |

There is **no separate LMV contract** — `liquidityManagerVault()` **is** the operator multisig Safe that holds Island LP after routing.

## Kodi token transferrer (on-chain discovery)

| Finding | Detail |
|---------|--------|
| **Configured mint recipient today** | **None.** `whitelistedMintAddresses(any)` is `false` for all probed EOAs/contracts. **Zero** `WhitelistedMintAddress` events on Senior or Junior since deploy. |
| **Operational address used in fork** | `0xE532DFede91f04B12a73d3d2Acd361424F41f76B` — EOA embedded in the vault **implementation bytecode** (same family as strategy-manager constants). Must be set via `setWhitelistedMintAddress(transferrer, true)` before minting. |
| **Not the transferrer** | `0xE76953834b165209a5FFE36fe3A833b52DD946d9` (empty EOA, never whitelisted). Meta Senior `0xC38421E5577250EBa177Bc5bC832E747bea13Ee0` is `UserWhitelisted` / `StrategyManagerSet` only (Meta path — out of scope). |
| **Admin mint function** | Use **`adminMintShares(address,uint256,string)`** (`0x2f8d85b2`) from **`DEFAULT_ADMIN`**. The selector `adminMint(address,uint256)` reverts with no data even when `OPERATOR_ROLE` + mint whitelist are satisfied. |
| **Pre-mint config (mainnet)** | Admin Safe must call `setWhitelistedMintAddress(kodiTransferrer, true)` then `adminMintShares(kodiTransferrer, 1_000_000e18, reason)`. |

Fork note: the test uses `vm.prank(ADMIN_SAFE)` to simulate the admin Safe executing those calls (no `execTransaction` signature assembly).

## Step table (corrected order)

| Step | Action | Senior (representative) | Junior | `vaultValue()` | `getVaultValue()` / `totalAssets()` | Share price (`convertToAssets(1e18)`) |
|------|--------|-------------------------|--------|----------------|--------------------------------------|----------------------------------------|
| 0 | Baseline | `totalSupply=0`, no Island | same | **reverts** | 0 / 0 | n/a (ts=0) |
| 1 | Admin: whitelist + **`adminMintShares` 1M** to Kodi transferrer | `totalSupply=1e6e18`, transferrer balance 1M | same | **reverts** | 0 / 0 | **0** (assets still 0) |
| 2 | Transferrer sends **~$1M Island LP** to vault (`272,952e18` LP at USDe/reserve ratio) | Island on **vault body** | same | **reverts** | 0 / 0 | **0** (LP on vault **not** counted) |
| 3 | **Operator EOA** calls **`transferToLiquidityManager(lp, island)`** (not `transferToLMV`) | Island on **LMV Safe** `0x246f…` | Island on `0xacf0…` | **still reverts** | **`~2.606e24` (~$2.61M mark)** | **`~2.606e18` per share** (~$2.61 PPS) |
| 4 | `transferToLMV(address,uint256)` from operator after step 3 | No-op / empty revert in practice | same | — | unchanged | unchanged |

### LP sizing (~$1M intent)

- **USDe/reserve ratio:** `272,952,300,828,455,311,673,549` LP (~$1M if priced as USDe × supply / pool USDe).
- **`totalAssets()` mark at that size:** **~$2.61M** per vault (implementation marks Island on the LMV Safe with a richer formula than USDe-side share only). For **~$1M on `totalAssets()`**, prior calibration was **~`104,700e18` LP** (see `ComputeLPNAVFork.t.sol`).

### Who can move LP to the LMV Safe?

| Caller | `transferToLMV` | `transferToLiquidityManager` |
|--------|-----------------|------------------------------|
| `liquidityManagerVault()` Safe as `msg.sender` | Fails (Safe lacks `OPERATOR_ROLE`) | Fails (needs operator) |
| Operator EOA `0xE909…` | Empty revert / ineffective after LP moved | **Works** |
| Strategy manager role holder `0xFFF775…` | Fails | Not required (operator path works) |

Production operator action should be **`transferToLiquidityManager`** from the **operator EOA** (or the same call batched via the operator Safe’s `execTransaction` with an owner signature — not exercised in this script).

## Arithmetic after step 3 (fork run)

| Metric | Senior | Junior |
|--------|--------|--------|
| `totalSupply` | 1,000,000e18 | 1,000,000e18 |
| `totalAssets` | ~2,605,969,262,374,723,904,203,778 (~2.606×10²⁴) | same order |
| `getVaultValue()` | matches `totalAssets` | matches |
| `vaultValue()` | **reverts** (always in this scenario) | **reverts** |
| Implied PPS (`totalAssets/totalSupply`) | ~**2.606** (18-dec USD per share) | ~**2.606** |
| Island LP location | LMV Safe | LMV Safe |

**When does NAV “record” without revert?**  
- **`vaultValue()` never succeeds** in this flow (empty revert on the external selector).  
- **`getVaultValue()` and `totalAssets()`** become non-zero only **after Island LP sits on the LMV Safe** (step 3), not after mint alone or LP on the vault contract.

## 10 USDe : 1 COMPUTE.r Island rebalance (fork)

**Script:** `simulation/IslandRatioFork.t.sol`  
**Command:** `cd simulation && forge test --match-path IslandRatioFork.t.sol -vv`

### How the 10:1 ratio is forced (fork-only)

Live Island `0x40E8…` delegates to `0xCFe9Ee61…` and reads CL pool `0xe97cAA346252C23b5C4C7771b5af75DC997cA65B`. On a fresh fork we:

1. **`vm.store` CL `slot0`** — set `sqrtPriceX96` for **token1/token0 = COMPUTE/USDe = 0.1** (i.e. **10 USDe per 1 COMPUTE.r**), using `sqrt(0.1)·2^96`.
2. **`deal` CL pool balances** — **70e18 USDe** and **7e18 COMPUTE.r** (10:1 amounts, live-scale, not billion-token deals).
3. **`vm.mockCall` Island `getUnderlyingBalances()`** — return the same **70e18 / 7e18** so **LP sizing** `1e6 × supply / amount0` matches the target ratio.

This does **not** mutate mainnet; it re-forks and reapplies cheats each run.

### Step comparison (Senior ≈ Junior)

| Step | Skewed pool (live reserves) | 10:1 rebalance |
|------|-----------------------------|----------------|
| **LP for “~$1M”** (`1e6×supply/amount0`) | **272,952e18** | **10,684e18** (~39× less LP) |
| **0–2** mint / LP on vault | `totalAssets` / `getVaultValue` = **0** | same |
| **3** after `transferToLiquidityManager` | **~2.606×10²⁴** (~**$2.61M**) | **~2.003×10²⁴** (~**$2.0M**) |
| **PPS** (1M shares) | **~2.606** | **~2.003** |
| **`totalAssets×1e18/LP`** | **~9.55×10¹⁸** | **~1.87×10²⁰** |

**Does “~$1M LP size” mark ~$1M?** **No.** The sizing helper assumes USDe-side pool accounting; **`totalAssets()` marks Island on the LMV Safe using CL pool state + LP**, so after step 3 you still get **~$2.0–2.6M** NAV per vault for the formula-sized LP amount—not ~1e24. Mocking only Island underlying (without CL pool + sqrtPrice) shrinks LP but leaves the old mark-per-LP → **~$7** NAV (see test logs in `IslandRatioFork.t.sol`).

## Exact $2M Island → $1M NAV per vault (canonical test)

**Script:** `simulation/IslandExactEconomics.t.sol`  
**Command:** `cd simulation && forge test --match-path IslandExactEconomics.t.sol -vv`

**Fork block:** `27863150` (Senior/Junior deployed; **real** `island.mint` for **~998k USDe + 100k COMPUTE.r** succeeds after CL seed). At **latest** head the same dual-sided mint **reverts** (`ERC20InsufficientBalance` on Island).

### Island seed / mint (real, not heuristic)

1. **CL pool** `0xe97c…`: `deal` **1,000,000 USDe** + **100,000 COMPUTE.r**; set **sqrtPriceX96** for **10 USDe : 1 COMPUTE.r** (`token1/token0 = 0.1`).
2. **`getMintAmounts(1e6 USDe, 100k COMPUTE)`** → deposit **~998,224 USDe + 100,000 COMPUTE**; **`mintAmount` = X ≈ `7.4788×10²⁰` LP**.
3. **`island.mint(X, seeder)`** — pulls both tokens; after mint Island **`getUnderlyingBalances()` ≈ (998,225 USDe, 100,000 COMPUTE)** (~**$2M** at $10/COMPUTE + $1/USDe).

### Vault flow result (step 3)

| Metric | Senior / Junior (each) |
|--------|-------------------------|
| **LP sent** | **X/2** |
| **`totalAssets` / `getVaultValue`** | **≈ `9.9911×10²³`** (~**$999,111**) |
| **PPS** (`ta×1e18 / 1e6 shares`) | **≈ `0.9991×10¹⁸`** (~**$0.9991**) |
| **Gap vs $1M / $1** | **~$889 short** (~0.09%) |

Steps 0–2: NAV **0** until LP is on the **LMV Safe** (same as prior flows).

**Latest-head note:** dual-sided 1M+100k mint fails; **2M USDe-only** mint achieves **~$1.000002M** NAV per vault for **X/2** (see removed probe `Mint2M.t.sol` in git history) but does **not** deposit 100k COMPUTE.r.

## Related artifacts

- `ComputeLPNAVFork.t.sol` — LP-first flow, `transferToLMV` probes, ~$1M `totalAssets` LP calibration  
- `IslandExactEconomics.t.sol` — **canonical** 1M USDe + 100k COMPUTE Island mint → X LP → ~$1M NAV per vault  
- `IslandRatioFork.t.sol` — skewed vs 10:1 rebalance (superseded for sizing by `IslandExactEconomics.t.sol`)  
- `RoleProbe.t.sol` — slot layout, Safe owners, failed `transferToLMV` matrix  
- **Dropped:** Meta `MintThenLPFork` / `depositToSubVault` path (per user request)
