#!/bin/bash
# Generate calldata for upgrade initializers
# Usage: ./script/generate_upgrade_calldata.sh

echo "========================================"
echo "  UPGRADE CALLDATA GENERATOR"
echo "========================================"
echo ""

# V4 initializer (no params)
echo "📦 initializeV4() - Senior Vault V4 Migration"
echo "   Selector: $(cast sig 'initializeV4()')"
echo "   Calldata: $(cast calldata 'initializeV4()')"
echo ""

# V3 initializer (no params)
echo "📦 initializeV3() - Reentrancy Guard"
echo "   Selector: $(cast sig 'initializeV3()')"
echo "   Calldata: $(cast calldata 'initializeV3()')"
echo ""

# V2 initializer (with params)
echo "📦 initializeV2(address,address,address) - Role Setup"
echo "   Selector: $(cast sig 'initializeV2(address,address,address)')"
echo "   Example calldata (with placeholder addresses):"
echo "   $(cast calldata 'initializeV2(address,address,address)' 0x0000000000000000000000000000000000000001 0x0000000000000000000000000000000000000002 0x0000000000000000000000000000000000000003)"
echo ""

echo "========================================"
echo "  USAGE EXAMPLES"
echo "========================================"
echo ""

echo "# Upgrade to V4 (Senior Vault):"
echo 'cast send $SENIOR_PROXY \'
echo '  "upgradeToAndCall(address,bytes)" \'
echo '  $NEW_IMPL \'
echo "  $(cast calldata 'initializeV4()') \\"
echo '  --private-key $ADMIN_KEY \'
echo '  --rpc-url $RPC_URL'
echo ""

echo "# Or with hardcoded bytes:"
echo 'cast send $SENIOR_PROXY \'
echo '  "upgradeToAndCall(address,bytes)" \'
echo '  $NEW_IMPL \'
echo "  0x54a08606 \\"
echo '  --private-key $ADMIN_KEY \'
echo '  --rpc-url $RPC_URL'
echo ""

echo "========================================"
echo "  QUICK REFERENCE"
echo "========================================"
echo ""
echo "Function                              | Calldata"
echo "--------------------------------------|------------------"
echo "initializeV4()                        | 0x54a08606"
echo "initializeV3()                        | 0x38e454b1"
echo "initializeV2(addr,addr,addr)          | 0x2c3bb44a + params"
echo ""

echo "========================================"
echo "  GENERATE CUSTOM CALLDATA"
echo "========================================"
echo ""
echo "# For any function:"
echo "cast calldata 'functionName(type1,type2)' arg1 arg2"
echo ""
echo "# Examples:"
echo "cast calldata 'initializeV4()'"
echo "cast calldata 'setRole(uint8,address)' 0 0x1234...abcd"
echo "cast calldata 'migrateUsers(address[])' '[0xUser1,0xUser2]'"

