# Can You Use `investInLP` to Transfer to Multi-Sig? What About Non-USDe Tokens?

## Short Answer

### For USDe (Stablecoin)

**✅ YES - But with requirements:**
- Multi-sig must be **whitelisted as an LP** first
- Requires `liquidityManager` role (not admin directly)
- Only transfers USDe (stablecoin), not other tokens

### For Non-USDe Tokens

**❌ NO - `investInLP` only works for USDe**

**Alternatives:**
- ❌ No direct function exists in Senior/Reserve vaults
- ✅ Junior Vault has `rescueToHook()` for any ERC20 (but only to hook)
- ⚠️ Would need contract upgrade to add generic transfer function

---

## Using `investInLP` for Multi-Sig

### Requirements

1. **Multi-sig must be whitelisted as LP:**
   ```solidity
   // Admin must whitelist multi-sig first
   executeWhitelistAction(WhitelistAction.ADD_LP, multisigAddress)
   ```

2. **Requires `liquidityManager` role:**
   - Function uses `onlyLiquidityManager` modifier
   - Admin can set liquidityManager: `setLiquidityManager(multisigAddress)`
   - Or liquidityManager calls the function

3. **Only transfers USDe:**
   - Function is hardcoded to `_stablecoin`
   - Cannot transfer other tokens

### Step-by-Step Process

**Step 1: Whitelist Multi-Sig**
```bash
# Admin whitelists multi-sig as LP
cast send $VAULT_PROXY \
  "executeWhitelistAction(uint8,address)" \
  0 \  # ADD_LP action
  $MULTISIG_ADDRESS \
  --private-key $ADMIN_KEY \
  --rpc-url $RPC_URL
```

**Step 2: Transfer USDe**
```bash
# LiquidityManager transfers USDe to multi-sig
cast send $VAULT_PROXY \
  "investInLP(address,uint256)" \
  $MULTISIG_ADDRESS \
  1000000000000000000000 \  # 1000 USDe
  --private-key $LIQUIDITY_MANAGER_KEY \
  --rpc-url $RPC_URL
```

### Security Considerations

**⚠️ Important:**
- Multi-sig becomes a "whitelisted LP" - this is a security consideration
- Anyone with `liquidityManager` role can send funds to whitelisted LPs
- Make sure whitelisting is intentional and secure

---

## For Non-USDe Tokens

### Current State: ❌ No Direct Function

**`investInLP` is hardcoded:**
```solidity
function investInLP(address lp, uint256 amount) external onlyLiquidityManager {
    // ...
    _stablecoin.safeTransfer(lp, amount);  // ← Hardcoded to _stablecoin!
    // ...
}
```

**It cannot transfer other tokens.**

### Available Options

#### Option 1: Junior Vault - `rescueToHook()` (Any ERC20)

**Function:**
```solidity
function rescueToHook(address t) external onlyAdmin {
    IERC20(t).safeTransfer(address(kodiakHook), IERC20(t).balanceOf(address(this)));
}
```

**Limitations:**
- ✅ Works for any ERC20 token
- ❌ Only transfers to hook (not to multi-sig directly)
- ❌ Only exists in Junior Vault

**Workflow:**
```
1. Transfer token to hook: rescueToHook(tokenAddress)
2. Hook admin swaps/rescues: adminSwapAndReturnToVault() or adminRescueTokens()
3. Multi-sig receives from hook (if hook admin is multi-sig)
```

#### Option 2: Contract Upgrade (Add Generic Function)

**Add a new function:**
```solidity
/// @notice Transfer any ERC20 token to specified address (admin only)
function transferToken(address token, address to, uint256 amount) external onlyAdmin {
    if (token == address(0) || to == address(0)) revert ZeroAddress();
    if (amount == 0) revert InvalidAmount();
    
    IERC20(token).safeTransfer(to, amount);
    emit TokenTransferred(token, to, amount);
}
```

**This would require:**
1. Contract upgrade
2. Deploy new implementation
3. Upgrade proxy

#### Option 3: Emergency Withdraw (Senior Vault Only)

**Function:**
```solidity
function emergencyWithdraw(uint256 amount) external onlyAdmin {
    if (!paused()) revert NotPaused();
    if (amount == 0) revert InvalidAmount();
    
    _stablecoin.safeTransfer(_treasury, amount);  // ← Only to treasury, only USDe
    emit EmergencyWithdraw(_treasury, amount);
}
```

**Limitations:**
- ❌ Only works when paused
- ❌ Only transfers to treasury (not multi-sig)
- ❌ Only USDe (stablecoin)

