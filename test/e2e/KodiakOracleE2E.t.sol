// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {ConcreteJuniorVault} from "../../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../../src/concrete/ConcreteReserveVault.sol";
import {UnifiedConcreteSeniorVault} from "../../src/concrete/UnifiedConcreteSeniorVault.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IKodiakVaultHook} from "../../src/integrations/IKodiakVaultHook.sol";
import {IKodiakIsland} from "../../src/integrations/IKodiakIsland.sol";

/**
 * @title KodiakOracleE2ETest
 * @notice End-to-end tests for complete system workflows with Kodiak + Oracle
 */
contract KodiakOracleE2ETest is Test {
    ConcreteJuniorVault public juniorVault;
    ConcreteReserveVault public reserveVault;
    UnifiedConcreteSeniorVault public seniorVault;
    MockERC20 public stablecoin;
    MockERC20 public honey;
    MockERC20 public juniorLP;
    MockERC20 public reserveLP;
    MockERC20 public seniorLP;
    
    address public admin = address(this);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public charlie = address(0xC);
    
    address public juniorHook;
    address public reserveHook;
    address public seniorHook;
    address public juniorIsland;
    address public reserveIsland;
    address public seniorIsland;
    
    uint256 constant LP_PRICE = 1e18;
    
    function setUp() public {
        // Deploy tokens
        stablecoin = new MockERC20("USDC", "USDC", 18);
        honey = new MockERC20("HONEY", "HONEY", 18);
        juniorLP = new MockERC20("Junior LP", "jLP", 18);
        reserveLP = new MockERC20("Reserve LP", "rLP", 18);
        seniorLP = new MockERC20("Senior LP", "sLP", 18);
        
        // Deploy vaults
        juniorVault = new ConcreteJuniorVault();
        reserveVault = new ConcreteReserveVault();
        seniorVault = new UnifiedConcreteSeniorVault();
        
        // Initialize vaults (with placeholders first)
        juniorVault.initialize(
            address(stablecoin),
            address(0x1),  // placeholder
            0
        );
        
        reserveVault.initialize(
            address(stablecoin),
            address(0x1),  // placeholder
            0
        );
        
        seniorVault.initialize(
            address(stablecoin),
            "Senior USD",
            "snrUSD",
            address(juniorVault),
            address(reserveVault),
            address(this),  // treasury
            0               // initial value
        );
        
        // Update senior vault references
        juniorVault.updateSeniorVault(address(seniorVault));
        reserveVault.updateSeniorVault(address(seniorVault));
        
        // Create islands with realistic pool ratios
        juniorIsland = address(new FullMockIsland(
            address(stablecoin),
            address(honey),
            1000000e18,  // 1M USDC
            2000000e18,  // 2M HONEY
            address(juniorLP)
        ));
        
        reserveIsland = address(new FullMockIsland(
            address(stablecoin),
            address(honey),
            500000e18,   // 500K USDC
            1000000e18,  // 1M HONEY
            address(reserveLP)
        ));
        
        seniorIsland = address(new FullMockIsland(
            address(stablecoin),
            address(honey),
            2000000e18,  // 2M USDC
            4000000e18,  // 4M HONEY
            address(seniorLP)
        ));
        
        // Create hooks
        juniorHook = address(new FullMockHook(address(juniorVault), juniorIsland));
        reserveHook = address(new FullMockHook(address(reserveVault), reserveIsland));
        seniorHook = address(new FullMockHook(address(seniorVault), seniorIsland));
        
        // Setup hooks
        juniorVault.setKodiakHook(juniorHook);
        reserveVault.setKodiakHook(reserveHook);
        seniorVault.setKodiakHook(seniorHook);
        
        // Whitelist LP tokens for spillover/backstop
        juniorVault.addWhitelistedLPToken(address(juniorLP));
        reserveVault.addWhitelistedLPToken(address(reserveLP));
        seniorVault.addWhitelistedLPToken(address(seniorLP));
        
        // Mint LP tokens to hooks (simulating deployed positions)
        juniorLP.mint(juniorHook, 100000e18);
        reserveLP.mint(reserveHook, 50000e18);
        seniorLP.mint(seniorHook, 200000e18);
        
        // Mint stablecoin to users
        stablecoin.mint(alice, 1000000e18);
        stablecoin.mint(bob, 500000e18);
        stablecoin.mint(charlie, 250000e18);
    }
    
    // ============================================
    // E2E: Production Deployment Workflow
    // ============================================
    
    function test_E2E_productionDeployment() public {
        console.log("=== E2E: Production Deployment ===");
        
        // Phase 1: Configure oracles (manual mode with validation)
        console.log("Phase 1: Configure oracles");
        juniorVault.configureOracle(juniorIsland, true, 500, true, false);
        reserveVault.configureOracle(reserveIsland, true, 500, true, false);
        seniorVault.configureOracle(seniorIsland, true, 500, true, false);
        
        // Phase 2: Users deposit
        console.log("Phase 2: Users deposit");
        
        juniorVault.setVaultValue(0);
        vm.startPrank(alice);
        stablecoin.approve(address(juniorVault), 100000e18);
        uint256 aliceShares = juniorVault.deposit(100000e18, alice);
        vm.stopPrank();
        console.log("Alice deposited 100K, got shares:", aliceShares);
        
        reserveVault.setVaultValue(0);
        vm.startPrank(bob);
        stablecoin.approve(address(reserveVault), 50000e18);
        uint256 bobShares = reserveVault.deposit(50000e18, bob);
        vm.stopPrank();
        console.log("Bob deposited 50K, got shares:", bobShares);
        
        // Phase 3: Admin deploys funds to Kodiak
        console.log("Phase 3: Deploy to Kodiak");
        juniorVault.deployToKodiak(90000e18, 0, address(0), "", address(0), "");
        reserveVault.deployToKodiak(45000e18, 0, address(0), "", address(0), "");
        console.log("Deployed to Kodiak successfully");
        
        // Phase 4: Keeper updates vault values
        console.log("Phase 4: Update vault values");
        uint256 juniorCalc = juniorVault.getCalculatedVaultValue();
        uint256 reserveCalc = reserveVault.getCalculatedVaultValue();
        
        juniorVault.setVaultValue(juniorCalc);
        reserveVault.setVaultValue(reserveCalc);
        console.log("Junior value:", juniorCalc);
        console.log("Reserve value:", reserveCalc);
        
        // Phase 5: Verify values are correct
        assertGt(juniorVault.vaultValue(), 90000e18);
        assertGt(reserveVault.vaultValue(), 45000e18);
        console.log("=== Deployment Complete ===\n");
    }
    
    // ============================================
    // E2E: Migration to Automatic Mode
    // ============================================
    
    function test_E2E_migrateToAutomaticMode() public {
        console.log("=== E2E: Migrate to Automatic Mode ===");
        
        // Start with manual mode
        console.log("Phase 1: Start with manual mode");
        juniorVault.configureOracle(juniorIsland, true, 500, true, false);
        juniorVault.setVaultValue(100000e18);
        
        // Users deposit
        vm.startPrank(alice);
        stablecoin.approve(address(juniorVault), 50000e18);
        juniorVault.deposit(50000e18, alice);
        vm.stopPrank();
        
        // Deploy funds
        juniorVault.deployToKodiak(140000e18, 0, address(0), "", address(0), "");
        
        // Manual value update
        uint256 calcValue = juniorVault.getCalculatedVaultValue();
        juniorVault.setVaultValue(calcValue);
        console.log("Manual mode value:", juniorVault.vaultValue());
        
        // Migrate to automatic
        console.log("Phase 2: Migrate to automatic");
        juniorVault.configureOracle(juniorIsland, true, 0, false, true);
        
        uint256 autoValue1 = juniorVault.vaultValue();
        console.log("Automatic mode value:", autoValue1);
        assertGt(autoValue1, 0);
        
        // Deploy more funds (no manual update needed!)
        console.log("Phase 3: Deploy more funds");
        stablecoin.mint(address(juniorVault), 50000e18);
        juniorVault.deployToKodiak(50000e18, 0, address(0), "", address(0), "");
        
        uint256 autoValue2 = juniorVault.vaultValue();
        console.log("New automatic value:", autoValue2);
        assertGt(autoValue2, autoValue1);
        console.log("=== Migration Complete ===\n");
    }
    
    // ============================================
    // E2E: Multi-User Complex Scenario
    // ============================================
    
    function test_E2E_multiUserComplexScenario() public {
        console.log("=== E2E: Multi-User Complex Scenario ===");
        
        // Setup: Configure automatic mode for all vaults
        juniorVault.configureOracle(juniorIsland, true, 0, false, true);
        reserveVault.configureOracle(reserveIsland, true, 0, false, true);
        seniorVault.configureOracle(seniorIsland, true, 0, false, true);
        
        // Set initial values
        juniorVault.setVaultValue(0);
        reserveVault.setVaultValue(0);
        
        // Round 1: Alice and Bob deposit
        console.log("Round 1: Alice and Bob deposit");
        vm.startPrank(alice);
        stablecoin.approve(address(juniorVault), 200000e18);
        juniorVault.deposit(200000e18, alice);
        vm.stopPrank();
        
        vm.startPrank(bob);
        stablecoin.approve(address(reserveVault), 100000e18);
        reserveVault.deposit(100000e18, bob);
        vm.stopPrank();
        
        // Admin deploys funds
        juniorVault.deployToKodiak(180000e18, 0, address(0), "", address(0), "");
        reserveVault.deployToKodiak(90000e18, 0, address(0), "", address(0), "");
        
        uint256 juniorValue1 = juniorVault.vaultValue();
        uint256 reserveValue1 = reserveVault.vaultValue();
        console.log("After deployment - Junior:", juniorValue1, "Reserve:", reserveValue1);
        
        // Round 2: Charlie deposits (different vault values now)
        console.log("Round 2: Charlie deposits");
        vm.startPrank(charlie);
        stablecoin.approve(address(juniorVault), 100000e18);
        uint256 charlieShares = juniorVault.deposit(100000e18, charlie);
        vm.stopPrank();
        console.log("Charlie got shares:", charlieShares);
        
        // Admin deploys Charlie's deposit
        juniorVault.sweepToKodiak(0, address(0), "", address(0), "");
        
        uint256 juniorValue2 = juniorVault.vaultValue();
        console.log("After Charlie - Junior:", juniorValue2);
        assertGt(juniorValue2, juniorValue1);
        
        // Round 3: Alice withdraws some
        console.log("Round 3: Alice withdraws");
        vm.startPrank(alice);
        uint256 aliceShares = juniorVault.balanceOf(alice);
        uint256 withdrawAmount = juniorVault.redeem(aliceShares / 2, alice, alice);
        vm.stopPrank();
        console.log("Alice withdrew:", withdrawAmount);
        
        // Verify everyone has correct balances
        assertGt(juniorVault.balanceOf(alice), 0);
        assertGt(juniorVault.balanceOf(charlie), 0);
        assertGt(reserveVault.balanceOf(bob), 0);
        console.log("=== Complex Scenario Complete ===\n");
    }
    
    // ============================================
    // E2E: Oracle Validation Prevents Errors
    // ============================================
    
    function test_E2E_oracleValidationPreventsErrors() public {
        console.log("=== E2E: Oracle Validation ===");
        
        // Setup with validation enabled
        juniorVault.configureOracle(juniorIsland, true, 500, true, false);
        
        // Deploy funds
        stablecoin.mint(address(juniorVault), 100000e18);
        juniorVault.deployToKodiak(100000e18, 0, address(0), "", address(0), "");
        
        // Get correct value
        uint256 correctValue = juniorVault.getCalculatedVaultValue();
        console.log("Calculated value:", correctValue);
        
        // Keeper updates with correct value (should pass)
        juniorVault.setVaultValue(correctValue);
        console.log("Set correct value - Success");
        
        // Keeper tries wrong value (should fail)
        vm.expectRevert();
        juniorVault.setVaultValue(correctValue * 2);
        console.log("Rejected wrong value - Success");
        
        // Value should still be correct
        assertEq(juniorVault.vaultValue(), correctValue);
        console.log("=== Validation Working ===\n");
    }
    
    // ============================================
    // E2E: Dust Management
    // ============================================
    
    function test_E2E_dustManagement() public {
        console.log("=== E2E: Dust Management ===");
        
        juniorVault.configureOracle(juniorIsland, true, 0, false, true);
        
        // Users deposit various amounts
        vm.startPrank(alice);
        stablecoin.approve(address(juniorVault), 123456e18);
        juniorVault.deposit(123456e18, alice);
        vm.stopPrank();
        
        vm.startPrank(bob);
        stablecoin.approve(address(juniorVault), 67890e18);
        juniorVault.deposit(67890e18, bob);
        vm.stopPrank();
        
        // Admin deploys most funds
        console.log("Deploy most funds");
        juniorVault.deployToKodiak(180000e18, 0, address(0), "", address(0), "");
        
        uint256 remainingDust = stablecoin.balanceOf(address(juniorVault));
        console.log("Remaining dust:", remainingDust);
        
        // Sweep all dust
        console.log("Sweep dust");
        juniorVault.sweepToKodiak(0, address(0), "", address(0), "");
        
        // No idle funds left
        assertEq(stablecoin.balanceOf(address(juniorVault)), 0);
        console.log("All dust deployed successfully");
        console.log("=== Dust Management Complete ===\n");
    }
    
    // ============================================
    // E2E: Hook Replacement
    // ============================================
    
    function test_E2E_hookReplacement() public {
        console.log("=== E2E: Hook Replacement ===");
        
        juniorVault.configureOracle(juniorIsland, true, 0, false, true);
        
        // Deploy with first hook
        stablecoin.mint(address(juniorVault), 100000e18);
        juniorVault.deployToKodiak(100000e18, 0, address(0), "", address(0), "");
        
        uint256 value1 = juniorVault.vaultValue();
        console.log("Value with first hook:", value1);
        
        // Replace hook
        console.log("Replacing hook");
        address newHook = address(new FullMockHook(address(juniorVault), juniorIsland));
        juniorLP.mint(newHook, 150000e18); // More LP in new hook
        
        juniorVault.setKodiakHook(newHook);
        
        uint256 value2 = juniorVault.vaultValue();
        console.log("Value with new hook:", value2);
        assertNotEq(value2, value1);
        console.log("=== Hook Replacement Complete ===\n");
    }
    
    // ============================================
    // E2E: Stress Test
    // ============================================
    
    function test_E2E_stressTest() public {
        console.log("=== E2E: Stress Test ===");
        
        // Configure all vaults in automatic mode
        juniorVault.configureOracle(juniorIsland, true, 0, false, true);
        reserveVault.configureOracle(reserveIsland, true, 0, false, true);
        seniorVault.configureOracle(seniorIsland, true, 0, false, true);
        
        juniorVault.setVaultValue(0);
        reserveVault.setVaultValue(0);
        
        // Multiple rounds of deposits and deployments
        for (uint256 i = 0; i < 5; i++) {
            console.log("Round", i + 1);
            
            // Users deposit
            vm.startPrank(alice);
            stablecoin.approve(address(juniorVault), 10000e18);
            juniorVault.deposit(10000e18, alice);
            vm.stopPrank();
            
            vm.startPrank(bob);
            stablecoin.approve(address(reserveVault), 5000e18);
            reserveVault.deposit(5000e18, bob);
            vm.stopPrank();
            
            // Admin deploys
            juniorVault.sweepToKodiak(0, address(0), "", address(0), "");
            reserveVault.sweepToKodiak(0, address(0), "", address(0), "");
            
            // Check values increased
            console.log("Junior value:", juniorVault.vaultValue());
            console.log("Reserve value:", reserveVault.vaultValue());
        }
        
        // Final checks
        assertGt(juniorVault.vaultValue(), 50000e18);
        assertGt(reserveVault.vaultValue(), 25000e18);
        console.log("=== Stress Test Complete ===\n");
    }
}

