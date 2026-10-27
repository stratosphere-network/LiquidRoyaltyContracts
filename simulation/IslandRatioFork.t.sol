// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "forge-std/StdStorage.sol";

/// @dev Re-fork with Island pool forced toward 10 USDe : 1 COMPUTE.r (token0:token1 amounts),
///      then run the standard seed flow and compare NAV steps vs live skewed pool.
contract IslandRatioForkTest is Test {
    using stdStorage for StdStorage;

    address constant SENIOR = 0xeb04926d24b9526D847498153C88d80296F1bb73;
    address constant JUNIOR = 0x3499a7FFB37Dbd4d0d94c203614C093314FD937f;
    address constant ISLAND = 0x40E8Fa74792274d9d9A328D41324E9d5199C0A16;
    address constant ISLAND_IMPL = 0xCFe9Ee61c271fBA4D190498b5A71B8CB365a3590;
    address constant CL_POOL = 0xe97cAA346252C23b5C4C7771b5af75DC997cA65B;
    address constant USDE = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34;
    address constant COMPUTE = 0xB8CD0b8E056A91c00FD388EdDb37E6E445844B21;

    address constant KODI_TOKEN_TRANSFERRER = 0xE532DFede91f04B12a73d3d2Acd361424F41f76B;
    address constant OPERATOR = 0xE90986e67A9cbEbcF67084cbBF8E24FAa0a43Bcb;
    address constant ADMIN_SAFE = 0xd60c3A29Fbe444cF9d3AA240F4a9263BC83bde61;

    uint256 constant TARGET_USDE_PER_COMPUTE = 10; // 10 USDe per 1 COMPUTE.r (18-dec token amounts)

    struct PoolSnap {
        uint256 poolUsde;
        uint256 poolCompute;
        uint256 islandAmount0;
        uint256 islandAmount1;
        uint256 islandSupply;
        uint256 lpForOneMillionUsdeSide;
    }

    function testCompareSkewedVsTenToOneRatio() public {
        vm.createSelectFork("https://rpc.berachain.com");

        PoolSnap memory skew = _poolSnapshot();
        _logPool("SKEWED (live fork)", skew);

        _runFlow("SKEWED", skew.lpForOneMillionUsdeSide, false);

        // Re-fork clean state for 10:1 scenario
        vm.createSelectFork("https://rpc.berachain.com");
        PoolSnap memory rebalanced = _forceTenToOnePool();
        _logPool("REBALANCED 10 USDe : 1 COMPUTE", rebalanced);

        _runFlow("REBALANCED", rebalanced.lpForOneMillionUsdeSide, true);
    }

    function _forceTenToOnePool() internal returns (PoolSnap memory snap) {
        snap = _poolSnapshot();

        // 1) Uniswap V3 sqrtPrice: token1/token0 = COMPUTE/USDe = 0.1 (10 USDe per 1 COMPUTE.r).
        uint160 sqrtPriceX96 = _sqrtPriceX96ForRatio(1e17);
        _setPoolSqrtPriceX96(sqrtPriceX96);

        // 2) CL pool ERC20 balances at 10:1 (same order of magnitude as live pool, not inflated deals).
        uint256 computeBase = 7e18;
        uint256 usdeBase = computeBase * TARGET_USDE_PER_COMPUTE;
        deal(USDE, CL_POOL, usdeBase);
        deal(COMPUTE, CL_POOL, computeBase);

        // 3) Island underlying view aligned for LP sizing (vault `totalAssets` still reads CL pool + LP).
        vm.mockCall(
            ISLAND,
            abi.encodeWithSignature("getUnderlyingBalances()"),
            abi.encode(usdeBase, computeBase)
        );

        snap = _poolSnapshot();
        return snap;
    }

    function _sqrtPriceX96ForRatio(uint256 token1PerToken0_1e18) internal pure returns (uint160) {
        // sqrtPriceX96 = sqrt(token1/token0) * 2^96
        uint256 ratio = token1PerToken0_1e18; // already 1e18-scaled
        uint256 sqrtRatio = _sqrt(ratio * 1e18); // sqrt(ratio) with 1e18 precision
        uint256 sqrtPriceX96 = (sqrtRatio * (uint256(1) << 96)) / 1e18;
        return uint160(sqrtPriceX96);
    }

    function _sqrt(uint256 x) internal pure returns (uint256 z) {
        if (x == 0) return 0;
        z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    /// @dev Uniswap V3 slot0: slot 0 packs sqrtPriceX96 (lower 160 bits).
    function _setPoolSqrtPriceX96(uint160 sqrtPriceX96) internal {
        bytes32 slot0 = bytes32(vm.load(CL_POOL, bytes32(uint256(0))));
        uint256 cleared = uint256(slot0) & ~uint256(type(uint160).max);
        vm.store(CL_POOL, bytes32(uint256(0)), bytes32(cleared | uint256(sqrtPriceX96)));
    }

    function _poolSnapshot() internal view returns (PoolSnap memory s) {
        s.poolUsde = IERC20(USDE).balanceOf(CL_POOL);
        s.poolCompute = IERC20(COMPUTE).balanceOf(CL_POOL);
        s.islandSupply = IKodiakIsland(ISLAND).totalSupply();
        (s.islandAmount0, s.islandAmount1) = IKodiakIsland(ISLAND).getUnderlyingBalances();
        if (s.islandAmount0 > 0) {
            s.lpForOneMillionUsdeSide = (1_000_000e18 * s.islandSupply) / s.islandAmount0;
        }
    }

    function _logPool(string memory label, PoolSnap memory s) internal view {
        console2.log("----", label);
        console2.log("CL pool USDe", s.poolUsde);
        console2.log("CL pool COMPUTE", s.poolCompute);
        if (s.poolCompute > 0) {
            console2.log("pool USDe/COMPUTE (1e18)", s.poolUsde * 1e18 / s.poolCompute);
        }
        console2.log("Island amount0 USDe", s.islandAmount0);
        console2.log("Island amount1 COMPUTE", s.islandAmount1);
        if (s.islandAmount1 > 0) {
            console2.log("Island amount0/amount1 (1e18)", s.islandAmount0 * 1e18 / s.islandAmount1);
        }
        console2.log("Island LP supply", s.islandSupply);
        console2.log("LP for ~$1M (1e6*supply/amount0)", s.lpForOneMillionUsdeSide);
    }

    function _runFlow(string memory tag, uint256 lpAmount, bool rebalanced) internal {
        console2.log("======== FLOW", tag);
        _snapVaults(tag, 0, "baseline");

        _adminConfigureAndMint(SENIOR);
        _adminConfigureAndMint(JUNIOR);
        _snapVaults(tag, 1, "after adminMintShares 1M");

        deal(ISLAND, KODI_TOKEN_TRANSFERRER, lpAmount * 2);
        vm.startPrank(KODI_TOKEN_TRANSFERRER);
        IERC20(ISLAND).transfer(SENIOR, lpAmount);
        IERC20(ISLAND).transfer(JUNIOR, lpAmount);
        vm.stopPrank();
        _snapVaults(tag, 2, "after Island LP on vault bodies");

        vm.prank(OPERATOR);
        IVault(SENIOR).transferToLiquidityManager(lpAmount, ISLAND);
        vm.prank(OPERATOR);
        IVault(JUNIOR).transferToLiquidityManager(lpAmount, ISLAND);
        _snapVaults(tag, 3, "after transferToLiquidityManager");

        if (rebalanced) {
            uint256 ta = IVault(SENIOR).totalAssets();
            console2.log("Senior totalAssets vs 1M target (1e24)", ta);
            console2.log("Within 5% of 1M", ta > 95e23 && ta < 105e23);
        }
    }

    function _adminConfigureAndMint(address vault) internal {
        vm.startPrank(ADMIN_SAFE);
        IVault(vault).setWhitelistedMintAddress(KODI_TOKEN_TRANSFERRER, true);
        IVault(vault).adminMintShares(KODI_TOKEN_TRANSFERRER, 1_000_000e18, "kodi-seed");
        vm.stopPrank();
    }

    function _snapVaults(string memory tag, uint256 step, string memory label) internal view {
        console2.log("--- flow step", step);
        console2.log("tag", tag);
        console2.log("label", label);
        _vaultLine("Senior", SENIOR);
        _vaultLine("Junior", JUNIOR);
    }

    function _vaultLine(string memory name, address vault) internal view {
        address lmv = IVault(vault).liquidityManagerVault();
        uint256 ts = IERC20(vault).totalSupply();
        uint256 ta = IVault(vault).totalAssets();
        uint256 gvv = IVault(vault).getVaultValue();
        uint256 cta = ts > 0 ? IVault(vault).convertToAssets(1e18) : 0;
        uint256 pps = ts == 0 ? 0 : (ta * 1e18) / ts;
        uint256 lpBal = IERC20(ISLAND).balanceOf(lmv);

        console2.log(name, "totalSupply", ts);
        console2.log(name, "totalAssets", ta);
        console2.log(name, "getVaultValue", gvv);
        console2.log(name, "convertToAssets(1e18)", cta);
        console2.log(name, "PPS", pps);
        console2.log(name, "Island on LMV", lpBal);
        if (lpBal > 0 && ta > 0) {
            console2.log(name, "totalAssets*1e18/LP", ta * 1e18 / lpBal);
        }
    }
}

interface IVault {
    function setWhitelistedMintAddress(address, bool) external;
    function adminMintShares(address, uint256, string memory) external;
    function transferToLiquidityManager(uint256, address) external;
    function liquidityManagerVault() external view returns (address);
    function totalAssets() external view returns (uint256);
    function getVaultValue() external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

interface IKodiakIsland {
    function totalSupply() external view returns (uint256);
    function getUnderlyingBalances() external view returns (uint256, uint256);
}
