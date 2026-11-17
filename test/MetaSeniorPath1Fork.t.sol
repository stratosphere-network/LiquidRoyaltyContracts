// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {MetaSeniorVault} from "../src/concrete/MetaSeniorVault.sol";
import {MetaSeniorVaultPath1} from "../src/concrete/MetaSeniorVaultPath1.sol";

interface IUUPSUpgradeable {
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
}

/// @notice Fork test against live Meta Senior proxy (storage smoke + upgrade simulation).
contract MetaSeniorPath1ForkTest is Test {
    address internal constant PROXY = 0xC38421E5577250EBa177Bc5bC832E747bea13Ee0;
    address internal constant ADMIN = 0xd60c3A29Fbe444cF9d3AA240F4a9263BC83bde61;

    function setUp() public {
        vm.createSelectFork("https://berachain.drpc.org");
    }

    function test_fork_upgrade_preservesCoreState() public {
        MetaSeniorVault before = MetaSeniorVault(PROXY);
        uint256 supply = before.totalSupply();
        uint256 assets = before.totalAssets();
        address fee = before.feeAddress();
        uint256 feeBps = before.unstakingFeeBps();

        address impl = address(new MetaSeniorVaultPath1());
        vm.prank(ADMIN);
        IUUPSUpgradeable(PROXY).upgradeToAndCall(impl, "");

        MetaSeniorVaultPath1 afterUpgrade = MetaSeniorVaultPath1(PROXY);
        assertEq(afterUpgrade.totalSupply(), supply);
        assertEq(afterUpgrade.feeAddress(), fee);
        assertEq(afterUpgrade.unstakingFeeBps(), feeBps);
        assertApproxEqRel(afterUpgrade.totalAssets(), assets, 1e15);

        assertFalse(afterUpgrade.hasRole(afterUpgrade.MINTER_ROLE(), ADMIN));
        console2.log("post-upgrade totalAssets", afterUpgrade.totalAssets());
    }
}