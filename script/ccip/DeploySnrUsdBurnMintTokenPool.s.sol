// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {ITokenPoolFactory} from "../../src/ccip/ITokenPoolFactory.sol";

/// @notice CCIP BurnMintTokenPool 2.0.0 deploy helper (dry-run by default).
/// @dev Run bytecode export in chainlink-ccip for `BurnMintTokenPool` init code (see docs/meta_senior_path1_upgrade.md).
contract DeploySnrUsdBurnMintTokenPool is Script {
    address internal constant BERA_FACTORY = 0x961971D9Ef1D61e2EEAC94c50De96D600797DFE9;
    address internal constant BERA_TOKEN = 0xC38421E5577250EBa177Bc5bC832E747bea13Ee0;
    address internal constant BERA_SAFE = 0xd60c3A29Fbe444cF9d3AA240F4a9263BC83bde61;
    uint64 internal constant BERA_REMOTE_SELECTOR = 15971525489660198786;

    address internal constant BASE_FACTORY = 0x8cE19F73e85a68490e08c89b510215Ca71B0F2B8;
    address internal constant BASE_TOKEN = 0xdB3A54CBC468e8D99d7522579174E0733D548507;
    address internal constant BASE_SAFE = 0xc6EAa8A2D727bCb74316D4C93Ca25D164B0Ad91e;
    uint64 internal constant BASE_REMOTE_SELECTOR = 1294465214383781161;

    bytes32 internal constant USER_SALT = keccak256("LiquidRoyalty-snrUSD-Path1-v1");
    uint8 internal constant POOL_TYPE_BURN_MINT = 0;

    function run() external {
        uint256 chain = block.chainid;
        require(chain == 80094 || chain == 8453, "Set --rpc-url to Berachain or Base");

        address factoryAddr = chain == 80094 ? BERA_FACTORY : BASE_FACTORY;
        address token = chain == 80094 ? BERA_TOKEN : BASE_TOKEN;
        address futureOwner = chain == 80094 ? BERA_SAFE : BASE_SAFE;
        bool broadcast = vm.envOr("SNRUSD_POOL_BROADCAST", false);

        bytes memory poolInitCode = vm.envOr("BURN_MINT_POOL_INIT_CODE", bytes(""));

        ITokenPoolFactory factory = ITokenPoolFactory(factoryAddr);
        (address rmn, address tar, address registryModule, address router) = factory.getStaticConfig();

        console2.log("=== snrUSD BurnMintTokenPool 2.0.0 ===");
        console2.log("chainId", chain);
        console2.log("factory", factoryAddr);
        console2.log("token", token);
        console2.log("futureOwner", futureOwner);
        console2.log("router", router);
        console2.log("rmn", rmn);
        console2.log("tokenAdminRegistry", tar);
        console2.log("registryModuleOwnerCustom", registryModule);
        console2.log("userSalt", vm.toString(USER_SALT));
        console2.log("rateLimit: capacity=1000e18 rate=1 (FTF buckets disabled in RemoteTokenPoolInfo defaults)");
        console2.log("broadcast", broadcast);

        if (poolInitCode.length == 0) {
            console2.log("Set BURN_MINT_POOL_INIT_CODE from chainlink-ccip BurnMintTokenPool creationCode.");
            return;
        }

        ITokenPoolFactory.RemoteTokenPoolInfo[] memory remotePools = new ITokenPoolFactory.RemoteTokenPoolInfo[](1);
        remotePools[0] = ITokenPoolFactory.RemoteTokenPoolInfo({
            remoteChainSelector: chain == 80094 ? BERA_REMOTE_SELECTOR : BASE_REMOTE_SELECTOR,
            remotePoolAddress: bytes(""),
            remotePoolInitCode: poolInitCode,
            remoteChainConfig: ITokenPoolFactory.RemoteChainConfig({
                remotePoolFactory: chain == 80094 ? BASE_FACTORY : BERA_FACTORY,
                remoteRouter: chain == 80094 ? 0x881e3A65B4d4a04dD529061dd0071cf975F58bCD : 0x71a275704c283486fBa26dad3dd0DB78804426eF,
                remoteRMNProxy: chain == 80094
                    ? 0xC842c69d54F83170C42C4d556B4F6B2ca53Dd3E8
                    : 0x25943b8C30C47F4eF09CcF2BAE315EbaF591881d,
                remoteLockBox: address(0),
                remoteTokenDecimals: 18
            }),
            poolType: POOL_TYPE_BURN_MINT,
            remoteTokenAddress: abi.encode(chain == 80094 ? BASE_TOKEN : BERA_TOKEN),
            remoteTokenInitCode: hex"",
            rateLimiterConfig: ITokenPoolFactory.RateLimitConfig({isEnabled: true, capacity: uint128(1000e18), rate: 1})
        });

        if (broadcast) {
            uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
            vm.startBroadcast(pk);
            address pool = factory.deployTokenPoolWithExistingToken(
                token, 18, POOL_TYPE_BURN_MINT, remotePools, poolInitCode, address(0), USER_SALT, futureOwner
            );
            vm.stopBroadcast();
            console2.log("deployedPool", pool);
        }
    }
}