// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ConcreteJuniorVault} from "../../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../../src/concrete/ConcreteReserveVault.sol";
import {UnifiedConcreteSeniorVault} from "../../src/concrete/UnifiedConcreteSeniorVault.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {IKodiakVaultHook} from "../../src/integrations/IKodiakVaultHook.sol";
import {IKodiakIsland} from "../../src/integrations/IKodiakIsland.sol";

/**
 * @title KodiakIntegrationTest
 * @notice Unit tests for Kodiak integration (setKodiakHook, deployToKodiak, sweepToKodiak)
 */
contract KodiakIntegrationTest is Test {
    ConcreteJuniorVault public juniorVault;
    ConcreteReserveVault public reserveVault;
    UnifiedConcreteSeniorVault public seniorVault;
    MockERC20 public stablecoin;
    MockERC20 public lpToken;
    
    address public admin = address(this);
    address public user = address(0x1);
    address public mockHook;
    address public mockIsland;
    
    uint256 constant INITIAL_VALUE = 1000e18;
    
    event WhitelistedLPAdded(address indexed lp);
    event KodiakDeployment(uint256 amount, uint256 lpReceived, uint256 timestamp);
    
    function setUp() public {
        // Deploy mocks
        stablecoin = new MockERC20("Stablecoin", "USDC", 18);
        lpToken = new MockERC20("LP Token", "LP", 18);
        
        // Deploy Junior vault with proxy
        ConcreteJuniorVault juniorImpl = new ConcreteJuniorVault();
        bytes memory juniorInitData = abi.encodeWithSelector(
            ConcreteJuniorVault.initialize.selector,
            address(stablecoin),
            address(0x1),  // placeholder
            0
        );
        ERC1967Proxy juniorProxy = new ERC1967Proxy(address(juniorImpl), juniorInitData);
        juniorVault = ConcreteJuniorVault(address(juniorProxy));
        
        // Deploy Reserve vault with proxy
        ConcreteReserveVault reserveImpl = new ConcreteReserveVault();
        bytes memory reserveInitData = abi.encodeWithSelector(
            ConcreteReserveVault.initialize.selector,
            address(stablecoin),
            address(0x1),  // placeholder
            0
        );
        ERC1967Proxy reserveProxy = new ERC1967Proxy(address(reserveImpl), reserveInitData);
        reserveVault = ConcreteReserveVault(address(reserveProxy));
        
        // Deploy Senior vault with proxy
        UnifiedConcreteSeniorVault seniorImpl = new UnifiedConcreteSeniorVault();
        bytes memory seniorInitData = abi.encodeWithSelector(
            UnifiedConcreteSeniorVault.initialize.selector,
            address(stablecoin),
            "Senior USD",
            "snrUSD",
            address(juniorVault),
            address(reserveVault),
            address(this),  // treasury
            0               // initial value
        );
        ERC1967Proxy seniorProxy = new ERC1967Proxy(address(seniorImpl), seniorInitData);
        seniorVault = UnifiedConcreteSeniorVault(address(seniorProxy));
        
        // Set test contract as admin for all vaults
        juniorVault.setAdmin(admin);
        reserveVault.setAdmin(admin);
        seniorVault.setAdmin(admin);
        
        // Update senior vault references
        juniorVault.updateSeniorVault(address(seniorVault));
        reserveVault.updateSeniorVault(address(seniorVault));
        
        // Create mock hook and island
        mockHook = address(new MockKodiakHook(address(juniorVault), address(lpToken)));
        mockIsland = address(lpToken);
        
        // Mint tokens
        stablecoin.mint(address(juniorVault), 10000e18);
        stablecoin.mint(address(reserveVault), 10000e18);
    }
    
    // ============================================
    // setKodiakHook Tests
    // ============================================
    
    function test_setKodiakHook_success() public {
        vm.expectEmit(true, false, false, true);
        emit WhitelistedLPAdded(mockHook);
        
        juniorVault.setKodiakHook(mockHook);
        
        assertEq(address(juniorVault.kodiakHook()), mockHook);
    }
    
    function test_setKodiakHook_autoWhitelists() public {
        juniorVault.setKodiakHook(mockHook);
        
        // Check hook is whitelisted
        assertTrue(juniorVault.isWhitelistedLP(mockHook));
    }
    
    function test_setKodiakHook_replacesOldHook() public {
        // Set first hook
        juniorVault.setKodiakHook(mockHook);
        assertTrue(juniorVault.isWhitelistedLP(mockHook));
        
        // Create new hook
        address newHook = address(new MockKodiakHook(address(juniorVault), address(lpToken)));
        
        // Set new hook
        juniorVault.setKodiakHook(newHook);
        
        // Old hook should be removed from whitelist
        assertFalse(juniorVault.isWhitelistedLP(mockHook));
        // New hook should be whitelisted
        assertTrue(juniorVault.isWhitelistedLP(newHook));
        assertEq(address(juniorVault.kodiakHook()), newHook);
    }
    
    function test_setKodiakHook_revertsIfWrongVault() public {
        address wrongHook = address(new MockKodiakHook(address(0x999), address(lpToken)));
        
        vm.expectRevert(abi.encodeWithSignature("WrongVault()"));
        juniorVault.setKodiakHook(wrongHook);
    }
    
    function test_setKodiakHook_onlyAdmin() public {
        vm.prank(user);
        vm.expectRevert();  // Should revert with OnlyAdmin
        juniorVault.setKodiakHook(mockHook);
    }
    
    // ============================================
    // deployToKodiak Tests
    // ============================================
    
    function test_deployToKodiak_success() public {
        juniorVault.setKodiakHook(mockHook);
        
        uint256 deployAmount = 1000e18;
        uint256 minLP = 990e18;
        
        vm.expectEmit(false, false, false, true);
        emit KodiakDeployment(deployAmount, 1000e18, block.timestamp);
        
        juniorVault.deployToKodiak(
            deployAmount,
            minLP,
            address(0), // aggregator
            "",         // swap data
            address(0),
            ""
        );
        
        // Check stablecoin was transferred to hook
        assertEq(stablecoin.balanceOf(mockHook), deployAmount);
    }
    
    function test_deployToKodiak_revertsIfNoHook() public {
        vm.expectRevert(abi.encodeWithSignature("KodiakHookNotSet()"));
        juniorVault.deployToKodiak(1000e18, 990e18, address(0), "", address(0), "");
    }
    
    function test_deployToKodiak_revertsIfZeroAmount() public {
        juniorVault.setKodiakHook(mockHook);
        
        vm.expectRevert(abi.encodeWithSignature("InvalidAmount()"));
        juniorVault.deployToKodiak(0, 0, address(0), "", address(0), "");
    }
    
    function test_deployToKodiak_revertsIfInsufficientBalance() public {
        juniorVault.setKodiakHook(mockHook);
        
        uint256 tooMuch = 20000e18; // More than vault has
        
        vm.expectRevert(abi.encodeWithSignature("InsufficientBalance()"));
        juniorVault.deployToKodiak(tooMuch, 0, address(0), "", address(0), "");
    }
    
    function test_deployToKodiak_revertsIfSlippageTooHigh() public {
        juniorVault.setKodiakHook(mockHook);
        
        uint256 deployAmount = 1000e18;
        uint256 minLP = 2000e18; // Expecting more than possible
        
        vm.expectRevert(abi.encodeWithSignature("SlippageTooHigh()"));
        juniorVault.deployToKodiak(deployAmount, minLP, address(0), "", address(0), "");
    }
    
    function test_deployToKodiak_multipleDeployments() public {
        juniorVault.setKodiakHook(mockHook);
        
        // First deployment
        juniorVault.deployToKodiak(1000e18, 990e18, address(0), "", address(0), "");
        assertEq(stablecoin.balanceOf(mockHook), 1000e18);
        
        // Second deployment
        juniorVault.deployToKodiak(500e18, 490e18, address(0), "", address(0), "");
        assertEq(stablecoin.balanceOf(mockHook), 1500e18);
    }
    
    function test_deployToKodiak_onlyAdmin() public {
        juniorVault.setKodiakHook(mockHook);
        
        vm.prank(user);
        vm.expectRevert();  // Should revert with OnlyAdmin
        juniorVault.deployToKodiak(1000e18, 990e18, address(0), "", address(0), "");
    }
    
    // ============================================
    // sweepToKodiak Tests
    // ============================================
    
    function test_sweepToKodiak_success() public {
        juniorVault.setKodiakHook(mockHook);
        
        uint256 vaultBalance = stablecoin.balanceOf(address(juniorVault));
        
        vm.expectEmit(false, false, false, true);
        emit KodiakDeployment(vaultBalance, vaultBalance, block.timestamp);
        
        juniorVault.sweepToKodiak(vaultBalance - 100e18, address(0), "", address(0), "");
        
        // All idle funds should be swept
        assertEq(stablecoin.balanceOf(mockHook), vaultBalance);
        assertEq(stablecoin.balanceOf(address(juniorVault)), 0);
    }
    
    function test_sweepToKodiak_revertsIfNoIdle() public {
        juniorVault.setKodiakHook(mockHook);
        
        // Deploy all funds first
        uint256 all = stablecoin.balanceOf(address(juniorVault));
        juniorVault.deployToKodiak(all, all - 100e18, address(0), "", address(0), "");
        
        // Try to sweep (nothing left)
        vm.expectRevert(abi.encodeWithSignature("InvalidAmount()"));
        juniorVault.sweepToKodiak(0, address(0), "", address(0), "");
    }
    
    function test_sweepToKodiak_revertsIfNoHook() public {
        vm.expectRevert(abi.encodeWithSignature("KodiakHookNotSet()"));
        juniorVault.sweepToKodiak(0, address(0), "", address(0), "");
    }
    
    function test_sweepToKodiak_onlyAdmin() public {
        juniorVault.setKodiakHook(mockHook);
        
        vm.prank(user);
        vm.expectRevert();  // Should revert with OnlyAdmin
        juniorVault.sweepToKodiak(0, address(0), "", address(0), "");
    }
    
    // ============================================
    // Cross-Vault Tests
    // ============================================
    
    function test_reserveVault_kodiakIntegration() public {
        address reserveHook = address(new MockKodiakHook(address(reserveVault), address(lpToken)));
        
        reserveVault.setKodiakHook(reserveHook);
        assertEq(address(reserveVault.kodiakHook()), reserveHook);
        
        reserveVault.deployToKodiak(1000e18, 990e18, address(0), "", address(0), "");
        assertEq(stablecoin.balanceOf(reserveHook), 1000e18);
    }
    
    function test_seniorVault_kodiakIntegration() public {
        address seniorHook = address(new MockKodiakHook(address(seniorVault), address(lpToken)));
        
        seniorVault.setKodiakHook(seniorHook);
        assertEq(address(seniorVault.kodiakHook()), seniorHook);
        
        // Mint some funds to senior vault
        stablecoin.mint(address(seniorVault), 5000e18);
        
        seniorVault.deployToKodiak(1000e18, 990e18, address(0), "", address(0), "");
        assertEq(stablecoin.balanceOf(seniorHook), 1000e18);
    }
}