// ============================================
// Mock Contracts
// ============================================

contract FullMockIsland is IKodiakIsland {
    IERC20 private _token0;
    IERC20 private _token1;
    address public pool;
    address public lpToken;
    uint256 private balance0;
    uint256 private balance1;
    uint256 private _totalSupply = 1000000e18;
    
    constructor(address token0_, address token1_, uint256 balance0_, uint256 balance1_, address lpToken_) {
        _token0 = IERC20(token0_);
        _token1 = IERC20(token1_);
        balance0 = balance0_;
        balance1 = balance1_;
        lpToken = lpToken_;
        pool = address(this);
    }
    
    function token0() external view override returns (IERC20) {
        return _token0;
    }
    
    function token1() external view override returns (IERC20) {
        return _token1;
    }
    
    function lowerTick() external pure override returns (int24) {
        return -887220;
    }
    
    function upperTick() external pure override returns (int24) {
        return 887220;
    }
    
    function getUnderlyingBalances() external view override returns (uint256, uint256) {
        return (balance0, balance1);
    }
    
    function getMintAmounts(uint256, uint256) external pure override returns (uint256, uint256, uint256) {
        return (0, 0, 1000e18);
    }
    
    function mint(uint256, address to) external override returns (uint256, uint256) {
        MockERC20(lpToken).mint(to, 1000e18);
        return (0, 0);
    }
    
    function burn(uint256, address) external pure override returns (uint256, uint256) {
        return (0, 0);
    }
    
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) external view returns (uint256) {
        return MockERC20(lpToken).balanceOf(account);
    }
    
    function transfer(address, uint256) external pure returns (bool) {
        return true;
    }
    
    function transferFrom(address, address, uint256) external pure returns (bool) {
        return true;
    }
    
    function approve(address, uint256) external pure returns (bool) {
        return true;
    }
    
    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }
}

contract FullMockHook is IKodiakVaultHook {
    address public immutable vault;
    address public immutable island;
    
    constructor(address _vault, address _island) {
        vault = _vault;
        island = _island;
    }
    
    function onAfterDeposit(uint256) external override {}
    
    function onAfterDepositWithSwaps(
        uint256,
        address,
        bytes calldata,
        address,
        bytes calldata
    ) external override {}
    
    function ensureFundsAvailable(uint256) external override {}
    
    function transferIslandLP(address, uint256) external override {}
    
    function getIslandLPBalance() external view override returns (uint256) {
        address lpToken = FullMockIsland(island).lpToken();
        return IERC20(lpToken).balanceOf(address(this));
    }
}

