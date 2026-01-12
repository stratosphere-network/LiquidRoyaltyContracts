# How Does ALAR Get Liquidated to Stablecoin for Withdrawal?

## Short Answer

**✅ Automatic liquidation happens via LP tokens, NOT raw tokens.**

When a user withdraws ALAR:
1. Vault checks if it has enough stablecoin
2. If not, it **automatically liquidates LP tokens** from Kodiak hook
3. Hook burns LP tokens → receives HONEY (stablecoin) + WBTC
4. Hook sends HONEY to vault → vault sends to user
5. WBTC stays in hook (admin can swap later)

**⚠️ If vault only has raw tokens (not LP tokens), automatic liquidation WON'T work.**
- Admin must manually swap tokens to stablecoin first
- Use `executeReserveAction(RescueAndSwap, ...)` or `executeReserveAction(SwapStable, ...)`

---

## Automatic Liquidation Flow

### Step-by-Step Process

**1. User Initiates Withdrawal**
```solidity
// User calls: withdraw(amount, receiver, owner)
// Reserve vault's _withdraw() is called
```

**2. Vault Checks Liquidity**
```solidity
function _withdraw(...) internal override {
    // Calculate penalties and fees
    (uint256 earlyPenalty, uint256 afterPenalty) = ...;
    
    // 🔑 KEY: Ensures liquidity is available
    _ensureLiquidityAvailable(afterPenalty);
    
    // Transfer stablecoin to user
    _stablecoin.safeTransfer(receiver, net);
}
```

**3. Automatic LP Liquidation**
```solidity
function _ensureLiquidityAvailable(uint256 amountNeeded) internal {
    for (uint256 i = 0; i < 3; i++) {  // Up to 3 attempts
        uint256 bal = _stablecoin.balanceOf(address(this));
        if (bal >= amountNeeded) break;  // ✅ Enough stablecoin
        
        // ❌ Not enough - need to liquidate LP
        uint256 needed = amountNeeded - bal;
        
        // Try to withdraw from reward vault if LP is staked
        // ...
        
        // 🔑 Liquidate LP tokens from hook
        try kodiakHook.liquidateLPForAmount(needed) {
            // Hook burns LP, sends stablecoin to vault
        } catch { break; }
    }
    
    // If still not enough, revert
    if (_stablecoin.balanceOf(address(this)) < amountNeeded) {
        revert InsufficientLiquidity();
    }
}
```

**4. Hook Liquidates LP Tokens**
```solidity
function liquidateLPForAmount(uint256 unstakeUsd) public onlyVault {
    // 1. Calculate LP tokens needed
    uint256 lpNeeded = calculateLPNeeded(unstakeUsd);
    
    // 2. Burn LP tokens from Kodiak Island pool
    island.burn(lpNeeded, address(this));
    // Returns: WBTC + HONEY (stablecoin)
    
    // 3. Send HONEY (stablecoin) to vault
    island.token1().safeTransfer(vault, honeyReceived);
    
    // 4. WBTC stays in hook (admin can swap later)
    // wbtcReceived stays in hook
}
```

**5. Vault Receives Stablecoin**
- Hook sends HONEY (stablecoin) to vault
- Vault now has enough stablecoin
- Vault transfers to user

---

## What If Vault Only Has Tokens (Not LP)?

### ❌ Automatic Liquidation Won't Work

**Problem:**
- `_ensureLiquidityAvailable()` only liquidates **LP tokens**
- If vault has raw tokens (e.g., WBTC, USDC) but no LP tokens, it will revert
- Error: `InsufficientLiquidity()`

**Why:**
```solidity
function _ensureLiquidityAvailable(uint256 amountNeeded) internal {
    // ...
    try kodiakHook.liquidateLPForAmount(needed) {
        // This only works if hook has LP tokens
        // If hook has no LP, this will fail
    } catch { break; }
    
    // If no LP tokens, this will revert
    if (_stablecoin.balanceOf(address(this)) < amountNeeded) {
        revert InsufficientLiquidity();  // ❌ Reverts here
    }
}
```

### ✅ Solution: Manual Token Swap

**Admin must swap tokens to stablecoin first:**

#### Option 1: Swap Tokens from Hook

**If tokens are in hook:**
```solidity
// Use RescueAndSwap action
executeReserveAction(
    ReserveAction.RescueAndSwap,  // Action 2
    tokenIn,                      // Token to swap (e.g., WBTC)
    0,                            // tokenB unused
    amount,                       // Amount to swap
    minOut,                       // Minimum stablecoin expected
    aggregator,                   // Swap aggregator
    swapData,                     // Swap calldata
    0x0,                          // agg1 unused
    0x                            // data1 unused
)
```

**What it does:**
1. Calls `kodiakHook.adminSwapAndReturnToVault(tokenIn, amount, swapData, aggregator)`
2. Hook swaps token to stablecoin
3. Hook sends stablecoin to vault
4. Vault now has stablecoin for withdrawals

#### Option 2: Swap Stablecoin to Token (Reverse)

**If vault has stablecoin but needs tokens:**
```solidity
// Use SwapStable action
executeReserveAction(
    ReserveAction.SwapStable,     // Action 1
    tokenOut,                     // Token to receive
    0,                            // tokenB unused
    amount,                       // Stablecoin amount
    minOut,                       // Minimum tokens expected
    aggregator,                   // Swap aggregator
    swapData,                     // Swap calldata
    0x0,                          // agg1 unused
    0x                            // data1 unused
)
```

#### Option 3: Exit LP to Token

