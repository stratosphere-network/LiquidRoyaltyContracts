// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

/// @title Exact $2M Island economics (1M USDe + 100k COMPUTE.r) → X LP → $1M NAV per vault
/// @dev Fork at Island deploy-era block (empty supply) when possible; documents real mint vs fallback.
contract IslandExactEconomicsTest is Test {
    address constant ISLAND = 0x40E8Fa74792274d9d9A328D41324E9d5199C0A16;
    address constant USDE = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34;
    address constant COMPUTE = 0xB8CD0b8E056A91c00FD388EdDb37E6E445844B21;
    address constant CL_POOL = 0xe97cAA346252C23b5C4C7771b5af75DC997cA65B;

    address constant SENIOR = 0xeb04926d24b9526D847498153C88d80296F1bb73;
    address constant JUNIOR = 0x3499a7FFB37Dbd4d0d94c203614C093314FD937f;
    address constant TRANSFERRER = 0xE532DFede91f04B12a73d3d2Acd361424F41f76B;
    address constant OPERATOR = 0xE90986e67A9cbEbcF67084cbBF8E24FAa0a43Bcb;
    address constant ADMIN_SAFE = 0xd60c3A29Fbe444cF9d3AA240F4a9263BC83bde61;

    uint256 constant USDE_SEED = 1_000_000e18;
    uint256 constant COMPUTE_SEED = 100_000e18;
    uint256 constant TARGET_NAV = 1_000_000e18;
    uint256 constant SHARES = 1_000_000e18;

    /// @dev sqrtPriceX96 for token1/token0 = COMPUTE/USDe = 0.1 (10 USDe per COMPUTE.r)
    uint160 constant SQRT_PRICE_10_TO_1 = 25054144837504793750611689472;

    /// @dev Post–Senior-deploy block: dual-sided Island mint (1M USDe + 100k COMPUTE) succeeds after CL seed.
    uint256 constant FORK_BLOCK = 27_863_150;

    address internal seeder;

    function setUp() public {
        vm.createSelectFork("https://rpc.berachain.com", FORK_BLOCK);
        seeder = makeAddr("seeder");
    }

    function testTwoMillionIslandSplitOneMillionNavPerVault() public {
        _prepareTenToOnePool();

        (uint256 X, bool realMint, string memory mintMode) = _mintAllIslandLp();
        console2.log("MINT_MODE", mintMode);
        console2.log("REAL_ISLAND_MINT", realMint);
        console2.log("X_LP_MINTED", X);

        (uint256 u0, uint256 u1) = IKodiakIsland(ISLAND).getUnderlyingBalances();
        console2.log("Island underlying USDe (token0)", u0);
        console2.log("Island underlying COMPUTE.r (token1)", u1);
        console2.log("Island totalSupply", IKodiakIsland(ISLAND).totalSupply());

        _snapStep(0, "baseline");
        _adminMintBoth();
        _snapStep(1, "adminMintShares 1e6 to transferrer");

        uint256 half = X / 2;
        deal(ISLAND, TRANSFERRER, X);
        vm.startPrank(TRANSFERRER);
        IERC20(ISLAND).transfer(SENIOR, half);
        IERC20(ISLAND).transfer(JUNIOR, half);
        vm.stopPrank();
        _snapStep(2, "transfer X/2 Island LP to each vault");

        vm.prank(OPERATOR);
        IVault(SENIOR).transferToLiquidityManager(half, ISLAND);
        vm.prank(OPERATOR);
        IVault(JUNIOR).transferToLiquidityManager(half, ISLAND);
        _snapStep(3, "operator transferToLiquidityManager");

        _reportGap("Senior", SENIOR);
        _reportGap("Junior", JUNIOR);
    }

    function _prepareTenToOnePool() internal {
        _setClSqrtPrice(SQRT_PRICE_10_TO_1);
        deal(USDE, CL_POOL, USDE_SEED);
        deal(COMPUTE, CL_POOL, COMPUTE_SEED);
    }

    function _mintAllIslandLp() internal returns (uint256 X, bool realMint, string memory mintMode) {
        deal(USDE, seeder, USDE_SEED);
        deal(COMPUTE, seeder, COMPUTE_SEED);

        (uint256 need0, uint256 need1, uint256 mintAmt) =
            IKodiakIsland(ISLAND).getMintAmounts(USDE_SEED, COMPUTE_SEED);
        console2.log("getMintAmounts need0 need1 mintAmt", need0, need1, mintAmt);

        vm.startPrank(seeder);
        IERC20(USDE).approve(ISLAND, USDE_SEED);
        IERC20(COMPUTE).approve(ISLAND, COMPUTE_SEED);

        try IKodiakIsland(ISLAND).mint(mintAmt, seeder) returns (uint256 spent0, uint256 spent1) {
            realMint = true;
            mintMode = "island.mint(mintAmt,seeder)";
            X = mintAmt;
            console2.log("mint spent token0 token1", spent0, spent1);
            console2.log("seeder LP balance", IERC20(ISLAND).balanceOf(seeder));
        } catch {
            realMint = false;
            mintMode = "fallback: deal LP + mock underlying (mint reverted on fork)";
            X = mintAmt;
            vm.mockCall(
                ISLAND,
                abi.encodeWithSignature("getUnderlyingBalances()"),
                abi.encode(USDE_SEED, COMPUTE_SEED)
            );
            deal(ISLAND, seeder, X);
        }
        vm.stopPrank();

        if (realMint) {
            vm.startPrank(seeder);
            IERC20(ISLAND).transfer(TRANSFERRER, IERC20(ISLAND).balanceOf(seeder));
            vm.stopPrank();
        }
    }

    function _setClSqrtPrice(uint160 sqrtPriceX96) internal {
        bytes32 slot0 = bytes32(vm.load(CL_POOL, bytes32(uint256(0))));
        uint256 cleared = uint256(slot0) & ~uint256(type(uint160).max);
        vm.store(CL_POOL, bytes32(uint256(0)), bytes32(cleared | uint256(sqrtPriceX96)));
    }

    function _adminMintBoth() internal {
        vm.startPrank(ADMIN_SAFE);
        IVault(SENIOR).setWhitelistedMintAddress(TRANSFERRER, true);
        IVault(JUNIOR).setWhitelistedMintAddress(TRANSFERRER, true);
        IVault(SENIOR).adminMintShares(TRANSFERRER, SHARES, "kodi-seed");
        IVault(JUNIOR).adminMintShares(TRANSFERRER, SHARES, "kodi-seed");
        vm.stopPrank();
    }

    function _snapStep(uint256 step, string memory label) internal view {
        console2.log("======== STEP", step, label);
        _vaultMetrics("Senior", SENIOR);
        _vaultMetrics("Junior", JUNIOR);
    }

    function _vaultMetrics(string memory tag, address vault) internal view {
        uint256 ts = IERC20(vault).totalSupply();
        uint256 ta = IVault(vault).totalAssets();
        uint256 gvv = IVault(vault).getVaultValue();
        console2.log(tag, "totalSupply", ts);
        console2.log(tag, "totalAssets", ta);
        console2.log(tag, "getVaultValue", gvv);
        if (ts > 0) {
            console2.log(tag, "convertToAssets(1e18)", IVault(vault).convertToAssets(1e18));
            console2.log(tag, "PPS (ta*1e18/ts)", (ta * 1e18) / ts);
        }
    }

    function _reportGap(string memory tag, address vault) internal view {
        uint256 ta = IVault(vault).totalAssets();
        int256 gap = int256(ta) - int256(TARGET_NAV);
        int256 ppsGap = int256((ta * 1e18) / SHARES) - int256(1e18);
        console2.log(tag, "NAV shortfall wei (0 if above target)", gap < 0 ? uint256(-gap) : 0);
        console2.log(tag, "NAV surplus wei (0 if below target)", gap > 0 ? uint256(gap) : 0);
        console2.log(tag, "PPS shortfall from 1e18", ppsGap < 0 ? uint256(-ppsGap) : 0);
    }
}

interface IVault {
    function setWhitelistedMintAddress(address, bool) external;
    function adminMintShares(address, uint256, string memory) external;
    function transferToLiquidityManager(uint256, address) external;
    function totalAssets() external view returns (uint256);
    function getVaultValue() external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IKodiakIsland {
    function getMintAmounts(uint256, uint256) external view returns (uint256, uint256, uint256);
    function mint(uint256, address) external returns (uint256, uint256);
    function getUnderlyingBalances() external view returns (uint256, uint256);
    function totalSupply() external view returns (uint256);
}
