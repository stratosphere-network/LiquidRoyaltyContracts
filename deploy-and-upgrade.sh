#!/bin/bash

# Deploy and Upgrade Script
# Usage: ./deploy-and-upgrade.sh

set -e

echo "=========================================="
echo "Stratosphere Vault Deployment & Upgrade"
echo "=========================================="
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "Error: .env file not found!"
    exit 1
fi

# Source .env
source .env

# Check required variables
if [ -z "$PRIVATE_KEY" ] || [ -z "$RPC_URL" ] || [ -z "$ETHERSCAN_API_KEY" ]; then
    echo "Error: Missing required environment variables!"
    echo "Required: PRIVATE_KEY, RPC_URL, ETHERSCAN_API_KEY"
    exit 1
fi

echo "Options:"
echo "1) Deploy implementations only"
echo "2) Upgrade proxies (manual - need to set addresses)"
echo "3) Deploy AND upgrade (all-in-one)"
echo ""
read -p "Select option [1-3]: " option

case $option in
    1)
        echo ""
        echo "Deploying new implementations..."
        forge script script/DeployNewImplementations.s.sol:DeployNewImplementations \
            --rpc-url $RPC_URL \
            --broadcast \
            --verify \
            --etherscan-api-key $ETHERSCAN_API_KEY \
            -vvv
        ;;
    2)
        echo ""
        echo "WARNING: Make sure you've set the implementation addresses in UpgradeToNewImplementations.s.sol!"
        read -p "Continue? [y/N]: " confirm
        if [ "$confirm" != "y" ]; then
            echo "Cancelled"
            exit 0
        fi
        
        forge script script/UpgradeToNewImplementations.s.sol:UpgradeToNewImplementations \
            --rpc-url $RPC_URL \
            --broadcast \
            -vvv
        ;;
    3)
        echo ""
        echo "Deploying implementations and upgrading proxies..."
        read -p "This will upgrade all vaults. Continue? [y/N]: " confirm
        if [ "$confirm" != "y" ]; then
            echo "Cancelled"
            exit 0
        fi
        
        forge script script/DeployAndUpgradeAll.s.sol:DeployAndUpgradeAll \
            --rpc-url $RPC_URL \
            --broadcast \
            --verify \
            --etherscan-api-key $ETHERSCAN_API_KEY \
            -vvv
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

echo ""
echo "=========================================="
echo "Done!"
echo "=========================================="

