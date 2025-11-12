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
 * @title KodiakOracleIntegrationTest
 * @notice Integration tests for Kodiak + Oracle working together across vaults
 */
contract KodiakOracleIntegrationTest is Test {
    ConcreteJuniorVault public juniorVault;
    ConcreteReserveVault public reserveVault;
    UnifiedConcreteSeniorVault public seniorVault;
    MockERC20 public stablecoin;
    MockERC20 public token1;
    MockERC20 public lpToken;
    
    address public admin = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    
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
        token1 = new MockERC20("HONEY", "HONEY", 18);
        lpToken = new MockERC20("LP", "LP", 18);
        
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
        
        // Create mock islands
        juniorIsland = address(new MockIsland(address(stablecoin), address(token1), 1000000e18, 2000000e18));
        reserveIsland = address(new MockIsland(address(stablecoin), address(token1), 500000e18, 1000000e18));
        seniorIsland = address(new MockIsland(address(stablecoin), address(token1), 2000000e18, 4000000e18));
        
        // Create hooks
        juniorHook = address(new MockHook(address(juniorVault), juniorIsland, 1000e18));
        reserveHook = address(new MockHook(address(reserveVault), reserveIsland, 500e18));
        seniorHook = address(new MockHook(address(seniorVault), seniorIsland, 2000e18));
        
        // Setup hooks
        juniorVault.setKodiakHook(juniorHook);
        reserveVault.setKodiakHook(reserveHook);
        seniorVault.setKodiakHook(seniorHook);
        
        // Mint initial funds
        stablecoin.mint(address(juniorVault), 100000e18);
        stablecoin.mint(address(reserveVault), 50000e18);
        stablecoin.mint(address(seniorVault), 200000e18);
        
        // Whitelist LP tokens
        juniorVault.addWhitelistedLPToken(juniorIsland);
        reserveVault.addWhitelistedLPToken(reserveIsland);
        seniorVault.addWhitelistedLPToken(seniorIsland);
    }
    
    // ============================================
    // Multi-Vault Integration Tests
    // ============================================
    
    function test_allVaults_canDeployToKodiak() public {
        // Junior deploys
        juniorVault.deployToKodiak(10000e18, 9000e18, address(0), "", address(0), "");
        assertEq(stablecoin.balanceOf(juniorHook), 10000e18);
        
        // Reserve deploys
        reserveVault.deployToKodiak(5000e18, 4000e18, address(0), "", address(0), "");
        assertEq(stablecoin.balanceOf(reserveHook), 5000e18);
        
        // Senior deploys
        seniorVault.deployToKodiak(20000e18, 18000e18, address(0), "", address(0), "");
        assertEq(stablecoin.balanceOf(seniorHook), 20000e18);
    }
    
    function test_allVaults_canSweepDust() public {
        // Deploy most funds
        juniorVault.deployToKodiak(90000e18, 0, address(0), "", address(0), "");
        reserveVault.deployToKodiak(40000e18, 0, address(0), "", address(0), "");
        seniorVault.deployToKodiak(180000e18, 0, address(0), "", address(0), "");
        
        // Sweep remaining dust
        juniorVault.sweepToKodiak(0, address(0), "", address(0), "");
        reserveVault.sweepToKodiak(0, address(0), "", address(0), "");
        seniorVault.sweepToKodiak(0, address(0), "", address(0), "");
        
        // All funds should be deployed
        assertEq(stablecoin.balanceOf(address(juniorVault)), 0);
        assertEq(stablecoin.balanceOf(address(reserveVault)), 0);
        assertEq(stablecoin.balanceOf(address(seniorVault)), 0);
    }
    
    function test_allVaults_oracleConfiguration() public {
        // Configure oracles for all vaults
        juniorVault.configureOracle(juniorIsland, true, 500, true, false);
        reserveVault.configureOracle(reserveIsland, true, 500, true, false);
        seniorVault.configureOracle(seniorIsland, true, 500, true, false);
        
        // Check all configured correctly
        (address island1,,,,) = juniorVault.getOracleConfig();
        (address island2,,,,) = reserveVault.getOracleConfig();
        (address island3,,,,) = seniorVault.getOracleConfig();
        
        assertEq(island1, juniorIsland);
        assertEq(island2, reserveIsland);
        assertEq(island3, seniorIsland);
    }
    
    function test_allVaults_calculatedValues() public {
        // Configure automatic mode for all
        juniorVault.configureOracle(juniorIsland, true, 0, false, true);
        reserveVault.configureOracle(reserveIsland, true, 0, false, true);
        seniorVault.configureOracle(seniorIsland, true, 0, false, true);
        
        // All should return calculated values
        uint256 juniorValue = juniorVault.vaultValue();
        uint256 reserveValue = reserveVault.vaultValue();
        uint256 seniorValue = seniorVault.vaultValue();
        
        assertGt(juniorValue, 0);
        assertGt(reserveValue, 0);
        assertGt(seniorValue, 0);
    }
    
    // ============================================
    // Real-World Flow Tests
    // ============================================
    
    function test_fullFlow_userDeposit_adminDeploys_oracleCalculates() public {
        // Setup: Configure oracles in automatic mode
        juniorVault.configureOracle(juniorIsland, true, 0, false, true);
        reserveVault.configureOracle(reserveIsland, true, 0, false, true);
        
        // Step 1: User deposits to Junior vault
        juniorVault.setVaultValue(100000e18); // Set initial value
        stablecoin.mint(user1, 50000e18);
        
        vm.startPrank(user1);
        stablecoin.approve(address(juniorVault), 50000e18);
        uint256 shares = juniorVault.deposit(50000e18, user1);
        vm.stopPrank();
        
        assertGt(shares, 0);
        assertEq(stablecoin.balanceOf(address(juniorVault)), 150000e18); // 100k + 50k
        
        // Step 2: Admin deploys funds to Kodiak
        juniorVault.deployToKodiak(140000e18, 0, address(0), "", address(0), "");
        
        // Step 3: Oracle automatically calculates new value
        uint256 vaultValue = juniorVault.vaultValue();
        assertGt(vaultValue, 0);
        
        // Value should reflect LP + idle funds
        uint256 calculatedValue = juniorVault.getCalculatedVaultValue();
        assertEq(vaultValue, calculatedValue);
    }
    
    function test_fullFlow_multipleVaultsIndependent() public {
        // Each vault operates independently
        
        // Junior: Manual mode with validation
        juniorVault.configureOracle(juniorIsland, true, 500, true, false);
        juniorVault.setVaultValue(100000e18);
        juniorVault.deployToKodiak(50000e18, 0, address(0), "", address(0), "");
        
        // Reserve: Automatic mode
        reserveVault.configureOracle(reserveIsland, true, 0, false, true);
        reserveVault.deployToKodiak(30000e18, 0, address(0), "", address(0), "");
        
        // Senior: No oracle (traditional)
        seniorVault.deployToKodiak(100000e18, 0, address(0), "", address(0), "");
        
        // Each should work correctly
        assertEq(juniorVault.vaultValue(), 100000e18); // Manual set value
        assertGt(reserveVault.vaultValue(), 0); // Calculated value
        
        // Senior can still set value manually
        seniorVault.setVaultValue(200000e18);
        assertEq(seniorVault.vaultValue(), 200000e18);
    }
    
    function test_fullFlow_validation_protectsAgainstErrors() public {
        // Setup: Junior with validation
        juniorVault.configureOracle(juniorIsland, true, 500, true, false);
        
        // Deploy funds
        juniorVault.deployToKodiak(50000e18, 0, address(0), "", address(0), "");
        
        // Get calculated value
        uint256 calculatedValue = juniorVault.getCalculatedVaultValue();
        
        // Admin tries to set correct value (should pass)
        juniorVault.setVaultValue(calculatedValue);
        assertEq(juniorVault.vaultValue(), calculatedValue);
        
        // Admin tries to set wrong value (should fail)
        vm.expectRevert();
        juniorVault.setVaultValue(calculatedValue * 2);
        
        // Value should still be correct
        assertEq(juniorVault.vaultValue(), calculatedValue);
    }
    
    function test_fullFlow_modeSwitch_preservesFlexibility() public {
        // Start with manual mode (for testing/development)
        juniorVault.configureOracle(juniorIsland, true, 500, true, false);
        juniorVault.setVaultValue(100000e18);
        juniorVault.deployToKodiak(50000e18, 0, address(0), "", address(0), "");
        
        assertEq(juniorVault.vaultValue(), 100000e18);
        
        // Migrate to automatic (for production)
        juniorVault.configureOracle(juniorIsland, true, 0, false, true);
        
        uint256 autoValue = juniorVault.vaultValue();
        assertGt(autoValue, 0);
        assertNotEq(autoValue, 100000e18); // Now using calculated value
        
        // Deploy more funds
        juniorVault.deployToKodiak(30000e18, 0, address(0), "", address(0), "");
        
        // Value updates automatically
        uint256 newAutoValue = juniorVault.vaultValue();
        assertGt(newAutoValue, autoValue);
    }
    
    // ============================================
    // Edge Cases
    // ============================================
    
    function test_edgeCase_zeroLPBalance_fallsBackToStored() public {
        // Configure automatic mode
        juniorVault.configureOracle(juniorIsland, true, 0, false, true);
        
        // Create hook with 0 LP
        address zeroHook = address(new MockHook(address(juniorVault), juniorIsland, 0));
        juniorVault.setKodiakHook(zeroHook);
        
        // Set stored value
        juniorVault.setVaultValue(50000e18);
        
        // Should fallback to stored (calculated is 0)
        assertEq(juniorVault.vaultValue(), 50000e18);
    }
    
    function test_edgeCase_noHook_oracleReturnsZero() public {
        // Remove hook
        juniorVault.setKodiakHook(address(0));
        
        // Configure oracle
        juniorVault.configureOracle(juniorIsland, true, 0, false, false);
        
        // Calculated value should be 0
        assertEq(juniorVault.getCalculatedVaultValue(), 0);
    }
    
    function test_edgeCase_multipleDeployments_valueSumCorrect() public {
        // Configure automatic mode
        juniorVault.configureOracle(juniorIsland, true, 0, false, true);
        
        uint256 value1 = juniorVault.vaultValue();
        
        // Multiple deployments
        juniorVault.deployToKodiak(10000e18, 0, address(0), "", address(0), "");
        uint256 value2 = juniorVault.vaultValue();
        assertGt(value2, value1);
        
        juniorVault.deployToKodiak(20000e18, 0, address(0), "", address(0), "");
        uint256 value3 = juniorVault.vaultValue();
        assertGt(value3, value2);
        
        juniorVault.deployToKodiak(30000e18, 0, address(0), "", address(0), "");
        uint256 value4 = juniorVault.vaultValue();
        assertGt(value4, value3);
    }
    
    function test_edgeCase_hookSwitch_recalculatesCorrectly() public {
        // Configure automatic mode
        juniorVault.configureOracle(juniorIsland, true, 0, false, true);
        
        uint256 value1 = juniorVault.vaultValue();
        
        // Switch to new hook with different LP balance
        address newHook = address(new MockHook(address(juniorVault), juniorIsland, 5000e18));
        juniorVault.setKodiakHook(newHook);
        
        uint256 value2 = juniorVault.vaultValue();
        assertNotEq(value2, value1);
    }
}

// ============================================
// Mock Contracts
// ============================================

contract MockIsland is IKodiakIsland {
    IERC20 private _token0;
    IERC20 private _token1;
    address public pool;
    uint256 private balance0;
    uint256 private balance1;
    uint256 private _totalSupply = 1000000e18;
    
    constructor(address token0_, address token1_, uint256 balance0_, uint256 balance1_) {
        _token0 = IERC20(token0_);
        _token1 = IERC20(token1_);
        balance0 = balance0_;
        balance1 = balance1_;
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

contract MockHook is IKodiakVaultHook {
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

