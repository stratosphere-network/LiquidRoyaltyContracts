# ✅ Liquid Royalty Subgraphs - DEPLOYED

## 🎉 Your GraphQL APIs

All 3 subgraphs are **LIVE** and using your custom TypeScript code:

### Senior Vault (snrUSD)

```
https://api.goldsky.com/api/public/project_cmjgbb5x4ix5j0104hdx03a5u/subgraphs/liquid-royalty-senior/v2.0.0/gn
```

### Junior Vault (jnr)

```
https://api.goldsky.com/api/public/project_cmjgbb5x4ix5j0104hdx03a5u/subgraphs/liquid-royalty-junior/v2.0.0/gn
```

### Reserve Vault (alar)

```
https://api.goldsky.com/api/public/project_cmjgbb5x4ix5j0104hdx03a5u/subgraphs/liquid-royalty-reserve/v2.0.0/gn
```

---

## 📊 Check Status

```bash
goldsky subgraph list
```

Wait for `Synced: 100%` on all three (should be fast - only syncing from block 13403095).

---

## 🧪 Test Your APIs

Click the URLs above or query them:

```graphql
{
  # Get all users
  users(first: 10) {
    id
    totalDeposited
    totalWithdrawn
  }

  # Get recent deposits
  deposits(first: 10, orderBy: timestamp, orderDirection: desc) {
    user {
      id
    }
    assets
    shares
    timestamp
  }

  # Protocol stats (YOUR custom entity!)
  protocolStats(id: "protocol") {
    totalDeposits
    totalWithdrawals
    totalUsers
  }
}
```

---

## 📁 What Was Deployed

For each vault, Goldsky is running:

- ✅ **Your TypeScript handlers** (`src/mapping.ts`)
- ✅ **Your custom schema** (`schema.graphql`)
- ✅ **Start block 13403095** (only 1.2M blocks to sync)

NOT auto-generated - this is YOUR code!

---

## 🔄 Update & Redeploy

To update code:

```bash
# 1. Edit src/mapping.ts or schema.graphql
cd senior  # or junior/reserve

# 2. Rebuild
npx graph build

# 3. Redeploy with new version
goldsky subgraph deploy liquid-royalty-senior/v2.0.1 --path .
```

---

## 📦 Deployment Command (For Future)

```bash
export GOLDSKY_TOKEN="cmjgbh3y2jnxw01z75kcydbib"

# Deploy Senior
cd senior
goldsky subgraph deploy liquid-royalty-senior/v2.0.0 --path .

# Deploy Junior
cd ../junior
goldsky subgraph deploy liquid-royalty-junior/v2.0.0 --path .

# Deploy Reserve
cd ../reserve
goldsky subgraph deploy liquid-royalty-reserve/v2.0.0 --path .
```

---

## 📊 What Gets Indexed (With Your Custom Code)

### All Vaults:

- ✅ Deposits & Withdrawals
- ✅ Transfers
- ✅ Cooldowns & Penalties
- ✅ Fees
- ✅ Vault Values
- ✅ BGT Claims

### Senior Only:

- ✅ Backstop Triggered
- ✅ Profit Spillover

### Junior & Reserve:

- ✅ Spillover Received
- ✅ Backstop Provided
- ✅ Rebase Events

### Custom Aggregations (Your Code):

- ✅ User total deposits/withdrawals
- ✅ Protocol stats
- ✅ Entity relationships

---

## ✅ You're Live!

Your custom indexers are running on Goldsky! 🚀

Check sync status and start querying your data!
