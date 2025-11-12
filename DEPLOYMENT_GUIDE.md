# Liquid Royalty Protocol - Deployment & Go-Live Guide

> **Complete guide for deploying and launching the protocol to production**

**Version**: 3.0.0 (On-Chain Oracle & Kodiak Integration)  
**Last Updated**: November 12, 2025  
**Target Network**: Berachain Mainnet (initially), Polygon (optional)

---

## Table of Contents

1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [Environment Setup](#environment-setup)
3. [Testnet Deployment](#testnet-deployment)
4. [Oracle Configuration](#oracle-configuration)
5. [Kodiak Integration Setup](#kodiak-integration-setup)
6. [Security Verification](#security-verification)
7. [Mainnet Deployment](#mainnet-deployment)
8. [Post-Deployment Configuration](#post-deployment-configuration)
9. [Go-Live Checklist](#go-live-checklist)
10. [Monitoring & Maintenance](#monitoring--maintenance)
11. [Emergency Procedures](#emergency-procedures)
12. [Upgrade Procedures](#upgrade-procedures)

---

## Pre-Deployment Checklist

### 1. Code Audit & Security

- [ ] **Smart contract audit completed** (by reputable firm)
- [ ] All critical/high severity issues resolved
- [ ] Medium/low severity issues addressed or documented
- [ ] Economic model reviewed by economists/DeFi experts
- [ ] Oracle system validated (LP price calculation accuracy)
- [ ] Access control mechanisms reviewed
- [ ] Upgrade mechanisms tested
- [ ] Re-entrancy protections verified

### 2. Testing Completion

- [ ] All unit tests passing (180+ tests)
- [ ] Integration tests passing
- [ ] E2E tests passing
- [ ] Gas optimization completed
- [ ] Fuzz testing performed (256+ runs per test)
- [ ] Edge case scenarios tested:
  - [ ] Zero liquidity
  - [ ] Extreme price ratios
  - [ ] Large numbers (overflow protection)
  - [ ] Tiny numbers (precision protection)
  - [ ] Multiple rebase cycles
  - [ ] Backstop scenarios
  - [ ] Spillover scenarios

### 3. Documentation

- [ ] README.md updated with latest features
- [ ] Math spec (`math_spec.md`) accurate
- [ ] API documentation complete
- [ ] User guides written
- [ ] Admin playbooks created
- [ ] Emergency procedures documented

### 4. Infrastructure

- [ ] RPC endpoints configured (primary + backups)
- [ ] Monitoring systems set up (Grafana/Prometheus)
- [ ] Alerting configured (PagerDuty/Discord)
- [ ] Keeper bot infrastructure ready
- [ ] Frontend deployed (if applicable)
- [ ] Backend API deployed (if applicable)

### 5. Legal & Compliance

- [ ] Legal review completed
- [ ] Terms of service finalized
- [ ] Risk disclosures prepared
- [ ] Regulatory compliance checked
- [ ] Insurance coverage obtained (if applicable)

### 6. Financial Preparation

- [ ] Initial liquidity secured (min $500K recommended)
- [ ] Treasury wallet funded (gas for operations)
- [ ] Admin multi-sig wallet configured (recommended: 3-of-5)
- [ ] Emergency fund allocated

---

## Environment Setup

### 1. Install Dependencies

```bash
# Clone repository
git clone <repo-url>
cd LiquidRoyaltyContracts

# Install Foundry dependencies
forge install

# Install backend dependencies
cd wrapper && npm install

# Install frontend dependencies
cd ../simulation && npm install
```

### 2. Configure Environment Variables

#### Root `.env`

```bash
# Deployer private key (use hardware wallet for mainnet!)
PRIVATE_KEY=0x...

# RPC URLs
BERACHAIN_TESTNET_RPC=https://artio.rpc.berachain.com
BERACHAIN_MAINNET_RPC=https://rpc.berachain.com
POLYGON_RPC_URL=https://polygon-rpc.com

# Etherscan API keys (for verification)
BERASCAN_API_KEY=...
POLYGONSCAN_API_KEY=...

# Admin addresses (USE MULTI-SIG!)
ADMIN_ADDRESS=0x...
TREASURY_ADDRESS=0x...

# Stablecoin address
STABLECOIN_ADDRESS=0x...  # USDC/USDE on target chain
```

#### Backend `wrapper/.env`

```bash
ADMIN_PRIVATE_KEY=0x...
RPC_URL=https://rpc.berachain.com
PORT=3000
```

#### Frontend `simulation/.env`

```bash
VITE_API_URL=https://api.yourdomain.com
VITE_ADMIN_PRIVATE_KEY=0x...  # NEVER expose this in production!
VITE_NETWORK=berachain-mainnet
```

### 3. Prepare Deployment Scripts

Create `script/DeployProduction.s.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UnifiedConcreteSeniorVault} from "../src/concrete/UnifiedConcreteSeniorVault.sol";
import {ConcreteJuniorVault} from "../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../src/concrete/ConcreteReserveVault.sol";

contract DeployProduction is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address stablecoin = vm.envAddress("STABLECOIN_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy implementations
        UnifiedConcreteSeniorVault seniorImpl = new UnifiedConcreteSeniorVault();
        ConcreteJuniorVault juniorImpl = new ConcreteJuniorVault();
        ConcreteReserveVault reserveImpl = new ConcreteReserveVault();
        
        console.log("Senior Implementation:", address(seniorImpl));
        console.log("Junior Implementation:", address(juniorImpl));
        console.log("Reserve Implementation:", address(reserveImpl));
        
        // 2. Deploy proxies with placeholder senior vault
        bytes memory juniorInitData = abi.encodeWithSelector(
            ConcreteJuniorVault.initialize.selector,
            stablecoin,
            address(0x1),  // Placeholder
            0              // Initial value = 0
        );
        
        bytes memory reserveInitData = abi.encodeWithSelector(
            ConcreteReserveVault.initialize.selector,
            stablecoin,
            address(0x1),  // Placeholder
            0              // Initial value = 0
        );
        
        ERC1967Proxy juniorProxy = new ERC1967Proxy(
            address(juniorImpl),
            juniorInitData
        );
        
        ERC1967Proxy reserveProxy = new ERC1967Proxy(
            address(reserveImpl),
            reserveInitData
        );
        
        // 3. Deploy senior vault with actual addresses
        bytes memory seniorInitData = abi.encodeWithSelector(
            UnifiedConcreteSeniorVault.initialize.selector,
            stablecoin,
            "Senior USD",
            "snrUSD",
            address(juniorProxy),
            address(reserveProxy),
            treasury,
            0  // Initial value = 0
        );
        
        ERC1967Proxy seniorProxy = new ERC1967Proxy(
            address(seniorImpl),
            seniorInitData
        );
        
        console.log("Senior Vault Proxy:", address(seniorProxy));
        console.log("Junior Vault Proxy:", address(juniorProxy));
        console.log("Reserve Vault Proxy:", address(reserveProxy));
        
        // 4. Update junior/reserve with actual senior address
        ConcreteJuniorVault(address(juniorProxy)).updateSeniorVault(address(seniorProxy));
        ConcreteReserveVault(address(reserveProxy)).updateSeniorVault(address(seniorProxy));
        
        // 5. Set admin to multi-sig
        UnifiedConcreteSeniorVault(address(seniorProxy)).setAdmin(admin);
        ConcreteJuniorVault(address(juniorProxy)).setAdmin(admin);
        ConcreteReserveVault(address(reserveProxy)).setAdmin(admin);
        
        vm.stopBroadcast();
        
        // Save addresses
        string memory addresses = string(abi.encodePacked(
            "SENIOR_VAULT=", vm.toString(address(seniorProxy)), "\n",
            "JUNIOR_VAULT=", vm.toString(address(juniorProxy)), "\n",
            "RESERVE_VAULT=", vm.toString(address(reserveProxy)), "\n"
        ));
        
        vm.writeFile("deployed_addresses.txt", addresses);
    }
}
```

---

## Testnet Deployment

### Phase 1: Deploy to Testnet

```bash
# 1. Set testnet RPC
export RPC_URL=$BERACHAIN_TESTNET_RPC

# 2. Get testnet funds from faucet
# Visit https://artio.faucet.berachain.com

# 3. Deploy contracts
forge script script/DeployProduction.s.sol \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify

# 4. Save deployment addresses
cat deployed_addresses.txt
```

### Phase 2: Initial Configuration

```bash
# Export deployed addresses
source deployed_addresses.txt

# 1. Whitelist stablecoin for deposits
cast send $SENIOR_VAULT "addWhitelistedDepositor(address)" $YOUR_TEST_ADDRESS \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

# 2. Set initial vault values (required before first deposit)
cast send $SENIOR_VAULT "setVaultValue(uint256)" 0 \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

cast send $JUNIOR_VAULT "setVaultValue(uint256)" 0 \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

cast send $RESERVE_VAULT "setVaultValue(uint256)" 0 \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

### Phase 3: Testnet Testing

```bash
# 1. Test deposits
cast send $SENIOR_VAULT "deposit(uint256,address)" \
  "1000000000" \  # 1000 USDC (6 decimals)
  $YOUR_TEST_ADDRESS \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

# 2. Check balance
cast call $SENIOR_VAULT "balanceOf(address)" $YOUR_TEST_ADDRESS \
  --rpc-url $RPC_URL

# 3. Test oracle configuration (if Kodiak available on testnet)
cast send $SENIOR_VAULT "configureOracle(address,bool,uint256,bool,bool)" \
  $KODIAK_ISLAND \
  true \    # stablecoinIsToken0
  500 \     # 5% max deviation
  true \    # enable validation
  true \    # use calculated value
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

### Phase 4: Integration Testing

Run through all critical user flows:

1. **User deposits** to all three vaults
2. **Kodiak deployment** (if available)
3. **Rebase execution**
4. **Spillover scenario** (simulate profit)
5. **Backstop scenario** (simulate loss)
6. **Withdrawals** with and without cooldown
7. **Oracle validation** (check deviation protection)

### Phase 5: Stress Testing

```bash
# Run automated stress tests
forge test --match-path "test/e2e/*.t.sol" --fork-url $RPC_URL

# Monitor gas costs
forge test --gas-report --fork-url $RPC_URL
```

---

## Oracle Configuration

### Step 1: Identify Kodiak Island

```bash
# On Berachain mainnet, get the USDC-BERA Island address
USDC_BERA_ISLAND=0x...  # Get from Kodiak docs

# Verify Island contract
cast call $USDC_BERA_ISLAND "token0()" --rpc-url $RPC_URL
cast call $USDC_BERA_ISLAND "token1()" --rpc-url $RPC_URL
cast call $USDC_BERA_ISLAND "totalSupply()" --rpc-url $RPC_URL
```

### Step 2: Configure Oracle

```bash
# Configure oracle for automatic mode
cast send $SENIOR_VAULT "configureOracle(address,bool,uint256,bool,bool)" \
  $USDC_BERA_ISLAND \
  true \     # USDC is token0 (verify this!)
  500 \      # 5% max deviation
  true \     # enable validation
  true \     # use calculated value (automatic mode)
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY

# Repeat for Junior and Reserve vaults
cast send $JUNIOR_VAULT "configureOracle(...)" ...
cast send $RESERVE_VAULT "configureOracle(...)" ...
```

### Step 3: Verify Oracle

```bash
# Get calculated LP price
cast call $SENIOR_VAULT "getCalculatedLPPrice()" --rpc-url $RPC_URL

# Get calculated vault value
cast call $SENIOR_VAULT "getCalculatedVaultValue()" --rpc-url $RPC_URL

# Get oracle config
cast call $SENIOR_VAULT "getOracleConfig()" --rpc-url $RPC_URL
```

---

## Kodiak Integration Setup

### Step 1: Deploy Kodiak Hook

```bash
# Deploy KodiakVaultHook
forge create src/integrations/KodiakVaultHook.sol:KodiakVaultHook \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --constructor-args \
    $SENIOR_VAULT \
    $KODIAK_ISLAND_ROUTER \
    $USDC_BERA_ISLAND

# Save hook address
KODIAK_HOOK=0x...
```

### Step 2: Whitelist Aggregators

```bash
# Whitelist Kodiak's swap aggregator
cast send $KODIAK_HOOK "whitelistAggregator(address)" \
  $KODIAK_AGGREGATOR \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY

# Whitelist additional aggregators if needed (1inch, etc.)
cast send $KODIAK_HOOK "whitelistAggregator(address)" \
  $ONEINCH_AGGREGATOR \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY
```

### Step 3: Connect Hook to Vaults

```bash
# Set hook on all vaults
cast send $SENIOR_VAULT "setKodiakHook(address)" $KODIAK_HOOK \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY

cast send $JUNIOR_VAULT "setKodiakHook(address)" $KODIAK_HOOK \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY

cast send $RESERVE_VAULT "setKodiakHook(address)" $KODIAK_HOOK \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY
```

### Step 4: Whitelist Kodiak LP Token

```bash
# Get Kodiak Island LP token address
KODIAK_LP_TOKEN=$USDC_BERA_ISLAND  # Island IS the LP token

# Whitelist in all vaults (for spillover/backstop transfers)
cast send $SENIOR_VAULT "addWhitelistedLPToken(address)" $KODIAK_LP_TOKEN \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY

cast send $JUNIOR_VAULT "addWhitelistedLPToken(address)" $KODIAK_LP_TOKEN \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY

cast send $RESERVE_VAULT "addWhitelistedLPToken(address)" $KODIAK_LP_TOKEN \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY
```

### Step 5: Test Deployment

```bash
# Get swap quote from Kodiak API
# POST https://api.kodiak.finance/quote
# Body: { "fromToken": "USDC", "toToken": "BERA", "amount": "50000000000" }
# Response: { "swapData0": "0x...", "swapData1": "0x...", "expectedLP": "7500..." }

# Deploy 50K USDC to Kodiak
cast send $SENIOR_VAULT "deployToKodiak(uint256,uint256,address,bytes,address,bytes)" \
  50000000000 \              # 50K USDC (6 decimals)
  7500000000000000000000 \   # Min 7500 LP (slippage protection)
  $AGGREGATOR_ADDRESS \
  $SWAP_DATA_0 \
  $AGGREGATOR_ADDRESS \
  $SWAP_DATA_1 \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY \
  --gas-limit 1000000
```

---

## Security Verification

### 1. Access Control Audit

```bash
# Verify admin is multi-sig
cast call $SENIOR_VAULT "admin()" --rpc-url $RPC_URL
cast call $JUNIOR_VAULT "admin()" --rpc-url $RPC_URL
cast call $RESERVE_VAULT "admin()" --rpc-url $RPC_URL

# Verify treasury address
cast call $SENIOR_VAULT "treasury()" --rpc-url $RPC_URL

# Check implementation addresses
cast call $SENIOR_VAULT "implementation()" --rpc-url $RPC_URL
```

### 2. Parameter Validation

```bash
# Check rebase interval
cast call $SENIOR_VAULT "minRebaseInterval()" --rpc-url $RPC_URL
# Should be: 2592000 (30 days)

# Check withdrawal cooldown
cast call $SENIOR_VAULT "cooldownPeriod()" --rpc-url $RPC_URL
# Should be: 604800 (7 days)

# Check oracle config
cast call $SENIOR_VAULT "getOracleConfig()" --rpc-url $RPC_URL
```

### 3. Test Emergency Functions

```bash
# Test pause (then unpause immediately)
cast send $SENIOR_VAULT "pause()" \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY

cast send $SENIOR_VAULT "unpause()" \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY
```

### 4. Verify Upgrade Protection

```bash
# Ensure only admin can upgrade
cast send $SENIOR_VAULT "upgradeTo(address)" $NEW_IMPL \
  --rpc-url $RPC_URL \
  --private-key $USER_PRIVATE_KEY
# Should fail with "OnlyAdmin()"
```

---

## Mainnet Deployment

### Pre-Launch: 48 Hours Before

**Day -2 (48 hours before launch)**

- [ ] Final audit report reviewed
- [ ] All critical issues resolved
- [ ] Testnet running stable for 7+ days
- [ ] Multi-sig wallet configured and tested
- [ ] Team briefed on emergency procedures
- [ ] Monitoring dashboards set up
- [ ] Social media announcements prepared
- [ ] User documentation published

### Launch Day Preparation

**Day -1 (24 hours before launch)**

```bash
# 1. Deploy contracts to mainnet
forge script script/DeployProduction.s.sol \
  --rpc-url $BERACHAIN_MAINNET_RPC \
  --broadcast \
  --verify \
  --slow  # Use slow mode for better reliability

# 2. Verify all contract addresses
cat deployed_addresses.txt

# 3. Transfer ownership to multi-sig
# (Should be done in deployment script)

# 4. Configure oracle
# (Follow steps in Oracle Configuration section)

# 5. Set up Kodiak integration
# (Follow steps in Kodiak Integration Setup section)
```

### Launch: Go-Live Sequence

**Hour 0: Soft Launch (Whitelist Only)**

```bash
# 1. Whitelist early supporters (max 50)
for address in $WHITELIST_ADDRESSES; do
  cast send $SENIOR_VAULT "addWhitelistedDepositor(address)" $address \
    --rpc-url $RPC_URL \
    --private-key $ADMIN_PRIVATE_KEY
done

# 2. Set initial deposit cap (Reserve vault)
cast send $RESERVE_VAULT "setVaultValue(uint256)" \
  "1000000000000000000000000" \  # $1M cap
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY

# 3. Monitor for 4 hours
# - Watch for any unexpected behavior
# - Verify oracle calculations
# - Check Kodiak deployments
```

**Hour 4: Increase Cap**

```bash
# Increase to $5M cap
cast send $RESERVE_VAULT "setVaultValue(uint256)" \
  "5000000000000000000000000" \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY
```

**Hour 12: Public Launch**

```bash
# Remove whitelist requirement
cast send $SENIOR_VAULT "setWhitelistEnabled(bool)" false \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY
```

### Post-Launch: First 7 Days

**Daily Tasks**:

```bash
# Check vault values
cast call $SENIOR_VAULT "vaultValue()" --rpc-url $RPC_URL
cast call $JUNIOR_VAULT "vaultValue()" --rpc-url $RPC_URL
cast call $RESERVE_VAULT "vaultValue()" --rpc-url $RPC_URL

# Check backing ratio
cast call $SENIOR_VAULT "getBackingRatio()" --rpc-url $RPC_URL

# Check LP holdings
cast call $KODIAK_HOOK "getIslandLPBalance()" --rpc-url $RPC_URL

# Verify oracle accuracy
CALC=$(cast call $SENIOR_VAULT "getCalculatedVaultValue()" --rpc-url $RPC_URL)
STORED=$(cast call $SENIOR_VAULT "getStoredVaultValue()" --rpc-url $RPC_URL)
echo "Calculated: $CALC"
echo "Stored: $STORED"
```

**Weekly Tasks**:
- Review all transactions
- Check for anomalies
- Update documentation as needed
- Gather user feedback

---

## Post-Deployment Configuration

### 1. Set Management Fee Recipient

```bash
cast send $SENIOR_VAULT "setTreasury(address)" $TREASURY_ADDRESS \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY
```

### 2. Configure Rebase Parameters

```bash
# Set minimum rebase interval (30 days)
cast send $SENIOR_VAULT "setMinRebaseInterval(uint256)" 2592000 \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY
```

### 3. Set Withdrawal Cooldown

```bash
# Set 7-day cooldown
cast send $SENIOR_VAULT "setCooldownPeriod(uint256)" 604800 \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY
```

### 4. Deploy Initial Liquidity to Kodiak

```bash
# Deploy $100K to Kodiak
# (Get swap quote from Kodiak API first)
cast send $SENIOR_VAULT "deployToKodiak(...)" \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY \
  --gas-limit 1500000
```

---

## Go-Live Checklist

### Technical Readiness

- [ ] All contracts deployed to mainnet
- [ ] All contracts verified on block explorer
- [ ] Oracle configured and validated
- [ ] Kodiak integration tested
- [ ] Initial liquidity deployed
- [ ] Multi-sig wallet is admin
- [ ] Treasury wallet configured
- [ ] Monitoring systems active
- [ ] Alerting configured
- [ ] Backend API deployed
- [ ] Frontend deployed
- [ ] DNS configured
- [ ] SSL certificates active

### Operational Readiness

- [ ] Admin team trained
- [ ] Emergency procedures documented
- [ ] Incident response plan ready
- [ ] Communication channels set up (Discord/Telegram)
- [ ] Social media accounts active
- [ ] Support system ready

### Legal & Compliance

- [ ] Terms of service published
- [ ] Privacy policy published
- [ ] Risk disclosures displayed
- [ ] Legal review completed
- [ ] Insurance coverage active (if applicable)

### Financial Readiness

- [ ] Initial liquidity secured ($500K+)
- [ ] Treasury funded (gas for operations)
- [ ] Emergency fund allocated ($50K+)
- [ ] Accounting systems set up

### User Experience

- [ ] User documentation complete
- [ ] Video tutorials created
- [ ] FAQ published
- [ ] Support email/chat active
- [ ] Community guidelines published

---

## Monitoring & Maintenance

### Real-Time Monitoring

#### Key Metrics Dashboard

Monitor these metrics 24/7:

```javascript
// Grafana/Prometheus queries

// 1. Total Value Locked (TVL)
sum(vault_value{vault=~"senior|junior|reserve"})

// 2. Backing Ratio
senior_vault_value / senior_total_supply

// 3. LP Holdings Value
kodiak_lp_balance * kodiak_lp_price

// 4. Oracle Deviation
abs(calculated_value - stored_value) / calculated_value

// 5. Gas Prices
avg(gas_price_gwei)

// 6. Transaction Success Rate
sum(tx_success) / sum(tx_total)
```

#### Alerts Configuration

```yaml
# alerts.yaml

# Critical Alerts (PagerDuty)
- alert: BackingRatioCritical
  expr: backing_ratio < 0.95
  for: 5m
  severity: critical
  message: "Backing ratio below 95%!"

- alert: OracleDeviationHigh
  expr: oracle_deviation > 0.10
  for: 10m
  severity: critical
  message: "Oracle deviation > 10%!"

- alert: ContractPaused
  expr: vault_paused == 1
  severity: critical
  message: "Vault contract is paused!"

# Warning Alerts (Discord/Slack)
- alert: BackingRatioWarning
  expr: backing_ratio < 1.00
  for: 15m
  severity: warning
  message: "Backing ratio below 100%"

- alert: HighGasPrices
  expr: avg_gas_price > 500
  for: 30m
  severity: warning
  message: "Gas prices > 500 gwei"

- alert: LowLiquidity
  expr: vault_value < 100000
  severity: warning
  message: "Vault value < $100K"
```

### Daily Operations

#### Morning Checklist (Every Day at 9 AM)

```bash
#!/bin/bash
# daily_health_check.sh

echo "=== Daily Health Check ==="
echo ""

# 1. Check vault values
echo "Vault Values:"
SENIOR=$(cast call $SENIOR_VAULT "vaultValue()" --rpc-url $RPC_URL)
JUNIOR=$(cast call $JUNIOR_VAULT "vaultValue()" --rpc-url $RPC_URL)
RESERVE=$(cast call $RESERVE_VAULT "vaultValue()" --rpc-url $RPC_URL)
echo "Senior:  $(echo "scale=2; $SENIOR / 10^18" | bc) USD"
echo "Junior:  $(echo "scale=2; $JUNIOR / 10^18" | bc) USD"
echo "Reserve: $(echo "scale=2; $RESERVE / 10^18" | bc) USD"
echo ""

# 2. Check backing ratio
echo "Backing Ratio:"
RATIO=$(cast call $SENIOR_VAULT "getBackingRatio()" --rpc-url $RPC_URL)
echo "$(echo "scale=2; $RATIO / 10^16" | bc)%"
echo ""

# 3. Check oracle accuracy
echo "Oracle Validation:"
CALC=$(cast call $SENIOR_VAULT "getCalculatedVaultValue()" --rpc-url $RPC_URL)
STORED=$(cast call $SENIOR_VAULT "getStoredVaultValue()" --rpc-url $RPC_URL)
echo "Calculated: $(echo "scale=2; $CALC / 10^18" | bc) USD"
echo "Stored:     $(echo "scale=2; $STORED / 10^18" | bc) USD"
DEV=$(echo "scale=4; ($CALC - $STORED) / $CALC" | bc)
echo "Deviation:  $(echo "scale=2; $DEV * 100" | bc)%"
echo ""

# 4. Check last rebase
echo "Last Rebase:"
LAST_REBASE=$(cast call $SENIOR_VAULT "lastRebaseTime()" --rpc-url $RPC_URL)
CURRENT_TIME=$(date +%s)
DAYS_AGO=$(echo "($CURRENT_TIME - $LAST_REBASE) / 86400" | bc)
echo "$DAYS_AGO days ago"
echo ""

# 5. Check Kodiak LP holdings
echo "Kodiak LP Holdings:"
LP_BALANCE=$(cast call $KODIAK_HOOK "getIslandLPBalance()" --rpc-url $RPC_URL)
LP_PRICE=$(cast call $SENIOR_VAULT "getCalculatedLPPrice()" --rpc-url $RPC_URL)
LP_VALUE=$(echo "$LP_BALANCE * $LP_PRICE / 10^36" | bc)
echo "LP Tokens: $(echo "scale=2; $LP_BALANCE / 10^18" | bc)"
echo "LP Price:  $(echo "scale=2; $LP_PRICE / 10^18" | bc) USD"
echo "LP Value:  $LP_VALUE USD"
```

### Monthly Operations

#### Rebase Execution (Day 1 of each month)

```bash
#!/bin/bash
# execute_rebase.sh

echo "=== Monthly Rebase Execution ==="
echo ""

# 1. Pre-rebase checks
echo "Step 1: Pre-rebase validation"
RATIO=$(cast call $SENIOR_VAULT "getBackingRatio()" --rpc-url $RPC_URL)
echo "Current backing ratio: $(echo "scale=2; $RATIO / 10^16" | bc)%"

if [ $RATIO -lt 95000000000000000 ]; then
  echo "WARNING: Backing ratio < 95%! Review before rebase!"
  exit 1
fi

# 2. Calculate LP price (if using manual mode)
LP_PRICE=$(cast call $SENIOR_VAULT "getCalculatedLPPrice()" --rpc-url $RPC_URL)
echo "LP Price: $(echo "scale=2; $LP_PRICE / 10^18" | bc) USD"

# 3. Execute rebase
echo ""
echo "Step 2: Executing rebase..."

if [ "$USE_AUTOMATIC_MODE" = "true" ]; then
  # Automatic mode (no LP price needed)
  cast send $SENIOR_VAULT "rebase()" \
    --rpc-url $RPC_URL \
    --private-key $ADMIN_PRIVATE_KEY \
    --gas-limit 1000000
else
  # Manual mode (provide LP price)
  cast send $SENIOR_VAULT "rebase(uint256)" $LP_PRICE \
    --rpc-url $RPC_URL \
    --private-key $ADMIN_PRIVATE_KEY \
    --gas-limit 1000000
fi

echo "Rebase completed!"

# 4. Post-rebase validation
echo ""
echo "Step 3: Post-rebase validation"
NEW_RATIO=$(cast call $SENIOR_VAULT "getBackingRatio()" --rpc-url $RPC_URL)
echo "New backing ratio: $(echo "scale=2; $NEW_RATIO / 10^16" | bc)%"

EPOCH=$(cast call $SENIOR_VAULT "epoch()" --rpc-url $RPC_URL)
echo "New epoch: $EPOCH"
```

---

## Emergency Procedures

### Emergency Contact Tree

```
Level 1 (Immediate): Technical Lead, Smart Contract Lead
Level 2 (15 min):    CEO, CTO, Legal Counsel
Level 3 (1 hour):    Full Team, PR Team
```

### Emergency Scenarios

#### 1. Critical Bug Discovered

**Immediate Actions**:

```bash
# 1. PAUSE all vaults
cast send $SENIOR_VAULT "pause()" \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY

cast send $JUNIOR_VAULT "pause()" \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY

cast send $RESERVE_VAULT "pause()" \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY

# 2. Notify users (social media, email)
# 3. Assess severity
# 4. Prepare fix
# 5. Deploy upgrade (see Upgrade Procedures)
```

#### 2. Oracle Manipulation Detected

**Immediate Actions**:

```bash
# 1. Switch to manual mode
cast send $SENIOR_VAULT "configureOracle(address,bool,uint256,bool,bool)" \
  $ORACLE_ISLAND \
  true \
  500 \
  true \
  false \  # Disable automatic mode
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY

# 2. Update vault values manually with verified data
cast send $SENIOR_VAULT "setVaultValue(uint256)" $VERIFIED_VALUE \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY

# 3. Investigate root cause
# 4. Implement fix
```

#### 3. Backing Ratio < 90%

**Immediate Actions**:

```bash
# 1. Assess situation
RATIO=$(cast call $SENIOR_VAULT "getBackingRatio()" --rpc-url $RPC_URL)
DEFICIT=$(cast call $SENIOR_VAULT "calculateBackstopDeficit()" --rpc-url $RPC_URL)

echo "Backing ratio: $(echo "scale=2; $RATIO / 10^16" | bc)%"
echo "Deficit: $(echo "scale=2; $DEFICIT / 10^18" | bc) USD"

# 2. Check Reserve availability
RESERVE_VALUE=$(cast call $RESERVE_VAULT "vaultValue()" --rpc-url $RPC_URL)
echo "Reserve available: $(echo "scale=2; $RESERVE_VALUE / 10^18" | bc) USD"

# 3. Execute backstop if needed
cast send $SENIOR_VAULT "rebase(uint256)" $LP_PRICE \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY \
  --gas-limit 1500000

# 4. If insufficient, consider emergency capital injection
```

#### 4. Kodiak Island Exploit

**Immediate Actions**:

```bash
# 1. Attempt to withdraw all LP from Kodiak
cast send $KODIAK_HOOK "emergencyWithdraw()" \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY \
  --gas-limit 2000000

# 2. Pause deposits
cast send $SENIOR_VAULT "pause()" \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY

# 3. Disconnect Kodiak hook
cast send $SENIOR_VAULT "setKodiakHook(address)" 0x0000000000000000000000000000000000000000 \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY

# 4. Assess losses
# 5. Communicate with users
```

### Emergency Multi-Sig Execution

For critical actions requiring multi-sig:

```bash
# 1. Create transaction on Gnosis Safe
# Visit https://app.safe.global

# 2. Submit transaction for signing
# Target: $SENIOR_VAULT
# Function: pause()
# Value: 0

# 3. Get 3 of 5 signatures
# 4. Execute transaction
# 5. Verify execution
```

---

## Upgrade Procedures

### Non-Critical Upgrade (New Features)

**Timeline**: 7-day notice

**Steps**:

```bash
# Day 0: Announce upgrade
# - Social media announcement
# - Email notification
# - Discord/Telegram announcement

# Day 7: Deploy new implementation
forge create src/concrete/UnifiedConcreteSeniorVaultV2.sol:UnifiedConcreteSeniorVaultV2 \
  --rpc-url $RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY

NEW_IMPL=0x...

# Verify implementation
forge verify-contract $NEW_IMPL \
  src/concrete/UnifiedConcreteSeniorVaultV2.sol:UnifiedConcreteSeniorVaultV2 \
  --chain berachain

# Upgrade via multi-sig
cast send $SENIOR_VAULT "upgradeTo(address)" $NEW_IMPL \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY

# Verify upgrade
cast call $SENIOR_VAULT "implementation()" --rpc-url $RPC_URL

# Post-upgrade testing
forge test --match-path "test/e2e/*.t.sol" --fork-url $RPC_URL
```

### Critical Bug Fix (Emergency Upgrade)

**Timeline**: Immediate

**Steps**:

```bash
# 1. PAUSE contracts immediately
# (See Emergency Procedures)

# 2. Deploy fixed implementation
forge create src/concrete/UnifiedConcreteSeniorVaultFixed.sol:UnifiedConcreteSeniorVaultFixed \
  --rpc-url $RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --verify

FIXED_IMPL=0x...

# 3. Emergency multi-sig call
# Get 3 of 5 signatures ASAP

# 4. Upgrade
cast send $SENIOR_VAULT "upgradeTo(address)" $FIXED_IMPL \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY

# 5. UNPAUSE
cast send $SENIOR_VAULT "unpause()" \
  --rpc-url $RPC_URL \
  --private-key $ADMIN_PRIVATE_KEY

# 6. Monitor for 24 hours
# 7. Post-mortem analysis
```

---

## Appendix

### A. Contract Addresses (Template)

Save as `contract_addresses_mainnet.json`:

```json
{
  "network": "berachain-mainnet",
  "chainId": 80085,
  "deploymentDate": "2025-11-15",
  "contracts": {
    "seniorVault": {
      "proxy": "0x...",
      "implementation": "0x..."
    },
    "juniorVault": {
      "proxy": "0x...",
      "implementation": "0x..."
    },
    "reserveVault": {
      "proxy": "0x...",
      "implementation": "0x..."
    },
    "kodiakHook": "0x...",
    "stablecoin": "0x...",
    "kodiakIsland": "0x..."
  },
  "admin": {
    "multiSig": "0x...",
    "treasury": "0x..."
  }
}
```

### B. Gas Estimates

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| Deposit | ~150K | First deposit higher (~200K) |
| Withdraw | ~120K | With cooldown |
| Rebase (no spillover) | ~300K | Automatic mode |
| Rebase (with spillover) | ~600K | Includes LP transfers |
| Deploy to Kodiak | ~800K | Includes swaps |
| Oracle update | ~50K | Manual mode only |

### C. Support Contacts

- **Technical Issues**: tech-support@protocol.com
- **Emergency**: emergency@protocol.com (24/7)
- **Discord**: https://discord.gg/...
- **Telegram**: https://t.me/...

### D. External Dependencies

| Service | Purpose | Backup |
|---------|---------|--------|
| Berachain RPC | Blockchain access | Multiple providers |
| Kodiak API | Swap quotes | 1inch API |
| Grafana | Monitoring | Self-hosted |
| PagerDuty | Alerts | Discord webhooks |
| Etherscan | Block explorer | Bereascan |

---

**END OF DEPLOYMENT GUIDE**

Last Updated: November 12, 2025  
Version: 3.0.0

For questions or clarifications, contact the dev team.

