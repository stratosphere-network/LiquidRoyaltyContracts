# Contract Verification Guide for Berascan

> Complete step-by-step guide to verify all vault contracts on Berascan using Foundry

---

## Prerequisites

Before starting, ensure you have:

- `.env` file with `ETHERSCAN_API_KEY` (Berascan API key)
- All contracts deployed
- Your `prod_addresses.md` or deployment addresses handy

```bash
# Your .env should have:
ETHERSCAN_API_KEY=YOUR_API_KEY_HERE
PRIVATE_KEY=YOUR_PRIVATE_KEY_HERE
```

---

## Verification Overview

We'll verify in this order:

1. **Implementation Contracts** (3) - No constructor args, easiest
2. **Hook Contracts** (3) - Have constructor args
3. **Proxy Contracts** (3) - Complex constructor args
4. **Link Proxies** - Manual linking on Berascan

---

## Phase 1: Verify Implementation Contracts

Implementation contracts have no constructor arguments (they use initializers).

### Step 1: Verify Senior Implementation

```bash
cd /home/amschel/stratosphere/LiquidRoyaltyContracts
source .env

forge verify-contract \
  --watch \
  --chain 80094 \
  0xbc65274F211b6E3A8bf112b1519935b31403a84F \
  src/concrete/UnifiedConcreteSeniorVault.sol:UnifiedConcreteSeniorVault \
  --verifier etherscan \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

**Expected Output:**
```
Submitting verification...
Contract successfully verified
```

---

### Step 2: Verify Junior Implementation

```bash
forge verify-contract \
  --watch \
  --chain 80094 \
  0x09788C38906Ed9fE422Bc4AEcA6F24F27924a962 \
  src/concrete/ConcreteJuniorVault.sol:ConcreteJuniorVault \
  --verifier etherscan \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

---

### Step 3: Verify Reserve Implementation

```bash
forge verify-contract \
  --watch \
  --chain 80094 \
  0x7d1005d24E49883d38B375d762dfbfEFbd5d3A5C \
  src/concrete/ConcreteReserveVault.sol:ConcreteReserveVault \
  --verifier etherscan \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

---

## Phase 2: Verify Hook Contracts

Hooks have constructor arguments: `constructor(address vault, address stablecoin, address admin)`

### Step 4: Verify Senior Hook

```bash
forge verify-contract \
  --watch \
  --chain 80094 \
  0xa5Af193E027bE91EFF4CC042cC79E0782F5472AC \
  src/integrations/KodiakVaultHook.sol:KodiakVaultHook \
  --constructor-args $(cast abi-encode "constructor(address,address,address)" 0x78a352318C4aD88ca14f84b200962E797e80D033 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34 $(cast wallet address --private-key $PRIVATE_KEY)) \
  --verifier etherscan \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

**Constructor Args Explained:**
- `0x78a352318C4aD88ca14f84b200962E797e80D033` - Senior Vault address
- `0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34` - USDE stablecoin address
- `$(cast wallet address --private-key $PRIVATE_KEY)` - Your deployer/admin address

---

### Step 5: Verify Junior Hook

```bash
forge verify-contract \
  --watch \
  --chain 80094 \
  0xC6A224385e14dED076D86c69a91E42142698D1f1 \
  src/integrations/KodiakVaultHook.sol:KodiakVaultHook \
  --constructor-args $(cast abi-encode "constructor(address,address,address)" 0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34 $(cast wallet address --private-key $PRIVATE_KEY)) \
  --verifier etherscan \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

**Constructor Args:**
- `0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883` - Junior Vault address
- `0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34` - USDE stablecoin address
- Deployer address (dynamic)

---

### Step 6: Verify Reserve Hook

```bash
forge verify-contract \
  --watch \
  --chain 80094 \
  0xBe01A06f99f8366f8803A61332e110d1235E5f3C \
  src/integrations/KodiakVaultHook.sol:KodiakVaultHook \
  --constructor-args $(cast abi-encode "constructor(address,address,address)" 0x7754272c866892CaD4a414C76f060645bDc27203 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34 $(cast wallet address --private-key $PRIVATE_KEY)) \
  --verifier etherscan \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

**Constructor Args:**
- `0x7754272c866892CaD4a414C76f060645bDc27203` - Reserve Vault address
- `0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34` - USDE stablecoin address
- Deployer address (dynamic)

