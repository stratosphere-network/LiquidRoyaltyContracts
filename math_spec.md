# Senior Tranche Protocol - Mathematical Specification

## ⚡ Quick Reference: Three-Zone System

**Senior operates in three distinct zones with different actions:**

| Backing Range | Action | Why |
|---------------|--------|-----|
| **> 110%** | 🎉 **Profit Spillover** → Junior (80%) & Reserve (20%) | Senior has excess, share the wealth |
| **100% to 110%** | ✅ **No Action** (Healthy Buffer Zone) | Senior maintains peg + pays APY from buffer |
| **< 100%** | 🚨 **Backstop to 100.9%** ← Reserve first (no cap!), then Junior (no cap!) | Below peg, restore to 100.9% to afford next month's min APY |

**Dynamic APY Selection (11-13%):**
- 📈 System tries 13% APY first (maximize returns)
- 📊 If 13% would depeg, try 12%
- 📉 If 12% would depeg, try 11%
- 🛡️ If even 11% would depeg, use 11% + backstop
- **Result:** Users always get highest APY possible while maintaining peg!

**The Critical 100% Threshold:**
- 100% = **The Peg** (1 snrUSD = $1 in backing)
- If backing drops below 100%, we're **depegged** → Backstop triggers
- **Backstop restores to 100.9%** (not just 100%)
- **Why 100.9%?** Ensures we can afford minimum 11% APY next month (0.9167% minting) and stay at peg!

**Initial Setup:**
- ✅ **Launch:** Senior starts at 100% backing (1:1 deposit conversion)
- ✅ **Growth:** Strategy yield naturally pushes backing above 100%
- ✅ **Target:** System aims for 100-110% range through operations

**Operating Rules:** 
- ✅ **Above 110%:** Share profits with Junior/Reserve (incentive to participate)
- ✅ **100-110%:** Healthy operation zone (10% buffer, no action needed)
- ✅ **Below 100%:** Emergency backstop triggered to restore peg
- ✅ This creates a **wide buffer zone** where no spillover occurs!

---

