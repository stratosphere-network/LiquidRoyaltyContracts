// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

/// @dev Corrected seed order on Berachain mainnet fork (latest block).
contract FullScenario is Test {
    address constant SENIOR = 0xeb04926d24b9526D847498153C88d80296F1bb73;
    address constant JUNIOR = 0x3499a7FFB37Dbd4d0d94c203614C093314FD937f;
    address constant ISLAND = 0x40E8Fa74792274d9d9A328D41324E9d5199C0A16;
    /// @dev Implementation bytecode constant EOA; not whitelisted on mainnet until admin calls setWhitelistedMintAddress.
    address constant KODI_TOKEN_TRANSFERRER = 0xE532DFede91f04B12a73d3d2Acd361424F41f76B;
    address constant OPERATOR = 0xE90986e67A9cbEbcF67084cbBF8E24FAa0a43Bcb;
    /// @dev Admin Gnosis Safe (DEFAULT_ADMIN on both vaults today).
    address constant ADMIN_SAFE = 0xd60c3A29Fbe444cF9d3AA240F4a9263BC83bde61;

    function testFullCorrectedOrder() public {
        vm.createSelectFork("https://rpc.berachain.com");

        uint256 lp = _lpOneMillionUsdeShare();
        console2.log("LP ~$1M (USDe share)", lp);

        _snap(0, "baseline");

        _adminConfigureAndMint(SENIOR);
        _adminConfigureAndMint(JUNIOR);
        _snap(1, "adminMintShares 1M to Kodi token transferrer");

        deal(ISLAND, KODI_TOKEN_TRANSFERRER, lp * 2);
        vm.startPrank(KODI_TOKEN_TRANSFERRER);
        IERC20(ISLAND).transfer(SENIOR, lp);
        IERC20(ISLAND).transfer(JUNIOR, lp);
        vm.stopPrank();
        _snap(2, "transferrer sends Island LP to vault bodies");

        vm.prank(OPERATOR);
        IVault(SENIOR).transferToLiquidityManager(lp, ISLAND);
        vm.prank(OPERATOR);
        IVault(JUNIOR).transferToLiquidityManager(lp, ISLAND);
        _snap(3, "operator transferToLiquidityManager to LMV Safes");

        vm.prank(OPERATOR);
        (bool lmvFail,) =
            SENIOR.call(abi.encodeWithSignature("transferToLMV(address,uint256)", ISLAND, lp));
        console2.log("transferToLMV legacy from operator expected fail", lmvFail);
    }

    function _adminConfigureAndMint(address vault) internal {
        vm.startPrank(ADMIN_SAFE);
        IVault(vault).setWhitelistedMintAddress(KODI_TOKEN_TRANSFERRER, true);
        IVault(vault).adminMintShares(KODI_TOKEN_TRANSFERRER, 1_000_000e18, "kodi-seed");
        vm.stopPrank();
    }

    function _lpOneMillionUsdeShare() internal view returns (uint256) {
        uint256 supply = IKodiakIsland(ISLAND).totalSupply();
        (uint256 usde0,) = IKodiakIsland(ISLAND).getUnderlyingBalances();
        return (1_000_000e18 * supply) / usde0;
    }

    function _snap(uint256 step, string memory label) internal view {
        console2.log("======== STEP", step, label);
        _line("Senior", SENIOR);
        _line("Junior", JUNIOR);
        console2.log("transferrer Senior shares", IERC20(SENIOR).balanceOf(KODI_TOKEN_TRANSFERRER));
        console2.log("transferrer Junior shares", IERC20(JUNIOR).balanceOf(KODI_TOKEN_TRANSFERRER));
    }

    function _line(string memory tag, address vault) internal view {
        address lmv = IVault(vault).liquidityManagerVault();
        (bool vvOk, bytes memory vvData) = vault.staticcall(abi.encodeWithSignature("vaultValue()"));
        uint256 vv = vvOk && vvData.length >= 32 ? abi.decode(vvData, (uint256)) : 0;
        uint256 ts = IERC20(vault).totalSupply();
        uint256 ta = IVault(vault).totalAssets();
        uint256 gvv = IVault(vault).getVaultValue();
        uint256 cta = ts > 0 ? IVault(vault).convertToAssets(1e18) : 0;
        uint256 pps = ts == 0 ? 0 : (ta * 1e18) / ts;

        console2.log(tag, "LMV Safe", lmv);
        console2.log(tag, "totalSupply", ts);
        console2.log(tag, "totalAssets", ta);
        console2.log(tag, "vaultValue() ok", vvOk);
        console2.log(tag, "vaultValue()", vv);
        console2.log(tag, "getVaultValue()", gvv);
        console2.log(tag, "convertToAssets(1e18)", cta);
        console2.log(tag, "PPS (ta*1e18/ts)", pps);
        console2.log(tag, "Island on vault", IERC20(ISLAND).balanceOf(vault));
        console2.log(tag, "Island on LMV Safe", IERC20(ISLAND).balanceOf(lmv));
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