**If hook has LP but needs to convert to token:**
```solidity
// Use ExitLP action
executeReserveAction(
    ReserveAction.ExitLP,         // Action 4
    tokenOut,                      // Token to receive (e.g., WBTC)
    0,                             // tokenB unused
    lpAmount,                      // LP amount (0 = all)
    minOut,                        // Minimum tokens expected
    aggregator,                    // Swap aggregator
    swapData,                      // Swap calldata
    0x0,                           // agg1 unused
    0x                             // data1 unused
)
```

**What it does:**
1. Calls `kodiakHook.adminLiquidateAll(swapData, aggregator)`
2. Hook burns all LP tokens
3. Hook swaps to desired token
4. Hook sends token to vault

---

## Reserve Vault Token Flow

### Normal Operation (With LP Tokens)

```
User Deposits USDe
    ↓
Vault → Hook → Kodiak Island (LP tokens)
    ↓
User Withdraws
    ↓
Hook burns LP → HONEY (stablecoin) → Vault → User
    ↓
WBTC stays in hook (admin swaps later)
```

### Problem Scenario (Only Raw Tokens)

```
Vault has WBTC (from seedReserveWithToken)
    ↓
User Withdraws
    ↓
_ensureLiquidityAvailable() checks for stablecoin
    ↓
No stablecoin available
    ↓
Tries to liquidate LP tokens
    ↓
No LP tokens in hook
    ↓
❌ Reverts: InsufficientLiquidity()
```

### Solution (Manual Swap)

```
Vault has WBTC
    ↓
Admin calls: executeReserveAction(RescueAndSwap, WBTC, ...)
    ↓
Hook swaps WBTC → USDe
    ↓
Hook sends USDe to vault
    ↓
Vault now has USDe
    ↓
User can withdraw ✅
```

---

## Key Functions

### Automatic Liquidation (During Withdrawal)

**Function:** `_ensureLiquidityAvailable(uint256 amountNeeded)`
- **Called by:** `_withdraw()` automatically
- **What it does:** Liquidates LP tokens if needed
- **Requires:** LP tokens in hook
- **Limitation:** Only works with LP tokens, not raw tokens

### Manual Token Swaps (Admin Only)

**Function:** `executeReserveAction(ReserveAction action, ...)`
- **Role required:** `liquidityManager`
- **Available actions:**
  - `RescueAndSwap` (2): Swap tokens from hook to stablecoin
  - `SwapStable` (1): Swap stablecoin to tokens
  - `ExitLP` (4): Exit LP to tokens
  - `InvestKodiak` (0): Invest tokens into LP
  - `RescueToken` (3): Rescue tokens from hook

---

## Important Notes

### 1. Reserve Vault Design

**Reserve vault is designed to hold LP tokens, not raw tokens:**
- Tokens are typically in the **hook** (as LP tokens)
- Vault itself should have stablecoin for withdrawals
- Raw tokens in vault are unusual (usually from `seedReserveWithToken`)

### 2. LP Token Liquidation

**When LP is liquidated:**
- ✅ HONEY (stablecoin) → sent to vault immediately
- ⚠️ WBTC → stays in hook (not sent to vault)
- Admin must manually swap WBTC later using `RescueAndSwap`

### 3. Slippage Protection

**Automatic liquidation has slippage protection:**
- Minimum 95% of requested amount
- Up to 3 attempts
- Reverts if slippage too high

### 4. Reward Vault Integration

**If LP is staked in reward vault:**
- `_ensureLiquidityAvailable()` automatically withdraws from reward vault first
- Then liquidates LP tokens
- Seamless for user

---

## Example Scenarios

### Scenario 1: Normal Withdrawal (LP Available)

```
1. User withdraws 1000 USDe
2. Vault has 500 USDe, needs 500 more
3. _ensureLiquidityAvailable(1000) called
4. Hook has LP tokens → liquidates → sends 500 USDe to vault
5. Vault now has 1000 USDe → sends to user ✅
```

### Scenario 2: Withdrawal with Only Tokens (No LP)

```
1. User withdraws 1000 USDe
2. Vault has 0 USDe, but has WBTC
3. _ensureLiquidityAvailable(1000) called
4. Hook has no LP tokens → liquidation fails
5. ❌ Reverts: InsufficientLiquidity()

Solution:
1. Admin calls: executeReserveAction(RescueAndSwap, WBTC, 1000, ...)
2. Hook swaps WBTC → USDe → sends to vault
3. User can now withdraw ✅
```

### Scenario 3: Partial LP Available

```
1. User withdraws 1000 USDe
2. Vault has 200 USDe, needs 800 more
3. Hook has LP worth 500 USDe
4. _ensureLiquidityAvailable(1000) called
5. Hook liquidates LP → sends 500 USDe to vault
6. Vault now has 700 USDe, still needs 300
7. Hook has no more LP
8. ❌ Reverts: InsufficientLiquidity()

Solution:
1. Admin must add more LP or swap tokens
2. Or user withdraws smaller amount
```

---

## Summary

### How ALAR Gets Liquidated

**✅ Automatic (Normal Case):**
- User withdraws → `_ensureLiquidityAvailable()` called
- Hook liquidates LP tokens → sends stablecoin to vault
- Vault sends to user
- **Requires:** LP tokens in hook

**❌ Manual (Problem Case):**
- If vault only has raw tokens (not LP)
- Admin must swap tokens first: `executeReserveAction(RescueAndSwap, ...)`
- Then user can withdraw

### Key Takeaway

**Reserve vault is designed to hold LP tokens, not raw tokens.**
- Automatic liquidation only works with LP tokens
- Raw tokens must be manually swapped by admin
- Best practice: Keep assets as LP tokens in hook
