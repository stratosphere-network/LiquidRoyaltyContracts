# Contract ABIs

JSON ABIs for all deployed contracts in the Liquid Royalty Protocol.

---

## Main Vault Contracts

### UnifiedConcreteSeniorVault.json
**Address**: `0x65691bd1972e906459954306aDa0f622a47d4744`

The Senior Vault contract (snrHONEY). Lowest risk tranche with stable returns.

**Key Functions**:
- `deposit(uint256 assets, address receiver)` - Deposit HONEY to receive snrHONEY shares
- `withdraw(uint256 assets, address receiver, address owner)` - Withdraw HONEY
- `totalAssets()` - Get total vault assets including LP positions
- `getCalculatedVaultValue()` - Get vault value with LP positions valued by oracle
- `deployToKodiak(...)` - Deploy funds to Kodiak LP (admin only)

---

### ConcreteJuniorVault.json
**Address**: `0x3A1b3b300dEE06Caf0b691F1771d1Aa26d70B067`

The Junior Vault contract (jTRN). Higher risk, higher yield tranche.

**Key Functions**:
- `deposit(uint256 assets, address receiver)` - Deposit HONEY to receive jTRN shares
- `withdraw(uint256 assets, address receiver, address owner)` - Withdraw HONEY
- `totalAssets()` - Get total vault assets
- `getLPHoldings()` - Get all LP token holdings
- `deployToKodiak(...)` - Deploy funds to Kodiak LP (admin only)

---

### ConcreteReserveVault.json
**Address**: `0x2C75291479788C568A6750185CaDedf43aBFC553`

The Reserve Vault contract (resUSD). Backstop vault for the protocol.

**Key Functions**:
- `deposit(uint256 assets, address receiver)` - Deposit HONEY to receive resUSD shares
- `withdraw(uint256 assets, address receiver, address owner)` - Withdraw HONEY
- `totalAssets()` - Get total vault assets
- `deployToKodiak(...)` - Deploy funds to Kodiak LP (admin only)

---

## Integration Contracts

### KodiakVaultHook.json
**Addresses**:
- Senior Hook: `0xA0c26949319Fc893cc0b81A4E546EDbca51aAc97`
- Junior Hook: `0x59c338342F27c6a2B7dA08aF0f1D05d2Ae18CC38`
- Reserve Hook: `0x0F9DC3BC9A12315E7D99C768A7288a1D3356b539`

Handles Kodiak Finance integration for LP deployment and withdrawal.

**Key Functions**:
- `vault()` - Get associated vault address
- `router()` - Get Kodiak Island Router
- `island()` - Get Kodiak Island (LP token)
- `setRouter(address)` - Set Kodiak router (admin only)
- `setIsland(address)` - Set Kodiak island (admin only)

---

## Utility Contracts

### MockERC20.json
Mock ERC20 token for testing.

**Key Functions**:
- `mint(address to, uint256 amount)` - Mint tokens (anyone can call)
- `burn(address from, uint256 amount)` - Burn tokens (anyone can call)
- Standard ERC20 functions (transfer, approve, etc.)

---

## Usage Examples

### JavaScript/TypeScript (ethers.js v6)
```javascript
import { ethers } from 'ethers';
import SeniorVaultABI from './abi/UnifiedConcreteSeniorVault.json';

const provider = new ethers.JsonRpcProvider('https://artio.rpc.berachain.com');
const seniorVault = new ethers.Contract(
  '0x65691bd1972e906459954306aDa0f622a47d4744',
  SeniorVaultABI,
  provider
);

// Read total assets
const totalAssets = await seniorVault.totalAssets();
console.log('Total Assets:', ethers.formatEther(totalAssets));

// Deposit (with signer)
const signer = new ethers.Wallet(privateKey, provider);
const seniorVaultWithSigner = seniorVault.connect(signer);
const tx = await seniorVaultWithSigner.deposit(
  ethers.parseEther('100'), // 100 HONEY
  await signer.getAddress()
);
await tx.wait();
```

### Python (web3.py)
```python
from web3 import Web3
import json

w3 = Web3(Web3.HTTPProvider('https://artio.rpc.berachain.com'))

with open('abi/UnifiedConcreteSeniorVault.json') as f:
    abi = json.load(f)

senior_vault = w3.eth.contract(
    address='0x65691bd1972e906459954306aDa0f622a47d4744',
    abi=abi
)

# Read total assets
total_assets = senior_vault.functions.totalAssets().call()
print(f'Total Assets: {w3.from_wei(total_assets, "ether")} HONEY')
```

### Foundry (Solidity)
```solidity
import {UnifiedConcreteSeniorVault} from "./path/to/contract";

UnifiedConcreteSeniorVault seniorVault = UnifiedConcreteSeniorVault(0x65691bd1972e906459954306aDa0f622a47d4744);
uint256 totalAssets = seniorVault.totalAssets();
```

---

## Network Information

**Network**: Berachain Artio Testnet  
**Chain ID**: 80094  
**RPC URL**: https://artio.rpc.berachain.com  
**Stablecoin**: HONEY (`0xFCBD14DC51f0A4d49d5E53C2E0950e0bC26d0Dce`)

---

## Common Interfaces

All vaults implement:
- **ERC4626**: Standard tokenized vault interface
- **ERC20**: Standard token interface (for vault shares)
- **Pausable**: Emergency pause functionality
- **Admin Controlled**: Admin-only functions for management

---

## Regenerating ABIs

If you need to regenerate the ABIs after contract changes:

```bash
# Build contracts
forge build

# Extract ABIs
jq '.abi' out/UnifiedConcreteSeniorVault.sol/UnifiedConcreteSeniorVault.json > abi/UnifiedConcreteSeniorVault.json
jq '.abi' out/ConcreteJuniorVault.sol/ConcreteJuniorVault.json > abi/ConcreteJuniorVault.json
jq '.abi' out/ConcreteReserveVault.sol/ConcreteReserveVault.json > abi/ConcreteReserveVault.json
jq '.abi' out/KodiakVaultHook.sol/KodiakVaultHook.json > abi/KodiakVaultHook.json
```

---

For deployment information, see `DEPLOYMENT_GUIDE.md`

