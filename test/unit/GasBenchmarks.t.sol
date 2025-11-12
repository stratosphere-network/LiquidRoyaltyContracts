// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ConcreteJuniorVault} from "../../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../../src/concrete/ConcreteReserveVault.sol";
import {UnifiedConcreteSeniorVault} from "../../src/concrete/UnifiedConcreteSeniorVault.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";

/**
 * @title GasBenchmarksTest
 * @notice COMPREHENSIVE gas benchmarks for all vault operations
 */
contract GasBenchmarksTest is Test {
    ConcreteJuniorVault public juniorVault;
    ConcreteReserveVault public reserveVault;
    UnifiedConcreteSeniorVault public seniorVault;
    MockERC20 public stablecoin;
    MockERC20 public lpToken;
    
    address public admin = address(this);
    address public user = address(0x1);
    
    function setUp() public {
        stablecoin = new MockERC20("USDC", "USDC", 6);
        lpToken = new MockERC20("LP", "LP", 18);
        
        // Deploy Junior vault
        ConcreteJuniorVault juniorImpl = new ConcreteJuniorVault();
        bytes memory juniorInitData = abi.encodeWithSelector(
            ConcreteJuniorVault.initialize.selector,
            address(stablecoin),
            address(0x1),
            0
        );
        ERC1967Proxy juniorProxy = new ERC1967Proxy(address(juniorImpl), juniorInitData);
        juniorVault = ConcreteJuniorVault(address(juniorProxy));
        juniorVault.setAdmin(admin);
        
        // Deploy Reserve vault
        ConcreteReserveVault reserveImpl = new ConcreteReserveVault();
        bytes memory reserveInitData = abi.encodeWithSelector(
            ConcreteReserveVault.initialize.selector,
            address(stablecoin),
            address(0x1),
            0
        );
        ERC1967Proxy reserveProxy = new ERC1967Proxy(address(reserveImpl), reserveInitData);
        reserveVault = ConcreteReserveVault(address(reserveProxy));
        reserveVault.setAdmin(admin);
        
        // Deploy Senior vault
        UnifiedConcreteSeniorVault seniorImpl = new UnifiedConcreteSeniorVault();
        bytes memory seniorInitData = abi.encodeWithSelector(
            UnifiedConcreteSeniorVault.initialize.selector,
            address(stablecoin),
            "Senior USD",
            "snrUSD",
            address(juniorVault),
            address(reserveVault),
            address(this),
            0
        );
        ERC1967Proxy seniorProxy = new ERC1967Proxy(address(seniorImpl), seniorInitData);
        seniorVault = UnifiedConcreteSeniorVault(address(seniorProxy));
        seniorVault.setAdmin(admin);
        
        juniorVault.updateSeniorVault(address(seniorVault));
        reserveVault.updateSeniorVault(address(seniorVault));
        
        // Initial setup
        juniorVault.setVaultValue(1000000e18);
        reserveVault.setVaultValue(500000e18);
        reserveVault.setVaultValue(500000e18);  // Set twice for _lastMonthValue
        seniorVault.setVaultValue(2000000e18);
        
        // Mint some tokens to vaults
        stablecoin.mint(address(seniorVault), 2000000e6);
    }
    
    // ============================================
    // Deposit Gas Benchmarks
    // ============================================
    
    function test_gas_juniorDeposit_first() public {
        console.log("=== GAS: Junior Vault First Deposit ===");
        
        stablecoin.mint(user, 10000e6);
        vm.startPrank(user);
        stablecoin.approve(address(juniorVault), 10000e6);
        
        uint256 gasBefore = gasleft();
        juniorVault.deposit(10000e6, user);
        uint256 gasUsed = gasBefore - gasleft();
        
        vm.stopPrank();
        
        console.log("First deposit gas:", gasUsed);
    }
    
    function test_gas_juniorDeposit_subsequent() public {
        console.log("=== GAS: Junior Vault Subsequent Deposit ===");
        
        stablecoin.mint(user, 20000e6);
        vm.startPrank(user);
        stablecoin.approve(address(juniorVault), 20000e6);
        
        // First deposit
        juniorVault.deposit(10000e6, user);
        
        // Measure second deposit
        uint256 gasBefore = gasleft();
        juniorVault.deposit(10000e6, user);
        uint256 gasUsed = gasBefore - gasleft();
        
        vm.stopPrank();
        
        console.log("Subsequent deposit gas:", gasUsed);
    }
    
    function test_gas_seniorDeposit() public {
        console.log("=== GAS: Senior Vault Deposit ===");
        
        stablecoin.mint(user, 10000e6);
        vm.startPrank(user);
        stablecoin.approve(address(seniorVault), 10000e6);
        
        uint256 gasBefore = gasleft();
        seniorVault.deposit(10000e6, user);
        uint256 gasUsed = gasBefore - gasleft();
        
        vm.stopPrank();
        
        console.log("Senior deposit gas:", gasUsed);
    }
    
    function test_gas_depositComparison() public {
        console.log("=== GAS: Deposit Comparison (Junior vs Reserve vs Senior) ===");
        
        stablecoin.mint(user, 30000e6);
        vm.startPrank(user);
        stablecoin.approve(address(juniorVault), 10000e6);
        stablecoin.approve(address(reserveVault), 10000e6);
        stablecoin.approve(address(seniorVault), 10000e6);
        
        uint256 gas1 = gasleft();
        juniorVault.deposit(10000e6, user);
        uint256 juniorGas = gas1 - gasleft();
        
        uint256 gas2 = gasleft();
        reserveVault.deposit(10000e6, user);
        uint256 reserveGas = gas2 - gasleft();
        
        uint256 gas3 = gasleft();
        seniorVault.deposit(10000e6, user);
        uint256 seniorGas = gas3 - gasleft();
        
        vm.stopPrank();
        
        console.log("Junior deposit gas:  ", juniorGas);
        console.log("Reserve deposit gas: ", reserveGas);
        console.log("Senior deposit gas:  ", seniorGas);
    }
    
    // ============================================
    // Withdrawal Gas Benchmarks
    // ============================================
    
    function test_gas_withdraw() public {
        console.log("=== GAS: Withdrawal ===");
        
        // Setup: user deposits first
        stablecoin.mint(user, 10000e6);
        vm.startPrank(user);
        stablecoin.approve(address(juniorVault), 10000e6);
        uint256 shares = juniorVault.deposit(10000e6, user);
        
        // Measure withdrawal
        uint256 gasBefore = gasleft();
        juniorVault.redeem(shares, user, user);
        uint256 gasUsed = gasBefore - gasleft();
        
        vm.stopPrank();
        
        console.log("Withdrawal gas:", gasUsed);
    }
    
    // ============================================
    // Rebase Gas Benchmarks
    // ============================================
    
    function test_gas_rebase_noSpillover() public {
        console.log("=== GAS: Rebase (No Spillover) ===");
        
        // Create some supply first
        stablecoin.mint(user, 100000e6);
        vm.startPrank(user);
        stablecoin.approve(address(seniorVault), 100000e6);
        seniorVault.deposit(100000e6, user);
        vm.stopPrank();
        
        juniorVault.addWhitelistedLPToken(address(lpToken));
        reserveVault.addWhitelistedLPToken(address(lpToken));
        
        // Warp time to allow rebase
        vm.warp(block.timestamp + 31);
        
        uint256 gasBefore = gasleft();
        seniorVault.rebase(1e18);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Rebase (no spillover) gas:", gasUsed);
    }
    
    function test_gas_rebase_withSpillover() public {
        console.log("=== GAS: Rebase (With Spillover) ===");
        
        // Setup reserve vault value for deposit cap
        reserveVault.setVaultValue(1000000e18);
        reserveVault.setVaultValue(1000000e18);
        
        // Setup for spillover (130% backing)
        seniorVault.setVaultValue(1300000e18);
        stablecoin.mint(user, 1000000e6);
        
        vm.startPrank(user);
        stablecoin.approve(address(seniorVault), 1000000e6);
        seniorVault.deposit(1000000e6, user);
        vm.stopPrank();
        
        juniorVault.addWhitelistedLPToken(address(lpToken));
        reserveVault.addWhitelistedLPToken(address(lpToken));
        
        // Warp time to allow rebase
        vm.warp(block.timestamp + 31);
        
        uint256 gasBefore = gasleft();
        seniorVault.rebase(1e18);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Rebase (with spillover) gas:", gasUsed);
    }
    
    // ============================================
    // Kodiak Integration Gas
    // ============================================
    
    function test_gas_deployToKodiak() public {
        console.log("=== GAS: Deploy to Kodiak ===");
        
        MockKodiakHook hook = new MockKodiakHook(address(juniorVault), address(lpToken));
        juniorVault.setKodiakHook(address(hook));
        stablecoin.mint(address(juniorVault), 100000e6);
        
        uint256 gasBefore = gasleft();
        juniorVault.deployToKodiak(100000e6, 0, address(0), "", address(0), "");  // minLPTokens = 0 for gas measurement
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Deploy to Kodiak gas:", gasUsed);
    }
    
    function test_gas_sweepToKodiak() public {
        console.log("=== GAS: Sweep to Kodiak ===");
        
        MockKodiakHook hook = new MockKodiakHook(address(juniorVault), address(lpToken));
        juniorVault.setKodiakHook(address(hook));
        stablecoin.mint(address(juniorVault), 50000e6);
        
        uint256 gasBefore = gasleft();
        juniorVault.sweepToKodiak(0, address(0), "", address(0), "");  // minLPTokens = 0 for gas measurement
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Sweep to Kodiak gas:", gasUsed);
    }
    
    // ============================================
    // Admin Operations Gas
    // ============================================
    
    function test_gas_setVaultValue() public {
        console.log("=== GAS: Set Vault Value ===");
        
        uint256 gasBefore = gasleft();
        juniorVault.setVaultValue(1500000e18);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Set vault value gas:", gasUsed);
    }
    
    function test_gas_updateVaultValue() public {
        console.log("=== GAS: Update Vault Value ===");
        
        uint256 gasBefore = gasleft();
        juniorVault.updateVaultValue(100);  // +1%
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Update vault value gas:", gasUsed);
    }
    
    function test_gas_configureOracle() public {
        console.log("=== GAS: Configure Oracle ===");
        
        address island = address(0x123);
        
        uint256 gasBefore = gasleft();
        juniorVault.configureOracle(island, true, 500, true, false);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Configure oracle gas:", gasUsed);
    }
    
    // ============================================
    // Whitelist Management Gas
    // ============================================
    
    function test_gas_addWhitelistedLP() public {
        console.log("=== GAS: Add Whitelisted LP ===");
        
        uint256 gasBefore = gasleft();
        juniorVault.addWhitelistedLP(address(0x123));
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Add whitelisted LP gas:", gasUsed);
    }
    
    function test_gas_removeWhitelistedLP() public {
        console.log("=== GAS: Remove Whitelisted LP ===");
        
        juniorVault.addWhitelistedLP(address(0x123));
        
        uint256 gasBefore = gasleft();
        juniorVault.removeWhitelistedLP(address(0x123));
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Remove whitelisted LP gas:", gasUsed);
    }
    
    function test_gas_addWhitelistedLPToken() public {
        console.log("=== GAS: Add Whitelisted LP Token ===");
        
        uint256 gasBefore = gasleft();
        juniorVault.addWhitelistedLPToken(address(lpToken));
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Add whitelisted LP token gas:", gasUsed);
    }
    
    // ============================================
    // View Function Gas
    // ============================================
    
    function test_gas_vaultValue() public view {
        console.log("=== GAS: View Vault Value ===");
        
        uint256 gasBefore = gasleft();
        juniorVault.vaultValue();
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("View vault value gas:", gasUsed);
    }
    
    function test_gas_totalAssets() public view {
        console.log("=== GAS: View Total Assets ===");
        
        uint256 gasBefore = gasleft();
        juniorVault.totalAssets();
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("View total assets gas:", gasUsed);
    }
    
    function test_gas_previewDeposit() public view {
        console.log("=== GAS: Preview Deposit ===");
        
        uint256 gasBefore = gasleft();
        juniorVault.previewDeposit(10000e6);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Preview deposit gas:", gasUsed);
    }
    
    function test_gas_getLPHoldings() public {
        console.log("=== GAS: Get LP Holdings ===");
        
        // Add 5 LP tokens
        for (uint i = 0; i < 5; i++) {
            MockERC20 lp = new MockERC20("LP", "LP", 18);
            juniorVault.addWhitelistedLPToken(address(lp));
        }
        
        uint256 gasBefore = gasleft();
        juniorVault.getLPHoldings();
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Get LP holdings (5 tokens) gas:", gasUsed);
    }
    
    // ============================================
    // Comparative Gas Tests
    // ============================================
    
    function test_gas_comparison_depositVsWithdraw() public {
        console.log("=== GAS: Deposit vs Withdraw Comparison ===");
        
        stablecoin.mint(user, 20000e6);
        vm.startPrank(user);
        stablecoin.approve(address(juniorVault), 20000e6);
        
        uint256 gas1 = gasleft();
        uint256 shares = juniorVault.deposit(10000e6, user);
        uint256 depositGas = gas1 - gasleft();
        
        uint256 gas2 = gasleft();
        juniorVault.redeem(shares, user, user);
        uint256 withdrawGas = gas2 - gasleft();
        
        vm.stopPrank();
        
        console.log("Deposit gas:   ", depositGas);
        console.log("Withdraw gas:  ", withdrawGas);
        console.log("Difference:    ", depositGas > withdrawGas ? depositGas - withdrawGas : withdrawGas - depositGas);
    }
    
    // ============================================
    // Stress Test Gas
    // ============================================
    
    function test_gas_multipleDeposits() public {
        console.log("=== GAS: Multiple Deposits ===");
        
        stablecoin.mint(user, 100000e6);
        vm.startPrank(user);
        stablecoin.approve(address(juniorVault), 100000e6);
        
        uint256 totalGas = 0;
        
        for (uint i = 0; i < 10; i++) {
            uint256 gasBefore = gasleft();
            juniorVault.deposit(10000e6, user);
            uint256 gasUsed = gasBefore - gasleft();
            totalGas += gasUsed;
            console.log("Deposit", i + 1, "gas:", gasUsed);
        }
        
        vm.stopPrank();
        
        console.log("Total gas for 10 deposits:", totalGas);
        console.log("Average gas per deposit:  ", totalGas / 10);
    }
    
    function test_gas_largeWithdrawal() public {
        console.log("=== GAS: Large Withdrawal ===");
        
        // Setup large deposit
        stablecoin.mint(user, 1000000e6);
        vm.startPrank(user);
        stablecoin.approve(address(juniorVault), 1000000e6);
        uint256 shares = juniorVault.deposit(1000000e6, user);
        
        // Measure large withdrawal
        uint256 gasBefore = gasleft();
        juniorVault.redeem(shares, user, user);
        uint256 gasUsed = gasBefore - gasleft();
        
        vm.stopPrank();
        
        console.log("Large withdrawal gas:", gasUsed);
    }
}

contract MockKodiakHook {
    address public vault;
    address public island;
    uint256 public lpBalance;
    
    constructor(address vault_, address island_) {
        vault = vault_;
        island = island_;
    }
    
    function onAfterDeposit(uint256 amount) external {
        // Convert USDC (6 decimals) to LP (18 decimals)
        lpBalance += (amount * 1e18) / 1e6;
    }
    
    function onAfterDepositWithSwaps(
        uint256 amount,
        address,
        bytes calldata,
        address,
        bytes calldata
    ) external {
        // Convert USDC (6 decimals) to LP (18 decimals)
        lpBalance += (amount * 1e18) / 1e6;
    }
    
    function ensureFundsAvailable(uint256) external {}
    
    function transferIslandLP(address, uint256) external {}
    
    function getIslandLPBalance() external view returns (uint256) {
        return lpBalance;
    }
}

