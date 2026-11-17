// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {BaseSeniorVault} from "../src/concrete/BaseSeniorVault.sol";

/// @notice Deploy a fresh `BaseSeniorVault` implementation for UUPS upgrade on Base mainnet (8453).
/// @dev Does not deploy a proxy and does not call `initialize` on the live proxy.
/// @dev Live proxy: `0xdB3A54CBC468e8D99d7522579174E0733D548507` — after deploy, the Base Safe admin calls
///      `upgradeToAndCall(newImpl, 0x)` on that proxy.
///
/// Env vars (simulation needs only `BASE_SNRUSD_ADMIN` or the default Safe below):
/// - `BASE_SNRUSD_ADMIN` — passed to the implementation constructor as `initialAdmin` (matches live: Safe `0xc6EA...`).
/// - `BASE_SNRUSD_IMPLEMENTATION_BROADCAST` — set `true` to broadcast (default false: dry-run deploy only).
/// - `DEPLOYER_PRIVATE_KEY` — required when broadcast is true; never log or echo this value.
///
/// Example dry-run:
///   forge script script/DeployBaseSeniorVaultImplementation.s.sol --rpc-url $BASE_RPC_URL
///
/// Example broadcast + verify (Moss / ops):
///   BASE_SNRUSD_IMPLEMENTATION_BROADCAST=true forge script script/DeployBaseSeniorVaultImplementation.s.sol \
///     --rpc-url $BASE_RPC_URL --broadcast --verify
contract DeployBaseSeniorVaultImplementation is Script {
    address internal constant DEFAULT_ADMIN_SAFE = 0xc6EAa8A2D727bCb74316D4C93Ca25D164B0Ad91e;
    address internal constant LIVE_PROXY = 0xdB3A54CBC468e8D99d7522579174E0733D548507;

    function run() external {
        require(block.chainid == 8453, "Wrong chain: expected Base mainnet (8453)");

        address admin = vm.envOr("BASE_SNRUSD_ADMIN", DEFAULT_ADMIN_SAFE);
        bool shouldBroadcast = vm.envOr("BASE_SNRUSD_IMPLEMENTATION_BROADCAST", false);

        console2.log("=== BaseSeniorVault implementation deploy (upgrade prep) ===");
        console2.log("chainId", block.chainid);
        console2.log("initialAdmin (constructor)", admin);
        console2.log("live proxy (not upgraded by this script)", LIVE_PROXY);
        console2.log("broadcast", shouldBroadcast);

        address impl;

        if (shouldBroadcast) {
            uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
            vm.startBroadcast(deployerPrivateKey);
            impl = address(new BaseSeniorVault(admin));
            vm.stopBroadcast();
        } else {
            impl = address(new BaseSeniorVault(admin));
        }

        console2.log("new implementation", impl);
        console2.log("Next step: Base Safe upgradeToAndCall(proxy, newImpl, 0x)");
    }
}