---

## Phase 3: Verify Proxy Contracts

Proxies have constructor arguments: `constructor(address implementation, bytes initData)`

The `initData` is complex - it's the encoded `initialize()` call with all parameters.

### How to Extract Constructor Args

For each proxy, extract the deployment transaction data:

```bash
# For Senior Proxy
cat broadcast/DeploySeniorProxy.s.sol/80094/run-latest.json | jq '.transactions[] | select(.transactionType == "CREATE") | .transaction.input'

# For Junior Proxy
cat broadcast/DeployJuniorProxy.s.sol/80094/run-latest.json | jq '.transactions[] | select(.transactionType == "CREATE") | .transaction.input'

# For Reserve Proxy
cat broadcast/DeployReserveProxy.s.sol/80094/run-latest.json | jq '.transactions[] | select(.transactionType == "CREATE") | .transaction.input'
```

The output will be a long hex string. The constructor args are at the end (everything after the bytecode).

---

### Step 7: Verify Senior Proxy

**Extract constructor args first:**
```bash
cat broadcast/DeploySeniorProxy.s.sol/80094/run-latest.json | jq '.transactions[] | select(.transactionType == "CREATE") | .transaction.input'
```

**Then verify with the extracted args:**
```bash
forge verify-contract \
  --watch \
  --chain 80094 \
  0x78a352318C4aD88ca14f84b200962E797e80D033 \
  lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy \
  --constructor-args 000000000000000000000000bc65274f211b6e3a8bf112b1519935b31403a84f000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001646635466e0000000000000000000000005d3a1ff2b6bab83b63cd9ad0787074081a52ef3400000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001200000000000000000000000003a0a97dca5e6cacc258490d5ece453412f8e18830000000000000000000000007754272c866892cad4a414c76f060645bdc272030000000000000000000000006fa2149e69dbcbdcf6f16f755e08c10e53c406050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e53656e696f72205472616e6368650000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006736e72555344000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 \
  --verifier etherscan \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

**What's in the constructor args:**
- Implementation address: `0xbc65274f211b6e3a8bf112b1519935b31403a84f`
- Init data containing:
  - USDE address
  - Name: "Senior Tranche" (encoded)
  - Symbol: "snrUSD" (encoded)
  - Junior vault address
  - Reserve vault address
  - Treasury address
  - Initial value: 0

---

### Step 8: Verify Junior Proxy

**Extract constructor args:**
```bash
cat broadcast/DeployJuniorProxy.s.sol/80094/run-latest.json | jq '.transactions[] | select(.transactionType == "CREATE") | .transaction.input'
```

**Verify:**
```bash
forge verify-contract \
  --watch \
  --chain 80094 \
  0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883 \
  lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy \
  --constructor-args 00000000000000000000000009788c38906ed9fe422bc4aeca6f24f27924a9620000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000012475b30be60000000000000000000000005d3a1ff2b6bab83b63cd9ad0787074081a52ef3400000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e4a756e696f72205472616e63686500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000036a6e72000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 \
  --verifier etherscan \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

**What's in the constructor args:**
- Implementation: `0x09788c38906ed9fe422bc4aeca6f24f27924a962`
- Init data with name: "Junior Tranche", symbol: "jnr"

---

### Step 9: Verify Reserve Proxy

**Extract constructor args:**
```bash
cat broadcast/DeployReserveProxy.s.sol/80094/run-latest.json | jq '.transactions[] | select(.transactionType == "CREATE") | .transaction.input'
```

**Verify:**
```bash
forge verify-contract \
  --watch \
  --chain 80094 \
  0x7754272c866892CaD4a414C76f060645bDc27203 \
  lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy \
  --constructor-args 0000000000000000000000007d1005d24e49883d38b375d762dfbfefbd5d3a5c0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000012475b30be60000000000000000000000005d3a1ff2b6bab83b63cd9ad0787074081a52ef3400000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004416c6172000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004616c61720000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 \
  --verifier etherscan \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

**What's in the constructor args:**
- Implementation: `0x7d1005d24e49883d38b375d762dfbfefbd5d3a5c`
- Init data with name: "Alar", symbol: "alar"

---

## Phase 4: Link Proxies to Implementations

After verifying proxies, you need to manually tell Berascan they're proxies.

### Step 10: Link Senior Proxy

1. Go to: `https://berascan.com/address/0x78a352318C4aD88ca14f84b200962E797e80D033`
2. Click on the **"Contract"** tab
3. Look for **"More Options"** dropdown (top right of code section)
4. Click **"More Options"** → Select **"Is this a proxy?"**
5. Enter implementation address: `0xbc65274F211b6E3A8bf112b1519935b31403a84F`
6. Click **"Verify"** or **"Save"**

