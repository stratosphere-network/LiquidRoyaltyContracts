# COMPUTE.r Senior/Junior — Berachain mainnet fork simulation

**RPC:** `https://rpc.berachain.com`  
**Fork block (run):** ~`28038558` (latest at execution time)  
**Script:** `simulation/ComputeLPNAVFork.t.sol`  
**Command:**

```bash
cd simulation && forge test --match-test testComputeLPSeedAndLMVFlow -vv
```

## Live addresses (verified on fork)

| Role | Address |
|------|---------|
| Senior vault | `0xeb04926d24b9526D847498153C88d80296F1bb73` |
| Junior vault | `0x3499a7FFB37Dbd4d0d94c203614C093314FD937f` |
| Island LP (KODI-COMPUTE.r-USDe) | `0x40E8Fa74792274d9d9A328D41324E9d5199C0A16` |
| USDe (token0) | `0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34` |
| COMPUTE.r (token1) | `0xB8CD0b8E056A91c00FD388EdDb37E6E445844B21` |
| Senior impl (EIP-1967) | `0x0e4e9eb172a6cd8b457fe2387f9c2355bed0e1e0` |
| Junior impl | `0x02d744d1f458a4cd6a1a9cc48225490d1811245a` |
| Senior operator/LMV wallet (storage **slot 2**) | `0x246f89F3b451133bB9a84c3f0871C9198b90AA04` (minimal proxy) |
| Junior operator/LMV wallet (storage **slot 2**) | `0xacf0B6eFd883b3cE5A7cC9177005f12f049C9C2e` |

**Important:** These mainnet proxies are **not** the same bytecode/layout as this repo’s `BaseVault` / `UnifiedConcreteSeniorVault` (no `kodiakHook()` on storage; `vaultValue()` / `liquidityManager()` / `admin()` **revert** on live impl). They expose **`transferToLMV(address,uint256)`** (`0x3194517d`) and **`withdrawLPTokens(address,address,uint256)`** (`0x98c1b700`) selectors, plus a custom **`totalAssets()`** that marks an **operator wallet** (slot 2), not ERC20 balances on the vault body.

---

## LP amount for ~$1M (Island mark at fork)

Island `token0` = USDe, `token1` = COMPUTE.r.

| Quantity | Value |
|----------|--------|
| LP `totalSupply` | `747_879_875_461_301_733` (≈ **0.748e18** LP units) |
| USDe in pool (`getUnderlyingBalances().amount0`) | `2_739_965_456_203_749_875` (≈ **2.74 USDe** reported in pool accounting) |
| Simple USDe share mark: `usdPerLp = amount0 * 1e18 / totalSupply` | **3.663643783052331296e18** (~**$3.66**/LP) |
| LP raw amount for **$1M** at that mark: `1e24 * totalSupply / amount0` | **`272_952_300_828_455_311_673_549`** (~**272,952.3** LP) |

**Funding:** On fork, Island LP was **`deal`’d** to a test whale (`0x…bEEF`) because on-chain supply is far below 272k LP; the whale then `transfer`’d to each vault. Real mainnet would require minting/add-liquidity or sourcing from a large holder.

---

## Step-by-step results (Senior / Junior)

| Step | Senior `totalAssets()` | Junior `totalAssets()` | Slot-3 internal (~`_vaultValue`) | Island on **vault** | Island on **operator (slot 2)** | Island on **hook** | Notes |
|------|------------------------|------------------------|----------------------------------|---------------------|----------------------------------|--------------------|-------|
| **0 – baseline** | 0 | 0 | ~**10.03e18** each | 0 | 0 | 0 | `vaultValue()` reverts; slot 3 ≈ initial ~$10 seed |
| **1 – after ~$1M LP ERC20 transfer to vault** | **0** | **0** | ~**10.03e18** (unchanged) | **272,952e18** each | 0 | 0 | **Loose Island on vault body is ignored by `totalAssets()`** |
| **2 – `transferToLMV(island, amount)` as operator** | 0 | 0 | unchanged | unchanged | 0 | 0 | **Reverted** for operator, treasury, and bytecode-embedded EOAs (no strategy-manager key on fork) |
| **2b – simulated LMV effect** (vault → operator transfer) | **~2.606e24** | **~2.606e24** | ~**10.03e18** (unchanged) | **0** | **272,952e18** each | 0 | Matches intended **post-LMV** location; NAV appears here |

### When does each vault show ~$1M?

| Metric | Reaches ~$1M? | When |
|--------|----------------|------|
| **`totalAssets()` (live impl)** | **Not at the simple-pool $1M LP size** | Only after LP sits on the **operator/LMV wallet (slot 2)**. With **272,952 LP** the on-chain mark reads **~$2.61M** per vault (see below), not $1M. |
| **Slot-3 internal value** | **No** | Stays ~**$10** through all steps (no auto-update from LP). |
| **`vaultValue()` getter** | N/A | **Always reverts** on live proxies. |

