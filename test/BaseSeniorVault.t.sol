// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BaseSeniorVault} from "../src/concrete/BaseSeniorVault.sol";
import {BaseSeniorVaultV2} from "../src/concrete/BaseSeniorVaultV2.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract BaseSeniorVaultTest is Test {
    BaseSeniorVault internal vault;
    MockERC20 internal usde;

    address internal constant ADMIN = address(0xA11CE);
    address internal constant OPERATOR = address(0xB0B);
    address internal constant FEE = address(0xFEE);
    address internal constant USER = address(0x1001);
    address internal constant USER2 = address(0x1002);
    address internal constant TOKEN_POOL = address(0xC0CC);
    address internal constant DEPLOYER = address(0xDEAD);

    uint256 internal constant CAP = 1_000_000e18;

    function setUp() public {
        usde = new MockERC20("USDe", "USDe", 18);

        vm.prank(DEPLOYER);
        BaseSeniorVault impl = new BaseSeniorVault(ADMIN);

        bytes memory init = abi.encodeCall(
            BaseSeniorVault.initialize,
            (address(usde), OPERATOR, FEE, address(0))
        );

        vm.prank(DEPLOYER);
        vault = BaseSeniorVault(address(new ERC1967Proxy(address(impl), init)));

        usde.mint(USER, 10_000_000e18);
        usde.mint(USER2, 10_000_000e18);
        usde.mint(ADMIN, 10_000_000e18);
        usde.mint(TOKEN_POOL, 10_000_000e18);

        vm.startPrank(ADMIN);
        vault.setWhitelistedUser(USER, true);
        vault.setWhitelistedUser(USER2, true);
        vm.stopPrank();
    }

    function _deposit(address user, uint256 assets) internal returns (uint256 shares) {
        vm.startPrank(user);
        usde.approve(address(vault), assets);
        shares = vault.deposit(assets, user);
        vm.stopPrank();
    }

    // ─── initialize / roles ───────────────────────────────────────────────────

    function test_initialize_rolesAndDefaults() public view {
        assertEq(vault.name(), "Senior Vault");
        assertEq(vault.symbol(), "snrUSD");
        assertEq(vault.usde(), address(usde));
        assertEq(vault.feeAddress(), FEE);
        assertEq(vault.liquidityManagerVault(), address(0));
        assertFalse(vault.vaultOpenToPublic());
        assertEq(vault.depositCap(), 0);

        assertTrue(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), ADMIN));
        assertTrue(vault.hasRole(vault.OPERATOR_ROLE(), OPERATOR));
        assertFalse(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), DEPLOYER));
        assertFalse(vault.hasRole(vault.MINTER_ROLE(), ADMIN));
        assertFalse(vault.hasRole(vault.BURNER_ROLE(), ADMIN));
        assertFalse(vault.hasRole(vault.MINTER_ROLE(), ADMIN));
    }

  function test_initialize_acceptsZeroLMV() public view {
    assertEq(vault.liquidityManagerVault(), address(0));
    assertEq(vault.totalAssets(), 0);
  }

    // ─── 1:1 deposit / mint / preview ─────────────────────────────────────────

    function test_deposit_and_preview_oneToOne() public {
        uint256 amount = 1000e18;
        assertEq(vault.previewDeposit(amount), amount);
        assertEq(vault.convertToShares(amount), amount);
        assertEq(vault.convertToAssets(amount), amount);

        uint256 shares = _deposit(USER, amount);
        assertEq(shares, amount);
        assertEq(vault.balanceOf(USER), amount);
        assertEq(vault.totalAssets(), amount);
        assertEq(usde.balanceOf(address(vault)), amount);
    }

    function test_erc4626Mint_oneToOne() public {
        uint256 shares = 500e18;
        vm.startPrank(USER);
        usde.approve(address(vault), shares);
        uint256 assets = vault.mint(shares, USER);
        vm.stopPrank();
        assertEq(assets, shares);
        assertEq(vault.balanceOf(USER), shares);
    }

    function test_notPricedOffTotalAssetsSupplyRatio() public {
        _deposit(USER, 1000e18);
        usde.mint(address(vault), 5000e18);

        uint256 assetsNeeded = vault.previewMint(200e18);
        assertEq(assetsNeeded, 200e18);
    }

    // ─── cooldown + redeem fee ────────────────────────────────────────────────

    function test_cooldown_redeem_fee_and_clear() public {
        _deposit(USER, 1000e18);

        vm.prank(USER);
        vault.initiateCooldown(1000e18);

        vm.expectRevert(bytes("Cooldown not ended"));
        vm.prank(USER);
        vault.redeem(100e18, USER, USER);

        vm.warp(block.timestamp + 7 days + 1);

        uint256 feeExpected = (100e18 * 30) / 10_000;
        assertEq(vault.previewRedeem(100e18), 100e18 - feeExpected);

        uint256 feeBefore = usde.balanceOf(FEE);
        uint256 userBefore = usde.balanceOf(USER);

        vm.prank(USER);
        uint256 assets = vault.redeem(100e18, USER, USER);

        assertEq(assets, 100e18 - feeExpected);
        assertEq(usde.balanceOf(FEE), feeBefore + feeExpected);
        assertEq(usde.balanceOf(USER), userBefore + assets);
        assertFalse(vault.getCooldown(USER).active);
    }

    function test_operator_clearCooldown_forcesReinitiate() public {
        _deposit(USER, 50e18);
        vm.prank(USER);
        vault.initiateCooldown(50e18);

        vm.prank(OPERATOR);
        vault.clearCooldown(USER);

        assertEq(vault.maxRedeem(USER), 0);

        vm.expectRevert(bytes("No active cooldown"));
        vm.prank(USER);
        vault.redeem(50e18, USER, USER);

        vm.prank(USER);
        vault.initiateCooldown(50e18);

        uint256 ends = vault.getCooldown(USER).cooldownEnd;
        vm.warp(ends + 1);
        vm.prank(USER);
        vault.redeem(50e18, USER, USER);
    }

    // ─── withdraw disabled ────────────────────────────────────────────────────

    function test_withdraw_reverts() public {
        vm.expectRevert(bytes("Direct withdrawals disabled. Use initiateCooldown() then redeem()"));
        vault.withdraw(1, USER, USER);
    }

    // ─── pause ────────────────────────────────────────────────────────────────

    function test_pause_blocksDeposit() public {
        vm.prank(ADMIN);
        vault.pause();
        vm.startPrank(USER);
        usde.approve(address(vault), 1e18);
        vm.expectRevert();
        vault.deposit(1e18, USER);
        vm.stopPrank();
    }

    // ─── whitelist / public ───────────────────────────────────────────────────

    function test_whitelist_requiredWhenClosed() public {
        address outsider = address(0x99);
        usde.mint(outsider, 1e18);
        vm.startPrank(outsider);
        usde.approve(address(vault), 1e18);
        vm.expectRevert(bytes("User not whitelisted"));
        vault.deposit(1e18, outsider);
        vm.stopPrank();
    }

    function test_vaultOpenToPublic_skipsWhitelist() public {
        vm.prank(ADMIN);
        vault.setVaultOpenToPublic(true);

        address outsider = address(0x99);
        usde.mint(outsider, 1e18);
        vm.startPrank(outsider);
        usde.approve(address(vault), 1e18);
        vault.deposit(1e18, outsider);
        vm.stopPrank();
        assertEq(vault.balanceOf(outsider), 1e18);
    }

    // ─── deposit cap ──────────────────────────────────────────────────────────

    function test_depositCap_onTotalSupply() public {
        vm.prank(ADMIN);
        vault.setDepositCap(CAP);

        _deposit(USER, CAP);

        vm.startPrank(USER2);
        usde.approve(address(vault), 1);
        vm.expectRevert(bytes("Deposit cap exceeded"));
        vault.deposit(1, USER2);
        vm.stopPrank();
    }

    function test_bridgeMint_canExceedCap_thenBlocksUserDeposit() public {
        vm.startPrank(ADMIN);
        vault.setDepositCap(CAP);
        vault.setWhitelistedUser(USER2, true);
        vault.grantRole(vault.MINTER_ROLE(), TOKEN_POOL);
        vm.stopPrank();

        _deposit(USER, CAP);

        vm.prank(TOKEN_POOL);
        vault.mint(USER2, 100e18);

        assertGt(vault.totalSupply(), CAP);

        vm.startPrank(USER2);
        usde.approve(address(vault), 1);
        vm.expectRevert(bytes("Deposit cap exceeded"));
        vault.deposit(1, USER2);
        vm.stopPrank();
    }

    function test_adminMint_and_rebalance_notCapChecked() public {
        vm.prank(ADMIN);
        vault.setDepositCap(100e18);
        _deposit(USER, 100e18);

        vm.startPrank(ADMIN);
        vault.setWhitelistedMintAddress(USER2, true);
        vault.adminMintShares(USER2, 50e18, "airdrop");
        vm.stopPrank();

        vm.warp(block.timestamp + 30 days + 1);
        vm.prank(ADMIN);
        vault.rebalance(1200);
    }

    // ─── rebalance ────────────────────────────────────────────────────────────

    function test_rebalance_band_and_fees_supplyBasedMgmt() public {
        _deposit(USER, 1_000_000e18);
        usde.mint(address(vault), 50_000e18);

        uint256 supplyBefore = vault.totalSupply();
        vm.warp(block.timestamp + 30 days + 1);

        uint256 feeBefore = vault.balanceOf(FEE);
        uint256 feeUsdeBefore = usde.balanceOf(FEE);

        vm.prank(ADMIN);
        vault.rebalance(1200);

        uint256 expectedAirdrop = (supplyBefore * 1200) / 120_000;
        uint256 expectedMgmt = (supplyBefore * 8) / 10_000;
        uint256 expectedPerfUsde = (expectedAirdrop * 2) / 100;

        assertEq(vault.balanceOf(ADMIN), expectedAirdrop);
        assertEq(vault.balanceOf(FEE) - feeBefore, expectedMgmt);
        assertEq(usde.balanceOf(FEE) - feeUsdeBefore, expectedPerfUsde);
    }

    function test_rebalance_reverts_outOfBand() public {
        _deposit(USER, 100e18);
        vm.warp(block.timestamp + 30 days + 1);
        vm.prank(ADMIN);
        vm.expectRevert(bytes("Airdrop percentage must be between 11-13%"));
        vault.rebalance(1000);
    }

    // ─── admin mint / burn ──────────────────────────────────────────────────────

    function test_adminMint_and_burn() public {
        vm.startPrank(ADMIN);
        vault.setWhitelistedMintAddress(USER2, true);
        vault.adminMintShares(USER2, 100e18, "seed");
        vault.adminBurnShares(USER2, 40e18, "correction");
        vm.stopPrank();
        assertEq(vault.balanceOf(USER2), 60e18);
        assertEq(vault.totalSupply(), 60e18);
    }

    // ─── TokenPool mint/burn vs ERC4626 mint ───────────────────────────────────

    function test_tokenPool_mintBurn_roles() public {
        vm.startPrank(ADMIN);
        vault.grantRole(vault.MINTER_ROLE(), TOKEN_POOL);
        vault.grantRole(vault.BURNER_ROLE(), TOKEN_POOL);
        vm.stopPrank();

        uint256 assetsBefore = vault.totalAssets();
        vm.prank(TOKEN_POOL);
        vault.mint(USER, 1000e18);
        assertEq(vault.totalAssets(), assetsBefore);

        vm.prank(TOKEN_POOL);
        vault.burn(USER, 400e18);
        assertEq(vault.totalAssets(), assetsBefore);
    }

    function test_tokenPool_burnFrom_spendsAllowance() public {
        vm.startPrank(ADMIN);
        vault.grantRole(vault.BURNER_ROLE(), TOKEN_POOL);
        vm.stopPrank();

        _deposit(USER, 200e18);

        vm.startPrank(USER);
        vault.approve(TOKEN_POOL, 75e18);
        vm.stopPrank();

        vm.prank(TOKEN_POOL);
        vault.burnFrom(USER, 75e18);

        assertEq(vault.balanceOf(USER), 125e18);
        assertEq(vault.allowance(USER, TOKEN_POOL), 0);
    }

    function test_initiateCooldown_partialShares() public {
        _deposit(USER, 1000e18);
        vm.prank(USER);
        vault.initiateCooldown(250e18);

        BaseSeniorVault.CooldownInfo memory cd = vault.getCooldown(USER);
        assertEq(cd.sharesToBurn, 250e18);
        assertTrue(cd.active);
    }

    function test_initialize_reverts_zeroOperator() public {
        BaseSeniorVault impl = new BaseSeniorVault(ADMIN);
        bytes memory init = abi.encodeCall(
            BaseSeniorVault.initialize,
            (address(usde), address(0), FEE, address(0))
        );
        vm.expectRevert(bytes("Invalid operator"));
        new ERC1967Proxy(address(impl), init);
    }

    function test_tokenPool_distinctFromErc4626Mint() public pure {
        bytes4 erc4626MintSelector = bytes4(keccak256("mint(uint256,address)"));
        bytes4 cctMintSelector = bytes4(keccak256("mint(address,uint256)"));
        assertTrue(erc4626MintSelector != cctMintSelector);
    }

    // ─── transferToLiquidityManager ─────────────────────────────────────────────

    function test_transferToLiquidityManager() public {
        address lmv = address(0x1A4);
        MockERC20 other = new MockERC20("OTHER", "OTH", 18);

        vm.startPrank(ADMIN);
        vault.setLiquidityManagerVault(lmv);
        vm.stopPrank();

        other.mint(address(vault), 100e18);
        _deposit(USER, 50e18);

        vm.prank(OPERATOR);
        vault.transferToLiquidityManager(25e18, address(usde));
        vm.prank(OPERATOR);
        vault.transferToLiquidityManager(10e18, address(other));

        assertEq(usde.balanceOf(lmv), 25e18);
        assertEq(other.balanceOf(lmv), 10e18);
    }

    // ─── zero LMV totalAssets ───────────────────────────────────────────────────

    function test_totalAssets_zeroLMV_ignoresLMVUsde() public {
        address lmv = address(0x1A4);
        usde.mint(lmv, 999e18);
        _deposit(USER, 10e18);
        assertEq(vault.totalAssets(), 10e18);

        vm.prank(ADMIN);
        vault.setLiquidityManagerVault(lmv);
        assertEq(vault.totalAssets(), 10e18 + 999e18);
    }

    // ─── UUPS upgrade ───────────────────────────────────────────────────────────

    function test_uups_upgrade_onlyAdmin() public {
        vm.prank(USER);
        vm.expectRevert();
        vault.upgradeToAndCall(address(new BaseSeniorVaultV2(ADMIN)), "");

        BaseSeniorVaultV2 v2Impl = new BaseSeniorVaultV2(ADMIN);
        vm.prank(ADMIN);
        vault.upgradeToAndCall(address(v2Impl), "");

        BaseSeniorVaultV2 upgraded = BaseSeniorVaultV2(address(vault));
        vm.prank(ADMIN);
        upgraded.bumpVersion();
        assertGt(upgraded.versionMarker(), 0);
    }

    // ─── adminWithdraw ──────────────────────────────────────────────────────────

    function test_adminWithdraw_amountZeroWithdrawsFullBalance() public {
        _deposit(USER, 100e18);
        uint256 before = usde.balanceOf(ADMIN);
        vm.expectEmit(true, true, false, true);
        emit BaseSeniorVault.AdminWithdraw(ADMIN, address(usde), 100e18);
        vm.prank(ADMIN);
        vault.adminWithdraw(address(usde), 0, ADMIN);
        assertEq(usde.balanceOf(ADMIN), before + 100e18);
        assertEq(usde.balanceOf(address(vault)), 0);
    }

    function test_adminWithdraw_partialAmount() public {
        _deposit(USER, 100e18);
        uint256 before = usde.balanceOf(ADMIN);
        vm.prank(ADMIN);
        vault.adminWithdraw(address(usde), 40e18, ADMIN);
        assertEq(usde.balanceOf(ADMIN), before + 40e18);
        assertEq(usde.balanceOf(address(vault)), 60e18);
    }

    function test_adminWithdraw_revertsWhenNotAdmin() public {
        _deposit(USER, 10e18);
        vm.prank(USER);
        vm.expectRevert();
        vault.adminWithdraw(address(usde), 1e18, USER);
    }

    function test_adminWithdraw_revertsZeroToken() public {
        vm.prank(ADMIN);
        vm.expectRevert("Invalid token");
        vault.adminWithdraw(address(0), 0, ADMIN);
    }

    function test_adminWithdraw_revertsZeroReceiver() public {
        _deposit(USER, 1e18);
        vm.prank(ADMIN);
        vm.expectRevert("Invalid receiver");
        vault.adminWithdraw(address(usde), 1e18, address(0));
    }

    function test_adminWithdraw_revertsInsufficientBalance() public {
        _deposit(USER, 10e18);
        vm.prank(ADMIN);
        vm.expectRevert("Insufficient balance");
        vault.adminWithdraw(address(usde), 11e18, ADMIN);
    }

    function test_adminWithdraw_revertsNoBalance() public {
        vm.prank(ADMIN);
        vm.expectRevert("No balance to withdraw");
        vault.adminWithdraw(address(usde), 0, ADMIN);
    }

    // ─── deploy script role hygiene (simulated) ─────────────────────────────────

    function test_deployerHasNoPrivilegedRoles() public view {
        assertFalse(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), DEPLOYER));
        assertFalse(vault.hasRole(vault.OPERATOR_ROLE(), DEPLOYER));
    }
}