**Result:** "Read as Proxy" and "Write as Proxy" tabs appear!

---

### Step 11: Link Junior Proxy

1. Go to: `https://berascan.com/address/0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883`
2. Click **"Contract"** tab
3. Click **"More Options"** → **"Is this a proxy?"**
4. Enter implementation: `0x09788C38906Ed9fE422Bc4AEcA6F24F27924a962`
5. Confirm

---

### Step 12: Link Reserve Proxy

1. Go to: `https://berascan.com/address/0x7754272c866892CaD4a414C76f060645bDc27203`
2. Click **"Contract"** tab
3. Click **"More Options"** → **"Is this a proxy?"**
4. Enter implementation: `0x7d1005d24E49883d38B375d762dfbfEFbd5d3A5C`
5. Confirm

---

## Verification Complete!

After all steps, each vault page should show:

### Tabs Available:
- **Code** - Source code of the proxy
- **Read Contract** - Read proxy functions
- **Write Contract** - Write proxy functions
- **Read as Proxy** - Read implementation functions (all vault functions!)
- **Write as Proxy** - Execute implementation functions (deposits, withdrawals, etc!)

---

## Quick Reference Table

| Contract | Address | Type | Verification Command |
|----------|---------|------|---------------------|
| Senior Impl | `0xbc65274F211b6E3A8bf112b1519935b31403a84F` | Implementation | No constructor args |
| Junior Impl | `0x09788C38906Ed9fE422Bc4AEcA6F24F27924a962` | Implementation | No constructor args |
| Reserve Impl | `0x7d1005d24E49883d38B375d762dfbfEFbd5d3A5C` | Implementation | No constructor args |
| Senior Hook | `0xa5Af193E027bE91EFF4CC042cC79E0782F5472AC` | Hook | 3 constructor args |
| Junior Hook | `0xC6A224385e14dED076D86c69a91E42142698D1f1` | Hook | 3 constructor args |
| Reserve Hook | `0xBe01A06f99f8366f8803A61332e110d1235E5f3C` | Hook | 3 constructor args |
| Senior Proxy | `0x78a352318C4aD88ca14f84b200962E797e80D033` | Proxy | Complex init data |
| Junior Proxy | `0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883` | Proxy | Complex init data |
| Reserve Proxy | `0x7754272c866892CaD4a414C76f060645bDc27203` | Proxy | Complex init data |

---

## Troubleshooting

### Issue: "Constructor arguments mismatch"

**Solution:** Make sure you extracted the exact constructor args from the deployment transaction. The args must match exactly what was used during deployment.

```bash
# Re-extract from broadcast logs
cat broadcast/DeploySeniorProxy.s.sol/80094/run-latest.json | jq '.transactions[] | select(.transactionType == "CREATE") | .transaction.input'
```

---

### Issue: "Compilation failed"

**Solution:** Check your `foundry.toml` for compiler version and optimization settings. Berascan must compile with same settings.

```bash
grep -A 5 "\[profile.default\]" foundry.toml
```

---

### Issue: "Already verified"

**Solution:** Contract is already verified! Check Berascan directly. If verification was done by someone else, it's already good to go.

---

### Issue: Proxy tabs not showing

**Solution:** Manually link using "More Options" → "Is this a proxy?" on Berascan. This tells the explorer to show proxy functions.

---

## Benefits of Full Verification

After complete verification, you can:

1. **Read all vault state** from browser
   - Balances, values, ratios
   - Configuration parameters
   - User positions

2. **Execute transactions** from browser
   - Deposits
   - Withdrawals
   - Admin functions (rebase, configure)

3. **User-friendly interface**
   - Connect wallet directly
   - No command line needed
   - Clear function documentation

4. **Transparency**
   - Anyone can verify contract code
   - All functions visible
   - Build trust with users

---

**Verification Complete!** All contracts are now fully verified and interactive on Berascan.

