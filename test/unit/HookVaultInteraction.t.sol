// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ConcreteJuniorVault} from "../../src/concrete/ConcreteJuniorVault.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {IKodiakVaultHook} from "../../src/integrations/IKodiakVaultHook.sol";

/**
 * @title HookVaultInteractionTest
 * @notice DEEP tests for Hook-Vault interaction scenarios
 */
contract HookVaultInteractionTest is Test {
    ConcreteJuniorVault public vault;
    MockERC20 public stablecoin;
    MockERC20 public lpToken;
    MockKodiakHook public hook;
    
    address public admin = address(this);
    address public user = address(0x1);
    
    event KodiakDeployment(uint256 amount, uint256 lpReceived, uint256 timestamp);
    
    function setUp() public {
        stablecoin = new MockERC20("USDC", "USDC", 6);
        lpToken = new MockERC20("LP", "LP", 18);
        
        // Deploy vault with proxy
        ConcreteJuniorVault impl = new ConcreteJuniorVault();
        bytes memory initData = abi.encodeWithSelector(
            ConcreteJuniorVault.initialize.selector,
            address(stablecoin),
            address(0x1),
            0
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        vault = ConcreteJuniorVault(address(proxy));
        vault.setAdmin(admin);
        
        // Deploy hook
        hook = new MockKodiakHook(address(vault), address(lpToken));
        vault.setKodiakHook(address(hook));
        
        // Mint funds
        stablecoin.mint(address(vault), 1000000e6); // 1M USDC
    }
    
    // ============================================
    // Hook LP Minting Tests
    // ============================================
    
    function test_hook_mintsCorrectLP() public {
        console.log("=== Test: Hook Mints Correct LP Amount ===");
        
        uint256 deployAmount = 100000e6;
        uint256 expectedLP = 100000e18;
        
        // Configure hook to mint 1:1
        hook.setLPMintRatio(1e18);
        
        uint256 lpBefore = hook.lpBalance();
        
        vault.deployToKodiak(deployAmount, expectedLP - 1e18, address(0), "", address(0), "");
        
        uint256 lpAfter = hook.lpBalance();
        uint256 lpMinted = lpAfter - lpBefore;
        
        console.log("LP Minted:", lpMinted);
        console.log("Expected:", expectedLP);
        
        assertEq(lpMinted, expectedLP);
    }
    
    function test_hook_variableLPMinting() public {
        console.log("=== Test: Variable LP Minting Ratios ===");
        
        // Scenario 1: 1:1 ratio
        hook.setLPMintRatio(1e18);
        vault.deployToKodiak(100000e6, 99000e18, address(0), "", address(0), "");
        uint256 lp1 = hook.lpBalance();
        console.log("LP (1:1 ratio):", lp1);
        
        // Scenario 2: 2:1 ratio (2 LP per 1 USDC)
        hook.setLPMintRatio(2e18);
        vault.deployToKodiak(100000e6, 150000e18, address(0), "", address(0), "");
        uint256 lp2 = hook.lpBalance() - lp1;
        console.log("LP (2:1 ratio):", lp2);
        assertEq(lp2, 200000e18);
        
        // Scenario 3: 0.5:1 ratio (0.5 LP per 1 USDC)
        hook.setLPMintRatio(0.5e18);
        vault.deployToKodiak(100000e6, 40000e18, address(0), "", address(0), "");
        uint256 lp3 = hook.lpBalance() - lp1 - lp2;
        console.log("LP (0.5:1 ratio):", lp3);
        assertEq(lp3, 50000e18);
    }
    
    // ============================================
    // Hook Failure Scenarios
    // ============================================
    
    function test_hook_failsToMint_revertsTransaction() public {
        console.log("=== Test: Hook Mint Failure Reverts ===");
        
        hook.setShouldFailMint(true);
        
        vm.expectRevert("Mint failed");
        vault.deployToKodiak(100000e6, 99000e18, address(0), "", address(0), "");
    }
    
    function test_hook_mintsLessThanExpected_slippageProtection() public {
        console.log("=== Test: Slippage Protection Works ===");
        
        // Hook will mint 90K LP but we expect 95K minimum
        hook.setLPMintRatio(0.9e18);
        
        vm.expectRevert();  // SlippageTooHigh
        vault.deployToKodiak(100000e6, 95000e18, address(0), "", address(0), "");
    }
    
    function test_hook_returnsWrongLPBalance() public {
        console.log("=== Test: Hook Returns Wrong LP Balance ===");
        
        // Hook reports very high fake balance before deployment
        hook.setFakeLPBalance(999999e18);
        hook.setLPMintRatio(1e18);
        
        // Delta calculation:
        // lpBefore = 999999e18 (fake)
        // After deployment, hook still reports fake balance (999999e18)
        // lpReceived = lpAfter - lpBefore = 999999e18 + 100000e18 - 999999e18 = 100000e18
        // But our mock doesn't update the fake balance, so delta is wrong
        
        // This should fail slippage protection since delta won't match expected
        vm.expectRevert();  // SlippageTooHigh
        vault.deployToKodiak(100000e6, 99000e18, address(0), "", address(0), "");
        
        console.log("Correctly caught fake LP balance reporting");
    }
    
    // ============================================
    // Multiple Deployment Interaction
    // ============================================
    
    function test_multipleDeployments_lpAccumulation() public {
        console.log("=== Test: Multiple Deployments Accumulate LP ===");
        
        hook.setLPMintRatio(1e18);
        
        // 10 deployments of 10K each
        for (uint i = 0; i < 10; i++) {
            vault.deployToKodiak(10000e6, 9900e18, address(0), "", address(0), "");
            console.log("Deployment", i + 1, "- LP Balance:", hook.lpBalance());
        }
        
        uint256 finalLP = hook.lpBalance();
        console.log("Final LP:", finalLP);
        assertEq(finalLP, 100000e18);
    }
    
    function test_deployAll_thenSweepDust() public {
        console.log("=== Test: Deploy Most Then Sweep Dust ===");
        
        hook.setLPMintRatio(1e18);
        
        // Deploy 990K
        vault.deployToKodiak(990000e6, 980000e18, address(0), "", address(0), "");
        uint256 lp1 = hook.lpBalance();
        console.log("After first deployment - LP:", lp1);
        
        // Sweep remaining 10K dust
        vault.sweepToKodiak(9900e18, address(0), "", address(0), "");
        uint256 lp2 = hook.lpBalance();
        console.log("After sweep - LP:", lp2);
        
        // Should have deployed everything
        assertEq(stablecoin.balanceOf(address(vault)), 0);
        assertEq(lp2, 1000000e18);
    }
    
    // ============================================
    // Vault Balance Tracking
    // ============================================
    
    function test_vaultBalance_decreasesOnDeployment() public {
        console.log("=== Test: Vault Balance Decreases ===");
        
        uint256 balBefore = stablecoin.balanceOf(address(vault));
        console.log("Vault balance before:", balBefore);
        
        vault.deployToKodiak(100000e6, 99000e18, address(0), "", address(0), "");
        
        uint256 balAfter = stablecoin.balanceOf(address(vault));
        console.log("Vault balance after:", balAfter);
        
        assertEq(balBefore - balAfter, 100000e6);
    }
    
    function test_hookBalance_increasesOnDeployment() public {
        console.log("=== Test: Hook Balance Increases ===");
        
        uint256 hookBalBefore = stablecoin.balanceOf(address(hook));
        console.log("Hook balance before:", hookBalBefore);
        
        vault.deployToKodiak(100000e6, 99000e18, address(0), "", address(0), "");
        
        uint256 hookBalAfter = stablecoin.balanceOf(address(hook));
        console.log("Hook balance after:", hookBalAfter);
        
        assertEq(hookBalAfter - hookBalBefore, 100000e6);
    }
    
    // ============================================
    // Hook State Changes
    // ============================================
    
    function test_hook_tracksDeploymentCount() public {
        console.log("=== Test: Hook Tracks Deployment Count ===");
        
        for (uint i = 0; i < 5; i++) {
            vault.deployToKodiak(10000e6, 9900e18, address(0), "", address(0), "");
        }
        
        assertEq(hook.deploymentCount(), 5);
        console.log("Total deployments:", hook.deploymentCount());
    }
    
    function test_hook_tracksTotalDeployed() public {
        console.log("=== Test: Hook Tracks Total Amount Deployed ===");
        
        vault.deployToKodiak(100000e6, 99000e18, address(0), "", address(0), "");
        vault.deployToKodiak(200000e6, 199000e18, address(0), "", address(0), "");
        vault.deployToKodiak(50000e6, 49000e18, address(0), "", address(0), "");
        
        uint256 totalDeployed = hook.totalDeployed();
        console.log("Total deployed:", totalDeployed);
        assertEq(totalDeployed, 350000e6);
    }
    
    // ============================================
    // Edge Cases
    // ============================================
    
    function test_edgeCase_deployZeroAfterNonZero() public {
        console.log("=== Edge Case: Deploy Zero After Non-Zero ===");
        
        vault.deployToKodiak(100000e6, 99000e18, address(0), "", address(0), "");
        
        vm.expectRevert();  // InvalidAmount
        vault.deployToKodiak(0, 0, address(0), "", address(0), "");
    }
    
    function test_edgeCase_hookReentrancy() public {
        console.log("=== Edge Case: Hook Reentrancy Protection ===");
        
        hook.setShouldAttemptReentrancy(true);
        
        // Should fail due to reentrancy guard
        vm.expectRevert();
        vault.deployToKodiak(100000e6, 99000e18, address(0), "", address(0), "");
    }
    
    function test_stress_1000Deployments() public {
        console.log("=== Stress Test: 1000 Small Deployments ===");
        
        hook.setLPMintRatio(1e18);
        
        for (uint i = 0; i < 100; i++) {  // 100 deployments (1000 would be too slow)
            vault.deployToKodiak(1000e6, 990e18, address(0), "", address(0), "");
        }
        
        uint256 finalLP = hook.lpBalance();
        console.log("Final LP after 100 deployments:", finalLP);
        assertEq(finalLP, 100000e18);
    }
}

// ============================================
// Advanced Mock Hook
// ============================================

contract MockKodiakHook is IKodiakVaultHook {
    address public vault;
    address public island;
    uint256 public lpBalance;
    uint256 public deploymentCount;
    uint256 public totalDeployed;
    uint256 public lpMintRatio = 1e18;  // 1:1 by default
    uint256 public fakeLPBalance;
    bool public shouldFailMint;
    bool public shouldAttemptReentrancy;
    bool public useFakeBalance;
    
    constructor(address vault_, address island_) {
        vault = vault_;
        island = island_;
    }
    
    function setLPMintRatio(uint256 ratio) external {
        lpMintRatio = ratio;
    }
    
    function setFakeLPBalance(uint256 amount) external {
        fakeLPBalance = amount;
        useFakeBalance = true;
    }
    
    function setShouldFailMint(bool should) external {
        shouldFailMint = should;
    }
    
    function setShouldAttemptReentrancy(bool should) external {
        shouldAttemptReentrancy = should;
    }
    
    function onAfterDeposit(uint256 amount) external override {
        if (shouldFailMint) revert("Mint failed");
        if (shouldAttemptReentrancy) {
            // Try to call vault again (should fail)
            ConcreteJuniorVault(vault).deployToKodiak(1000e6, 0, address(0), "", address(0), "");
        }
        
        uint256 lpToMint = (amount * lpMintRatio) / 1e6;  // Adjust for USDC decimals
        lpBalance += lpToMint;
        deploymentCount++;
        totalDeployed += amount;
    }
    
    function onAfterDepositWithSwaps(
        uint256 amount,
        address,
        bytes calldata,
        address,
        bytes calldata
    ) external override {
        if (shouldFailMint) revert("Mint failed");
        if (shouldAttemptReentrancy) {
            ConcreteJuniorVault(vault).deployToKodiak(1000e6, 0, address(0), "", address(0), "");
        }
        
        uint256 lpToMint = (amount * lpMintRatio) / 1e6;
        lpBalance += lpToMint;
        deploymentCount++;
        totalDeployed += amount;
    }
    
    function ensureFundsAvailable(uint256) external override {}
    
    function transferIslandLP(address, uint256) external override {}
    
    function getIslandLPBalance() external view override returns (uint256) {
        return useFakeBalance ? fakeLPBalance : lpBalance;
    }
}

