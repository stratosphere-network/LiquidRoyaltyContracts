// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {BaseSeniorVault} from "../src/concrete/BaseSeniorVault.sol";

/// @notice Base mainnet (chain 8453) snrUSD deploy script — dry-run unless `BASE_SNRUSD_BROADCAST=true`.
/// @dev Does not broadcast in CI; no private keys required for simulation.
/// @dev Live deployment (Base 8453): proxy `0xdB3A54CBC468e8D99d7522579174E0733D548507`, implementation `0x920B83197484Ea410a9c9F28d9C39D5183eAD311`.
contract DeployBaseSeniorVault is Script {
  /// @dev Base USDe — verify on-chain before deployment (must have contract code).
  address internal constant BASE_USDE = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34;
  address internal constant FEE_ADDRESS = 0x23FD5F6e2B07970c9B00D1da8E85c201711B7b74;
  address internal constant DEFAULT_ADMIN_SAFE = 0xc6EAa8A2D727bCb74316D4C93Ca25D164B0Ad91e;

  function run() external {
    require(block.chainid == 8453, "Wrong chain: expected Base mainnet (8453)");

    address admin = vm.envOr("BASE_SNRUSD_ADMIN", DEFAULT_ADMIN_SAFE);
    address operator = vm.envOr("BASE_SNRUSD_OPERATOR", admin);
    address feeAddress = vm.envOr("BASE_SNRUSD_FEE_ADDRESS", FEE_ADDRESS);
    address usde = vm.envOr("BASE_SNRUSD_USDE", BASE_USDE);
    address liquidityManager = vm.envOr("BASE_SNRUSD_LMV", address(0));

    bool shouldBroadcast = vm.envOr("BASE_SNRUSD_BROADCAST", false);

    console2.log("=== Base Senior Vault (snrUSD) deploy ===");
    console2.log("chainId", block.chainid);
    console2.log("admin", admin);
    console2.log("operator", operator);
    console2.log("feeAddress", feeAddress);
    console2.log("usde", usde);
    console2.log("liquidityManagerVault", liquidityManager);
    console2.log("broadcast", shouldBroadcast);

    uint256 deployerPrivateKey = 0;
    address deployer = address(0);
    if (shouldBroadcast) {
      deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
      deployer = vm.addr(deployerPrivateKey);
    }

    bytes memory initData = abi.encodeCall(
      BaseSeniorVault.initialize,
      (usde, operator, feeAddress, liquidityManager)
    );

    address impl;
    address proxy;

    if (shouldBroadcast) {
      vm.startBroadcast(deployerPrivateKey);

      impl = address(new BaseSeniorVault(admin));
      proxy = address(new ERC1967Proxy(impl, initData));

      vm.stopBroadcast();
    } else {
      impl = address(new BaseSeniorVault(admin));
      proxy = address(new ERC1967Proxy(impl, initData));
    }

    BaseSeniorVault vault = BaseSeniorVault(proxy);

    console2.log("implementation", impl);
    console2.log("proxy", proxy);
    console2.log("name", vault.name());
    console2.log("symbol", vault.symbol());
    console2.log("vaultOpenToPublic", vault.vaultOpenToPublic());
    console2.log("depositCap", vault.depositCap());
    console2.log("feeAddress", vault.feeAddress());
    console2.log("liquidityManagerVault", vault.liquidityManagerVault());

    require(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), admin), "Admin role missing");
    require(vault.hasRole(vault.OPERATOR_ROLE(), operator), "Operator role missing");

    if (shouldBroadcast && deployer != address(0)) {
      require(!vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), deployer), "Deployer retained admin");
      require(!vault.hasRole(vault.OPERATOR_ROLE(), deployer), "Deployer retained operator");
      require(!vault.hasRole(vault.MINTER_ROLE(), deployer), "Deployer retained minter");
      require(!vault.hasRole(vault.BURNER_ROLE(), deployer), "Deployer retained burner");
    } else {
      console2.log("dry-run: deployer role hygiene skipped (no broadcast sender)");
    }

    console2.log("Done. Set BASE_SNRUSD_BROADCAST=true and DEPLOYER_PRIVATE_KEY to broadcast.");
  }
}