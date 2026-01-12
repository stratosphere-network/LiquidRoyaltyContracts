# Can Admin Transfer Tokens to Hook?

## Short Answer

**✅ YES - But it depends on which vault:**

- ✅ **Junior Vault**: Has `rescueToHook(address)` function
- ⚠️ **Senior Vault**: No direct function, but can use `deployToKodiak()`
- ⚠️ **Reserve Vault**: No direct function, but can use action functions

---

## Junior Vault: `rescueToHook()`

### Function Signature

```solidity
function rescueToHook(address t) external onlyAdmin {
    IERC20(t).safeTransfer(address(kodiakHook), IERC20(t).balanceOf(address(this)));
}
```

### How It Works

- ✅ **Only admin** can call this
- ✅ Transfers **all tokens** of type `t` from vault to hook
- ✅ Uses `safeTransfer` for safety
- ✅ Comment says: "Send tokens to hook (then use hook's adminSwapAndReturnToVault)"

### Usage Example

```bash
# Transfer all USDC tokens from Junior vault to its hook
cast send $JUNIOR_PROXY \
  "rescueToHook(address)" \
  0xUSDC_ADDRESS \
  --private-key $ADMIN_KEY \
  --rpc-url $RPC_URL
```

### Typical Workflow

1. Admin calls `rescueToHook(tokenAddress)` - transfers tokens to hook
2. Admin calls hook's `adminSwapAndReturnToVault()` - swaps tokens to stablecoin and returns to vault
3. Or use hook's other functions to process the tokens

---

## Senior Vault: `deployToKodiak()`

### Function Signature

```solidity
function deployToKodiak(
    uint256 amount, 
    uint256 minLPTokens, 
    uint256 expectedIdle, 
    uint256 maxDeviation,
    address agg0, 
    bytes calldata data0, 
    address agg1, 
    bytes calldata data1
) external onlyLiquidityManager nonReentrant
```

### How It Works