**~$1M `totalAssets()` (live mark):** From calibration (`100e18` LP on operator → `totalAssets ≈ 954.73e18`), use **~104,700 LP** (1e18 units), not 272,952 LP, to land near **$1M** on this implementation.

---

## Is NAV “correct” vs independent Island mark?

### Live COMPUTE.r proxies (this fork)

1. **`totalAssets()`** – On-chain view **does not** sum vault ERC20 balances. It **only** marks Island (and pool-related assets) held by the **operator wallet in storage slot 2** (plus embedded pool/oracle logic). Evidence: vault-only `deal` → `totalAssets` stays **0**; operator-only `deal` → `totalAssets` jumps (`testTotalAssetsMarksOperatorWallet`).
2. **Mark level** – Simple `USDe_in_pool / LP_supply` implies **~$3.66/LP** and **~$1M** for 272,952 LP, but **`totalAssets()` reports ~$2.61M** for that amount → the implementation uses a **richer mark** (includes CL pool / COMPUTE leg / `getUnderlyingBalances` math), not naive stable-side share only.
3. **Slot 3 (~$10)** – Behaves like a separate **`_vaultValue` / admin ledger** that **does not** move when LP is deposited or routed.
4. **`vaultValue()`** – Unusable via RPC (reverts); use **`totalAssets()`** for ERC4626-style external NAV on this deployment, or **slot 3** for internal ledger.

### This repo’s vault code (for comparison — **not** deployed at the addresses above)

| Path | NAV update |
|------|------------|
| **`seedVault(lp, amount, lpPrice)`** (seeder) | LP sent **directly to `kodiakHook`**; **`_vaultValue += amount * lpPrice`** immediately. |
| **`withdrawLPTokens(lpToken, lp, amount)`** (liquidity manager) | Moves LP from vault to whitelisted **`lp`** (hook); **does not** auto-increase `_vaultValue` — expects **`executeVaultValueAction`** / operator price. |
| **`_getLpConversionData`** | Uses **`getUnderlyingBalances()` second return as “stable”** — for this Island, **token0 = USDe, token1 = COMPUTE**, so the repo helper treats **COMPUTE (often 0)** as stable side → **on-chain helper undervalues LP** unless token ordering matches their assumption. |

**Hypothesis confirmed (live):** NAV **ignores** Island sitting on the **vault contract** until LP is in the **LMV/operator path** used by `totalAssets()`. **Operator price update** still required for slot-3 / `vaultValue` style ledger on live impl.

---

## LMV / ACL (fork)

| Function | Selector | Role (live) | Fork outcome |
|----------|----------|-------------|--------------|
| **`transferToLMV(address token, uint256 amount)`** | `0x3194517d` | **Strategy manager** (error string in impl bytecode); not slot-2 operator | **Revert** — impersonation failed for tested EOAs |
| **`withdrawLPTokens(address,address,uint256)`** | `0x98c1b700` | Liquidity manager (repo pattern) | Not usable — **`kodiakHook()` unset** / reverts |
| **Bypass on fork** | — | — | **`deal` LP**; **simulated** `vault.transfer(operator, amount)` after failed `transferToLMV` |

Embedded bytecode addresses (not all valid callers): `0xC465a6368D3708f6B738Cc46b9A1Ac650e1dE010`, `0xE532DFede91f04B12a73d3d2Acd361424F41f76B`.

---

## Related tests in the same file

```bash
cd simulation && forge test --match-test testTotalAssetsMarksOperatorWallet -vv
cd simulation && forge test --match-test testDiscoverTransferToLMVCaller -vv
```

---

## Summary answers

1. **When ~$1M Senior / Junior?** – **`totalAssets()`:** only after LP is on the **operator (slot 2)** wallet, **not** after vault ERC20 receipt. At the **USDe-share $1M LP size** (272,952 LP), the live mark shows **~$2.61M**, not $1M; use **~104,700 LP** for ~$1M on `totalAssets()`. **Slot-3 ledger** stays ~$10.
2. **Correct valuation?** – **Externally reported `totalAssets()`** tracks **operator-wallet LP** with a **pool-based mark**; **vault-body LP is ignored**. **Internal slot-3** does not track LP in this flow. Repo **`seedVault`** would update `_vaultValue`; repo **`withdrawLPTokens`** alone would not.
3. **LP for ~$1M (simple USDe pool mark):** **272,952.300828455311673549** LP (18 decimals); math above.
4. **ACL:** **`transferToLMV`** gated (strategy manager); **`withdrawLPTokens`** / hook path not configured on these proxies. Fork used **`deal` + simulated routing** to operator wallet.
