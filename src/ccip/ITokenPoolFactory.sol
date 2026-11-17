// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface ITokenPoolFactory {
    struct RemoteChainConfig {
        address remotePoolFactory;
        address remoteRouter;
        address remoteRMNProxy;
        address remoteLockBox;
        uint8 remoteTokenDecimals;
    }

    struct RemoteTokenPoolInfo {
        uint64 remoteChainSelector;
        bytes remotePoolAddress;
        bytes remotePoolInitCode;
        RemoteChainConfig remoteChainConfig;
        uint8 poolType;
        bytes remoteTokenAddress;
        bytes remoteTokenInitCode;
        RateLimitConfig rateLimiterConfig;
    }

    struct RateLimitConfig {
        bool isEnabled;
        uint128 capacity;
        uint128 rate;
    }

    function getStaticConfig()
        external
        view
        returns (address rmnProxy, address tokenAdminRegistry, address registryModuleOwnerCustom, address ccipRouter);

    function deployTokenPoolWithExistingToken(
        address token,
        uint8 localTokenDecimals,
        uint8 localPoolType,
        RemoteTokenPoolInfo[] calldata remoteTokenPools,
        bytes calldata tokenPoolInitCode,
        address lockBox,
        bytes32 salt,
        address futureOwner
    ) external returns (address poolAddress);
}