# Contract ABIs

This directory contains the JSON ABIs (Application Binary Interfaces) for all smart contracts in the Senior Tranche Protocol.

## 📦 Main Contracts (Deploy These)

### Vault Contracts
- **`UnifiedConcreteSeniorVault.json`** - Senior vault implementation (rebasing, lowest risk)
- **`ConcreteJuniorVault.json`** - Junior vault implementation (non-rebasing, medium risk)
- **`ConcreteReserveVault.json`** - Reserve vault implementation (non-rebasing, highest risk)

### Integration Contracts
- **`KodiakVaultHook.json`** - Kodiak Island LP management hook

### Testing
- **`MockERC20.json`** - Mock ERC20 token for testing

## 🔌 Interfaces (For Integration)

### Vault Interfaces
- **`IVault.json`** - Base vault interface (common functions)
- **`ISeniorVault.json`** - Senior vault specific interface
- **`IJuniorVault.json`** - Junior vault specific interface
- **`IReserveVault.json`** - Reserve vault specific interface

### External Integrations
- **`IKodiakVaultHook.json`** - Kodiak hook interface
- **`IKodiakIsland.json`** - Kodiak Island pool interface
- **`IKodiakIslandRouter.json`** - Kodiak router interface

## 📚 Abstract Contracts (Reference)

- **`BaseVault.json`** - Base vault abstract contract (ERC4626 compliant)
- **`UnifiedSeniorVault.json`** - Senior vault abstract contract
- **`JuniorVault.json`** - Junior vault abstract contract
- **`ReserveVault.json`** - Reserve vault abstract contract

## 🚀 Usage Examples

### Using with ethers.js (JavaScript/TypeScript)

```javascript
import { ethers } from 'ethers';
import seniorABI from './abi/UnifiedConcreteSeniorVault.json';

const provider = new ethers.providers.JsonRpcProvider('https://rpc.berachain.com');
const seniorVault = new ethers.Contract(
  '0x65691bd1972e906459954306aDa0f622a47d4744', // Senior vault address
  seniorABI,
  provider
);

// Read functions
const totalSupply = await seniorVault.totalSupply();
const backingRatio = await seniorVault.backingRatio();
const vaultValue = await seniorVault.vaultValue();

// Write functions (requires signer)
const signer = provider.getSigner();
const seniorVaultWithSigner = seniorVault.connect(signer);
const tx = await seniorVaultWithSigner.deposit(
  ethers.utils.parseEther('1000'), // 1000 HONEY
  userAddress
);
await tx.wait();
```

### Using with viem (TypeScript)

```typescript
import { createPublicClient, http } from 'viem';
import { berachain } from 'viem/chains';
import seniorABI from './abi/UnifiedConcreteSeniorVault.json';

const client = createPublicClient({
  chain: berachain,
  transport: http('https://rpc.berachain.com')
});

// Read functions
const backingRatio = await client.readContract({
  address: '0x65691bd1972e906459954306aDa0f622a47d4744',
  abi: seniorABI,
  functionName: 'backingRatio',
});
```

### Using with web3.py (Python)

```python
from web3 import Web3
import json

# Connect to Berachain
w3 = Web3(Web3.HTTPProvider('https://rpc.berachain.com'))

# Load ABI
with open('abi/UnifiedConcreteSeniorVault.json') as f:
    senior_abi = json.load(f)

# Create contract instance
senior_vault = w3.eth.contract(
    address='0x65691bd1972e906459954306aDa0f622a47d4744',
    abi=senior_abi
)

# Read functions
total_supply = senior_vault.functions.totalSupply().call()
backing_ratio = senior_vault.functions.backingRatio().call()

# Write functions
tx = senior_vault.functions.deposit(
    w3.to_wei(1000, 'ether'),  # 1000 HONEY
    user_address
).transact({'from': user_address})
```

### Using with Foundry Cast (CLI)

```bash
# Read contract
cast call 0x65691bd1972e906459954306aDa0f622a47d4744 \
  "backingRatio()(uint256)" \
  --rpc-url https://rpc.berachain.com

# Write to contract
cast send 0x65691bd1972e906459954306aDa0f622a47d4744 \
  "deposit(uint256,address)" \
  1000000000000000000000 \  # 1000 HONEY
  $USER_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url https://rpc.berachain.com
```

## 📋 Contract Addresses (Berachain Artio)

### Vaults
```
Senior:  0x65691bd1972e906459954306aDa0f622a47d4744
Junior:  0x3A1b3b300dEE06Caf0b691F1771d1Aa26d70B067
Reserve: 0x2C75291479788C568A6750185CaDedf43aBFC553
```

### Hooks
```
Senior Hook:  0x949Ba11180BDF15560D7Eba9864c929FA4a32bA2
Junior Hook:  0x9e7753A490628C65219c467A792b708A89209168
Reserve Hook: 0x88FA91FCF1771AC3C07b3f6684239A4A0B234299
```

### Tokens
```
HONEY (Stablecoin): 0xFCBD14DC51f0A4d49d5E53C2E0950e0bC26d0Dce
WBTC:               0x0555E30da8f98308EdB960aa94C0Db47230d2B9c
Kodiak Island:      0xf6b16E73d3b0e2784AAe8C4cd06099BE65d092Bf
```

## 🔄 Regenerating ABIs

To regenerate all ABIs after contract changes:

```bash
# Compile contracts
forge build

# Extract ABIs
./extract_abis.sh
./extract_more_abis.sh
```

Or manually:

```bash
# Extract ABI for a specific contract
jq '.abi' out/ContractName.sol/ContractName.json > abi/ContractName.json
```

## 📊 ABI Size Reference

| Contract | ABI Size | Functions | Events |
|----------|----------|-----------|--------|
| Senior | ~40KB | 60+ | 20+ |
| Junior | ~39KB | 50+ | 15+ |
| Reserve | ~40KB | 50+ | 15+ |
| Hook | ~16KB | 25+ | 10+ |

## 🔗 Related Documentation

- [Contract Architecture](../CONTRACT_ARCHITECTURE.md) - System design and flows
- [Deployment Guide](../DEPLOYMENT_GUIDE.md) - How to deploy contracts
- [Math Specification](../math_spec.md) - Protocol mathematics
- [Main README](../Readme.md) - Project overview

## 📝 Notes

- All ABIs are automatically generated from compiled Solidity contracts
- ABIs include all public/external functions, events, and errors
- ABIs are compatible with all standard Web3 libraries
- Abstract contract ABIs are included for reference but cannot be deployed directly

## 🆘 Support

For issues or questions about using these ABIs:
1. Check the [Contract Architecture](../CONTRACT_ARCHITECTURE.md) documentation
2. Review the contract source code in `/src`
3. See deployment examples in `/script`