---

## Comparison Table

| Function | Token Type | Destination | Role Required | Vault |
|----------|------------|-------------|---------------|-------|
| `investInLP()` | USDe only | Whitelisted LP | `liquidityManager` | All |
| `rescueToHook()` | Any ERC20 | Hook only | `admin` | Junior only |
| `emergencyWithdraw()` | USDe only | Treasury only | `admin` | Senior only |
| `transferToken()` (proposed) | Any ERC20 | Any address | `admin` | None (needs upgrade) |

---

## Recommended Approach

### For USDe to Multi-Sig

**✅ Use `investInLP()`:**
1. Whitelist multi-sig as LP (one-time)
2. Set multi-sig as liquidityManager (or have liquidityManager call)
3. Call `investInLP(multisigAddress, amount)`

**Pros:**
- ✅ Simple, direct transfer
- ✅ No contract upgrade needed
- ✅ Works immediately

**Cons:**
- ⚠️ Multi-sig becomes "whitelisted LP" (security consideration)
- ⚠️ Requires liquidityManager role

### For Non-USDe Tokens

**Option A: Use Junior Vault's `rescueToHook()` (if token is in Junior vault)**
```
1. rescueToHook(tokenAddress) → sends to hook
2. Hook admin (multi-sig) calls adminRescueTokens() → sends to vault
3. Then use investInLP() to send to multi-sig
```

**Option B: Contract Upgrade (Recommended for flexibility)**
```
1. Add transferToken() function
2. Upgrade contract
3. Use transferToken(token, multisig, amount)
```

**Option C: Accept Limitation**
- Only use `investInLP` for USDe
- For other tokens, swap to USDe first, then transfer

---

## Security Considerations

### Whitelisting Multi-Sig as LP

**Risks:**
- ⚠️ Any `liquidityManager` can send funds to whitelisted LPs
- ⚠️ Multi-sig becomes a "trusted LP" address
- ⚠️ If liquidityManager is compromised, attacker can drain to multi-sig

**Mitigations:**
- ✅ Only whitelist if absolutely necessary
- ✅ Use multi-sig for liquidityManager role itself
- ✅ Monitor all `investInLP` calls
- ✅ Consider time-locked or rate-limited transfers

### Alternative: Use Multi-Sig as LiquidityManager

**Instead of whitelisting multi-sig as LP:**
- Set multi-sig as `liquidityManager`
- Multi-sig can call `investInLP()` to send to itself
- But still requires whitelisting destination

**Better approach:**
- Set multi-sig as `liquidityManager`
- Multi-sig calls `investInLP(anotherAddress, amount)`
- But `anotherAddress` must still be whitelisted

---

## Code Example: Adding Generic Transfer Function

If you want to add a generic transfer function via upgrade:

```solidity
/// @notice Transfer any ERC20 token to specified address
/// @dev Admin-only function for emergency transfers
/// @param token Address of ERC20 token to transfer
/// @param to Recipient address
/// @param amount Amount to transfer (0 = transfer all)
function transferToken(address token, address to, uint256 amount) external onlyAdmin nonReentrant {
    if (token == address(0) || to == address(0)) revert ZeroAddress();
    
    IERC20 tokenContract = IERC20(token);
    uint256 balance = tokenContract.balanceOf(address(this));
    
    if (balance == 0) revert InvalidAmount();
    
    uint256 transferAmount = amount == 0 ? balance : amount;
    require(transferAmount <= balance, "insufficient balance");
    
    tokenContract.safeTransfer(to, transferAmount);
    emit TokenTransferred(token, to, transferAmount);
}

event TokenTransferred(address indexed token, address indexed to, uint256 amount);
```

**This would allow:**
- ✅ Transfer any ERC20 token
- ✅ To any address (including multi-sig)
- ✅ Admin-only (secure)
- ✅ Supports partial or full transfers

---

## Summary

### For USDe to Multi-Sig

**✅ YES - Use `investInLP()`:**
- Whitelist multi-sig as LP first
- Requires liquidityManager role
- Simple and direct

### For Non-USDe Tokens

**❌ NO - `investInLP` doesn't work**

**Options:**
1. **Junior Vault**: Use `rescueToHook()` (but only to hook)
2. **Contract Upgrade**: Add `transferToken()` function
3. **Workaround**: Swap to USDe first, then use `investInLP()`

**Recommendation:** Add `transferToken()` function via upgrade for maximum flexibility and security.
