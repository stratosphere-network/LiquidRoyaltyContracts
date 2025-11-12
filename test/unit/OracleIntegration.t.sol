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
 * @title OracleIntegrationTest
 * @notice Unit tests for Oracle integration (configureOracle, vaultValue modes, validation)
 */
contract OracleIntegrationTest is Test {
    ConcreteJuniorVault public juniorVault;
    MockERC20 public stablecoin;
    MockERC20 public token0;
    MockERC20 public token1;
    
    address public admin = address(this);
    address public user = address(0x1);
    address public mockHook;
    address public mockIsland;
    
    event OracleConfigured(address indexed island, bool stablecoinIsToken0, uint256 maxDeviationBps, bool enabled);
    event VaultValueValidated(uint256 providedValue, uint256 calculatedValue, uint256 deviationBps);
    event VaultValueUpdated(uint256 oldValue, uint256 newValue, int256 profitBps);
    
    function setUp() public {
        // Deploy mocks
        stablecoin = new MockERC20("USDC", "USDC", 18);
        token0 = stablecoin;
        token1 = new MockERC20("HONEY", "HONEY", 18);
        
        // Deploy vault
        juniorVault = new ConcreteJuniorVault();
        juniorVault.initialize(
            address(stablecoin),
            address(0x1), // placeholder senior vault
            0
        );
        
        // Create mock island with 1M USDC + 2M HONEY
        mockIsland = address(new MockKodiakIsland(
            address(token0),
            address(token1),
            1000000e18,  // 1M USDC
            2000000e18   // 2M HONEY
        ));
        
        // Create mock hook
        mockHook = address(new MockKodiakHookWithLP(
            address(juniorVault),
            mockIsland,
            1000e18  // 1000 LP tokens
        ));
        
        // Set hook
        juniorVault.setKodiakHook(mockHook);
        
        // Mint some idle stablecoin
        stablecoin.mint(address(juniorVault), 5000e18);
    }
    
    // ============================================
    // configureOracle Tests
    // ============================================
    
    function test_configureOracle_success() public {
        vm.expectEmit(true, false, false, true);
        emit OracleConfigured(mockIsland, true, 500, true);
        
        juniorVault.configureOracle(
            mockIsland,
            true,   // USDC is token0
            500,    // 5% max deviation
            true,   // Enable validation
            false   // Use admin-updated value
        );
        
        (
            address island,
            bool stablecoinIsToken0,
            uint256 maxDeviationBps,
            bool validationEnabled,
            bool useCalculatedValue
        ) = juniorVault.getOracleConfig();
        
        assertEq(island, mockIsland);
        assertTrue(stablecoinIsToken0);
        assertEq(maxDeviationBps, 500);
        assertTrue(validationEnabled);
        assertFalse(useCalculatedValue);
    }
    
    function test_configureOracle_revertsIfDeviationTooHigh() public {
        vm.expectRevert("Max deviation > 100%");
        juniorVault.configureOracle(
            mockIsland,
            true,
            10001,  // > 100%
            true,
            false
        );
    }
    
    function test_configureOracle_onlyAdmin() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("NotAdmin()"));
        juniorVault.configureOracle(mockIsland, true, 500, true, false);
    }
    
    function test_configureOracle_canUpdateSettings() public {
        // Initial config
        juniorVault.configureOracle(mockIsland, true, 500, true, false);
        
        // Update config
        juniorVault.configureOracle(mockIsland, false, 1000, false, true);
        
        (
            ,
            bool stablecoinIsToken0,
            uint256 maxDeviationBps,
            bool validationEnabled,
            bool useCalculatedValue
        ) = juniorVault.getOracleConfig();
        
        assertFalse(stablecoinIsToken0);
        assertEq(maxDeviationBps, 1000);
        assertFalse(validationEnabled);
        assertTrue(useCalculatedValue);
    }
    
    // ============================================
    // vaultValue Dual-Mode Tests
    // ============================================
    
    function test_vaultValue_manualMode() public {
        // Configure oracle in manual mode
        juniorVault.configureOracle(mockIsland, true, 500, false, false);
        
        // Set vault value manually
        juniorVault.setVaultValue(10000e18);
        
        // vaultValue() should return stored value
        assertEq(juniorVault.vaultValue(), 10000e18);
        assertEq(juniorVault.getStoredVaultValue(), 10000e18);
    }
    
    function test_vaultValue_automaticMode() public {
        // Configure oracle in automatic mode
        juniorVault.configureOracle(mockIsland, true, 0, false, true);
        
        // Set stored value (shouldn't be used)
        juniorVault.setVaultValue(10000e18);
        
        // vaultValue() should calculate from oracle
        uint256 calculatedValue = juniorVault.vaultValue();
        uint256 expectedValue = juniorVault.getCalculatedVaultValue();
        
        assertEq(calculatedValue, expectedValue);
        assertGt(calculatedValue, 0);
        // Stored value should be different
        assertEq(juniorVault.getStoredVaultValue(), 10000e18);
    }
    
    function test_vaultValue_automaticModeFallsBackIfZero() public {
        // Create hook with 0 LP balance
        address zeroHook = address(new MockKodiakHookWithLP(
            address(juniorVault),
            mockIsland,
            0  // 0 LP tokens
        ));
        juniorVault.setKodiakHook(zeroHook);
        
        // Configure automatic mode
        juniorVault.configureOracle(mockIsland, true, 0, false, true);
        
        // Set stored value
        juniorVault.setVaultValue(5000e18);
        
        // vaultValue() should fallback to stored (calculated is 0)
        assertEq(juniorVault.vaultValue(), 5000e18);
    }
    
    function test_vaultValue_switchBetweenModes() public {
        juniorVault.configureOracle(mockIsland, true, 0, false, false);
        
        // Manual mode
        juniorVault.setVaultValue(10000e18);
        assertEq(juniorVault.vaultValue(), 10000e18);
        
        // Switch to automatic
        juniorVault.configureOracle(mockIsland, true, 0, false, true);
        uint256 calculatedValue = juniorVault.vaultValue();
        assertGt(calculatedValue, 0);
        assertNotEq(calculatedValue, 10000e18);
        
        // Switch back to manual
        juniorVault.configureOracle(mockIsland, true, 0, false, false);
        assertEq(juniorVault.vaultValue(), 10000e18);
    }
    
    // ============================================
    // Validation Tests
    // ============================================
    
    function test_validation_passesWithinTolerance() public {
        // Configure oracle with 5% tolerance
        juniorVault.configureOracle(mockIsland, true, 500, true, false);
        
        // Get calculated value
        uint256 calculatedValue = juniorVault.getCalculatedVaultValue();
        
        // Set value within 5%
        uint256 newValue = calculatedValue * 104 / 100; // 4% higher
        
        vm.expectEmit(false, false, false, true);
        emit VaultValueValidated(newValue, calculatedValue, 400);
        
        juniorVault.setVaultValue(newValue);
        
        assertEq(juniorVault.vaultValue(), newValue);
    }
    
    function test_validation_revertsOutsideTolerance() public {
        // Configure oracle with 5% tolerance
        juniorVault.configureOracle(mockIsland, true, 500, true, false);
        
        // Get calculated value
        uint256 calculatedValue = juniorVault.getCalculatedVaultValue();
        
        // Set value outside 5%
        uint256 newValue = calculatedValue * 2; // 100% higher
        
        vm.expectRevert();
        juniorVault.setVaultValue(newValue);
    }
    
    function test_validation_skipsIfNotEnabled() public {
        // Configure oracle but disable validation
        juniorVault.configureOracle(mockIsland, true, 500, false, false);
        
        uint256 calculatedValue = juniorVault.getCalculatedVaultValue();
        
        // Set crazy value (should pass because validation disabled)
        uint256 crazyValue = calculatedValue * 10;
        juniorVault.setVaultValue(crazyValue);
        
        assertEq(juniorVault.vaultValue(), crazyValue);
    }
    
    function test_validation_skipsIfNotConfigured() public {
        // Don't configure oracle at all
        
        // Should be able to set any value
        juniorVault.setVaultValue(999999e18);
        assertEq(juniorVault.vaultValue(), 999999e18);
    }
    
    function test_validation_skipsIfCalculatedIsZero() public {
        // Create hook with 0 LP
        address zeroHook = address(new MockKodiakHookWithLP(
            address(juniorVault),
            mockIsland,
            0
        ));
        juniorVault.setKodiakHook(zeroHook);
        
        // Configure validation
        juniorVault.configureOracle(mockIsland, true, 500, true, false);
        
        // Should be able to set any value (calculated is 0)
        juniorVault.setVaultValue(10000e18);
        assertEq(juniorVault.vaultValue(), 10000e18);
    }
    
    // ============================================
    // getCalculatedVaultValue Tests
    // ============================================
    
    function test_getCalculatedVaultValue_withLPAndIdle() public {
        juniorVault.configureOracle(mockIsland, true, 0, false, false);
        
        uint256 calculatedValue = juniorVault.getCalculatedVaultValue();
        
        // Should be LP value + idle stablecoin
        assertGt(calculatedValue, 5000e18); // At least the idle amount
    }
    
    function test_getCalculatedVaultValue_noHookReturnsZero() public {
        // Remove hook
        juniorVault.setKodiakHook(address(0));
        
        juniorVault.configureOracle(mockIsland, true, 0, false, false);
        
        uint256 calculatedValue = juniorVault.getCalculatedVaultValue();
        assertEq(calculatedValue, 0);
    }
    
    // ============================================
    // Real-World Scenarios
    // ============================================
    
    function test_scenario_manualModeWithValidation() public {
        // Setup: Manual mode with 5% validation
        juniorVault.configureOracle(mockIsland, true, 500, true, false);
        
        // Keeper updates value
        uint256 calculatedValue = juniorVault.getCalculatedVaultValue();
        juniorVault.setVaultValue(calculatedValue);
        
        // Users see the set value
        assertEq(juniorVault.vaultValue(), calculatedValue);
        
        // Later, try to set wrong value
        vm.expectRevert();
        juniorVault.setVaultValue(calculatedValue * 2);
    }
    
    function test_scenario_automaticModeNoKeeper() public {
        // Setup: Automatic mode (no keeper needed)
        juniorVault.configureOracle(mockIsland, true, 0, false, true);
        
        // Users always see calculated value
        uint256 value1 = juniorVault.vaultValue();
        assertGt(value1, 0);
        
        // Deploy more funds to Kodiak
        stablecoin.mint(address(juniorVault), 5000e18);
        juniorVault.deployToKodiak(5000e18, 0, address(0), "", address(0), "");
        
        // Value should increase automatically
        uint256 value2 = juniorVault.vaultValue();
        assertGt(value2, value1);
    }
    
    function test_scenario_startConservativeMigrateToAuto() public {
        // Phase 1: Start with manual mode + validation
        juniorVault.configureOracle(mockIsland, true, 500, true, false);
        juniorVault.setVaultValue(10000e18);
        assertEq(juniorVault.vaultValue(), 10000e18);
        
        // Phase 2: Migrate to automatic mode
        juniorVault.configureOracle(mockIsland, true, 0, false, true);
        uint256 autoValue = juniorVault.vaultValue();
        assertGt(autoValue, 0);
        
        // No manual updates needed anymore
        assertEq(juniorVault.vaultValue(), juniorVault.getCalculatedVaultValue());
    }
}

