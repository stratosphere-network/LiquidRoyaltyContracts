// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MetaSeniorVault} from "../src/concrete/MetaSeniorVault.sol";
import {MetaSeniorVaultPath1} from "../src/concrete/MetaSeniorVaultPath1.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract MetaSeniorVaultPath1Test is Test {
    MockERC20 internal usde;
    MetaSeniorVaultPath1 internal vault;
    address internal constant ADMIN = address(0xA11CE);
    address internal constant OPERATOR = address(0xB0B);
    address internal constant POOL = address(0xC0CC);
    address internal constant USER = address(0x1001);

    function setUp() public {
        usde = new MockERC20("USDe", "USDe", 18);
        MetaSeniorVault baseImpl = new MetaSeniorVault();
        bytes memory init = abi.encodeCall(
            MetaSeniorVault.initialize,
            (address(usde), OPERATOR, ADMIN, "Senior Vault Master", "snrUSD", 30)
        );
        vm.prank(ADMIN);
        ERC1967Proxy proxy = new ERC1967Proxy(address(baseImpl), init);
        MetaSeniorVaultPath1 path1Impl = new MetaSeniorVaultPath1();
        bytes memory path1Init =
            abi.encodeWithSelector(MetaSeniorVaultPath1.initializePath1.selector, uint16(500), uint32(36 hours));
        vm.prank(ADMIN);
        MetaSeniorVault(address(proxy)).upgradeToAndCall(address(path1Impl), path1Init);
        vault = MetaSeniorVaultPath1(address(proxy));
        assertTrue(vault.vaultOpenToPublic());
        usde.mint(USER, 1_000_000e18);
    }

    function test_roles_notGrantedToAdminByDefault() public view {
        assertFalse(vault.hasRole(vault.MINTER_ROLE(), ADMIN));
        assertFalse(vault.hasRole(vault.BURNER_ROLE(), ADMIN));
    }

    function test_grantMintAndBurnRoles_poolOnly() public {
        vm.prank(ADMIN);
        vault.grantMintAndBurnRoles(POOL);
        assertTrue(vault.hasRole(vault.MINTER_ROLE(), POOL));
        assertTrue(vault.hasRole(vault.BURNER_ROLE(), POOL));
    }

    function test_tokenPoolMintBurn_doesNotChangeLocalVaultValue() public {
        vm.prank(ADMIN);
        vault.grantMintAndBurnRoles(POOL);

        usde.mint(address(vault), 1000e18);
        uint256 localBefore = vault.localVaultValue();

        vm.prank(POOL);
        vault.mint(USER, 500e18);
        assertEq(vault.localVaultValue(), localBefore);

        vm.prank(USER);
        vault.approve(POOL, 200e18);
        vm.prank(POOL);
        vault.burnFrom(USER, 200e18);
        assertEq(vault.localVaultValue(), localBefore);
    }

    function test_setBaseSleeveAssets_composesNav() public {
        usde.mint(address(vault), 100e18);
        vm.prank(OPERATOR);
        vault.setBaseSleeveAssets(50e18);
        assertEq(vault.reportedBaseSleeveAssets(), 50e18);
        assertEq(vault.getVaultValue(), vault.localVaultValue() + 50e18);
        assertEq(vault.totalAssets(), vault.getVaultValue());
    }

    function test_depositStillWorksAfterUpgrade() public {
        vm.startPrank(USER);
        usde.approve(address(vault), 100e18);
        uint256 shares = vault.deposit(100e18, USER);
        vm.stopPrank();
        assertEq(shares, 100e18);
        assertEq(vault.balanceOf(USER), 100e18);
    }
}