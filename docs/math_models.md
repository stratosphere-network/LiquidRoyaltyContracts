# LiquidRoyalty Tranching: Mathematical Models & Formulas

**Version 1.0**  
**Complete Mathematical Specification**

---

## Table of Contents

1. [Notation & Definitions](#1-notation--definitions)
2. [Core Formulas](#2-core-formulas)
3. [Rebase Algorithm](#3-rebase-algorithm)
4. [Three-Zone Spillover System](#4-three-zone-spillover-system)
5. [Fee Calculations](#5-fee-calculations)
6. [User Operations](#6-user-operations)
7. [System Constraints & Invariants](#7-system-constraints--invariants)
8. [Quick Reference](#8-quick-reference)

---

## 1. Notation & Definitions

### 1.1 State Variables

| Symbol | Description | Unit |
|--------|-------------|------|
| $S$ | Circulating supply of snrUSD | snrUSD |
| $V_s$ | USD value of Senior vault LP tokens | USD |
| $V_j$ | USD value of Junior vault LP tokens | USD |
| $V_r$ | USD value of Reserve vault assets | USD |
| $I$ | Rebase index | dimensionless |
| $t$ | Current time | seconds |
| $T_r$ | Last rebase timestamp | seconds |
| $N_{LP}^s$ | LP tokens held by Senior vault | LP tokens |
| $N_{LP}^j$ | LP tokens held by Junior vault | LP tokens |
| $N_{LP}^r$ | LP tokens held by Reserve vault (from spillover) | LP tokens |
| $N_X^r$ | Token X (volatile) held by Reserve vault | Token X |
| $P_{LP}$ | Current LP token price in USD | USD/LP |
| $P_X$ | Current Token X price in USD | USD/Token X |

### 1.2 Parameters (Constants)

| Symbol | Description | Value |
|--------|-------------|-------|
| $r_{min}$ | Minimum annual APY | 0.11 (11%) |
| $r_{mid}$ | Middle annual APY | 0.12 (12%) |
| $r_{max}$ | Maximum annual APY | 0.13 (13%) |
| $r_{month}^{min}$ | Min monthly rebase rate | $\frac{11\%}{12} = 0.009167$ |
| $r_{month}^{mid}$ | Mid monthly rebase rate | $\frac{12\%}{12} = 0.010000$ |
| $r_{month}^{max}$ | Max monthly rebase rate | $\frac{13\%}{12} = 0.010833$ |
| $f_{mgmt}$ | Annual management fee (token minting) | 0.01 (1%) |
| $f_{perf}$ | Performance fee (token dilution) | 0.02 (2%) |
| $f_{penalty}$ | Early withdrawal penalty | 0.05 (5%) |
| $\alpha_{target}$ | Senior target backing (profit spillover) | 1.10 (110%) |
| $\alpha_{trigger}$ | Senior backstop trigger threshold | 1.00 (100%) |
| $\alpha_{restore}$ | Senior backstop restoration target | 1.009 (100.9%) |
| $\beta_j^{spillover}$ | Junior spillover share | 0.80 (80%) |
| $\beta_r^{spillover}$ | Reserve spillover share | 0.20 (20%) |
| $\gamma$ | Deposit cap multiplier | 10 |
| $\tau$ | Cooldown period | 604800 (7 days) |

### 1.3 User State

| Symbol | Description | Unit |
|--------|-------------|------|
| $\sigma_i$ | User $i$'s share balance | shares |
| $b_i$ | User $i$'s snrUSD balance | snrUSD |
| $t_c^{(i)}$ | User $i$'s cooldown initiation time | seconds |

---

## 2. Core Formulas

### 2.1 User Balance (Rebase Index)

The actual snrUSD balance of user $i$:

$$
b_i = \sigma_i \cdot I
$$

Where:
- $\sigma_i$ = user's shares (constant between rebases)
- $I$ = current rebase index (increases each rebase)

**Initial state:** $I = 1.0$, so $b_i = \sigma_i$ (1:1 initially)

### 2.2 Total Supply

$$
S = \sum_{i=1}^{n} b_i = \sum_{i=1}^{n} (\sigma_i \cdot I) = I \cdot \sum_{i=1}^{n} \sigma_i = I \cdot \Sigma
$$

Where $\Sigma = \sum_{i=1}^{n} \sigma_i$ is the total shares (constant).

### 2.3 Vault Values

**Senior vault (LP tokens only):**
$$
V_s = N_{LP}^s \times P_{LP}
$$

**Junior vault (LP tokens only):**
$$
V_j = N_{LP}^j \times P_{LP}
$$

**Reserve vault (Token X + LP tokens - "Reserve for Reserves"):**
$$
V_r = (N_X^r \times P_X) + (N_{LP}^r \times P_{LP})
$$

Where:
- $N_X^r$ = Token X holdings (the volatile token)
- $N_{LP}^r$ = LP tokens received from spillover

**Critical:** $V_s$, $V_j$, $V_r$ change when:
1. **$N_{LP}$ or $N_X$ changes** (deposits, withdrawals, spillover, backstop)
2. **$P_{LP}$ or $P_X$ changes** (Token X price movements in DEX pool)

### 2.4 Senior Backing Ratio

$$
R_{senior} = \frac{V_s}{S}
$$

**Three Operating Zones:**

**Zone 1: Excess Backing**
$$
\text{If } R_{senior} > \alpha_{target} = 1.10
$$

**Zone 2: Healthy Buffer**
$$
\text{If } \alpha_{trigger} \leq R_{senior} \leq \alpha_{target}
$$
$$
\text{If } 1.00 \leq R_{senior} \leq 1.10
$$

**Zone 3: Depeg**
$$
\text{If } R_{senior} < \alpha_{trigger} = 1.00
$$

### 2.5 Total Ecosystem Backing

$$
R_{backing} = \frac{V_s + V_j + V_r}{S}
$$

**Interpretation:** Total USD backing per snrUSD across entire system.

### 2.6 Deposit Cap

$$
S_{max} = \gamma \cdot V_r = 10 \cdot V_r
$$

**Constraint:** $S \leq S_{max}$

Reserve vault size limits Senior vault growth (ensures adequate backstop capacity).

---

## 3. Rebase Algorithm

### 3.1 Step 1: Calculate Management Fee Tokens (TIME-BASED)

Management fee minted as snrUSD tokens based on actual time elapsed:

$$
S_{mgmt} = V_s \cdot f_{mgmt} \cdot \frac{t_{elapsed}}{365 \text{ days}}
$$

Where:
- $V_s$ = Current vault value
- $f_{mgmt}$ = Annual management fee rate (1% = 0.01)
- $t_{elapsed}$ = Time since last rebase in seconds
- $365 \text{ days}$ = Seconds per year (31,536,000 seconds)

**Example for 30-day rebase:**
$$
S_{mgmt} = V_s \cdot 0.01 \cdot \frac{30 \text{ days}}{365 \text{ days}} = V_s \cdot 0.000822
$$

### 3.2 Step 2: Dynamic APY Selection

**Try 13% APY first:**

User tokens minted (TIME-SCALED):
$$
S_{users}^{13} = S \cdot r_{month}^{max} \cdot \frac{t_{elapsed}}{30 \text{ days}} = S \cdot 0.010833 \cdot \frac{t_{elapsed}}{30 \text{ days}}
$$

Performance fee (2% of user tokens):
$$
S_{fee}^{13} = S_{users}^{13} \cdot f_{perf} = S_{users}^{13} \cdot 0.02
$$

Total new supply (users + performance fee + management fee):
$$
S_{new}^{13} = S + S_{users}^{13} + S_{fee}^{13} + S_{mgmt}
$$

**For 30-day rebase:**
$$
S_{new}^{13} = S + S \cdot 0.010833 + S \cdot 0.010833 \cdot 0.02 + S_{mgmt}
$$
$$
S_{new}^{13} = S \cdot 1.011050 + S_{mgmt}
$$

Backing check:
$$
R_{13} = \frac{V_s}{S_{new}^{13}} = \frac{V_s}{S + S_{users}^{13} + S_{fee}^{13} + S_{mgmt}}
$$

**If $R_{13} \geq 1.00$:** ✅ Use 13% APY

**Else, try 12% APY:**

$$
S_{users}^{12} = S \cdot r_{month}^{mid} \cdot \frac{t_{elapsed}}{30 \text{ days}} = S \cdot 0.010000 \cdot \frac{t_{elapsed}}{30 \text{ days}}
$$

$$
S_{fee}^{12} = S_{users}^{12} \cdot 0.02
$$

$$
S_{new}^{12} = S + S_{users}^{12} + S_{fee}^{12} + S_{mgmt}
$$

**For 30-day rebase:**
$$
S_{new}^{12} = S \cdot 1.010200 + S_{mgmt}
$$

$$
R_{12} = \frac{V_s}{S_{new}^{12}}
$$

**If $R_{12} \geq 1.00$:** ✅ Use 12% APY

**Else, try 11% APY:**

$$
S_{users}^{11} = S \cdot r_{month}^{min} \cdot \frac{t_{elapsed}}{30 \text{ days}} = S \cdot 0.009167 \cdot \frac{t_{elapsed}}{30 \text{ days}}
$$

$$
S_{fee}^{11} = S_{users}^{11} \cdot 0.02
$$

$$
S_{new}^{11} = S + S_{users}^{11} + S_{fee}^{11} + S_{mgmt}
$$

**For 30-day rebase:**
$$
S_{new}^{11} = S \cdot 1.009350 + S_{mgmt}
$$

$$
R_{11} = \frac{V_s}{S_{new}^{11}}
$$

**If $R_{11} \geq 1.00$:** ✅ Use 11% APY

**Else:** 🚨 Use 11% + Backstop

### 3.3 Step 3: Update Rebase Index (TIME-BASED)

The rebase index multiplier is TIME-SCALED:

$$
I_{new} = I_{old} \cdot \left(1 + r_{selected} \cdot \frac{t_{elapsed}}{30 \text{ days}}\right)
$$

Where:
- $r_{selected}$ = dynamically chosen monthly rate (0.010833, 0.010000, or 0.009167)
- $t_{elapsed}$ = time since last rebase in seconds
- $30 \text{ days}$ = assumed monthly period (2,592,000 seconds)

**IMPORTANT:** Performance fee ($f_{perf}$ = 2%) is NOT included in index calculation!

**Expanded formulas (for 30-day rebase):**

If 13% APY selected:
$$
I_{new} = I_{old} \cdot (1 + 0.010833) = I_{old} \cdot 1.010833
$$

If 12% APY selected:
$$
I_{new} = I_{old} \cdot (1 + 0.010000) = I_{old} \cdot 1.010000
$$

If 11% APY selected:
$$
I_{new} = I_{old} \cdot (1 + 0.009167) = I_{old} \cdot 1.009167
$$

**After rebase, user balances automatically increase:**
$$
b_i^{new} = \sigma_i \cdot I_{new}
$$

### 3.4 Step 4: Mint Fee Tokens to Treasury

Total fee tokens minted:
$$
S_{total\_fees} = S_{mgmt} + S_{fee}
$$

Where:
- $S_{mgmt}$ = management fee tokens (from Step 1)
- $S_{fee}$ = performance fee tokens (from Step 2)

---

## 4. Three-Zone Spillover System

### 4.1 Zone 1: Profit Spillover (R > 110%)

**Target value:**
$$
V_{target} = \alpha_{target} \cdot S_{new} = 1.10 \cdot S_{new}
$$

**Excess to distribute:**
$$
E = V_s - V_{target}
$$

**Distribution (80/20 split):**
$$
E_j = E \cdot \beta_j^{spillover} = E \cdot 0.80
$$
$$
E_r = E \cdot \beta_r^{spillover} = E \cdot 0.20
$$

**LP tokens to transfer:**
$$
N_{LP}^{transfer\_j} = \frac{E_j}{P_{LP}}
$$
$$
N_{LP}^{transfer\_r} = \frac{E_r}{P_{LP}}
$$

**Update holdings:**
$$
V_s^{final} = V_s - E = V_{target}
$$
$$
V_j^{new} = V_j + E_j
$$
$$
V_r^{new} = V_r + E_r
$$

### 4.2 Zone 2: Healthy Buffer (100% ≤ R ≤ 110%)

**Condition:**
$$
\alpha_{trigger} \leq R_{senior} \leq \alpha_{target}
$$
$$
1.00 \leq R_{senior} \leq 1.10
$$

**Action:** NO ACTION NEEDED ✅

### 4.3 Zone 3: Backstop (R < 100%)

**Restoration target:**
$$
V_{restore} = \alpha_{restore} \cdot S_{new} = 1.009 \cdot S_{new}
$$

**Deficit to cover:**
$$
D = V_{restore} - V_s
$$

**Reserve backstop (first priority):**

Total Reserve value available:
$$
V_r = (N_X^r \times P_X) + (N_{LP}^r \times P_{LP})
$$

Reserve provides:
$$
X_r = \min(V_r, D)
$$

**Remaining deficit after Reserve:**
$$
D' = D - X_r
$$

**Junior backstop (second priority):**
$$
X_j = \min(V_j, D')
$$

**Total backstop:**
$$
X_{total} = X_r + X_j
$$

**Reserve backstop process:**

1. **Calculate LP needed:**
$$
N_{LP}^{needed} = \frac{X_r}{P_{LP}}
$$

2. **Check Reserve LP holdings:**

If $N_{LP}^r \times P_{LP} \geq X_r$:
- Use existing LP tokens directly
- $N_{LP}^{transfer\_r} = N_{LP}^{needed}$

Else (insufficient LP, need to convert Token X):
- LP shortfall: $X_{shortfall} = X_r - (N_{LP}^r \times P_{LP})$
- Calculate Token X needed: $N_X^{convert} = \frac{X_{shortfall}}{P_X}$
- Swap 50% Token X to stablecoin: $N_X^{swap} = \frac{N_X^{convert}}{2}$
- Add liquidity with remaining Token X + swapped stablecoin
- Receive new LP tokens: $N_{LP}^{new}$
- Total transfer: $N_{LP}^{transfer\_r} = N_{LP}^r + N_{LP}^{new}$

**Junior backstop (straightforward LP transfer):**
$$
N_{LP}^{transfer\_j} = \frac{X_j}{P_{LP}}
$$

**Update holdings:**
$$
V_s^{final} = V_s + X_{total}
$$
$$
V_j^{new} = V_j - X_j
$$
$$
V_r^{new} = V_r - X_r
$$

---

## 5. Fee Calculations

### 5.1 Management Fee (Token Minting - TIME-BASED)

**Fee tokens minted:**
$$
S_{mgmt} = V_s \cdot \frac{f_{mgmt}}{12} \cdot \frac{t_{elapsed}}{30 \text{ days}}
$$

**For 30-day rebase:**
$$
S_{mgmt} = V_s \cdot \frac{0.01}{12} = V_s \cdot 0.000822
$$

**Properties:**
- Minted to protocol treasury as snrUSD tokens
- NOT deducted from $V_s$ (vault value stays the same)
- Time-based: scales with actual time elapsed

### 5.2 Performance Fee (Token Dilution)

**Charged by minting additional tokens:**
$$
S_{fee} = S_{users} \cdot f_{perf} = S_{users} \cdot 0.02
$$

Where:
- $S_{users}$ = tokens minted for users at selected APY
- $S_{fee}$ = additional tokens minted to treasury (2% of user tokens)

**Total supply increase:**
$$
S_{new} = S + S_{users} + S_{fee} + S_{mgmt}
$$

### 5.3 Early Withdrawal Penalty

**Applied if cooldown not met:**
$$
P(w, t_c) = \begin{cases}
w \cdot f_{penalty} & \text{if } t - t_c < \tau \\
0 & \text{if } t - t_c \geq \tau
\end{cases}
$$

Where:
- $w$ = withdrawal amount
- $t_c$ = cooldown initiation time
- $\tau$ = cooldown period (7 days)

**User receives:**
$$
w_{net} = w - P(w, t_c)
$$

---

## 6. User Operations

### 6.1 Deposit

User deposits $d$ USDE:

**Shares minted:**
$$
\sigma_{new} = \frac{d}{I}
$$

**User's new balance:**
$$
b_{new} = \sigma_{new} \cdot I = d
$$

This maintains 1:1 conversion at time of deposit.

### 6.2 Withdrawal

User wants to withdraw $w$ USDE:

**Shares to burn:**
$$
\sigma_{burn} = \frac{w}{I}
$$

**Check cooldown:**
$$
\text{Can withdraw} = \begin{cases}
\text{True} & \text{if } t - t_c^{(i)} \geq \tau \\
\text{False} & \text{otherwise}
\end{cases}
$$

**If cooldown met:**
$$
w_{net} = w \quad \text{(1:1 withdrawal, no penalty)}
$$

**If cooldown NOT met:**
$$
w_{net} = w \cdot (1 - f_{penalty}) = w \cdot 0.95
$$

### 6.3 Balance After Rebase

Before rebase:
$$
b_i^{before} = \sigma_i \cdot I_{old}
$$

After rebase:
$$
b_i^{after} = \sigma_i \cdot I_{new} = \sigma_i \cdot I_{old} \cdot (1 + r_{month})
$$

**User's gain:**
$$
\Delta b_i = b_i^{after} - b_i^{before} = \sigma_i \cdot I_{old} \cdot r_{month}
$$

---

## 7. System Constraints & Invariants

### 7.1 Invariant 1: 1:1 Redemption Peg

$$
\text{Redemption Value} = 1 \text{ snrUSD} = 1 \text{ USD}
$$

### 7.2 Invariant 2: Three-Zone Operating Range

$$
1.00 \leq \frac{V_s}{S_{new}} \leq 1.10 \quad \text{(target range)}
$$

After spillover/backstop, Senior returns to this range.

### 7.3 Invariant 3: Conservation of Value

Before rebase:
$$
V_{total}^{before} = V_s + V_j + V_r
$$

After rebase (with spillover/backstop):
$$
V_{total}^{after} = V_s^{net} + V_j + V_r
$$

(Spillover/backstop transfers value, doesn't create/destroy it)

### 7.4 Invariant 4: Deposit Cap

Always enforce:
$$
S \leq \gamma \cdot V_r = 10 \cdot V_r
$$

Revert deposits if this would be violated.

### 7.5 Invariant 5: Share Conservation

Total shares never change except for deposits/withdrawals:
$$
\Sigma(t) = \Sigma(t_0) + \sum \text{deposits} - \sum \text{withdrawals}
$$

Rebases do NOT change $\Sigma$, only $I$.

---

## 8. Quick Reference

### 8.1 Summary Table

| Concept | Formula |
|---------|---------|
| **User balance** | $b_i = \sigma_i \cdot I$ |
| **Management fee tokens** | $S_{mgmt} = V_s \cdot 0.01 \cdot \frac{t_{elapsed}}{365 \text{ days}}$ |
| **Performance fee tokens** | $S_{fee} = S_{users} \cdot 0.02$ |
| **Total fee tokens** | $S_{total\_fees} = S_{mgmt} + S_{fee}$ |
| **User tokens (time-scaled)** | $S_{users} = S \cdot r_{month} \cdot \frac{t_{elapsed}}{30 \text{ days}}$ |
| **Total new supply** | $S_{new} = S + S_{users} + S_{fee} + S_{mgmt}$ |
| **Try 13% APY (30 days)** | $S_{new}^{13} = S \cdot 1.011050 + S_{mgmt}$, use if $\frac{V_s}{S_{new}^{13}} \geq 1.00$ |
| **Try 12% APY (30 days)** | $S_{new}^{12} = S \cdot 1.010200 + S_{mgmt}$, use if $\frac{V_s}{S_{new}^{12}} \geq 1.00$ |
| **Try 11% APY (30 days)** | $S_{new}^{11} = S \cdot 1.009350 + S_{mgmt}$, use if $\frac{V_s}{S_{new}^{11}} \geq 1.00$ |
| **Rebase index update** | $I_{new} = I_{old} \cdot (1 + r_{selected} \cdot \frac{t_{elapsed}}{30 \text{ days}})$ |
| **Backing ratio** | $R_{senior} = \frac{V_s}{S_{new}}$ |
| **Profit spillover trigger** | $R_{senior} > 1.10$ (Zone 1) |
| **Healthy buffer zone** | $1.00 \leq R_{senior} \leq 1.10$ (Zone 2) |
| **Backstop trigger** | $R_{senior} < 1.00$ (Zone 3) |
| **Backstop restoration target** | 100.9% (enables next month's min APY) |
| **Profit spillover amount** | $E = V_s - (1.10 \cdot S_{new})$ |
| **Profit split** | $E_j = E \cdot 0.80$, $E_r = E \cdot 0.20$ |
| **Backstop deficit** | $D = (1.009 \cdot S_{new}) - V_s$ |
| **Reserve backstop (first)** | $X_r = \min(V_r, D)$ |
| **Junior backstop (second)** | $X_j = \min(V_j, D - X_r)$ |
| **Senior/Junior vault value** | $V_{vault} = N_{LP} \times P_{LP}$ |
| **Reserve vault value** | $V_r = (N_X^r \times P_X) + (N_{LP}^r \times P_{LP})$ |
| **Deposit shares minted** | $\sigma_{new} = \frac{d}{I}$ |
| **Withdrawal shares burned** | $\sigma_{burn} = \frac{w}{I}$ |
| **Early withdrawal penalty** | $P = w \cdot 0.05$ (if $t - t_c < 7$ days) |
| **Deposit cap** | $S_{max} = 10 \cdot V_r$ |

### 8.2 Three-Zone Decision Tree

```
Calculate: R_senior = V_s / S_new

IF R_senior > 1.10:
    → ZONE 1: Profit Spillover
    → E = V_s - (1.10 × S_new)
    → Junior gets 80%, Reserve gets 20%
    → Transfer LP tokens

ELSE IF R_senior >= 1.00 AND R_senior <= 1.10:
    → ZONE 2: Healthy Buffer
    → NO ACTION NEEDED ✅
    → Most common state

ELSE IF R_senior < 1.00:
    → ZONE 3: Backstop
    → D = (1.009 × S_new) - V_s
    → Reserve provides first: X_r = min(V_r, D)
    → Junior provides second: X_j = min(V_j, D - X_r)
    → Transfer LP tokens (or convert Token X → LP)
```

### 8.3 LP Price Dependency

$$
P_{LP} = f(P_{Token\_X}, \text{trading fees}, \text{impermanent loss})
$$

All vault values ultimately depend on Token X price movements in the DEX pool.

---

## Implementation Notes

1. **All calculations in wei (18 decimals)**
   - Use Solidity fixed-point math
   - Example: 11% = 110000 (basis points × 10)

2. **Order of operations matters**
   - Fees calculated BEFORE spillover/backstop
   - Spillover/backstop BEFORE rebase execution

3. **Rounding considerations**
   - Always round down for user benefits (withdrawals)
   - Always round up for protocol benefits (fees)

4. **Time-based calculations**
   - Use `block.timestamp` for time
   - 1 month ≈ 30 days = 2,592,000 seconds
   - 1 year = 365 days = 31,536,000 seconds

---

**End of Mathematical Models**