## Table of Contents
0. [Quick Reference: Three-Zone System](#-quick-reference-three-zone-system)
1. [Notation & Definitions](#notation--definitions)
2. [Core Formulas](#core-formulas)
3. [Rebase Algorithm](#rebase-algorithm)
4. [Three-Zone Spillover System](#three-zone-spillover-system)
5. [Fee Calculations](#fee-calculations)
6. [User Balance & Shares](#user-balance--shares)
7. [Withdrawal Mechanics](#withdrawal-mechanics)
8. [Constraints & Invariants](#constraints--invariants)

---

## Notation & Definitions

### **State Variables**

| Symbol | Description | Unit |
|--------|-------------|------|
| $S$ | Circulating supply of snrUSD | snrUSD |
| $V_s$ | USD value of Senior vault assets | USD |
| $V_j$ | USD value of Junior vault assets | USD |
| $V_r$ | USD value of Reserve vault | USD |
| $I$ | Rebase index | dimensionless |
| $t$ | Current time | seconds |
| $T_r$ | Last rebase timestamp | seconds |

### **Parameters (Constants)**

| Symbol | Description | Value |
|--------|-------------|-------|
| $r_{min}$ | Minimum annual APY | 0.11 (11%) |
| $r_{mid}$ | Middle annual APY | 0.12 (12%) |
| $r_{max}$ | Maximum annual APY | 0.13 (13%) |
| $r_{month}^{min}$ | Min monthly rebase rate | $\frac{11\%}{12} = 0.009167$ |
| $r_{month}^{mid}$ | Mid monthly rebase rate | $\frac{12\%}{12} = 0.010000$ |
| $r_{month}^{max}$ | Max monthly rebase rate | $\frac{13\%}{12} = 0.010833$ |
| $f_{mgmt}$ | Annual management fee (value deduction) | 0.01 (1%) |
| $f_{perf}$ | Performance fee (token dilution - 2% extra minted) | 0.02 (2%) |
| $f_{penalty}$ | Early withdrawal penalty | 0.05 (5%) |
| $\alpha_{target}$ | Senior target backing (profit spillover) | 1.10 (110%) |
| $\alpha_{trigger}$ | Senior backstop trigger threshold | 1.00 (100%) |
| $\alpha_{restore}$ | Senior backstop restoration target | 1.009 (100.9%) |
| $\beta_j^{spillover}$ | Junior spillover share (Senior → Junior) | 0.80 (80%) |
| $\beta_r^{spillover}$ | Reserve spillover share (Senior → Reserve) | 0.20 (20%) |
| $\gamma$ | Deposit cap multiplier | 10 |
| $\tau$ | Cooldown period | 604800 (7 days) |

### **User State**

| Symbol | Description | Unit |
|--------|-------------|------|
| $\sigma_i$ | User $i$'s share balance | shares |
| $b_i$ | User $i$'s snrUSD balance | snrUSD |
| $t_c^{(i)}$ | User $i$'s cooldown initiation time | seconds |

---

## Core Formulas

### **1. User Balance (via Rebase Index)**

The actual snrUSD balance of user $i$:

$$
b_i = \sigma_i \cdot I
$$

Where:
- $\sigma_i$ = user's shares (constant between rebases)
- $I$ = current rebase index (increases each rebase)

**Initial state:** $I = 1.0$, so $b_i = \sigma_i$ (1:1 initially)

---

### **2. Total Supply**

$$
S = \sum_{i=1}^{n} b_i = \sum_{i=1}^{n} (\sigma_i \cdot I) = I \cdot \sum_{i=1}^{n} \sigma_i = I \cdot \Sigma
$$

Where $\Sigma = \sum_{i=1}^{n} \sigma_i$ is the total shares (constant).

---

### **3. Backing Ratio (Total Ecosystem)**

$$
R_{backing} = \frac{V_s + V_j + V_r}{S}
$$

**Interpretation:** How many USD back each snrUSD across entire system.

---

### **4. Senior Backing Ratio**

$$
R_{senior} = \frac{V_s}{S}
$$

**Three Operating Zones:**

#### **Zone 1: Excess Backing ($R_{senior} > 1.10$)**
**Action:** Profit spillover to Junior (80%) & Reserve (20%)

$$
\text{If } R_{senior} > \alpha_{target} = 1.10
$$

- **Result:** Senior reduced back to exactly 110%
- **Example:** 115% backing → Spill 5% excess to Junior/Reserve
- **Frequency:** Happens when strategy performs very well
- **How reached:** Strategy yield accumulation over time pushes backing above 110%

---

#### **Zone 2: Healthy Buffer ($1.00 \leq R_{senior} \leq 1.10$)**
**Action:** No spillover in either direction ✅

$$
\text{If } \alpha_{trigger} \leq R_{senior} \leq \alpha_{target}
$$
$$
\text{If } 1.00 \leq R_{senior} \leq 1.10
$$

- **Result:** Senior maintains current backing
- **Why safe:** After rebase (costs ~0.9%), still above 100% peg
- **Example:** 105% backing → After rebase → ~104.1% → Still healthy!
- **Frequency:** **Most common state** in normal operation

**Key Insight:** This 10% buffer zone prevents constant spillover!

---

#### **Zone 3: Depeg ($R_{senior} < 1.00$)**
**Action:** Backstop from Reserve first (no cap!), then Junior (no cap!)

$$
\text{If } R_{senior} < \alpha_{trigger} = 1.00
$$

- **Result:** Senior restored to 100.9% (enables next month's min APY)
- **Why critical:** Senior is depegged, need to restore + afford next month's 11% APY
- **Example:** 98% backing → **Depegged!** → Backstop restores to 100.9% → Next month can mint 0.9167% and stay at 100%
- **Frequency:** Rare, only when strategy performs badly

---

**This creates balanced risk/reward for Junior holders:**
- ✅ **Upside:** Share in Senior's excess profits (>110%)
- ✅ **Wide safety zone:** 100-110% requires no action (10% buffer!)
- ✅ **Downside:** Secondary backstop (no cap!) - only called if Reserve depleted first

---

### **Initial Deployment (Day 0)**

**How Senior Launches:**

```
Users deposit: $850,000 USDE
System mints: 850,000 snrUSD (1:1 conversion)
Senior vault value: $850,000
Initial backing: 100% ✅

Formula: Initial_snrUSD = Deposit_USDE / 1.0
```

**Natural Growth Path:**

```
Day 0:    100% backing (launch)
          ↓
Week 1:   Strategy earns yield
          101-102% backing
          (Zone 2: No action)
          ↓
Month 1:  First rebase occurs
          ~100% backing after rebase
          (Peg maintained)
          ↓
Month 3:  Yield accumulates
          105-108% backing
          (Zone 2: Healthy operation)
          ↓
Month 6:  Strong performance
          112% backing
          (Zone 1: Profit spillover!)
          Excess shared with Junior/Reserve
          Returns to 110%
```

**Key Points:**
- ✅ **No upfront overcollateralization required**
- ✅ **110% is a target reached through operations, not a launch requirement**
- ✅ **System naturally gravitates toward 100-110% range**
- ✅ **Users always get 1:1 deposit conversion**

---

### **5. Deposit Cap**

$$
S_{max} = \gamma \cdot V_r = 10 \cdot V_r
$$

**Constraint:** $S \leq S_{max}$

---

## Rebase Algorithm

### **Input State at time $t$:**
- Current supply: $S$
- Senior value (reported): $V_s$
- Junior value: $V_j$
- Reserve value: $V_r$
- Last rebase index: $I_{old}$

### **Step 1: Calculate Gross Profit**

$$
\Pi_{gross} = V_s - V_s^{prev}
$$

Where $V_s^{prev}$ is Senior value at last rebase.

---

### **Step 2: Calculate Management Fee**

**Management Fee (monthly) - Deducted from value:**
$$
F_{mgmt} = V_s \cdot \frac{f_{mgmt}}{12} = V_s \cdot 0.000833
$$

In simple terms, Monthly Management Fee = Senior Value × (1% ÷ 12)

**Net Senior Value (after management fee):**
$$
V_s^{net} = V_s - F_{mgmt}
$$

**Note:** Performance fee is NO LONGER deducted from value. Instead, it's charged by minting additional tokens (see Step 3).

---

### **Step 3: Dynamic APY Selection (11-13%) + Performance Fee**


**The system tries to maximize APY while maintaining the peg!**


**Algorithm: Waterfall from 13% → 12% → 11%**

**Try 13% APY first (greedy maximization):**

User tokens minted:
$$
S_{users}^{13} = S \cdot r_{month}^{max} = S \cdot 0.010833
$$

Performance fee (2% of user tokens, minted to treasury):
$$
S_{fee}^{13} = S_{users}^{13} \cdot f_{perf} = S_{users}^{13} \cdot 0.02
$$

Total new supply (users + treasury):
$$
S_{new}^{13} = S + S_{users}^{13} + S_{fee}^{13} = S \cdot (1 + 0.010833 \cdot 1.02) = S \cdot 1.011050
$$

Backing check:
$$
R_{13} = \frac{V_s^{net}}{S_{new}^{13}}
$$

**If $R_{13} \geq 1.00$:** ✅ Use 13% APY, set $S_{new} = S_{new}^{13}$, $r_{selected} = 0.010833$

**Else, try 12% APY:**

User tokens:
$$
S_{users}^{12} = S \cdot 0.010000
$$

Performance fee:
$$
S_{fee}^{12} = S_{users}^{12} \cdot 0.02
$$

Total new supply:
$$
S_{new}^{12} = S \cdot (1 + 0.010000 \cdot 1.02) = S \cdot 1.010200
$$

Backing check:
$$
R_{12} = \frac{V_s^{net}}{S_{new}^{12}}
$$

**If $R_{12} \geq 1.00$:** ✅ Use 12% APY, set $S_{new} = S_{new}^{12}$, $r_{selected} = 0.010000$

**Else, try 11% APY:**

User tokens:
$$
S_{users}^{11} = S \cdot 0.009167
$$

Performance fee:
$$
S_{fee}^{11} = S_{users}^{11} \cdot 0.02
$$

Total new supply:
$$
S_{new}^{11} = S \cdot (1 + 0.009167 \cdot 1.02) = S \cdot 1.009350
$$

Backing check:
$$
R_{11} = \frac{V_s^{net}}{S_{new}^{11}}
$$

**If $R_{11} \geq 1.00$:** ✅ Use 11% APY, set $S_{new} = S_{new}^{11}$, $r_{selected} = 0.009167$

**Else:** 🚨 Use 11% anyway, backstop will be triggered, set $S_{new} = S_{new}^{11}$, $r_{selected} = 0.009167$


**Result:** $S_{new}$ and $r_{selected}$ are now set to the highest APY that maintains (or attempts to maintain) the peg.


**IMPORTANT:** This calculates the *conceptual* new supply. We don't actually mint tokens - we update the rebase index in Step 6!


**Performance Fee Model:**
- ✅ 2% extra tokens minted on top of user APY
- ✅ Minted to protocol treasury
- ✅ Dilutes backing ratio slightly (accounted for in backing checks)
- ✅ Example: 11% APY → Users get 0.009167, Treasury gets 0.000183 (total: 0.009350)


---

### **Step 4: Determine Operating Zone & Calculate Spillover**

**Calculate current backing ratio:**
$$
R_{senior} = \frac{V_s^{net}}{S_{new}}
$$

**Determine which of three zones Senior is in:**

---

#### **Zone 1: Excess Backing ($R_{senior} > 1.10$)**

**Calculate profit spillover target:**
$$
V_{target} = \alpha_{target} \cdot S_{new} = 1.10 \cdot S_{new}
$$

**Excess to distribute:**
$$
E = V_s^{net} - V_{target}
$$

**→ PROFIT SPILLOVER (Senior → Junior/Reserve)**

---

#### **Zone 2: Healthy Buffer ($1.00 \leq R_{senior} \leq 1.10$)**

**Check if in buffer zone:**
$$
\alpha_{trigger} \leq R_{senior} \leq \alpha_{target}
$$
$$
1.00 \leq R_{senior} \leq 1.10
$$

**→ NO ACTION NEEDED** ✅

**Why:** Senior maintains the 1:1 peg and has buffer to pay APY from yield.

---

#### **Zone 3: Depeg ($R_{senior} < 1.00$)**

**Backstop trigger (when to activate):**
$$
V_{trigger} = \alpha_{trigger} \cdot S_{new} = 1.00 \cdot S_{new}
$$

**Restoration target (how much to restore to):**
$$
V_{restore} = \alpha_{restore} \cdot S_{new} = 1.009 \cdot S_{new}
$$

**Deficit to cover:**
$$
D = V_{restore} - V_s^{net}
$$

**→ BACKSTOP (Junior/Reserve → Senior)**

**Why restore to 100.9% (not just 100%):**
- Ensures next month we can mint minimum 11% APY (0.9167%)
- After next month's rebase: 100.9% - 0.9167% ≈ 100% (still at peg!)
- Without this buffer, we'd need backstop every single month

---

**In simple terms:**

```
Senior after fees: $1,050,000
New supply: 1,000,000 snrUSD
Backing ratio: $1,050,000 / 1,000,000 = 105%

Target (110%): $1,100,000
Trigger (100%): $1,000,000
Restore (100.9%): $1,009,000

Case 1: Backing 115% (> 110%)
  → Zone 1: Profit spillover
  → Share $50k with Junior/Reserve (80/20)
  
Case 2: Backing 105% (between 100% and 110%)
  → Zone 2: Healthy buffer ✅
  → No action needed!
  → Senior maintains peg + buffer
  
Case 3: Backing 98% (< 100%)
  → Zone 3: Depegged! 🚨
  → Deficit: $1,009,000 - $980,000 = $29,000
  → Junior/Reserve provide $29k
  → Restore to 100.9% (not 100%)
  → Why? Next month can mint 0.9167% and stay at 100%!
```


---

### **Step 5A: Execute Profit Spillover (if $\Delta V > 0$)**

**When Senior backing > 110%, share excess with Junior & Reserve!**

**Total excess:**
$$
E = \Delta V = V_s^{net} - V_{target}
$$

**Distribution (80/20 split):**
$$
E_j = E \cdot \beta_j^{spillover} = E \cdot 0.80
$$
$$
E_r = E \cdot \beta_r^{spillover} = E \cdot 0.20
$$

**Transfer assets:**
$$
V_s^{final} = V_s^{net} - E = V_{target}
$$
$$
V_j^{new} = V_j + E_j
$$
$$
V_r^{new} = V_r + E_r
$$

**In simple terms:**

```
Senior has $1,000,000 (excess)
Target is $935,000
Excess: $65,000

Split:
- Junior gets: $65,000 × 80% = $52,000 🎉
- Reserve gets: $65,000 × 20% = $13,000 🎉

Final state:
- Senior: $935,000 (exactly 110%)
- Junior: $850,000 + $52,000 = $902,000
- Reserve: $625,000 + $13,000 = $638,000
```

**This is how Junior holders get rewarded for supporting the system!**

---

### **Step 5B: Execute Backstop (if $\Delta V < 0$)**

**When Senior backing < 100%, Junior & Reserve provide support to restore to 100.9%.**

**Restoration target:**
$$
V_{restore} = \alpha_{restore} \cdot S_{new} = 1.009 \cdot S_{new}
$$

**Deficit to cover:**
$$
D = V_{restore} - V_s^{net}
$$

**Backstop Waterfall (Reserve → Junior, NO CAPS):**

**Pull from Reserve first (everything if needed):**
$$
X_r = \min(V_r, D)
$$

**Remaining deficit after Reserve:**
$$
D' = D - X_r
$$

**Pull from Junior if Reserve insufficient (everything if needed):**
$$
X_j = \min(V_j, D')
$$

**Total backstop:**
$$
X_{total} = X_r + X_j
$$

**Transfer assets:**
$$
V_s^{final} = V_s^{net} + X_{total}
$$
$$
V_j^{new} = V_j - X_j
$$
$$
V_r^{new} = V_r - X_r
$$

**In simple terms:**

```
Senior has $980,000 (deficit - depegged!)
Supply: 1,000,000 snrUSD
Current backing: 98%

Restoration target (100.9%): $1,009,000
Deficit: $1,009,000 - $980,000 = $29,000

Waterfall (Reserve → Junior, NO CAPS):
1. Reserve has: $625,000
   Reserve gives: min($625,000, $29,000) = $29,000 ✅
   Deficit covered! Junior not needed!

Final state:
- Senior: $980,000 + $29,000 = $1,009,000 (100.9% backing) ✅
- Junior: $850,000 (untouched)
- Reserve: $625,000 - $29,000 = $596,000

Next month (assuming 0% profit):
- Start: 100.9% backing
- Mint 11% APY (0.9167%): 1,009,167 snrUSD
- New backing: $1,009,000 / 1,009,167 = 100% ✅
- Still at peg! No backstop needed!
```

**Example with larger deficit (Reserve depleted):**

```
Senior has $500,000 (severe depeg!)
Supply: 1,000,000 snrUSD
Current backing: 50%

Restoration target (100.9%): $1,009,000
Deficit: $1,009,000 - $500,000 = $509,000

Waterfall:
1. Reserve has: $625,000
   Reserve gives: min($625,000, $509,000) = $509,000
   Reserve DEPLETED! 
   Remaining deficit: $509,000 - $509,000 = $0 ✅

2. Junior not needed (Reserve covered it all)

Final state:
- Senior: $500,000 + $509,000 = $1,009,000 (100.9%) ✅
- Junior: $850,000 (untouched)
- Reserve: $625,000 - $509,000 = $116,000 (18.6% remaining)
```

**Example with catastrophic deficit (both depleted):**

```
Senior has $200,000 (catastrophic depeg!)
Supply: 1,000,000 snrUSD

Deficit: $1,009,000 - $200,000 = $809,000

Waterfall:
1. Reserve gives everything: $625,000
   Remaining: $809,000 - $625,000 = $184,000

2. Junior gives: min($850,000, $184,000) = $184,000
   Deficit covered! ✅

Final state:
- Senior: $1,009,000 (100.9%) ✅
- Junior: $850,000 - $184,000 = $666,000 (21.6% loss)
- Reserve: $0 (WIPED OUT!)
```

**This is how Junior holders take on risk in exchange for upside!**
 


---

### **Step 6: Update Rebase Index**


**This is the ONLY thing we actually execute on-chain to complete the rebase!**


The rebase index multiplier includes BOTH user APY and performance fee:

$$
I_{new} = I_{old} \cdot (1 + r_{selected} \cdot (1 + f_{perf}))
$$

Where:
- $r_{selected}$ = the dynamically chosen rate from Step 3 (0.010833, 0.010000, or 0.009167)
- $f_{perf}$ = 0.02 (2% performance fee)

**Expanded formulas:**

If 13% APY selected:
$$
I_{new} = I_{old} \cdot (1 + 0.010833 \cdot 1.02) = I_{old} \cdot 1.011050
$$

If 12% APY selected:
$$
I_{new} = I_{old} \cdot (1 + 0.010000 \cdot 1.02) = I_{old} \cdot 1.010200
$$

If 11% APY selected:
$$
I_{new} = I_{old} \cdot (1 + 0.009167 \cdot 1.02) = I_{old} \cdot 1.009350
$$

**After rebase, user balances automatically increase:**
$$
b_i^{new} = \sigma_i \cdot I_{new}
$$

**Treasury balance also increases** (holds protocol fee shares):
$$
b_{treasury}^{new} = \sigma_{treasury} \cdot I_{new}
$$

In simple terms: new_rebase_index = old_rebase_index × (1 + selected_rate × 1.02)

**Key Point:** The 2% performance fee is captured by minting additional shares to the treasury during rebase execution, which then grow with the index like all other shares.

---

## Three-Zone Spillover System

### **Understanding the Three Operating Zones**

**Senior operates in three distinct zones with different spillover behavior:**

#### **Mechanism Overview:**

```
┌──────────────────────────────────────────┐
│  ZONE 1: Senior Backing > 110%          │
│  (Excess Profits)                        │
│                                          │
│  Senior → Junior (80%)                   │
│  Senior → Reserve (20%)                  │
│                                          │
│  Senior returns to exactly 110% ✅       │
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│  ZONE 2: 100% ≤ Backing ≤ 110%          │
│  (Healthy Buffer - MOST COMMON)          │
│                                          │
│  NO ACTION NEEDED                        │
│                                          │
│  Everyone keeps their money ✅           │
│  Senior maintains 1:1 peg + buffer ✅    │
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│  ZONE 3: Senior Backing < 100%          │
│  (Depegged - Emergency)                  │
│                                          │
│  Reserve → Senior (no cap!)              │
│  Junior → Senior (no cap, if needed!)   │
│                                          │
│  Senior restored to 100.9% ✅            │
│  Next month: can mint 11% & stay at peg!│
│                                          │
└──────────────────────────────────────────┘
```

**The Critical Insight - The 100% Threshold:**

```
100% = The Peg (1 snrUSD = $1 backing)

Starting at 105%:
  ✅ Zone 2: Healthy buffer!
  ✅ No action needed, Senior maintains peg + extra buffer

Starting at 98%:
  🚨 Zone 3: Depegged!
  🚨 Below 1:1 backing! MUST trigger backstop!
  → Junior/Reserve provide support to restore to 100.9%
  → Why 100.9%? Next month can mint 11% APY and stay at peg!

This creates a 10% "no-action" buffer zone (100-110%)!
```

#### **Why This Design?**

**Creates Balanced Incentives with Wide Operating Range:**

**For Junior Holders:**
- ✅ **Upside:** Share in 80% of Senior's excess profits (>110%)
- ✅ **Wide buffer:** No action needed for 10% range (100-110%)
- ✅ **Downside:** **Secondary backstop** - Only called if Reserve depleted (no cap!)
- ✅ **Result:** Protected by Reserve first, rare exposure, well-compensated

**For Reserve:**
- ✅ **Upside:** Receives 20% of Senior's excess profits (passive income)
- ✅ **Wide buffer:** Same 10% no-action zone
- ✅ **Downside:** **PRIMARY backstop** - First line of defense (no cap, can be wiped out!)
- ✅ **Growth Over Time:** Reserve grows from profit spillover (if not used for backstop)

**For Senior Holders:**
- ✅ **Stability:** Fluctuates naturally in 100-110% range
- ✅ **Dynamic APY:** 11-13% annual returns, always maximized by dynamic selection
- ✅ **Protection:** Wide buffer + Junior/Reserve backstop
- ✅ **Peg safety:** Always maintains 1:1 redemption (≥100%)

---

#### **Dynamic APY Selection Examples:**

**Example 1: High Backing (Can afford 13% APY)**
```
After fees: $1,080,000
Current supply: 1,000,000 snrUSD

Try 13%: S_new = 1,010,833
Backing: $1,080,000 / 1,010,833 = 106.8% ✅ >= 100%
→ USE 13% APY! 🎉
→ Result: Zone 2 (106.8%), no action needed
```

**Example 2: Medium Backing (Can only afford 12% APY)**
```
After fees: $1,020,000
Current supply: 1,000,000 snrUSD

Try 13%: 1,010,833 → Backing 100.9% ✅ >= 100% (would work!)
→ USE 13% APY! 🎉

Note: Even at 100.9%, 13% works because we're still >= 100%!
```

**Example 3: Low Backing (Can only afford 11% APY)**
```
After fees: $1,010,000
Current supply: 1,000,000 snrUSD

Try 13%: 1,010,833 → Backing 99.9% ❌
Try 12%: 1,010,000 → Backing 100.0% ✅
→ USE 12% APY! ✅
→ Result: Exactly at peg (100%)
```

**Example 4: Critical (Need backstop even with 11%)**
```
After fees: $1,005,000
Current supply: 1,000,000 snrUSD

Try 13%: 1,010,833 → Backing 99.4% ❌
Try 12%: 1,010,000 → Backing 99.5% ❌
Try 11%: 1,009,167 → Backing 99.6% ❌
→ USE 11% + BACKSTOP 🚨
→ Need to restore to 100.9%: 1,009,167 × 1.009 = $1,018,255
→ Deficit: $1,018,255 - $1,005,000 = $13,255
→ Reserve provides: min(Reserve, $13,255) = $13,255 ✅
→ Junior not needed (Reserve covered it)
→ Final: $1,018,255 (100.9% backing, can afford next month's APY!)
```

---

#### **Three-Zone System Examples:**

**Scenario A: Bull Market (Senior earns 5%)**
```
Senior value: $1,150,000 (after yield)
New supply: 1,000,000 snrUSD
Backing: 115% (ZONE 1: > 110%)

Target (110%): $1,100,000
Excess: $50,000

→ PROFIT SPILLOVER:
  Junior gets: $50,000 × 80% = $40,000 🎉
  Reserve gets: $50,000 × 20% = $10,000 🎉
  Senior: Exactly $1,100,000 (110%)

Result: Everyone wins!
```

**Scenario B: Normal Operation (Senior earns 1%)**
```
Senior value: $1,050,000 (after yield & fees)
New supply: 1,000,000 snrUSD
Backing: 105% (ZONE 2: 100-110%)

Trigger (100%): $1,000,000
Target (110%): $1,100,000

→ NO ACTION NEEDED ✅
→ Everyone keeps their money
→ Senior maintains peg + 5% buffer

Result: Stable, healthy operation (most common state)
```

**Scenario C: Moderate Bear Market (Senior loses 2%)**
```
Senior value: $1,020,000 (after loss)
New supply: 1,000,000 snrUSD  
Backing: 102% (ZONE 2: 100-110%)

Trigger (100%): $1,000,000

→ NO ACTION NEEDED ✅
→ Still above 100% trigger
→ Senior maintains peg + 2% buffer
→ Junior/Reserve don't need to help!

Result: System resilient, buffer absorbs moderate losses
```

**Scenario D: Severe Bear Market (Senior loses 12%)**
```
Senior value: $980,000 (after severe loss)
New supply: 1,000,000 snrUSD
Backing: 98% (ZONE 3: < 100%)

Trigger (100%): $1,000,000
Restore target (100.9%): $1,009,000
Deficit: $1,009,000 - $980,000 = $29,000

→ BACKSTOP TRIGGERED (Reserve → Junior, NO CAPS):
  Reserve provides: min($625k, $29k) = $29,000 ✅
  Junior provides: $0 (not needed, Reserve covered it)
  Senior: $1,009,000 (100.9%)

→ Restored to 100.9% (not just 100%)!
→ Why? Next month can mint 11% APY and stay at peg!

Result: Emergency backstop works, Reserve absorbs loss, Junior untouched, system sustainable
```

### **Three-Zone Spillover Algorithm**

Given:
- Current Senior value: $V_s^{net}$ (after fees)
- New supply: $S_{new}$ (after rebase calculation)

**Calculate backing ratio:**
$$
R_{senior} = \frac{V_s^{net}}{S_{new}}
$$

**Calculate thresholds:**
$$
V_{target} = \alpha_{target} \cdot S_{new} = 1.10 \cdot S_{new}
$$
$$
V_{trigger} = \alpha_{trigger} \cdot S_{new} = 1.00 \cdot S_{new}
$$
$$
V_{restore} = \alpha_{restore} \cdot S_{new} = 1.009 \cdot S_{new}
$$

### **Complete Rebase Algorithm with Dynamic APY**

```
// STEP 1: Calculate fees and net value
V_s_net = V_s - F_mgmt - F_perf

// STEP 2: Dynamic APY Selection (Waterfall: 13% → 12% → 11%)
S_new_13 = S × 1.010833
R_13 = V_s_net / S_new_13

IF R_13 >= 1.00:
    S_new = S_new_13
    r_selected = 0.010833  // 13% APY
    selected_APY = "13%"
ELSE:
    S_new_12 = S × 1.010000
    R_12 = V_s_net / S_new_12
    
    IF R_12 >= 1.00:
        S_new = S_new_12
        r_selected = 0.010000  // 12% APY
        selected_APY = "12%"
    ELSE:
        S_new_11 = S × 1.009167
        R_11 = V_s_net / S_new_11
        
        IF R_11 >= 1.00:
            S_new = S_new_11
            r_selected = 0.009167  // 11% APY
            selected_APY = "11%"
        ELSE:
            // Use 11% anyway, backstop will be triggered
            S_new = S_new_11
            r_selected = 0.009167  // 11% APY + backstop
            selected_APY = "11% (backstop needed)"

// STEP 3: Calculate backing ratio with selected APY
R_senior = V_s_net / S_new

// STEP 4: Three-Zone Decision
```

---

### **Three-Zone Decision Algorithm**

```
// ZONE 1: Excess Backing (> 110%)
IF R_senior > 1.10:
    // PROFIT SPILLOVER (Senior → Junior/Reserve)
    Excess = V_s_net - V_target
    
    // Split 80/20
    To_Junior = Excess × 0.80
    To_Reserve = Excess × 0.20
    
    // Transfer
    Senior_Value -= Excess
    Junior_Value += To_Junior
    Reserve_Value += To_Reserve
    
    // Result: Senior = exactly 110% backing ✅
    
// ZONE 2: Healthy Buffer (100% to 110%)
ELSE IF R_senior >= 1.00 AND R_senior <= 1.10:
    // NO ACTION NEEDED
    // Everyone keeps their money ✅
    // Senior maintains 1:1 peg + buffer ✅
    
    // This is the MOST COMMON state in normal operation!
    
// ZONE 3: Depeg (< 100%)
ELSE IF R_senior < 1.00:
    // BACKSTOP (Reserve → Junior → Senior, NO CAPS!)
    // Restore to 100.9% (not 100%) to afford next month's min APY
    V_restore = 1.009 × S_new
    Deficit = V_restore - V_s_net
    
    // Pull from Reserve FIRST (everything if needed!)
    X_r = min(V_r, Deficit)
    D_remaining = Deficit - X_r
    
    IF D_remaining > 0:
        // Pull from Junior (everything if needed!)
        X_j = min(V_j, D_remaining)
        D_final = D_remaining - X_j
        
        IF D_final > 0:
            // Emergency: Insufficient backstop
            WARN: System undercollateralized
            // Senior remains below 100.9%
            // Reserve + Junior both wiped out!
            // May still depeg next month!
    ELSE:
        X_j = 0  // Junior not needed
    
    // Transfer
    Senior_Value += (X_r + X_j)
    Reserve_Value -= X_r
    Junior_Value -= X_j
    
    // Result: Senior restored to 100.9% ✅
    // Can afford 11% APY next month without depegging!
    // Reserve took the hit first, Junior is backup

// STEP 5: Update Rebase Index
I_new = I_old × (1 + r_selected)

// User balances automatically increase via index
// b_i = σ_i × I_new

EMIT RebaseExecuted(selected_APY, I_new, S_new, V_s_final, zone)
```

**Key Insight:** This three-zone system ensures:
- ✅ Excess profits are shared (incentivizes Junior participation)
- ✅ **Wide buffer zone** prevents constant spillover (100-110%)
- ✅ Backstop only when depegged (< 100%)
- ✅ System naturally operates in the healthy buffer zone most of the time

### **Junior APY Impact**

Junior's returns are affected by BOTH spillover directions:

#### **Case A: Junior Receives Spillover ($E_j > 0$)**

**Junior's effective monthly return:**
$$
r_j^{eff} = \frac{\Pi_j - F_j + E_j}{V_j}
$$

Where:
- $\Pi_j$ = Junior gross profit from own strategy
- $F_j$ = Junior fees (management + performance)
- $E_j$ = Spillover received from Senior (80% of excess)

**Junior APY:**
$$
APY_j = \left(1 + r_j^{eff}\right)^{12} - 1
$$

**Example:**
```
Junior earns 2% ($17k profit), pays $4k fees
Receives $52k spillover from Senior

Monthly return: ($17k - $4k + $52k) / $850k = 7.65%
APY: (1.0765)^12 - 1 = 143% 🚀
```

---

#### **Case B: Junior Provides Backstop ($X_j > 0$)**

**Junior's effective monthly return:**
$$
r_j^{eff} = \frac{\Pi_j - F_j - X_j}{V_j}
$$

Where:
- $\Pi_j$ = Junior gross profit from own strategy
- $F_j$ = Junior fees (management + performance)
- $X_j$ = Backstop given to Senior (NO CAP - can be wiped out if Reserve depleted!)

**Junior APY:**
$$
APY_j = \left(1 + r_j^{eff}\right)^{12} - 1
$$

**Example:**
```
Junior earns 0% ($0 profit), pays $4k fees
Provides $85k backstop to Senior (after Reserve depleted)

Monthly return: ($0 - $4k - $85k) / $850k = -10.47%
APY: (0.8953)^12 - 1 = -72% 💀
```

---

#### **Case C: No Spillover (Balanced)**

**Junior's effective monthly return:**
$$
r_j^{eff} = \frac{\Pi_j - F_j}{V_j}
$$

**Junior APY:**
$$
APY_j = \left(1 + r_j^{eff}\right)^{12} - 1
$$

**Example:**
```
Junior earns 1.5% ($12.75k profit), pays $4.25k fees
No spillover in either direction

Monthly return: ($12.75k - $4.25k) / $850k = 1.0%
APY: (1.01)^12 - 1 = 12.7% ✅
```

---

**Key Takeaway:** Junior has:
- ✅ **High upside** when Senior performs well (receives 80% of excess)
- ⚠️ **High downside risk** when Senior underperforms (NO CAP - secondary backstop after Reserve)
- ✅ **Balanced risk/reward** with Reserve as primary protection layer
- ⚠️ **Can be wiped out** in catastrophic scenarios (if Reserve + Junior both depleted)

---

## Fee Calculations

### **Management Fee (Value Deduction)**

**Monthly accrual:**
$$
F_{mgmt}(t) = V(t) \cdot \frac{f_{mgmt}}{12}
$$

**Collected during rebase:**
- Transferred to protocol treasury
- Deducted from $V_s$ before backing check

**Example:**
```
Senior value: $10,500,000
Management fee: $10,500,000 × (1% / 12) = $8,750
Net value: $10,500,000 - $8,750 = $10,491,250
```

---

### **Performance Fee (Token Dilution)**

**Charged by minting additional tokens:**
$$
S_{fee} = S_{users} \cdot f_{perf} = S_{users} \cdot 0.02
$$

Where:
- $S_{users}$ = tokens minted for users at selected APY
- $S_{fee}$ = additional tokens minted to treasury (2% of user tokens)

**Total supply increase:**
$$
S_{new} = S + S_{users} + S_{fee} = S \cdot (1 + r_{selected} \cdot 1.02)
$$

**Properties:**
- ✅ Always charged (no profit requirement)
- ✅ Minted as extra tokens, not deducted from value
- ✅ Dilutes backing ratio by ~2% of the rebase amount
- ✅ Treasury tokens grow with rebase index like all shares

**Example:**
```
Current supply: 10,000,000 snrUSD
Selected APY: 11% (monthly rate: 0.009167)

User tokens minted: 10,000,000 × 0.009167 = 91,670
Performance fee: 91,670 × 2% = 1,833
Total new supply: 10,091,670 + 1,833 = 10,093,503

Users get: 91,670 snrUSD
Treasury gets: 1,833 snrUSD
```

---

### **Early Withdrawal Penalty**

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

**Penalty destination:**
- Stays in vault
- Effectively increases $V_s$
- Benefits remaining holders

---

## User Balance & Shares

### **Deposit**

User deposits $d$ USDE:

**Shares minted:**
$$
\sigma_{new} = \frac{d}{I}
$$

**User's new balance:**
$$
b_{new} = \sigma_{new} \cdot I = d
$$

**This maintains 1:1 conversion at time of deposit.**

**At Launch (Day 0):**
```
First depositor: $1,000 USDE
Rebase index: 1.0 (initial)
Shares minted: 1,000 / 1.0 = 1,000 shares
Balance: 1,000 × 1.0 = 1,000 snrUSD ✅
Backing: 100% (1:1)
```

**After Several Rebases:**
```
New depositor: $1,000 USDE
Rebase index: 1.05 (grown through rebases)
Shares minted: 1,000 / 1.05 = 952.38 shares
Balance: 952.38 × 1.05 = 1,000 snrUSD ✅
Still 1:1 conversion for new user!
```

---

### **Withdrawal**

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

---

### **Balance After Rebase**

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

## Withdrawal Mechanics

### **Liquidity Sources**

**Total assets:**
$$
A_{total} = A_{liquid} + A_{deployed}
$$

Where:
- $A_{liquid}$ = USDE in vault contract
- $A_{deployed}$ = USDE in strategy (stablecoins)

### **Withdrawal Flow**

User withdraws $w$ USDE:

**Step 1: Check liquid reserves**
$$
w_{reserve} = \min(w, A_{liquid})
$$

**Step 2: If insufficient, exit LP**
$$
w_{strategy} = w - w_{reserve}
$$

Must call: `strategy.withdraw(w_strategy)`

**Step 3: Transfer to user**
$$
\text{Transfer}(w_{net}) \text{ to user}
$$

---

## Constraints & Invariants

### **Invariant 1: 1:1 Redemption Peg**

**The peg and backing are DIFFERENT concepts:**

- **Peg (Exchange Rate):** 1 snrUSD always redeems for $1 USD of value
  $$
  \text{Redemption Value} = 1 \text{ snrUSD} = 1 \text{ USD}
  $$

- **Backing (Collateralization):** System holds $1.10 for every $1.00 of snrUSD (safety buffer)
  $$
  \frac{V_s}{S} \geq 1.10
  $$

**Key Point:** The 1:1 peg is what users experience (1 snrUSD = 1 USD). The 110% backing is internal overcollateralization for safety.

---

### **Invariant 2: Three-Zone Operating Range**

Senior operates in three distinct zones:

**Zone 1: Profit Spillover Zone ($R_{senior} > 1.10$)**
$$
\frac{V_s^{final}}{S_{new}} = 1.10
$$
After spillover, Senior returns to exactly 110% backing.

**Zone 2: Healthy Buffer Zone ($1.00 \leq R_{senior} \leq 1.10$)**
$$
1.00 \leq \frac{V_s}{S_{new}} \leq 1.10
$$
No action needed. This is the **normal operating state** (10% range).

**Zone 3: Backstop Zone ($R_{senior} < 1.00$)**
$$
\frac{V_s^{final}}{S_{new}} \geq 1.009
$$
After backstop, Senior restored to at least 100.9% (enables next month's min APY).

**Critical Thresholds:**
- **110%** = Profit spillover trigger (share excess)
- **100%** = Backstop trigger (depeg / need help)
- **100.9%** = Backstop restoration target (sustain next month's 11% APY)

**How It Works:**
- **If > 110%:** Excess spills to Junior/Reserve → Senior returns to 110%
- **If 100-110%:** Healthy buffer → No action needed ✅
- **If < 100%:** Junior/Reserve provide backstop → Senior restored to 100.9%

**Why 100.9% restoration?**
- Ensures we can afford minimum 11% APY (0.9167% minting) next month
- Without this buffer, would need backstop every single month
- Creates sustainable system even with 0% strategy returns

**Important Notes:**
- **10% buffer zone:** Prevents constant spillover activity
- **Most common state:** Senior naturally operates in 100-110% range
- **Backstop is rare:** Only when strategy performs very badly
- **Peg always maintained:** Senior ≥ 100% after each rebase

**Operating States:**
```
>110%        : Profit spillover to Junior/Reserve
100-110%     : Healthy buffer (NO ACTION) ✅✅✅
<100%        : Backstop from Junior/Reserve (Depeg!)
```

**In extreme cases:**
```
If Junior + Reserve combined value is insufficient:
→ Senior may remain <100%
→ Depeg persists!
→ Emergency: System undercollateralized ⚠️
→ Both Reserve and Junior can be wiped out!
```

---

### **Invariant 3: Conservation of Value**

Before rebase:
$$
V_{total}^{before} = V_s + V_j + V_r
$$

After rebase (with backstop $X_j, X_r$):
$$
V_{total}^{after} = V_s^{net} + X_j + X_r + (V_j - X_j) + (V_r - X_r) = V_s^{net} + V_j + V_r
$$

(Backstop transfers value, doesn't create/destroy it)

---

### **Invariant 4: Deposit Cap**

Always enforce:
$$
S \leq \gamma \cdot V_r
$$

Revert deposits if this would be violated.

---

### **Invariant 5: Share Conservation**

Total shares never change except for deposits/withdrawals:
$$
\Sigma(t) = \Sigma(t_0) + \sum \text{deposits} - \sum \text{withdrawals}
$$

Rebases do NOT change $\Sigma$, only $I$.

---

## Example Calculation

### **Scenario: Senior After Several Months of Operation**

**Context:** Senior launched at 100% backing, has been operating for several months, strategy has been performing well.

### **Given (Current State):**
- $S = 10,000,000$ snrUSD (current supply)
- $V_s = 11,150,000$ USD (current value - grown through strategy yield)
- $V_s^{prev} = 11,000,000$ USD (value 30 days ago)
- $I_{old} = 1.0$ (rebase index)
- Current backing: $11,150,000 / 10,000,000 = 111.5%$ (Zone 1!)

### **Step 1: Management Fee**
$$
F_{mgmt} = 11,150,000 \times 0.000833 = 9,288 \text{ USD}
$$
$$
V_s^{net} = 11,150,000 - 9,288 = 11,140,712 \text{ USD}
$$

**Note:** Performance fee is NO LONGER deducted here. It's handled by minting extra tokens in Step 2.

### **Step 2: Dynamic APY Selection + Performance Fee**

**Try 13% APY first:**

User tokens to mint:
$$
S_{users}^{13} = 10,000,000 \times 0.010833 = 108,330 \text{ snrUSD}
$$

Performance fee (2% extra):
$$
S_{fee}^{13} = 108,330 \times 0.02 = 2,167 \text{ snrUSD}
$$

Total new supply:
$$
S_{new}^{13} = 10,000,000 + 108,330 + 2,167 = 10,110,497 \text{ snrUSD}
$$

Backing check:
$$
R_{13} = \frac{11,140,712}{10,110,497} = 1.1019 = 110.19\%
$$

**Check: $R_{13} = 110.19\% \geq 100\%$** ✅ **USE 13% APY!**

**Selected:**
- $S_{new} = 10,110,497$ snrUSD
- $r_{selected} = 0.010833$ (13% APY)
- User tokens: $108,330$ snrUSD
- Treasury fee tokens: $2,167$ snrUSD

**Why 13% works:** Even after minting 108,330 for users + 2,167 for treasury, backing is still 110.19% > 100%!

### **Step 3: Determine Zone & Check for Spillover**

**Calculate backing ratio (with 13% APY + performance fee):**
$$
R_{senior} = \frac{11,140,712}{10,110,497} = 1.1019 = 110.19\%
$$

**Check which zone:**
$$
R_{senior} = 110.19\% > 110\%
$$

**ZONE 1: Profit Spillover! 🎉**

**Calculate 110% target:**
$$
V_{target} = 1.10 \times 10,110,497 = 11,121,547 \text{ USD}
$$

**Calculate excess:**
$$
E = 11,140,712 - 11,121,547 = 19,165 \text{ USD}
$$

**Senior has excess backing! Will share $19,165 with Junior/Reserve.**

### **Step 4: Execute Profit Spillover**

**Split 80/20:**
$$
E_j = 19,165 \times 0.80 = 15,332 \text{ USD to Junior}
$$
$$
E_r = 19,165 \times 0.20 = 3,833 \text{ USD to Reserve}
$$

**Final values:**
$$
V_s^{final} = 11,140,712 - 19,165 = 11,121,547 \text{ USD (exactly 110%)}
$$
$$
V_j^{new} = 5,000,000 + 15,332 = 5,015,332 \text{ USD}
$$
$$
V_r^{new} = 2,000,000 + 3,833 = 2,003,833 \text{ USD}
$$

### **Step 5: Update Index (with 13% APY + 2% fee!)**
$$
I_{new} = 1.0 \times (1 + 0.010833 \times 1.02) = 1.0 \times 1.011050 = 1.011050
$$

### **Result:**
- ✅ **Senior holders:** Balances increased by 1.0833% (13% APY!) 🎉
- ✅ **Protocol treasury:** Received 2,167 snrUSD (2% performance fee via dilution)
- ✅ **Senior vault:** Exactly 110% backing maintained
- ✅ **Junior holders:** Received $15,332 profit share (0.31% bonus!)
- ✅ **Reserve:** Received $3,833 (0.19% growth)
- ✅ **Management fee:** $9,288 (deducted from value)

**Everyone wins!** This is how the two-way spillover creates balanced incentives.

**🎯 Key Insights:** 
- Dynamic APY selection means users got 13% APY this month (not just 11%)! 
- Performance fee charged via token dilution (2% extra minted) instead of value deduction
- Treasury receives 2,167 snrUSD that will grow with future rebases
- System automatically maximized returns while maintaining the peg

---

## Summary of Key Formulas

| Concept | Formula |
|---------|---------|
| User balance | $b_i = \sigma_i \cdot I$ |
| **Dynamic APY Selection** | |
| Try 13% APY | $S_{new}^{13} = S \cdot 1.011050$ (includes 2% fee), use if $\frac{V_s^{net}}{S_{new}^{13}} \geq 1.00$ |
| Try 12% APY | $S_{new}^{12} = S \cdot 1.010200$ (includes 2% fee), use if $\frac{V_s^{net}}{S_{new}^{12}} \geq 1.00$ |
| Try 11% APY | $S_{new}^{11} = S \cdot 1.009350$ (includes 2% fee), use if $\frac{V_s^{net}}{S_{new}^{11}} \geq 1.00$ (or use + backstop) |
| Rebase index update | $I_{new} = I_{old} \cdot (1 + r_{selected} \cdot 1.02)$ |
| Management fee (value) | $F_{mgmt} = V_s \cdot \frac{f_{mgmt}}{12}$ |
| Performance fee (tokens) | $S_{fee} = S_{users} \cdot 0.02$ (minted to treasury) |
| **Three-Zone Spillover** | |
| Backing ratio | $R_{senior} = \frac{V_s^{net}}{S_{new}}$ |
| Profit spillover trigger | $R_{senior} > 1.10$ (Zone 1) |
| Healthy buffer zone | $1.00 \leq R_{senior} \leq 1.10$ (Zone 2, no action) |
| Backstop trigger | $R_{senior} < 1.00$ (Zone 3) |
| Backstop restoration target | 100.9% (enables next month's min APY) |
| Profit spillover amount | $E = V_s^{net} - (1.10 \cdot S_{new})$ |
| Profit split | $E_j = E \cdot 0.80$, $E_r = E \cdot 0.20$ |
| Backstop deficit | $D = (1.009 \cdot S_{new}) - V_s^{net}$ |
| Reserve backstop (first) | $X_r = \min(V_r, D)$ (no cap!) |
| Junior backstop (second) | $X_j = \min(V_j, D - X_r)$ (no cap!) |
| Backstop waterfall | Reserve → Junior (no limits) |
| Early withdrawal penalty | $P = w \cdot 0.05$ (if $t - t_c < 7$ days) |
| Deposit cap | $S_{max} = 10 \cdot V_r$ |

---

## Notes on Implementation

1. **All calculations in wei (18 decimals)**
   - Use Solidity fixed-point math
   - Example: 11% = 110000 (basis points × 10)

2. **Order of operations matters**
   - Fees BEFORE backstop check
   - Backstop BEFORE rebase execution

3. **Rounding considerations**
   - Always round down for user benefits (withdrawals)
   - Always round up for protocol benefits (fees)

4. **Time-based calculations**
   - Use `block.timestamp` for time
   - 1 month ≈ 30 days = 2,592,000 seconds

---

## References

- ERC4626: https://eips.ethereum.org/EIPS/eip-4626
- Rebase tokens: Ampleforth, Olympus DAO
- Structured tranches: Barnbridge, Saffron Finance
- LP mechanics: Uniswap v2, Curve Finance