// ============================================
// Mock Contracts
// ============================================

contract MockKodiakIsland is IKodiakIsland {
    IERC20 private _token0;
    IERC20 private _token1;
    address public pool;
    uint256 private balance0;
    uint256 private balance1;
    uint256 private _totalSupply;
    
    constructor(address token0_, address token1_, uint256 balance0_, uint256 balance1_) {
        _token0 = IERC20(token0_);
        _token1 = IERC20(token1_);
        balance0 = balance0_;
        balance1 = balance1_;
        _totalSupply = 1000000e18; // 1M LP tokens total supply
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
        return (0, 0, 0);
    }
    
    function mint(uint256, address) external pure override returns (uint256, uint256) {
        return (0, 0);
    }
    
    function burn(uint256, address) external pure override returns (uint256, uint256) {
        return (0, 0);
    }
    
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address) external pure returns (uint256) {
        return 0;
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

contract MockKodiakHookWithLP is IKodiakVaultHook {
    address public immutable vault;
    address public immutable island;
    uint256 public lpBalance;
    
    constructor(address _vault, address _island, uint256 _lpBalance) {
        vault = _vault;
        island = _island;
        lpBalance = _lpBalance;
    }
    
    function onAfterDeposit(uint256 amount) external override {
        lpBalance += amount;
    }
    
    function onAfterDepositWithSwaps(
        uint256 amount,
        address,
        bytes calldata,
        address,
        bytes calldata
    ) external override {
        lpBalance += amount;
    }
    
    function ensureFundsAvailable(uint256) external override {}
    
    function transferIslandLP(address, uint256) external override {}
    
    function getIslandLPBalance() external view override returns (uint256) {
        return lpBalance;
    }
}

