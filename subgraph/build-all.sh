#!/bin/bash

# Build all 3 subgraphs at once

set -e

echo "🔨 Building all Liquid Royalty subgraphs..."
echo ""

# Build Senior
echo "📊 Building Senior Vault..."
cd senior
npx graph codegen
npx graph build
cd ..
echo "✅ Senior built"
echo ""

# Build Junior
echo "📊 Building Junior Vault..."
cd junior
npx graph codegen
npx graph build
cd ..
echo "✅ Junior built"
echo ""

# Build Reserve
echo "📊 Building Reserve Vault..."
cd reserve
npx graph codegen
npx graph build
cd ..
echo "✅ Reserve built"
echo ""

echo "🎉 All subgraphs built successfully!"
echo ""
echo "Deploy with:"
echo "  cd senior && goldsky subgraph deploy liquid-royalty-senior/v2.0.0 --path ."
echo "  cd junior && goldsky subgraph deploy liquid-royalty-junior/v2.0.0 --path ."
echo "  cd reserve && goldsky subgraph deploy liquid-royalty-reserve/v2.0.0 --path ."

