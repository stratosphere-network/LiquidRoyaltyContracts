// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {ITokenPoolFactory} from "../../src/ccip/ITokenPoolFactory.sol";

/// @notice Production-style BurnMintTokenPool 2.0.0 deploy (wJNR pattern). Dry-run by default.
contract DeploySnrUsdBurnMintTokenPool is Script {
    address internal constant DEPLOYER = 0x271e6335145685345078b08Bd1C2168Ea4D9b086;

    address internal constant BERA_FACTORY = 0x961971D9Ef1D61e2EEAC94c50De96D600797DFE9;
    address internal constant BERA_TOKEN = 0xC38421E5577250EBa177Bc5bC832E747bea13Ee0;
    address internal constant BERA_SAFE = 0xd60c3A29Fbe444cF9d3AA240F4a9263BC83bde61;
    address internal constant BERA_RMN = 0x25943b8C30C47F4eF09CcF2BAE315EbaF591881d;
    address internal constant BERA_ROUTER = 0x71a275704c283486fBa26dad3dd0DB78804426eF;
    uint64 internal constant BERA_REMOTE_SELECTOR = 15971525489660198786;

    address internal constant BASE_FACTORY = 0x8cE19F73e85a68490e08c89b510215Ca71B0F2B8;
    address internal constant BASE_TOKEN = 0xdB3A54CBC468e8D99d7522579174E0733D548507;
    address internal constant BASE_SAFE = 0xc6EAa8A2D727bCb74316D4C93Ca25D164B0Ad91e;
    address internal constant BASE_RMN = 0xC842c69d54F83170C42C4d556B4F6B2ca53Dd3E8;
    address internal constant BASE_ROUTER = 0x881e3A65B4d4a04dD529061dd0071cf975F58bCD;
    uint64 internal constant BASE_REMOTE_SELECTOR = 1294465214383781161;

    bytes32 internal constant USER_SALT = keccak256("LiquidRoyalty:snrUSD:BurnMintTokenPool:v1");
    uint8 internal constant POOL_TYPE_BURN_MINT = 0;
    uint256 internal constant POOL_CREATION_CODE_LEN = 23_986;
    uint128 internal constant RATE_CAPACITY = 1000 ether;
    uint128 internal constant RATE_PER_SECOND = 11_574_074_074_074_074; // 1000e18 / 86400

    function run() external {
        uint256 chain = block.chainid;
        require(chain == 80094 || chain == 8453, "Use Berachain or Base RPC");

        bytes memory creationCode = vm.readFileBinary("script/bytecode/BurnMintTokenPool.v2.0.0.bin");
        require(creationCode.length == POOL_CREATION_CODE_LEN, "BurnMintTokenPool.v2.0.0.bin size mismatch");

        bool broadcast = vm.envOr("SNRUSD_POOL_BROADCAST", false);
        bytes32 effectiveSalt = keccak256(abi.encodePacked(USER_SALT, DEPLOYER));

        address localFactory = chain == 80094 ? BERA_FACTORY : BASE_FACTORY;
        address localToken = chain == 80094 ? BERA_TOKEN : BASE_TOKEN;
        address localRmn = chain == 80094 ? BERA_RMN : BASE_RMN;
        address localRouter = chain == 80094 ? BERA_ROUTER : BASE_ROUTER;
        address futureOwner = chain == 80094 ? BERA_SAFE : BASE_SAFE;

        address remoteToken = chain == 80094 ? BASE_TOKEN : BERA_TOKEN;
        address remoteFactory = chain == 80094 ? BASE_FACTORY : BERA_FACTORY;
        uint64 remoteSelector = chain == 80094 ? BERA_REMOTE_SELECTOR : BASE_REMOTE_SELECTOR;

        address predictedRemote = _predictPool(
            remoteFactory, remoteToken, chain == 80094 ? BASE_RMN : BERA_RMN, chain == 80094 ? BASE_ROUTER : BERA_ROUTER, creationCode, effectiveSalt
        );
        address predictedLocal = _predictPool(localFactory, localToken, localRmn, localRouter, creationCode, effectiveSalt);

        console2.log("=== snrUSD BurnMintTokenPool 2.0.0 (wJNR pattern) ===");
        console2.log("chainId", chain);
        console2.log("deployer", DEPLOYER);
        console2.log("userSalt");
        console2.logBytes32(USER_SALT);
        console2.log("effectiveSalt");
        console2.logBytes32(effectiveSalt);
        console2.log("predictedLocalPool", predictedLocal);
        console2.log("predictedRemotePool", predictedRemote);
        console2.log("rate capacity", RATE_CAPACITY);
        console2.log("rate per second", RATE_PER_SECOND);
        console2.log("expected pool typeAndVersion", "BurnMintTokenPool 2.0.0");
        console2.log("pool creation code bytes", creationCode.length);

        ITokenPoolFactory.RemoteTokenPoolInfo[] memory remotePools = new ITokenPoolFactory.RemoteTokenPoolInfo[](1);
        remotePools[0] = ITokenPoolFactory.RemoteTokenPoolInfo({
            remoteChainSelector: remoteSelector,
            remotePoolAddress: abi.encode(predictedRemote),
            remotePoolInitCode: "",
            remoteChainConfig: ITokenPoolFactory.RemoteChainConfig({
                remotePoolFactory: address(0),
                remoteRouter: address(0),
                remoteRMNProxy: address(0),
                remoteLockBox: address(0),
                remoteTokenDecimals: 18
            }),
            poolType: POOL_TYPE_BURN_MINT,
            remoteTokenAddress: abi.encode(remoteToken),
            remoteTokenInitCode: "",
            rateLimiterConfig: ITokenPoolFactory.RateLimitConfig({
                isEnabled: true,
                capacity: RATE_CAPACITY,
                rate: RATE_PER_SECOND
            })
        });

        if (broadcast) {
            uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
            require(vm.addr(pk) == DEPLOYER, "Deployer must be Moss EOA");
            vm.startBroadcast(pk);
            address deployed = ITokenPoolFactory(localFactory).deployTokenPoolWithExistingToken(
                localToken,
                18,
                POOL_TYPE_BURN_MINT,
                remotePools,
                creationCode,
                address(0),
                USER_SALT,
                futureOwner
            );
            vm.stopBroadcast();
            require(deployed == predictedLocal, "CREATE2 address mismatch");
            console2.log("deployedPool", deployed);
        } else {
            console2.log("Dry-run: predictions only (SNRUSD_POOL_BROADCAST=false)");
        }
    }

    function _predictPool(
        address factory,
        address token,
        address rmn,
        address router,
        bytes memory creationCode,
        bytes32 effectiveSalt
    ) internal pure returns (address) {
        bytes memory initCode = abi.encodePacked(
            creationCode,
            abi.encode(token, uint8(18), address(0), rmn, router)
        );
        return Create2.computeAddress(effectiveSalt, keccak256(initCode), factory);
    }
}