- ⚠️ Requires `liquidityManager` role (not admin directly)
- ✅ Transfers stablecoin to hook
- ✅ Calls `hook.onAfterDepositWithSwaps()` to invest
- ⚠️ Only works for stablecoin (the vault's asset token)

### Usage Example

```bash
# Deploy 1000 stablecoins to hook
cast send $SENIOR_PROXY \
  "deployToKodiak(uint256,uint256,uint256,uint256,address,bytes,address,bytes)" \
  1000000000000000000000 \
  0 \
  0 \
  0 \
  0x0000000000000000000000000000000000000000 \
  0x \
  0x0000000000000000000000000000000000000000 \
  0x \
  --private-key $LIQUIDITY_MANAGER_KEY \
  --rpc-url $RPC_URL
```

---

## Reserve Vault: `executeReserveAction()`

### Function Signature

```solidity
function executeReserveAction(
    ReserveAction action,
    address tokenA,
    address tokenB,
    uint256 amount,
    uint256 minOut,
    address agg0,
    bytes calldata data0,
    address agg1,
    bytes calldata data1
) external onlyLiquidityManager nonReentrant
```

### Available Actions

**For transferring tokens to hook:**
- `InvestKodiak`: Invests stablecoin via hook (similar to deployToKodiak)

**Note:** Reserve vault has functions to rescue tokens FROM hook, not TO hook.

---

## Direct ERC20 Transfer (Not Recommended)

### Manual Transfer

You could theoretically use standard ERC20 transfer:

```solidity
// In vault contract
IERC20(token).safeTransfer(address(kodiakHook), amount);
```

**But:**
- ❌ No dedicated admin function for this (except Junior's `rescueToHook`)
- ❌ Would require contract modification or upgrade
- ⚠️ Hook may not be designed to accept arbitrary tokens

---

## Hook Functions to Use After Transfer

### After Sending Tokens to Hook

Once tokens are in the hook, you can use hook's admin functions:

#### 1. `adminSwapAndReturnToVault()`

```solidity
function adminSwapAndReturnToVault(
    address tokenIn,
    uint256 amountIn,
    bytes calldata swapData,
    address aggregator
) external onlyRole(DEFAULT_ADMIN_ROLE)
```

- Swaps tokens to stablecoin
- Returns stablecoin to vault
- Requires swap calldata from aggregator

#### 2. `adminRescueTokens()`

```solidity
function adminRescueTokens(
    address token,
    uint256 amount
) external onlyRole(ADMIN_ROLE)
```

- Rescues tokens FROM hook TO vault
- Opposite direction (hook → vault)

---

## Comparison Table

| Vault | Function | Token Type | Role Required | Notes |
|-------|----------|------------|---------------|-------|
| **Junior** | `rescueToHook(address)` | Any ERC20 | `admin` | ✅ Direct function, transfers all tokens |
| **Senior** | `deployToKodiak(...)` | Stablecoin only | `liquidityManager` | ⚠️ Only for stablecoin, invests immediately |
| **Reserve** | `executeReserveAction(InvestKodiak, ...)` | Stablecoin only | `liquidityManager` | ⚠️ Only for stablecoin, invests immediately |
| **Any** | Direct ERC20 transfer | Any ERC20 | N/A | ❌ Would require contract modification |

---

## Recommended Approach by Vault Type

### For Junior Vault

**✅ Use `rescueToHook()`:**
```bash
# Transfer tokens to hook
cast send $JUNIOR_PROXY "rescueToHook(address)" $TOKEN_ADDRESS --private-key $ADMIN_KEY

# Then swap in hook (if needed)
cast send $HOOK_ADDRESS "adminSwapAndReturnToVault(...)" --private-key $HOOK_ADMIN_KEY
```

### For Senior Vault

**⚠️ Use `deployToKodiak()` (if stablecoin):**
```bash
cast send $SENIOR_PROXY "deployToKodiak(...)" --private-key $LIQUIDITY_MANAGER_KEY
```

**OR: Add `rescueToHook()` function via upgrade** (if you need it)

### For Reserve Vault

**⚠️ Use `executeReserveAction(InvestKodiak, ...)` (if stablecoin):**
```bash
cast send $RESERVE_PROXY "executeReserveAction(...)" --private-key $LIQUIDITY_MANAGER_KEY
```

**OR: Add `rescueToHook()` function via upgrade** (if you need it)

---

## Adding `rescueToHook()` to Other Vaults

If you need this functionality in Senior or Reserve vaults, you can add it:

### Example Implementation

```solidity
/// @notice Send tokens to hook (then use hook's adminSwapAndReturnToVault)
function rescueToHook(address t) external onlyAdmin {
    if (address(kodiakHook) == address(0)) revert KodiakHookNotSet();
    IERC20(t).safeTransfer(address(kodiakHook), IERC20(t).balanceOf(address(this)));
}
```

**This would require:**
1. Contract upgrade
2. Deploy new implementation
3. Upgrade proxy to new implementation

---

## Security Considerations

### When Using `rescueToHook()`

1. ✅ **Only admin** can call (protected by `onlyAdmin`)
2. ✅ Uses `safeTransfer` (handles non-standard ERC20)
3. ⚠️ Transfers **ALL tokens** of that type (not partial)
4. ⚠️ Hook must be able to handle the token type
5. ⚠️ Make sure hook has proper admin functions to process tokens

### Best Practices

1. **Verify hook address is correct** before calling
2. **Check token balance** before transfer
3. **Have a plan** for processing tokens in hook (swap, etc.)
4. **Test on testnet** first if possible

---

## Summary

**✅ YES, admin can transfer tokens to hook:**

- **Junior Vault**: `rescueToHook(address token)` - ✅ Direct function
- **Senior Vault**: `deployToKodiak(...)` - ⚠️ Only for stablecoin, requires liquidityManager
- **Reserve Vault**: `executeReserveAction(...)` - ⚠️ Only for stablecoin, requires liquidityManager

**If you need `rescueToHook()` in Senior or Reserve:**
- Requires contract upgrade
- Can copy implementation from Junior Vault
- Relatively simple to add

**Typical use case:**
- Transfer stuck/wrong tokens to hook
- Use hook's `adminSwapAndReturnToVault()` to convert to stablecoin
- Stablecoin returns to vault automatically
