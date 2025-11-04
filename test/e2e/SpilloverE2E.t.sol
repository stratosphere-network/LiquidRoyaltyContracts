// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UnifiedConcreteSeniorVault} from "../../src/concrete/UnifiedConcreteSeniorVault.sol";
import {ConcreteJuniorVault} from "../../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../../src/concrete/ConcreteReserveVault.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MathLib} from "../../src/libraries/MathLib.sol";
import {SpilloverLib} from "../../src/libraries/SpilloverLib.sol";

/**
 * @title SpilloverE2E
 * @notice E2E tests for profit spillover scenarios (>110% backing)
 * @dev Tests the complete spillover flow across all three vaults
 */
contract SpilloverE2E is Test {
    UnifiedConcreteSeniorVault public senior;
    ConcreteJuniorVault public junior;
    ConcreteReserveVault public reserve;
    MockERC20 public lpToken;
    
    address public treasury;
    address public keeper;
    address public seniorUser;
    address public juniorUser;
    address public reserveUser;
    
    uint256 constant INITIAL_VALUE = 1000e18;
    
    function setUp() public {
        treasury = makeAddr("treasury");
        keeper = makeAddr("keeper");
        seniorUser = makeAddr("seniorUser");
        juniorUser = makeAddr("juniorUser");
        reserveUser = makeAddr("reserveUser");
        
        // Deploy LP token
        lpToken = new MockERC20("USDe-SAIL", "USDe-SAIL", 18);
        
        // Compute the address where Senior vault proxy will be deployed
        // Nonce: +3 implementations, +2 proxies (junior, reserve), then senior proxy
        uint64 currentNonce = vm.getNonce(address(this));
        address predictedSeniorAddress = vm.computeCreateAddress(address(this), currentNonce + 5);
        
        // Deploy implementations
        ConcreteJuniorVault juniorImpl = new ConcreteJuniorVault();
        ConcreteReserveVault reserveImpl = new ConcreteReserveVault();
        UnifiedConcreteSeniorVault seniorImpl = new UnifiedConcreteSeniorVault();
        
        // Deploy Junior and Reserve vault proxies
        ERC1967Proxy juniorProxy = new ERC1967Proxy(address(juniorImpl), abi.encodeWithSelector(ConcreteJuniorVault.initialize.selector, address(lpToken), predictedSeniorAddress, INITIAL_VALUE));
        junior = ConcreteJuniorVault(address(juniorProxy));
        
        ERC1967Proxy reserveProxy = new ERC1967Proxy(address(reserveImpl), abi.encodeWithSelector(ConcreteReserveVault.initialize.selector, address(lpToken), predictedSeniorAddress, INITIAL_VALUE));
        reserve = ConcreteReserveVault(address(reserveProxy));
        
        // Deploy Senior vault proxy
        ERC1967Proxy seniorProxy = new ERC1967Proxy(address(seniorImpl), abi.encodeWithSelector(UnifiedConcreteSeniorVault.initialize.selector, address(lpToken), "Senior USD", "snrUSD", address(junior), address(reserve), treasury, INITIAL_VALUE));
        senior = UnifiedConcreteSeniorVault(address(seniorProxy));
        
        require(address(senior) == predictedSeniorAddress, "Senior address mismatch");
        
        // Mint LP tokens to vaults and users
        lpToken.mint(address(senior), INITIAL_VALUE);
        lpToken.mint(address(junior), INITIAL_VALUE);
        lpToken.mint(address(reserve), INITIAL_VALUE);
        lpToken.mint(seniorUser, 10000e18);
        lpToken.mint(juniorUser, 10000e18);
        lpToken.mint(reserveUser, 10000e18);
        
        senior.setAdmin(keeper);
    }
    
    /**
     * @notice Test spillover when backing ratio >110%
     * @dev Math Spec: Zone 1 - Profit Spillover
     *      - Excess = V_s - 1.10 × S
     *      - 80% to Junior, 20% to Reserve
     */
    function testSpilloverBasic() public {
        // 1. Senior user deposits 1000 snrUSD
        vm.startPrank(seniorUser);
        lpToken.approve(address(senior), 1000e18);
        senior.deposit(1000e18, seniorUser);
        vm.stopPrank();
        
        uint256 seniorSupply = senior.totalSupply();
        assertEq(seniorSupply, 1000e18);
        
        // 2. Simulate vault profit (+20%)
        vm.warp(block.timestamp + 30 days);
        vm.prank(keeper);
        senior.updateVaultValue(2000); // +20%
        
        uint256 juniorValueBefore = junior.vaultValue();
        uint256 reserveValueBefore = reserve.vaultValue();
        
        // Senior backing ratio: (1000 + 1000*1.20) / 1000 = 2200/1000 = 220% (>110%)
        assertGt(senior.backingRatio(), 110e16); // >110%
        
        // 3. Execute rebase (should trigger spillover)
        vm.prank(keeper);
        senior.rebase();
        
        // 4. Verify spillover occurred
        uint256 juniorValueAfter = junior.vaultValue();
        uint256 reserveValueAfter = reserve.vaultValue();
        
        // Junior should receive ~80% of excess
        assertGt(juniorValueAfter, juniorValueBefore);
        
        // Reserve should receive ~20% of excess
        assertGt(reserveValueAfter, reserveValueBefore);
        
        // Senior backing should be brought down to ~110%
        uint256 finalRatio = senior.backingRatio();
        assertApproxEqRel(finalRatio, 110e16, 1e16); // Within 1%
    }
    
    /**
     * @notice Test spillover distribution (80/20 split)
     * @dev Math Spec: E_j = E × 0.80, E_r = E × 0.20
     */
    function testSpilloverDistribution() public {
        // Setup: Deposit and create profit
        vm.startPrank(seniorUser);
        lpToken.approve(address(senior), 1000e18);
        senior.deposit(1000e18, seniorUser);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 30 days);
        vm.prank(keeper);
        senior.updateVaultValue(3000); // +30% profit
        
        uint256 juniorBefore = junior.vaultValue();
        uint256 reserveBefore = reserve.vaultValue();
        
        // Execute rebase with spillover
        vm.prank(keeper);
        senior.rebase();
        
        uint256 juniorIncrease = junior.vaultValue() - juniorBefore;
        uint256 reserveIncrease = reserve.vaultValue() - reserveBefore;
        
        // Verify 80/20 split (approximately)
        uint256 totalSpillover = juniorIncrease + reserveIncrease;
        uint256 juniorPercentage = (juniorIncrease * 100) / totalSpillover;
        uint256 reservePercentage = (reserveIncrease * 100) / totalSpillover;
        
        assertApproxEqAbs(juniorPercentage, 80, 1); // ~80%
        assertApproxEqAbs(reservePercentage, 20, 1); // ~20%
    }
    
    /**
     * @notice Test multiple spillovers accumulate in Junior/Reserve
     */
    function testMultipleSpillovers() public {
        vm.startPrank(seniorUser);
        lpToken.approve(address(senior), 1000e18);
        senior.deposit(1000e18, seniorUser);
        vm.stopPrank();
        
        uint256 juniorInitial = junior.vaultValue();
        uint256 reserveInitial = reserve.vaultValue();
        
        // First spillover
        vm.warp(block.timestamp + 30 days);
        vm.prank(keeper);
        senior.updateVaultValue(2000); // +20%
        vm.prank(keeper);
        senior.rebase();
        
        uint256 juniorAfterFirst = junior.vaultValue();
        uint256 reserveAfterFirst = reserve.vaultValue();
        
        assertGt(juniorAfterFirst, juniorInitial);
        assertGt(reserveAfterFirst, reserveInitial);
        
        // Second spillover
        vm.warp(block.timestamp + 30 days);
        vm.prank(keeper);
        senior.updateVaultValue(2000); // Another +20%
        vm.prank(keeper);
        senior.rebase();
        
        uint256 juniorAfterSecond = junior.vaultValue();
        uint256 reserveAfterSecond = reserve.vaultValue();
        
        // Both should have increased again
        assertGt(juniorAfterSecond, juniorAfterFirst);
        assertGt(reserveAfterSecond, reserveAfterFirst);
    }
    
    /**
     * @notice Test spillover increases Junior/Reserve share value
     */
    function testSpilloverIncreasesShareValue() public {
        // Junior user deposits
        vm.startPrank(juniorUser);
        lpToken.approve(address(junior), 500e18);
        uint256 juniorShares = junior.deposit(500e18, juniorUser);
        vm.stopPrank();
        
        // Reserve user deposits
        vm.startPrank(reserveUser);
        lpToken.approve(address(reserve), 500e18);
        uint256 reserveShares = reserve.deposit(500e18, reserveUser);
        vm.stopPrank();
        
        // Get initial share prices
        uint256 juniorAssetsPerShareBefore = junior.convertToAssets(1e18);
        uint256 reserveAssetsPerShareBefore = reserve.convertToAssets(1e18);
        
        // Senior deposits and triggers spillover
        vm.startPrank(seniorUser);
        lpToken.approve(address(senior), 1000e18);
        senior.deposit(1000e18, seniorUser);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 30 days);
        vm.prank(keeper);
        senior.updateVaultValue(3000); // +30%
        vm.prank(keeper);
        senior.rebase();
        
        // Get new share prices
        uint256 juniorAssetsPerShareAfter = junior.convertToAssets(1e18);
        uint256 reserveAssetsPerShareAfter = reserve.convertToAssets(1e18);
        
        // Share value should increase
        assertGt(juniorAssetsPerShareAfter, juniorAssetsPerShareBefore);
        assertGt(reserveAssetsPerShareAfter, reserveAssetsPerShareBefore);
    }
    
    /**
     * @notice Test spillover with multiple Senior depositors
     */
    function testSpilloverWithMultipleUsers() public {
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");
        lpToken.mint(user2, 1000e18);
        lpToken.mint(user3, 1000e18);
        
        // Three users deposit
        vm.startPrank(seniorUser);
        lpToken.approve(address(senior), 1000e18);
        senior.deposit(1000e18, seniorUser);
        vm.stopPrank();
        
        vm.startPrank(user2);
        lpToken.approve(address(senior), 1000e18);
        senior.deposit(1000e18, user2);
        vm.stopPrank();
        
        vm.startPrank(user3);
        lpToken.approve(address(senior), 1000e18);
        senior.deposit(1000e18, user3);
        vm.stopPrank();
        
        // Trigger spillover
        vm.warp(block.timestamp + 30 days);
        vm.prank(keeper);
        senior.updateVaultValue(3000); // +30%
        vm.prank(keeper);
        senior.rebase();
        
        // All users should benefit from rebase
        uint256 balance1 = senior.balanceOf(seniorUser);
        uint256 balance2 = senior.balanceOf(user2);
        uint256 balance3 = senior.balanceOf(user3);
        
        // All balances should have increased proportionally
        assertGt(balance1, 1000e18);
        assertGt(balance2, 1000e18);
        assertGt(balance3, 1000e18);
        assertApproxEqRel(balance1, balance2, 1e14); // Should be equal
        assertApproxEqRel(balance2, balance3, 1e14);
    }
    
    /**
     * @notice Test spillover updates cumulative tracking
     */
    function testSpilloverTracking() public {
        vm.startPrank(seniorUser);
        lpToken.approve(address(senior), 1000e18);
        senior.deposit(1000e18, seniorUser);
        vm.stopPrank();
        
        assertEq(junior.totalSpilloverReceived(), 0);
        assertEq(reserve.totalSpilloverReceived(), 0);
        
        // Trigger spillover
        vm.warp(block.timestamp + 30 days);
        vm.prank(keeper);
        senior.updateVaultValue(3000); // +30%
        vm.prank(keeper);
        senior.rebase();
        
        // Cumulative spillover should be tracked
        assertGt(junior.totalSpilloverReceived(), 0);
        assertGt(reserve.totalSpilloverReceived(), 0);
    }
    
    /**
     * @notice Fuzz test: Spillover maintains 80/20 split across various profit amounts
     */
    function testFuzz_SpilloverDistribution(uint256 profitBps) public {
        profitBps = bound(profitBps, 1500, 5000); // 15% to 50% profit
        
        vm.startPrank(seniorUser);
        lpToken.approve(address(senior), 1000e18);
        senior.deposit(1000e18, seniorUser);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 30 days);
        vm.prank(keeper);
        senior.updateVaultValue(int256(profitBps));
        
        uint256 juniorBefore = junior.vaultValue();
        uint256 reserveBefore = reserve.vaultValue();
        
        vm.prank(keeper);
        senior.rebase();
        
        uint256 juniorIncrease = junior.vaultValue() - juniorBefore;
        uint256 reserveIncrease = reserve.vaultValue() - reserveBefore;
        
        if (juniorIncrease + reserveIncrease > 0) {
            uint256 totalSpillover = juniorIncrease + reserveIncrease;
            uint256 juniorPct = (juniorIncrease * 100) / totalSpillover;
            
            // Should be approximately 80%
            assertApproxEqAbs(juniorPct, 80, 2);
        }
    }
}

