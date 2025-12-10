# Certora Formal Verification for Senior Tranche Protocol

This directory contains comprehensive formal verification specifications for the Senior Tranche Protocol's mathematical formulas using Certora Prover.

## 📋 Overview

The formal verification suite validates all critical mathematical properties from the [Mathematical Specification](../math_spec.md), including:

1. **Core Formulas** - User balance, total supply, backing ratios
2. **Fee Calculations** - Time-based management & performance fees  
3. **Dynamic APY Selection** - Greedy maximization (13% → 12% → 11%)
4. **Three-Zone Spillover System** - Profit spillover, healthy buffer, backstop

## 🏗️ Structure

```
certora/
├── conf/                   # Configuration files
│   ├── MathLib.conf        # Core math verification
│   ├── FeeLib.conf         # Fee calculations verification
│   ├── RebaseLib.conf      # APY selection verification
│   └── SpilloverLib.conf   # Three-zone system verification
├── harness/                # Harness contracts (expose internal functions)
│   ├── MathLibHarness.sol
│   ├── FeeLibHarness.sol
│   ├── RebaseLibHarness.sol
│   └── SpilloverLibHarness.sol
├── specs/                  # CVL specifications
│   ├── MathLib.spec        # 17 rules + 2 invariants
│   ├── FeeLib.spec         # 17 rules + 1 invariant
│   ├── RebaseLib.spec      # 13 rules + 2 invariants
│   └── SpilloverLib.spec   # 18 rules + 2 invariants
└── README.md              # This file
```

## 🚀 Quick Start

### Prerequisites

```bash
# Install Certora CLI
pip install certora-cli

# Set up Certora API key (get from https://www.certora.com/)
export CERTORAKEY="your-api-key-here"
```

### Running Verifications

**Verify all libraries:**
```bash
cd /home/amschel/stratosphere/tranching
chmod +x certora/run_all_verifications.sh
./certora/run_all_verifications.sh
```

**Verify a single library:**
```bash
chmod +x certora/verify_single.sh
./certora/verify_single.sh MathLib      # Core formulas
./certora/verify_single.sh FeeLib       # Fee calculations
./certora/verify_single.sh RebaseLib    # Dynamic APY
./certora/verify_single.sh SpilloverLib # Three-zone system
```

**Manual verification:**
```bash
certoraRun certora/conf/MathLib.conf
```

## 📚 Verification Coverage

### 1. MathLib - Core Mathematical Formulas

**Formulas Verified:**
- ✅ User Balance: `b_i = σ_i × I` (Math Spec 4.2.1)
- ✅ Total Supply: `S = I × Σ` (Math Spec 4.2.2)
- ✅ Backing Ratio: `R_senior = V_s / S` (Math Spec 4.2.4)
- ✅ Deposit Cap: `S_max = 10 × V_r` (Math Spec 4.2.6)

**Key Properties (17 Rules):**
- `RULE-MATH-001`: User balance formula correctness
- `RULE-MATH-002`: Shares calculation correctness
- `RULE-MATH-003`: Balance-shares roundtrip consistency
- `RULE-MATH-007`: Backing ratio formula correctness
- `RULE-MATH-011`: Deposit cap formula correctness
- ... and 12 more properties

**Invariants (2):**
- `INV-CONST-001`: Protocol constants correctly set
- `INV-CONST-002`: Spillover shares sum to 100%

### 2. FeeLib - Fee Calculations & Time-Based Logic

**Formulas Verified:**
- ✅ Management Fee (TIME-BASED): `S_mgmt = V_s × 1% × (t_elapsed / 365 days)` (Math Spec 5.1 Step 1)
- ✅ Performance Fee: `S_fee = S_users × 2%` (Math Spec 6.2)
- ✅ Withdrawal Penalty: `P = w × 20% if (t - t_c < 7 days)` (Math Spec 6.4)
- ✅ Rebase Supply: `S_new = S + S_users + S_fee + S_mgmt` (Math Spec 5.1 Step 2)
- ✅ Rebase Index: `I_new = I_old × (1 + r_selected × timeScaling)` (Math Spec 5.1 Step 5)

**Key Properties (17 Rules):**
- `RULE-FEE-001`: Management fee formula (monthly)
- `RULE-FEE-002`: Management fee tokens (time-based)
- `RULE-FEE-003`: Management fee grows linearly with time
- `RULE-FEE-005`: Performance fee formula correctness
- `RULE-FEE-007`: Withdrawal penalty formula (within cooldown)
- `RULE-FEE-013`: Rebase index formula correctness
- ... and 11 more properties

**Critical Verifications:**
- ⏰ **Time-based management fees** prevent over-charging
- 🎯 **Performance fee** always exactly 2% of user tokens
- 🔒 **Withdrawal penalties** apply correctly based on cooldown

### 3. RebaseLib - Dynamic APY Selection (13% → 12% → 11%)

**Algorithm Verified:**
- ✅ Waterfall APY selection (Math Spec 5.1 Step 2)
- ✅ Greedy maximization (highest APY that maintains peg)
- ✅ Backing ratio checks for each tier
- ✅ Backstop flagging when all APYs fail

**Key Properties (13 Rules):**
- `RULE-REBASE-001`: Waterfall ordering correct (tries 13% first)
- `RULE-REBASE-002`: Selected APY always maintains peg
- `RULE-REBASE-003`: Greedy maximization property
- `RULE-REBASE-007`: Index always increases
- `RULE-REBASE-008`: Higher APY produces higher index
- `RULE-REBASE-010`: Backstop flag correctness
- ... and 7 more properties

**Core Guarantees:**
- 🎯 System **always** selects highest sustainable APY
- 🔒 **Peg maintained** (≥100% backing) unless backstop needed
- 📈 Users get **maximum possible returns** (13% if possible)

