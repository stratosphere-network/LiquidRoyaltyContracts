# Deployment Scripts

Modular deployment scripts for the Liquid Royalty Protocol.

## Prerequisites

1. **Install Foundry** (if not already installed):
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Install dependencies**:
   ```bash
   forge install
   ```

3. **Install `jq`** (for JSON parsing):
   ```bash
   # Ubuntu/Debian
   sudo apt install jq
   
   # macOS
   brew install jq
   ```

4. **Install `bc`** (for calculations):
   ```bash
   # Ubuntu/Debian
   sudo apt install bc
   
   # macOS (usually pre-installed)
   ```

## Setup

1. **Create a `.env` file in the project root**:

```bash
# Copy the template
cp .env.example .env

# Edit with your values
nano .env
```

Your `.env` should contain:

```bash
PRIVATE_KEY=0xyour_private_key_here
RPC_URL=https://artio.rpc.berachain.com
```

2. **Get testnet BERA** (if deploying to testnet):
   - Visit: https://artio.faucet.berachain.com
   - Connect your wallet
   - Request testnet BERA

## Scripts

### 1. Deploy Tokens

**File**: `1_deploy_tokens.sh`

Deploys 2 ERC20 tokens with custom parameters.

**Configure** (edit the script):
```bash
# Token 1 Configuration
TOKEN1_NAME="USDE"
TOKEN1_SYMBOL="USDE"
TOKEN1_DECIMALS=6
TOKEN1_MINT_AMOUNT="10000000"  # Will mint 10M USDE

# Token 2 Configuration
TOKEN2_NAME="SAIL"
TOKEN2_SYMBOL="SAIL"
TOKEN2_DECIMALS=18
TOKEN2_MINT_AMOUNT="1000000"   # Will mint 1M SAIL
```

**Run**:
```bash
./scripts/1_deploy_tokens.sh
```

**Output**:
- Deploys both tokens
- Mints specified amounts to your address
- Saves addresses to `deployed_tokens.txt`

**Example Output**:
```
====================================
✅ DEPLOYMENT COMPLETE!
====================================

📋 DEPLOYED ADDRESSES:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
USDE (USDE): 0x5FbDB2315678afecb367f032d93F642f64180aa3
SAIL (SAIL): 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💰 YOUR BALANCES:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
10000000 USDE
1000000 SAIL
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

### 2. Deploy Vaults (Coming Soon)

**File**: `2_deploy_vaults.sh`

Will deploy:
- Senior Vault (snrUSD) - Implementation + Proxy
- Junior Vault (jnrUSD) - Implementation + Proxy
- Reserve Vault (resUSD) - Implementation + Proxy

---

### 3. Configure Oracle (Coming Soon)

**File**: `3_configure_oracle.sh`

Will configure:
- Set Kodiak Island address
- Configure oracle parameters
- Enable automatic vault value calculation

---

### 4. Deploy to Kodiak (Coming Soon)

**File**: `4_deploy_to_kodiak.sh`

Will:
- Deploy Kodiak hook
- Connect hook to vaults
- Deploy funds to Kodiak Island

---

## Usage Flow

**Full Deployment**:

```bash
# Step 1: Deploy tokens
./scripts/1_deploy_tokens.sh

# Step 2: Create pool on Kodiak/Uniswap with the token addresses
# (Manual step - use the addresses from deployed_tokens.txt)

# Step 3: Deploy vaults (coming soon)
./scripts/2_deploy_vaults.sh

# Step 4: Configure oracle (coming soon)
./scripts/3_configure_oracle.sh

# Step 5: Deploy to Kodiak (coming soon)
./scripts/4_deploy_to_kodiak.sh
```

---

## Troubleshooting

### "Command not found: jq"
Install jq:
```bash
sudo apt install jq  # Ubuntu/Debian
brew install jq      # macOS
```

### "Command not found: bc"
Install bc:
```bash
sudo apt install bc  # Ubuntu/Debian
```

### "Insufficient balance"
Get testnet BERA from the faucet:
https://artio.faucet.berachain.com

### "Transaction failed"
1. Check your balance: `cast balance YOUR_ADDRESS --rpc-url $RPC_URL`
2. Check gas prices: `cast gas-price --rpc-url $RPC_URL`
3. Try again with higher gas: Add `--gas-limit 1000000` to cast commands

### "RPC error"
1. Check if RPC is working: `curl -X POST $RPC_URL -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'`
2. Try a different RPC endpoint
3. Check your internet connection

---

## Verify Deployments

**Check token balance**:
```bash
source deployed_tokens.txt
cast call $TOKEN1_ADDRESS "balanceOf(address)(uint256)" YOUR_ADDRESS --rpc-url $RPC_URL
```

**Check token info**:
```bash
cast call $TOKEN1_ADDRESS "name()(string)" --rpc-url $RPC_URL
cast call $TOKEN1_ADDRESS "symbol()(string)" --rpc-url $RPC_URL
cast call $TOKEN1_ADDRESS "decimals()(uint8)" --rpc-url $RPC_URL
```

**View on block explorer**:
- Berachain Artio: https://artio.beratrail.io/address/TOKEN_ADDRESS

---

## Tips

1. **Save gas**: Test on local Anvil first before deploying to testnet
   ```bash
   # Terminal 1: Start Anvil
   anvil
   
   # Terminal 2: Deploy (update RPC_URL in .env to http://localhost:8545)
   ./scripts/1_deploy_tokens.sh
   ```

2. **Reuse addresses**: The `deployed_tokens.txt` file can be sourced in other scripts:
   ```bash
   source deployed_tokens.txt
   echo $TOKEN1_ADDRESS
   ```

3. **Customize tokens**: Edit the configuration section at the top of `1_deploy_tokens.sh` before running

4. **Multiple deployments**: The script overwrites `deployed_tokens.txt`, so back it up if needed:
   ```bash
   cp deployed_tokens.txt deployed_tokens_backup.txt
   ```

---

## Security Notes

⚠️ **NEVER commit your `.env` file to git!**

The `.env` file contains your private key. Make sure `.env` is in `.gitignore`:

```bash
# Check if .env is ignored
git check-ignore .env

# If not, add it to .gitignore
echo ".env" >> .gitignore
```

⚠️ **Use a test wallet for testnets!**

Don't use your mainnet wallet private key for testnet deployments.

---

## Need Help?

- Check the main README.md for more details
- Review the DEPLOYMENT_GUIDE.md for production deployments
- Open an issue on GitHub

---

**Last Updated**: November 12, 2025

