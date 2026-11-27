// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {JuniorYieldRouter} from "../src/concrete/JuniorYieldRouter.sol";

/// @notice Base mainnet (chain 8453) Junior Yield Router — simulation by default (no broadcast).
/// @dev Does not broadcast unless `JUNIOR_YIELD_ROUTER_BROADCAST=true`; no private keys required for dry-run.
///
/// Production constructor args (Base):
///   USDe:        0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34
///   Destination: 0x88849e4c4e01E2ca8d9BA3bd5EF24B05F70aa771 (Junior Safe)
///   Admin:       0xc6EAa8A2D727bCb74316D4C93Ca25D164B0Ad91e (Admin Safe)
///
/// Dry-run:
///   forge script script/DeployJuniorYieldRouter.s.sol:DeployJuniorYieldRouter \
///     --rpc-url https://mainnet.base.org
///
/// Broadcast + verify (operator machine only — requires DEPLOYER_PRIVATE_KEY and BASESCAN_API_KEY):
///   forge script script/DeployJuniorYieldRouter.s.sol:DeployJuniorYieldRouter \
///     --rpc-url $BASE_RPC_URL \
///     --broadcast \
///     --verify \
///     --verifier etherscan \
///     --etherscan-api-key $BASESCAN_API_KEY \
///     --chain-id 8453
///
/// After deploy, verify manually if needed:
///   forge verify-contract <DEPLOYED_ADDRESS> src/concrete/JuniorYieldRouter.sol:JuniorYieldRouter \
///     --chain-id 8453 \
///     --etherscan-api-key $BASESCAN_API_KEY \
///     --constructor-args $(cast abi-encode "constructor(address,address,address)" \
///       0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34 \
///       0x88849e4c4e01E2ca8d9BA3bd5EF24B05F70aa771 \
///       0xc6EAa8A2D727bCb74316D4C93Ca25D164B0Ad91e)
contract DeployJuniorYieldRouter is Script {
    address internal constant BASE_USDE = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34;
    address internal constant JUNIOR_SAFE = 0x88849e4c4e01E2ca8d9BA3bd5EF24B05F70aa771;
    address internal constant ADMIN_SAFE = 0xc6EAa8A2D727bCb74316D4C93Ca25D164B0Ad91e;

    function run() external {
        bool simulateAnyChain = vm.envOr("JUNIOR_YIELD_ROUTER_SKIP_CHAIN_CHECK", false);
        if (!simulateAnyChain) {
            require(block.chainid == 8453, "Wrong chain: expected Base mainnet (8453)");
        }

        address usde = vm.envOr("JUNIOR_YIELD_ROUTER_USDE", BASE_USDE);
        address destination = vm.envOr("JUNIOR_YIELD_ROUTER_DESTINATION", JUNIOR_SAFE);
        address admin = vm.envOr("JUNIOR_YIELD_ROUTER_ADMIN", ADMIN_SAFE);

        bool shouldBroadcast = vm.envOr("JUNIOR_YIELD_ROUTER_BROADCAST", false);

        console2.log("=== Junior Yield Router (Base) deploy ===");
        console2.log("chainId", block.chainid);
        console2.log("usde", usde);
        console2.log("destination (Junior Safe)", destination);
        console2.log("admin", admin);
        console2.log("broadcast", shouldBroadcast);

        JuniorYieldRouter deployed;

        if (shouldBroadcast) {
            uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
            vm.startBroadcast(deployerPrivateKey);
            deployed = new JuniorYieldRouter(usde, destination, admin);
            vm.stopBroadcast();
        } else {
            deployed = new JuniorYieldRouter(usde, destination, admin);
        }

        console2.log("JuniorYieldRouter", address(deployed));
        console2.log("DESTINATION", deployed.DESTINATION());
        require(deployed.hasRole(deployed.DEFAULT_ADMIN_ROLE(), admin), "Admin role missing");

        console2.log("Done. Set JUNIOR_YIELD_ROUTER_BROADCAST=true and DEPLOYER_PRIVATE_KEY to broadcast.");
    }
}