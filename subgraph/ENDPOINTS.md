# 🚀 Your Live GraphQL Endpoints

## ✅ All 3 Subgraphs Deployed Successfully

### Senior Vault (snrUSD)
```
https://api.goldsky.com/api/public/project_cmjgbb5x4ix5j0104hdx03a5u/subgraphs/liquid-royalty-senior/v2.0.0/gn
```
**Contract:** `0x49298F4314eb127041b814A2616c25687Db6b650`

### Junior Vault (jnr)
```
https://api.goldsky.com/api/public/project_cmjgbb5x4ix5j0104hdx03a5u/subgraphs/liquid-royalty-junior/v2.0.0/gn
```
**Contract:** `0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883`

### Reserve Vault (alar)
```
https://api.goldsky.com/api/public/project_cmjgbb5x4ix5j0104hdx03a5u/subgraphs/liquid-royalty-reserve/v2.0.0/gn
```
**Contract:** `0x7754272c866892CaD4a414C76f060645bDc27203`

---

## 📊 Check Sync Status

```bash
goldsky subgraph list
```

Currently syncing from block **13403095** (fast sync - ~1.2M blocks).

---

## 🧪 Test Query

Open any endpoint URL in your browser, or:

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"query":"{ users(first: 5) { id totalDeposited totalWithdrawn } }"}' \
  https://api.goldsky.com/api/public/project_cmjgbb5x4ix5j0104hdx03a5u/subgraphs/liquid-royalty-senior/v2.0.0/gn
```

---

## 💻 Frontend Integration

```typescript
const SENIOR_API = 'https://api.goldsky.com/api/public/project_cmjgbb5x4ix5j0104hdx03a5u/subgraphs/liquid-royalty-senior/v2.0.0/gn';
const JUNIOR_API = 'https://api.goldsky.com/api/public/project_cmjgbb5x4ix5j0104hdx03a5u/subgraphs/liquid-royalty-junior/v2.0.0/gn';
const RESERVE_API = 'https://api.goldsky.com/api/public/project_cmjgbb5x4ix5j0104hdx03a5u/subgraphs/liquid-royalty-reserve/v2.0.0/gn';

async function getUserBalance(address: string) {
  const response = await fetch(SENIOR_API, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      query: `
        query GetUser($address: ID!) {
          user(id: $address) {
            totalDeposited
            totalWithdrawn
            deposits { assets shares timestamp }
          }
        }
      `,
      variables: { address: address.toLowerCase() }
    })
  });
  return await response.json();
}
```

---

## ✅ What's Running

- ✅ Your custom TypeScript event handlers
- ✅ Your custom GraphQL schema
- ✅ Protocol stats aggregation
- ✅ User balance tracking
- ✅ All 10+ events per vault

**Network:** berachain-mainnet  
**Start Block:** 13403095  
**Status:** Syncing → Will be 100% in ~30 minutes

---

Save these URLs - you'll need them for your frontend! 🎯