// ============================================
// Mock Contracts
// ============================================

contract MockKodiakHook is IKodiakVaultHook {
    address public immutable vault;
    address public immutable island;
    uint256 public lpBalance;
    
    constructor(address _vault, address _island) {
        vault = _vault;
        island = _island;
    }
    
    function onAfterDeposit(uint256 amount) external override {
        // Mock: just track the LP balance (1:1 with deposit)
        lpBalance += amount;
    }
    
    function onAfterDepositWithSwaps(
        uint256 amount,
        address,
        bytes calldata,
        address,
        bytes calldata
    ) external override {
        // Mock: just track the LP balance (1:1 with deposit)
        lpBalance += amount;
    }
    
    function ensureFundsAvailable(uint256) external override {
        // Mock: do nothing
    }
    
    function liquidateLPForAmount(uint256) external override {
        // Mock: do nothing
    }
    
    function transferIslandLP(address, uint256) external override {
        // Mock: do nothing
    }
    
    function getIslandLPBalance() external view override returns (uint256) {
        return lpBalance;
    }
    
    function adminSwapAndReturnToVault(
        address,
        uint256,
        bytes calldata,
        address
    ) external override {}
    
    function adminRescueTokens(
        address,
        address,
        uint256
    ) external override {}
    
    function adminLiquidateAll(
        bytes calldata,
        address
    ) external override {}
}