### 4. SpilloverLib - Three-Zone Spillover System

**Zones Verified:**
- ✅ **Zone 1** (>110%): Profit Spillover → Junior (80%) & Reserve (20%)
- ✅ **Zone 2** (100-110%): Healthy Buffer (no action)
- ✅ **Zone 3** (<100%): Backstop ← Reserve first, then Junior

**Formulas Verified:**
- ✅ Zone 1: `V_target = 1.10 × S_new`, `E = V_s - V_target`, split 80/20 (Math Spec 5.1 Step 4A)
- ✅ Zone 3: `V_restore = 1.009 × S_new`, waterfall Reserve→Junior (Math Spec 5.1 Step 4B)

**Key Properties (18 Rules):**
- `RULE-SPILLOVER-001`: Zone 1 determination (>110%)
- `RULE-SPILLOVER-005`: Profit spillover target formula
- `RULE-SPILLOVER-007`: Spillover 80/20 split
- `RULE-SPILLOVER-010`: Backstop restoration to 100.9%
- `RULE-SPILLOVER-012`: Backstop waterfall (Reserve first)
- `RULE-SPILLOVER-018`: Restoration buffer enables next rebase
- ... and 12 more properties

**Critical Guarantees:**
- 💰 **Profit spillover** always 80/20 split (Junior/Reserve)
- 🛡️ **Reserve provides first** during backstop (correct priority)
- 🔄 **100.9% restoration** enables next month's 11% APY
- ⚖️ **Value conservation** in all transfers

## 🎯 Verification Goals

### Mathematical Correctness
- ✅ All formulas match the mathematical specification exactly
- ✅ No arithmetic overflows or underflows
- ✅ Precision maintained across all calculations

### Economic Properties
- ✅ Conservation of value (no money created/destroyed)
- ✅ Fee distribution fair and consistent
- ✅ APY selection maximizes user returns

### Safety Properties
- ✅ No division by zero
- ✅ All state transitions are valid
- ✅ Invariants preserved across operations

## 📊 Verification Results

After running verifications, you'll see results for:

| Library | Rules | Invariants | Focus Area |
|---------|-------|------------|------------|
| **MathLib** | 17 | 2 | Core formulas, precision |
| **FeeLib** | 17 | 1 | Time-based fees, penalties |
| **RebaseLib** | 13 | 2 | Dynamic APY (13%→12%→11%) |
| **SpilloverLib** | 18 | 2 | Three-zone system |
| **TOTAL** | **65** | **7** | **Full protocol math** |

## 🔍 Understanding the Specs

### Rule Naming Convention

```
RULE-[LIBRARY]-[NUMBER]: [Description]
```

**Examples:**
- `RULE-MATH-001`: MathLib, first rule (user balance formula)
- `RULE-FEE-007`: FeeLib, rule #7 (withdrawal penalty)
- `RULE-REBASE-003`: RebaseLib, rule #3 (greedy maximization)
- `RULE-SPILLOVER-012`: SpilloverLib, rule #12 (backstop waterfall)

### Invariant Naming Convention

```
INV-[CATEGORY]-[NUMBER]: [Description]
```

**Examples:**
- `INV-CONST-001`: Protocol constants invariant
- `INV-FEE-001`: Time constants invariant
- `INV-REBASE-001`: APY tiers ordering invariant

### Key Verification Techniques

1. **Parametric Rules**: Test properties for all possible inputs
2. **Invariants**: Properties that must always hold
3. **Deterministic Verification**: Not testing, but mathematical proof
4. **Counterexample Generation**: If a rule fails, Certora shows why

## 🐛 Debugging Failed Rules

If a rule fails, Certora provides:

1. **Call Trace**: Exact sequence of calls that violated the property
2. **Variable Values**: All intermediate values in the computation
3. **Counterexample**: Concrete input that breaks the rule

**Example:**
```
Rule RULE-MATH-003 failed
Counterexample:
  depositAmount = 1000
  rebaseIndex = 1500000000000000000
  Expected roundtrip: 1000
  Actual roundtrip: 999
  Issue: Rounding error exceeds tolerance
```

## 📖 References

- **Mathematical Specification**: [../math_spec.md](../math_spec.md)
- **Certora Documentation**: https://docs.certora.com/
- **CVL Reference**: https://docs.certora.com/en/latest/docs/cvl/index.html
- **Certora Community**: https://forum.certora.com/

## 💡 Tips for Writing Specs

1. **Start with simple properties** - Verify basic formulas first
2. **Use preconditions** - `require` statements filter out irrelevant cases
3. **Check overflow bounds** - `require value < max_uint256 / multiplier`
4. **Test edge cases** - Zero values, maximum values, boundary conditions
5. **Use helper functions** - Break complex rules into smaller pieces

## 🤝 Contributing

When adding new protocol features:

1. Update the mathematical specification first
2. Add harness functions for new library functions
3. Write CVL rules matching the math spec
4. Run verification and fix any issues
5. Document the new rules in this README

## ⚠️ Known Limitations

- **Loop unrolling**: Limited to 3 iterations (configurable)
- **Hash abstraction**: Optimistic hashing for performance
- **External calls**: Some may require summarization
- **Gas costs**: Not modeled in verification

## 📞 Support

For Certora-specific issues:
- **Forum**: https://forum.certora.com/
- **Docs**: https://docs.certora.com/
- **Support**: support@certora.com

For protocol-specific questions:
- Review [math_spec.md](../math_spec.md)
- Check contract comments and NatSpec
- Consult the development team

---

**Last Updated**: December 2024  
**Certora Prover Version**: Latest  
**Solidity Version**: 0.8.20

