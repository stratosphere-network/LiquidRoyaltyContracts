#!/bin/bash

# Extract ABIs from Forge artifacts and save to abi/ folder

ABI_DIR="abi"
OUT_DIR="out"

echo "🔧 Extracting ABIs to ${ABI_DIR}/ folder..."

# Main deployable contracts
echo "Extracting vault ABIs..."
jq '.abi' ${OUT_DIR}/UnifiedConcreteSeniorVault.sol/UnifiedConcreteSeniorVault.json > ${ABI_DIR}/UnifiedConcreteSeniorVault.json
jq '.abi' ${OUT_DIR}/ConcreteJuniorVault.sol/ConcreteJuniorVault.json > ${ABI_DIR}/ConcreteJuniorVault.json
jq '.abi' ${OUT_DIR}/ConcreteReserveVault.sol/ConcreteReserveVault.json > ${ABI_DIR}/ConcreteReserveVault.json

# Hooks
echo "Extracting hook ABIs..."
jq '.abi' ${OUT_DIR}/KodiakVaultHook.sol/KodiakVaultHook.json > ${ABI_DIR}/KodiakVaultHook.json

# Interfaces (for frontend type safety)
echo "Extracting interface ABIs..."
jq '.abi' ${OUT_DIR}/ISeniorVault.sol/ISeniorVault.json > ${ABI_DIR}/ISeniorVault.json
jq '.abi' ${OUT_DIR}/IVault.sol/IVault.json > ${ABI_DIR}/IVault.json
jq '.abi' ${OUT_DIR}/IKodiakVaultHook.sol/IKodiakVaultHook.json > ${ABI_DIR}/IKodiakVaultHook.json
jq '.abi' ${OUT_DIR}/IKodiakIsland.sol/IKodiakIsland.json > ${ABI_DIR}/IKodiakIsland.json
jq '.abi' ${OUT_DIR}/IKodiakIslandRouter.sol/IKodiakIslandRouter.json > ${ABI_DIR}/IKodiakIslandRouter.json

# Abstract contracts (useful for understanding inheritance)
echo "Extracting abstract contract ABIs..."
jq '.abi' ${OUT_DIR}/BaseVault.sol/BaseVault.json > ${ABI_DIR}/BaseVault.json
jq '.abi' ${OUT_DIR}/UnifiedSeniorVault.sol/UnifiedSeniorVault.json > ${ABI_DIR}/UnifiedSeniorVault.json
jq '.abi' ${OUT_DIR}/JuniorVault.sol/JuniorVault.json > ${ABI_DIR}/JuniorVault.json
jq '.abi' ${OUT_DIR}/ReserveVault.sol/ReserveVault.json > ${ABI_DIR}/ReserveVault.json

# ERC20 (for token interactions)
echo "Extracting ERC20 ABI..."
jq '.abi' ${OUT_DIR}/ERC20.sol/ERC20.json > ${ABI_DIR}/ERC20.json

echo "✅ ABI extraction complete!"
echo ""
echo "📂 ABIs saved to ${ABI_DIR}/ folder:"
ls -lh ${ABI_DIR}/*.json | awk '{print "  -", $9, "(" $5 ")"}'

