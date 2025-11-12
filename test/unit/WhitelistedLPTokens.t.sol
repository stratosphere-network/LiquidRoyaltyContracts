// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ConcreteJuniorVault} from "../../src/concrete/ConcreteJuniorVault.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";

/**
 * @title WhitelistedLPTokensTest
 * @notice COMPREHENSIVE tests for whitelisted LP tokens array management
 */
contract WhitelistedLPTokensTest is Test {
    ConcreteJuniorVault public vault;
    MockERC20 public stablecoin;
    
    MockERC20[] public lpTokens;
    address public admin = address(this);
    
    function setUp() public {
        stablecoin = new MockERC20("USDC", "USDC", 6);
        
        // Deploy vault
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
        
        // Create 20 LP tokens
        for (uint i = 0; i < 20; i++) {
            MockERC20 lpToken = new MockERC20(
                string(abi.encodePacked("LP", vm.toString(i))),
                string(abi.encodePacked("LP", vm.toString(i))),
                18
            );
            lpTokens.push(lpToken);
        }
    }
    
    // ============================================
    // Basic Operations
    // ============================================
    
    function test_addSingleLPToken() public {
        console.log("=== Test: Add Single LP Token ===");
        
        vault.addWhitelistedLPToken(address(lpTokens[0]));
        
        assertTrue(vault.isWhitelistedLPToken(address(lpTokens[0])));
        
        address[] memory whitelisted = vault.getWhitelistedLPTokens();
        assertEq(whitelisted.length, 1);
        assertEq(whitelisted[0], address(lpTokens[0]));
        
        console.log("Single LP token added successfully");
    }
    
    function test_addMultipleLPTokens() public {
        console.log("=== Test: Add Multiple LP Tokens ===");
        
        for (uint i = 0; i < 5; i++) {
            vault.addWhitelistedLPToken(address(lpTokens[i]));
        }
        
        address[] memory whitelisted = vault.getWhitelistedLPTokens();
        assertEq(whitelisted.length, 5);
        
        for (uint i = 0; i < 5; i++) {
            assertTrue(vault.isWhitelistedLPToken(address(lpTokens[i])));
            console.log("LP", i, "whitelisted:", whitelisted[i]);
        }
    }
    
    function test_removeLPToken() public {
        console.log("=== Test: Remove LP Token ===");
        
        // Add 3 tokens
        for (uint i = 0; i < 3; i++) {
            vault.addWhitelistedLPToken(address(lpTokens[i]));
        }
        
        // Remove middle one
        vault.removeWhitelistedLPToken(address(lpTokens[1]));
        
        assertFalse(vault.isWhitelistedLPToken(address(lpTokens[1])));
        
        address[] memory whitelisted = vault.getWhitelistedLPTokens();
        assertEq(whitelisted.length, 2);
        
        console.log("LP token removed successfully");
    }
    
    // ============================================
    // Array Management
    // ============================================
    
    function test_arrayOrder_afterRemoval() public {
        console.log("=== Test: Array Order After Removal ===");
        
        // Add 5 tokens
        for (uint i = 0; i < 5; i++) {
            vault.addWhitelistedLPToken(address(lpTokens[i]));
        }
        
        console.log("Initial order:");
        address[] memory before = vault.getWhitelistedLPTokens();
        for (uint i = 0; i < before.length; i++) {
            console.log("  ", i, ":", before[i]);
        }
        
        // Remove token at index 2
        vault.removeWhitelistedLPToken(address(lpTokens[2]));
        
        console.log("After removal:");
        address[] memory afterRemoval = vault.getWhitelistedLPTokens();
        for (uint i = 0; i < afterRemoval.length; i++) {
            console.log("  ", i, ":", afterRemoval[i]);
        }
        
        // Should have 4 tokens left
        assertEq(afterRemoval.length, 4);
        
        // All remaining tokens should still be whitelisted
        for (uint i = 0; i < afterRemoval.length; i++) {
            assertTrue(vault.isWhitelistedLPToken(afterRemoval[i]));
        }
    }
    
    function test_multipleRemovals() public {
        console.log("=== Test: Multiple Removals ===");
        
        // Add 10 tokens
        for (uint i = 0; i < 10; i++) {
            vault.addWhitelistedLPToken(address(lpTokens[i]));
        }
        
        assertEq(vault.getWhitelistedLPTokens().length, 10);
        
        // Remove every other token
        for (uint i = 0; i < 10; i += 2) {
            vault.removeWhitelistedLPToken(address(lpTokens[i]));
        }
        
        address[] memory remaining = vault.getWhitelistedLPTokens();
        console.log("Remaining tokens:", remaining.length);
        assertEq(remaining.length, 5);
        
        // Verify the right tokens remain
        for (uint i = 1; i < 10; i += 2) {
            assertTrue(vault.isWhitelistedLPToken(address(lpTokens[i])));
        }
        
        for (uint i = 0; i < 10; i += 2) {
            assertFalse(vault.isWhitelistedLPToken(address(lpTokens[i])));
        }
    }
    
    function test_removeAll() public {
        console.log("=== Test: Remove All Tokens ===");
        
        // Add 5 tokens
        for (uint i = 0; i < 5; i++) {
            vault.addWhitelistedLPToken(address(lpTokens[i]));
        }
        
        // Remove all
        for (uint i = 0; i < 5; i++) {
            vault.removeWhitelistedLPToken(address(lpTokens[i]));
        }
        
        address[] memory whitelisted = vault.getWhitelistedLPTokens();
        assertEq(whitelisted.length, 0);
        console.log("All tokens removed, array empty");
    }
    
    function test_addRemoveAdd() public {
        console.log("=== Test: Add-Remove-Add Pattern ===");
        
        // Add
        vault.addWhitelistedLPToken(address(lpTokens[0]));
        assertTrue(vault.isWhitelistedLPToken(address(lpTokens[0])));
        
        // Remove
        vault.removeWhitelistedLPToken(address(lpTokens[0]));
        assertFalse(vault.isWhitelistedLPToken(address(lpTokens[0])));
        
        // Add again
        vault.addWhitelistedLPToken(address(lpTokens[0]));
        assertTrue(vault.isWhitelistedLPToken(address(lpTokens[0])));
        
        address[] memory whitelisted = vault.getWhitelistedLPTokens();
        assertEq(whitelisted.length, 1);
        console.log("Add-Remove-Add pattern works");
    }
    
    // ============================================
    // Edge Cases
    // ============================================
    
    function test_edgeCase_addDuplicate() public {
        console.log("=== Edge Case: Add Duplicate ===");
        
        vault.addWhitelistedLPToken(address(lpTokens[0]));
        
        vm.expectRevert();  // LPAlreadyWhitelisted
        vault.addWhitelistedLPToken(address(lpTokens[0]));
        
        console.log("Duplicate addition blocked");
    }
    
    function test_edgeCase_removeNonExistent() public {
        console.log("=== Edge Case: Remove Non-Existent ===");
        
        vm.expectRevert();  // WhitelistedLPNotFound
        vault.removeWhitelistedLPToken(address(lpTokens[0]));
        
        console.log("Removing non-existent token blocked");
    }
    
    function test_edgeCase_addZeroAddress() public {
        console.log("=== Edge Case: Add Zero Address ===");
        
        vm.expectRevert();  // ZeroAddress
        vault.addWhitelistedLPToken(address(0));
        
        console.log("Zero address blocked");
    }
    
    function test_edgeCase_removeZeroAddress() public {
        console.log("=== Edge Case: Remove Zero Address ===");
        
        vm.expectRevert();  // ZeroAddress
        vault.removeWhitelistedLPToken(address(0));
        
        console.log("Zero address removal blocked");
    }
    
    // ============================================
    // Large Array Tests
    // ============================================
    
    function test_largeArray_add20Tokens() public {
        console.log("=== Test: Add 20 LP Tokens ===");
        
        for (uint i = 0; i < 20; i++) {
            vault.addWhitelistedLPToken(address(lpTokens[i]));
        }
        
        address[] memory whitelisted = vault.getWhitelistedLPTokens();
        assertEq(whitelisted.length, 20);
        
        console.log("20 tokens whitelisted successfully");
        
        // Verify all are whitelisted
        for (uint i = 0; i < 20; i++) {
            assertTrue(vault.isWhitelistedLPToken(address(lpTokens[i])));
        }
    }
    
    function test_largeArray_removeFromMiddle() public {
        console.log("=== Test: Remove from Middle of Large Array ===");
        
        // Add 20 tokens
        for (uint i = 0; i < 20; i++) {
            vault.addWhitelistedLPToken(address(lpTokens[i]));
        }
        
        // Remove token 10
        vault.removeWhitelistedLPToken(address(lpTokens[10]));
        
        address[] memory whitelisted = vault.getWhitelistedLPTokens();
        assertEq(whitelisted.length, 19);
        assertFalse(vault.isWhitelistedLPToken(address(lpTokens[10])));
        
        console.log("Removed from middle of 20 tokens");
    }
    
    function test_largeArray_removeManyFromLarge() public {
        console.log("=== Test: Remove Many from Large Array ===");
        
        // Add 20 tokens
        for (uint i = 0; i < 20; i++) {
            vault.addWhitelistedLPToken(address(lpTokens[i]));
        }
        
        // Remove 10 tokens (every other one)
        for (uint i = 0; i < 20; i += 2) {
            vault.removeWhitelistedLPToken(address(lpTokens[i]));
        }
        
        address[] memory whitelisted = vault.getWhitelistedLPTokens();
        assertEq(whitelisted.length, 10);
        
        console.log("Removed 10 tokens, 10 remaining");
    }
    
    // ============================================
    // getLPHoldings Tests
    // ============================================
    
    function test_getLPHoldings_withBalances() public {
        console.log("=== Test: Get LP Holdings with Balances ===");
        
        // Add 5 LP tokens
        for (uint i = 0; i < 5; i++) {
            vault.addWhitelistedLPToken(address(lpTokens[i]));
            // Mint some LP tokens to vault
            lpTokens[i].mint(address(vault), (i + 1) * 1000e18);
        }
        
        // Get holdings
        ConcreteJuniorVault.LPHolding[] memory holdings = vault.getLPHoldings();
        assertEq(holdings.length, 5);
        
        for (uint i = 0; i < 5; i++) {
            console.log("LP", i, "balance:", holdings[i].amount);
            assertEq(holdings[i].lpToken, address(lpTokens[i]));
            assertEq(holdings[i].amount, (i + 1) * 1000e18);
        }
    }
    
    function test_getLPHoldings_emptyArray() public {
        console.log("=== Test: Get LP Holdings Empty ===");
        
        ConcreteJuniorVault.LPHolding[] memory holdings = vault.getLPHoldings();
        assertEq(holdings.length, 0);
        console.log("Empty holdings returned correctly");
    }
    
    function test_getLPBalance() public {
        console.log("=== Test: Get Individual LP Balance ===");
        
        vault.addWhitelistedLPToken(address(lpTokens[0]));
        lpTokens[0].mint(address(vault), 5000e18);
        
        uint256 balance = vault.getLPBalance(address(lpTokens[0]));
        assertEq(balance, 5000e18);
        console.log("LP balance:", balance);
    }
    
    // ============================================
    // withdrawLPTokens Tests with Array
    // ============================================
    
    function test_withdrawLPTokens_requiresWhitelist() public {
        console.log("=== Test: Withdraw Requires Whitelisted Token ===");
        
        // Add LP protocol
        address lpProtocol = address(0x123);
        vault.addWhitelistedLP(lpProtocol);
        
        // Try to withdraw non-whitelisted LP token
        vm.expectRevert();  // WhitelistedLPNotFound
        vault.withdrawLPTokens(address(lpTokens[0]), lpProtocol, 1000e18);
        
        console.log("Non-whitelisted token withdrawal blocked");
    }
    
    function test_withdrawLPTokens_afterWhitelisting() public {
        console.log("=== Test: Withdraw After Whitelisting ===");
        
        // Setup
        address lpProtocol = address(0x123);
        vault.addWhitelistedLP(lpProtocol);
        vault.addWhitelistedLPToken(address(lpTokens[0]));
        lpTokens[0].mint(address(vault), 5000e18);
        
        // Withdraw
        vault.withdrawLPTokens(address(lpTokens[0]), lpProtocol, 1000e18);
        
        assertEq(lpTokens[0].balanceOf(lpProtocol), 1000e18);
        assertEq(lpTokens[0].balanceOf(address(vault)), 4000e18);
        console.log("Withdrawal successful");
    }
    
    // ============================================
    // Stress Tests
    // ============================================
    
    function test_stress_manyAddRemove() public {
        console.log("=== Stress Test: Many Add/Remove Operations ===");
        
        // Add all 20
        for (uint i = 0; i < 20; i++) {
            vault.addWhitelistedLPToken(address(lpTokens[i]));
        }
        
        // Remove first 10
        for (uint i = 0; i < 10; i++) {
            vault.removeWhitelistedLPToken(address(lpTokens[i]));
        }
        
        // Add first 10 back
        for (uint i = 0; i < 10; i++) {
            vault.addWhitelistedLPToken(address(lpTokens[i]));
        }
        
        // Should have all 20 again
        address[] memory whitelisted = vault.getWhitelistedLPTokens();
        assertEq(whitelisted.length, 20);
        
        console.log("Stress test completed, all 20 tokens present");
    }
    
    function test_stress_rapidAddRemove() public {
        console.log("=== Stress Test: Rapid Add/Remove ===");
        
        for (uint cycle = 0; cycle < 10; cycle++) {
            // Add 5
            for (uint i = 0; i < 5; i++) {
                if (!vault.isWhitelistedLPToken(address(lpTokens[i]))) {
                    vault.addWhitelistedLPToken(address(lpTokens[i]));
                }
            }
            
            // Remove 5
            for (uint i = 0; i < 5; i++) {
                if (vault.isWhitelistedLPToken(address(lpTokens[i]))) {
                    vault.removeWhitelistedLPToken(address(lpTokens[i]));
                }
            }
        }
        
        address[] memory whitelisted = vault.getWhitelistedLPTokens();
        console.log("After 10 cycles, array length:", whitelisted.length);
    }
    
    // ============================================
    // Gas Benchmarks
    // ============================================
    
    function test_gas_addLPToken() public {
        uint256 gasBefore = gasleft();
        vault.addWhitelistedLPToken(address(lpTokens[0]));
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas to add LP token:", gasUsed);
    }
    
    function test_gas_removeLPToken_from10() public {
        // Add 10 tokens
        for (uint i = 0; i < 10; i++) {
            vault.addWhitelistedLPToken(address(lpTokens[i]));
        }
        
        uint256 gasBefore = gasleft();
        vault.removeWhitelistedLPToken(address(lpTokens[5]));
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas to remove from 10 tokens:", gasUsed);
    }
    
    function test_gas_removeLPToken_from20() public {
        // Add 20 tokens
        for (uint i = 0; i < 20; i++) {
            vault.addWhitelistedLPToken(address(lpTokens[i]));
        }
        
        uint256 gasBefore = gasleft();
        vault.removeWhitelistedLPToken(address(lpTokens[10]));
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas to remove from 20 tokens:", gasUsed);
    }
    
    function test_gas_getLPHoldings_20tokens() public {
        // Add 20 tokens with balances
        for (uint i = 0; i < 20; i++) {
            vault.addWhitelistedLPToken(address(lpTokens[i]));
            lpTokens[i].mint(address(vault), 1000e18);
        }
        
        uint256 gasBefore = gasleft();
        vault.getLPHoldings();
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas to get 20 LP holdings:", gasUsed);
    }
}

