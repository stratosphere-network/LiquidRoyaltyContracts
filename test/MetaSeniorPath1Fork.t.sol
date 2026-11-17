// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {MetaSeniorVault} from "../src/concrete/MetaSeniorVault.sol";
import {MetaSeniorVaultPath1} from "../src/concrete/MetaSeniorVaultPath1.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUUPSUpgradeable {
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
}

/// @notice Fork test against live Meta Senior proxy (storage + mandatory initializePath1 upgrade).
contract MetaSeniorPath1ForkTest is Test {
    address internal constant PROXY = 0xC38421E5577250EBa177Bc5bC832E747bea13Ee0;
    address internal constant ADMIN = 0xd60c3A29Fbe444cF9d3AA240F4a9263BC83bde61;
    uint16 internal constant MAX_DELTA_BPS = 500;
    uint32 internal constant MAX_STALENESS = 36 hours;

    function setUp() public {
        vm.createSelectFork("https://berachain.drpc.org");
    }

    function test_fork_upgrade_preservesCoreState() public {
        bytes32 slot0Before = vm.load(PROXY, bytes32(uint256(0)));
        bytes32 slot3Before = vm.load(PROXY, bytes32(uint256(3)));
        bytes32 slot5Before = vm.load(PROXY, bytes32(uint256(5)));

        MetaSeniorVault before = MetaSeniorVault(PROXY);
        uint256 supply = before.totalSupply();
        uint256 assets = before.totalAssets();
        address fee = before.feeAddress();
        uint256 feeBps = before.unstakingFeeBps();
        address underlying = before.asset();

        address impl = address(new MetaSeniorVaultPath1());
        bytes memory initData =
            abi.encodeWithSelector(MetaSeniorVaultPath1.initializePath1.selector, MAX_DELTA_BPS, MAX_STALENESS);

        vm.prank(ADMIN);
        IUUPSUpgradeable(PROXY).upgradeToAndCall(impl, initData);

        MetaSeniorVaultPath1 afterUpgrade = MetaSeniorVaultPath1(PROXY);
        assertEq(afterUpgrade.totalSupply(), supply);
        assertEq(afterUpgrade.feeAddress(), fee);
        assertEq(afterUpgrade.unstakingFeeBps(), feeBps);
        assertEq(afterUpgrade.totalAssets(), assets);
        assertTrue(afterUpgrade.vaultOpenToPublic());
        assertEq(afterUpgrade.depositCap(), 0);
        assertEq(afterUpgrade.maxBaseSleeveDeltaBps(), MAX_DELTA_BPS);
        assertEq(afterUpgrade.baseSleeveMaxStaleness(), MAX_STALENESS);

        assertEq(vm.load(PROXY, bytes32(uint256(0))), slot0Before);
        assertEq(vm.load(PROXY, bytes32(uint256(3))), slot3Before);
        assertEq(vm.load(PROXY, bytes32(uint256(5))), slot5Before);

        assertFalse(afterUpgrade.hasRole(afterUpgrade.MINTER_ROLE(), ADMIN));

        address depositor = address(0xDEADBEEF);
        uint256 depositAmount = 1e18;
        deal(underlying, depositor, depositAmount);
        vm.startPrank(depositor);
        IERC20(underlying).approve(PROXY, depositAmount);
        uint256 shares = afterUpgrade.deposit(depositAmount, depositor);
        vm.stopPrank();
        assertGt(shares, 0);
        assertEq(afterUpgrade.balanceOf(depositor), shares);

        console2.log("post-upgrade totalAssets", afterUpgrade.totalAssets());
    }
}