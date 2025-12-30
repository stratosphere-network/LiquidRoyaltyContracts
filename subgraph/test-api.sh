#!/bin/bash

# Test your GraphQL endpoints with real data

USER_ADDRESS="0x6fa2149e69dbcbdcf6f16f755e08c10e53c40605"  # lowercase for GraphQL

echo "🧪 Testing Liquid Royalty Subgraph APIs"
echo "========================================"
echo ""
echo "Testing address: $USER_ADDRESS"
echo ""

# Test Senior Vault
echo "📊 SENIOR VAULT"
echo "---------------"
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{\"query\":\"{ user(id: \\\"$USER_ADDRESS\\\") { id totalDeposited totalWithdrawn deposits(first: 5, orderBy: timestamp, orderDirection: desc) { assets shares timestamp transactionHash } } }\"}" \
  https://api.goldsky.com/api/public/project_cmjh1lmjigfeb010c2rvw26vw/subgraphs/liquid-royalty-senior/v2.0.1/gn | jq '.'
echo ""
echo ""

# Test recent deposits (all users)
echo "📥 Recent Deposits (All Users)"
echo "------------------------------"
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"query":"{ deposits(first: 10, orderBy: timestamp, orderDirection: desc) { user { id } assets shares timestamp blockNumber } }"}' \
  https://api.goldsky.com/api/public/project_cmjh1lmjigfeb010c2rvw26vw/subgraphs/liquid-royalty-senior/v2.0.1/gn | jq '.'
echo ""
echo ""

# Test protocol stats
echo "📈 Protocol Stats"
echo "-----------------"
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"query":"{ protocolStats(id: \"protocol\") { totalDeposits totalWithdrawals totalUsers totalSpillovers totalBackstops } }"}' \
  https://api.goldsky.com/api/public/project_cmjh1lmjigfeb010c2rvw26vw/subgraphs/liquid-royalty-senior/v2.0.1/gn | jq '.'
echo ""
echo ""

# Test Junior Vault
echo "📊 JUNIOR VAULT"
echo "---------------"
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{\"query\":\"{ user(id: \\\"$USER_ADDRESS\\\") { id totalDeposited totalWithdrawn } }\"}" \
  https://api.goldsky.com/api/public/project_cmjh1lmjigfeb010c2rvw26vw/subgraphs/liquid-royalty-junior/v2.0.1/gn | jq '.'
echo ""
echo ""

# Test Reserve Vault
echo "📊 RESERVE VAULT"
echo "----------------"
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{\"query\":\"{ user(id: \\\"$USER_ADDRESS\\\") { id totalDeposited totalWithdrawn } }\"}" \
  https://api.goldsky.com/api/public/project_cmjh1lmjigfeb010c2rvw26vw/subgraphs/liquid-royalty-alar/v2.0.1/gn | jq '.'
echo ""

echo "✅ Tests complete!"
echo ""
echo "If you see data above, your indexers are working! 🎉"

