// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UnifiedConcreteSeniorVault} from "../../src/concrete/UnifiedConcreteSeniorVault.sol";
import {ConcreteJuniorVault} from "../../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../../src/concrete/ConcreteReserveVault.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MockKodiakHook} from "../mocks/MockKodiakHook.sol";
import {MathLib} from "../../src/libraries/MathLib.sol";

/**
 * @title NewFeaturesTest
 * @notice Tests for newly added features:
 *  - seedVault() / seedReserveWithToken()
 *  - investInKodiak()
 *  - mintManagementFee()
 *  - setMgmtFeeSchedule() and related getters
 *  - setTreasury() / treasury()
 * 
 * Note: setKodiakRouter() tests removed (N10 - dead code cleanup)
 */
contract NewFeaturesTest is Test {
    UnifiedConcreteSeniorVault public seniorVault;
    ConcreteJuniorVault public juniorVault;
    ConcreteReserveVault public reserveVault;
    
    MockERC20 public stablecoin;
    MockERC20 public lpToken;
    MockERC20 public wbtc;
    
    MockKodiakHook public seniorHook;
    MockKodiakHook public juniorHook;
    MockKodiakHook public reserveHook;
    
    address public treasury;
    address public admin;
    address public seedProvider;
    address public seeder;
    address public kodiakRouter;
    
    uint256 constant INITIAL_VALUE = 1000e18;
    uint256 constant LP_PRICE = 1e18;
    uint256 constant WBTC_PRICE = 50000e18; // 50k USD per WBTC
    
    function setUp() public {
        treasury = makeAddr("treasury");
        admin = makeAddr("admin");
        seedProvider = makeAddr("seedProvider");
        seeder = makeAddr("seeder");
        kodiakRouter = makeAddr("kodiakRouter");
        
        // Deploy tokens
        stablecoin = new MockERC20("HONEY", "HONEY", 18);
        lpToken = new MockERC20("LP Token", "LP", 18);
        wbtc = new MockERC20("Wrapped BTC", "WBTC", 8);
        
        // Predict Senior vault address
        uint64 currentNonce = vm.getNonce(address(this));
        address predictedSeniorAddress = vm.computeCreateAddress(address(this), currentNonce + 5);
        
        // Deploy implementations
        ConcreteJuniorVault juniorImpl = new ConcreteJuniorVault();
        ConcreteReserveVault reserveImpl = new ConcreteReserveVault();
        UnifiedConcreteSeniorVault seniorImpl = new UnifiedConcreteSeniorVault();
        
        // Deploy Junior proxy
        bytes memory juniorInitData = abi.encodeWithSelector(
            ConcreteJuniorVault.initialize.selector,
            address(stablecoin),
            predictedSeniorAddress,
            INITIAL_VALUE
        );
        ERC1967Proxy juniorProxy = new ERC1967Proxy(address(juniorImpl), juniorInitData);
        juniorVault = ConcreteJuniorVault(address(juniorProxy));
        
        // Deploy Reserve proxy
        bytes memory reserveInitData = abi.encodeWithSelector(
            ConcreteReserveVault.initialize.selector,
            address(stablecoin),
            predictedSeniorAddress,
            INITIAL_VALUE
        );
        ERC1967Proxy reserveProxy = new ERC1967Proxy(address(reserveImpl), reserveInitData);
        reserveVault = ConcreteReserveVault(address(reserveProxy));
        
        // Deploy Senior proxy
        bytes memory seniorInitData = abi.encodeWithSelector(
            UnifiedConcreteSeniorVault.initialize.selector,
            address(stablecoin),
            "Senior USD",
            "snrUSD",
            address(juniorVault),
            address(reserveVault),
            treasury,
            INITIAL_VALUE
        );
        ERC1967Proxy seniorProxy = new ERC1967Proxy(address(seniorImpl), seniorInitData);
        seniorVault = UnifiedConcreteSeniorVault(address(seniorProxy));
        
        // Verify prediction
        assertEq(address(seniorVault), predictedSeniorAddress);
        
        // Set admins
        seniorVault.setAdmin(admin);
        juniorVault.setAdmin(admin);
        reserveVault.setAdmin(admin);
        
        // Add seeders
        vm.startPrank(admin);
        seniorVault.addSeeder(seeder);
        juniorVault.addSeeder(seeder);
        reserveVault.addSeeder(seeder);
        vm.stopPrank();
        
        // Create hooks
        seniorHook = new MockKodiakHook(address(seniorVault), address(0), address(lpToken));
        juniorHook = new MockKodiakHook(address(juniorVault), address(0), address(lpToken));
        reserveHook = new MockKodiakHook(address(reserveVault), address(0), address(lpToken));
        
        // Set hooks
        vm.startPrank(admin);
        seniorVault.setKodiakHook(address(seniorHook));
        juniorVault.setKodiakHook(address(juniorHook));
        reserveVault.setKodiakHook(address(reserveHook));
        vm.stopPrank();
        
        // Mint tokens (N2 FIX: mint to seeder who will provide and receive shares)
        lpToken.mint(seeder, 1000e18);
        wbtc.mint(seeder, 10e8); // 10 WBTC
        stablecoin.mint(address(seniorVault), INITIAL_VALUE);
        stablecoin.mint(address(juniorVault), INITIAL_VALUE);
        stablecoin.mint(address(reserveVault), INITIAL_VALUE);
    }
    
    // ============================================
    // Treasury Tests
    // ============================================
    
    function testSetTreasury_Senior() public {
        address newTreasury = makeAddr("newTreasury");
        
        vm.prank(admin);
        seniorVault.setTreasury(newTreasury);
        
        assertEq(seniorVault.treasury(), newTreasury);
    }
    
    function testSetTreasury_Junior() public {
        address newTreasury = makeAddr("newTreasury");
        
        vm.prank(admin);
        juniorVault.setTreasury(newTreasury);
        
        assertEq(juniorVault.treasury(), newTreasury);
    }
    
    function testSetTreasury_Reserve() public {
        address newTreasury = makeAddr("newTreasury");
        
        vm.prank(admin);
        reserveVault.setTreasury(newTreasury);
        
        assertEq(reserveVault.treasury(), newTreasury);
    }
    
    function testCannotSetTreasury_NotAdmin() public {
        address hacker = makeAddr("hacker");
        
        vm.prank(hacker);
        vm.expectRevert();
        juniorVault.setTreasury(hacker);
    }
    
    // ============================================
    // Seed Vault Tests (Senior/Junior)
    // ============================================
    
    function testSeedVault_Senior() public {
        // Setup: approve LP tokens (N2 FIX: seeder provides tokens and gets shares)
        vm.prank(seeder);
        lpToken.approve(address(seniorVault), 100e18);
        
        uint256 seniorBalanceBefore = seniorVault.balanceOf(seeder);
        uint256 vaultValueBefore = seniorVault.vaultValue();
        
        // Seed vault (N2 FIX: shares now go to msg.sender/seeder, not seedProvider)
        vm.prank(seeder);
        seniorVault.seedVault(address(lpToken), 100e18, LP_PRICE);
        
        // Assertions
        uint256 expectedValue = 100e18; // 100 LP * 1 price = 100 USD
        assertEq(seniorVault.balanceOf(seeder) - seniorBalanceBefore, expectedValue, "Should mint 100 snrUSD");
        assertEq(seniorVault.vaultValue() - vaultValueBefore, expectedValue, "Vault value should increase");
        assertEq(lpToken.balanceOf(address(seniorHook)), 100e18, "LP should be in hook");
    }
    
    function testSeedVault_Junior() public {
        // Setup (N2 FIX: seeder provides tokens and gets shares)
        vm.prank(seeder);
        lpToken.approve(address(juniorVault), 50e18);
        
        uint256 juniorBalanceBefore = juniorVault.balanceOf(seeder);
        uint256 vaultValueBefore = juniorVault.vaultValue();
        
        // Seed vault
        vm.prank(seeder);
        juniorVault.seedVault(address(lpToken), 50e18, LP_PRICE);
        
        // Assertions
        uint256 expectedValue = 50e18;
        assertEq(juniorVault.balanceOf(seeder) - juniorBalanceBefore, expectedValue, "Should mint shares");
        assertEq(juniorVault.vaultValue() - vaultValueBefore, expectedValue, "Vault value should increase");
        assertEq(lpToken.balanceOf(address(juniorHook)), 50e18, "LP should be in hook");
    }
    
    function testCannotSeedVault_NotAdmin() public {
        address nonSeeder = makeAddr("nonSeeder");
        lpToken.mint(nonSeeder, 100e18);
        
        vm.prank(nonSeeder);
        lpToken.approve(address(juniorVault), 100e18);
        
        vm.prank(nonSeeder);
        vm.expectRevert();
        juniorVault.seedVault(address(lpToken), 100e18, LP_PRICE);
    }
    
    // ============================================
    // Seed Reserve with Token Tests
    // ============================================
    
    function testSeedReserveWithToken() public {
        // Setup: approve WBTC (N2 FIX: seeder provides tokens and gets shares)
        vm.prank(seeder);
        wbtc.approve(address(reserveVault), 1e8); // 1 WBTC
        
        uint256 reserveBalanceBefore = reserveVault.balanceOf(seeder);
        uint256 vaultValueBefore = reserveVault.vaultValue();
        
        // Seed reserve with WBTC
        // WBTC has 8 decimals, so 1 WBTC = 1e8
        // Price is in 18 decimals: 50000e18 USD per WBTC
        // Value = (1e8 * 50000e18) / 1e18 = 1e8 * 50000 = 5000000e8 = 50000e18
        vm.prank(seeder);
        reserveVault.seedReserveWithToken(address(wbtc), 1e8, WBTC_PRICE);
        
        // Assertions
        // expectedValue = (amount * tokenPrice) / 1e18
        //              = (1e8 * 50000e18) / 1e18
        //              = 50000e8 = 5000000000 (in 8 decimal format)
        // But we want it in 18 decimals: 50000e18
        uint256 expectedValue = (uint256(1e8) * WBTC_PRICE) / 1e18;
        assertEq(reserveVault.balanceOf(seeder) - reserveBalanceBefore, expectedValue, "Should mint shares");
        assertEq(reserveVault.vaultValue() - vaultValueBefore, expectedValue, "Vault value should increase");
        assertEq(wbtc.balanceOf(address(reserveVault)), 1e8, "WBTC should stay in vault");
        assertEq(wbtc.balanceOf(address(reserveHook)), 0, "WBTC should NOT be in hook yet");
    }
    
    function testCannotSeedReserveWithToken_NotAdmin() public {
        address nonSeeder = makeAddr("nonSeeder");
        wbtc.mint(nonSeeder, 1e8);
        
        vm.prank(nonSeeder);
        wbtc.approve(address(reserveVault), 1e8);
        
        vm.prank(nonSeeder);
        vm.expectRevert();
        reserveVault.seedReserveWithToken(address(wbtc), 1e8, WBTC_PRICE);
    }
    
    // ============================================
    // Kodiak Router Tests (N10: REMOVED - Dead Code)
    // ============================================
    // setKodiakRouter() was removed from ReserveVault as unused dead code
    // ReserveVault uses kodiakHook, which has its own router reference
    
    // ============================================
    // Invest in Kodiak Tests
    // ============================================
    
    function testInvestInKodiak() public {
        // First seed reserve with WBTC (N2 FIX: seeder provides and receives)
        vm.prank(seeder);
        wbtc.approve(address(reserveVault), 1e8);
        
        vm.prank(seeder);
        reserveVault.seedReserveWithToken(address(wbtc), 1e8, WBTC_PRICE);
        
        // Verify WBTC is in reserve vault
        assertEq(wbtc.balanceOf(address(reserveVault)), 1e8);
        
        // No need to mock - MockKodiakHook will automatically mint LP based on WBTC amount
        
        // Invest WBTC into Kodiak (same pattern as deployToKodiak)
        address island = makeAddr("kodiakIsland");
        address dexAggregator = makeAddr("1inch");
        bytes memory swapData = hex"1234"; // Mock swap calldata
        
        vm.prank(admin);
        reserveVault.investInKodiak(
            island,             // Kodiak Island (pool)
            address(wbtc),      // token
            0.5e8,              // 0.5 WBTC
            20000e18,           // minLP (~25k expected with slippage)
            dexAggregator,      // swap aggregator
            swapData,           // swap 0.5 WBTC to pool tokens
            address(0),         // no second aggregator
            ""                  // no second swap
        );
        
        // Verify WBTC was transferred to hook
        assertEq(wbtc.balanceOf(address(reserveVault)), 0.5e8, "Half WBTC should remain");
    }
    
    // ============================================
    // Management Fee Schedule Tests (Junior/Reserve)
    // ============================================
    
    function testSetMgmtFeeSchedule_Junior() public {
        uint256 newSchedule = 30 days;
        
        vm.prank(admin);
        juniorVault.setMgmtFeeSchedule(newSchedule);
        
        assertEq(juniorVault.getMgmtFeeSchedule(), newSchedule);
    }
    
    function testSetMgmtFeeSchedule_Reserve() public {
        uint256 newSchedule = 90 days;
        
        vm.prank(admin);
        reserveVault.setMgmtFeeSchedule(newSchedule);
        
        assertEq(reserveVault.getMgmtFeeSchedule(), newSchedule);
    }
    
    function testCannotSetMgmtFeeSchedule_NotAdmin() public {
        address hacker = makeAddr("hacker");
        
        vm.prank(hacker);
        vm.expectRevert();
        juniorVault.setMgmtFeeSchedule(30 days);
    }
    
    function testCannotSetMgmtFeeSchedule_Zero() public {
        vm.prank(admin);
        vm.expectRevert();
        juniorVault.setMgmtFeeSchedule(0);
    }
    
    // ============================================
    // Mint Performance Fee Tests (Junior/Reserve)
    // ============================================
    
    function testMintPerformanceFee_Junior() public {
        // Set treasury first
        vm.prank(admin);
        juniorVault.setTreasury(treasury);
        
        // Bootstrap vault with seedVault - this mints initial shares (N2 FIX)
        vm.prank(seeder);
        lpToken.approve(address(juniorVault), 100e18);
        
        vm.prank(seeder);
        juniorVault.seedVault(address(lpToken), 100e18, LP_PRICE);
        
        uint256 supplyBefore = juniorVault.totalSupply();
        
        // Set schedule and wait
        vm.prank(admin);
        juniorVault.setMgmtFeeSchedule(7 days);
        
        vm.warp(block.timestamp + 7 days);
        
        // Check can mint
        assertTrue(juniorVault.canMintManagementFee());
        assertEq(juniorVault.getTimeUntilNextMint(), 0);
        
        // Mint fee
        vm.prank(admin);
        juniorVault.mintManagementFee();
        
        // Assertions
        uint256 expectedFee = supplyBefore / 100; // 1% of supply
        assertEq(juniorVault.balanceOf(treasury), expectedFee, "Treasury should receive 1% of supply");
        assertEq(juniorVault.getLastMintTime(), block.timestamp, "Last mint time should update");
    }
    
    function testMintPerformanceFee_Reserve() public {
        // Set treasury
        vm.prank(admin);
        reserveVault.setTreasury(treasury);
        
        // Bootstrap vault with seedVault (N2 FIX)
        vm.prank(seeder);
        lpToken.approve(address(reserveVault), 100e18);
        
        vm.prank(seeder);
        reserveVault.seedVault(address(lpToken), 100e18, LP_PRICE);
        
        uint256 supplyBefore = reserveVault.totalSupply();
        
        // Set schedule
        vm.prank(admin);
        reserveVault.setMgmtFeeSchedule(30 days);
        
        vm.warp(block.timestamp + 30 days);
        
        // Mint fee
        vm.prank(admin);
        reserveVault.mintManagementFee();
        
        // Assertions
        uint256 expectedFee = supplyBefore / 100;
        assertEq(reserveVault.balanceOf(treasury), expectedFee);
    }
    
    function testCannotMintPerformanceFee_TooEarly() public {
        vm.prank(admin);
        juniorVault.setMgmtFeeSchedule(7 days);
        
        vm.warp(block.timestamp + 3 days); // Only 3 days, need 7
        
        assertFalse(juniorVault.canMintManagementFee());
        assertEq(juniorVault.getTimeUntilNextMint(), 4 days);
        
        vm.prank(admin);
        vm.expectRevert();
        juniorVault.mintManagementFee();
    }
    
    function testCannotMintPerformanceFee_NotAdmin() public {
        address hacker = makeAddr("hacker");
        
        vm.prank(admin);
        juniorVault.setMgmtFeeSchedule(7 days);
        
        vm.warp(block.timestamp + 7 days);
        
        vm.prank(hacker);
        vm.expectRevert();
        juniorVault.mintManagementFee();
    }
}

