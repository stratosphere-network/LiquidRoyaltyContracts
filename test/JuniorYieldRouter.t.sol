// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {JuniorYieldRouter} from "../src/concrete/JuniorYieldRouter.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract JuniorYieldRouterTest is Test {
    JuniorYieldRouter internal router;
    MockERC20 internal usde;
    MockERC20 internal otherToken;

    address internal constant ADMIN = address(0xA11CE);
    address internal constant JUNIOR_SAFE = address(0x8888);
    address internal constant USER = address(0x1001);
    address internal constant STRAY = address(0xBEEF);

    function setUp() public {
        usde = new MockERC20("USDe", "USDe", 18);
        otherToken = new MockERC20("Other", "OTH", 18);

        router = new JuniorYieldRouter(address(usde), JUNIOR_SAFE, ADMIN);

        usde.mint(USER, 1_000_000e18);
        otherToken.mint(address(router), 500e18);
    }

    function test_constructor_immutablesAndAdmin() public view {
        assertEq(address(router.USDE()), address(usde));
        assertEq(router.DESTINATION(), JUNIOR_SAFE);
        assertTrue(router.hasRole(router.DEFAULT_ADMIN_ROLE(), ADMIN));
    }

    function test_route_forwardsUsdeFromCaller() public {
        uint256 amount = 1000e18;

        vm.startPrank(USER);
        usde.approve(address(router), amount);
        vm.expectEmit(true, true, true, true);
        emit JuniorYieldRouter.USDeRouted(USER, address(router), amount, JUNIOR_SAFE);
        router.route(amount);
        vm.stopPrank();

        assertEq(usde.balanceOf(JUNIOR_SAFE), amount);
        assertEq(usde.balanceOf(address(router)), 0);
    }

    function test_route_revertsZeroAmount() public {
        vm.prank(USER);
        vm.expectRevert(JuniorYieldRouter.ZeroAmount.selector);
        router.route(0);
    }

    function test_route_revertsWithoutAllowance() public {
        vm.prank(USER);
        vm.expectRevert();
        router.route(1e18);
    }

    function test_route_revertsWhenPaused() public {
        vm.prank(ADMIN);
        router.pause();

        vm.startPrank(USER);
        usde.approve(address(router), 1e18);
        vm.expectRevert();
        router.route(1e18);
        vm.stopPrank();
    }

    function test_flush_forwardsRouterBalance() public {
        uint256 amount = 250e18;
        usde.mint(address(router), amount);

        vm.expectEmit(true, false, true, true);
        emit JuniorYieldRouter.USDeFlushed(address(router), amount, JUNIOR_SAFE);
        router.flush();

        assertEq(usde.balanceOf(JUNIOR_SAFE), amount);
        assertEq(usde.balanceOf(address(router)), 0);
    }

    function test_flush_revertsZeroBalance() public {
        vm.expectRevert(JuniorYieldRouter.ZeroAmount.selector);
        router.flush();
    }

    function test_pause_onlyAdmin() public {
        vm.prank(STRAY);
        vm.expectRevert();
        router.pause();

        vm.prank(ADMIN);
        router.pause();
        assertTrue(router.paused());

        vm.prank(ADMIN);
        router.unpause();
        assertFalse(router.paused());
    }

    function test_rescue_nonUsdeToken() public {
        uint256 amount = 100e18;

        vm.prank(ADMIN);
        vm.expectEmit(true, true, false, true);
        emit JuniorYieldRouter.TokenRescued(address(otherToken), STRAY, amount);
        router.rescueERC20(address(otherToken), STRAY, amount);

        assertEq(otherToken.balanceOf(STRAY), amount);
        assertEq(otherToken.balanceOf(address(router)), 400e18);
    }

    function test_rescue_usde_toJuniorSafe_ok() public {
        uint256 amount = 50e18;
        usde.mint(address(router), amount);

        vm.prank(ADMIN);
        router.rescueERC20(address(usde), JUNIOR_SAFE, amount);

        assertEq(usde.balanceOf(JUNIOR_SAFE), amount);
    }

    function test_rescue_usde_revertsIfNotJuniorSafe() public {
        uint256 amount = 50e18;
        usde.mint(address(router), amount);

        vm.prank(ADMIN);
        vm.expectRevert(
            abi.encodeWithSelector(JuniorYieldRouter.UsdeRescueDestinationForbidden.selector, STRAY, JUNIOR_SAFE)
        );
        router.rescueERC20(address(usde), STRAY, amount);
    }

    function test_rescueETH() public {
        uint256 amount = 1 ether;
        vm.deal(address(router), amount);

        vm.prank(ADMIN);
        vm.expectEmit(true, false, false, true);
        emit JuniorYieldRouter.EthRescued(STRAY, amount);
        router.rescueETH(payable(STRAY), amount);

        assertEq(STRAY.balance, amount);
        assertEq(address(router).balance, 0);
    }
}