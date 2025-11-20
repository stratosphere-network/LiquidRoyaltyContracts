// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ConcreteReserveVault} from "../../src/concrete/ConcreteReserveVault.sol";
import {UnifiedConcreteSeniorVault} from "../../src/concrete/UnifiedConcreteSeniorVault.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ReserveTokenManagementTest
 * @notice Comprehensive tests for Reserve vault token management functions
 */
contract ReserveTokenManagementTest is Test {
    ConcreteReserveVault public reserveVault;
    UnifiedConcreteSeniorVault public seniorVault;
    
    MockERC20 public honey;  // Stablecoin
    MockERC20 public wbtc;   // Non-stablecoin
    MockERC20 public lpToken;
    
    MockKodiakHook public hook;
    MockAggregator public aggregator;
    
    address public deployer = address(1);
    address public admin = address(2);
    address public seeder = address(3);
    address public user = address(4);
    
    // Events to test
    event StablecoinSwappedToToken(address indexed stablecoin, address indexed tokenOut, uint256 amountIn, uint256 amountOut, uint256 timestamp);
    event HookTokenSwappedToStablecoin(address indexed tokenIn, uint256 amountIn, uint256 stablecoinOut, uint256 timestamp);
    event TokenRescuedFromHook(address indexed token, uint256 amount, uint256 timestamp);
    event LPExitedToToken(uint256 lpAmount, address indexed tokenOut, uint256 tokenReceived, uint256 timestamp);
    event KodiakInvestment(address indexed island, address indexed tokenIn, uint256 amountIn, uint256 lpMinted, uint256 timestamp);
    
    function setUp() public {
        vm.startPrank(deployer);
        
        // Deploy tokens
        honey = new MockERC20("HONEY", "HONEY", 18);
        wbtc = new MockERC20("Wrapped BTC", "WBTC", 8);
        lpToken = new MockERC20("LP Token", "LP", 18);
        
        // Deploy Senior vault (needed for Reserve initialization)
        UnifiedConcreteSeniorVault seniorImpl = new UnifiedConcreteSeniorVault();
        bytes memory seniorInitData = abi.encodeWithSignature(
            "initialize(address,string,string,address,address,address,uint256)",
            address(honey),
            "Senior Tranche",
            "snrUSD",
            address(0x01), // Placeholder junior
            address(0x02), // Placeholder reserve
            admin,
            0
        );
        ERC1967Proxy seniorProxy = new ERC1967Proxy(address(seniorImpl), seniorInitData);
        seniorVault = UnifiedConcreteSeniorVault(address(seniorProxy));
        
        // Deploy Reserve vault
        ConcreteReserveVault reserveImpl = new ConcreteReserveVault();
        bytes memory reserveInitData = abi.encodeWithSignature(
            "initialize(address,address,uint256)",
            address(honey),
            address(seniorVault),
            0
        );
        ERC1967Proxy reserveProxy = new ERC1967Proxy(address(reserveImpl), reserveInitData);
        reserveVault = ConcreteReserveVault(address(reserveProxy));
        
        // Set admin
        seniorVault.setAdmin(admin);
        reserveVault.setAdmin(admin);
        
        vm.stopPrank();
        
        // Deploy mock hook
        hook = new MockKodiakHook(address(reserveVault), address(lpToken), address(honey), address(wbtc));
        
        // Deploy mock aggregator
        aggregator = new MockAggregator(address(honey), address(wbtc));
        
        // Admin sets hook
        vm.prank(admin);
        reserveVault.setKodiakHook(address(hook));
        
        // Mint tokens
        honey.mint(admin, 1000000e18);
        wbtc.mint(admin, 100e8);
        lpToken.mint(address(hook), 10000e18);
        
        // Give tokens to vault for testing
        vm.startPrank(admin);
        honey.transfer(address(reserveVault), 100000e18);
        wbtc.transfer(address(reserveVault), 10e8);
        vm.stopPrank();
        
        // Give tokens to hook for testing
        honey.mint(address(hook), 50000e18);
        wbtc.mint(address(hook), 5e8);
    }
    
    // ============================================
    // swapStablecoinToToken() Tests
    // ============================================
    
    function testSwapStablecoinToToken_Success() public {
        uint256 honeyAmount = 10000e18;
        uint256 expectedWBTC = 2e7; // 0.2 WBTC (at 50k/BTC)
        
        uint256 vaultWBTCBefore = wbtc.balanceOf(address(reserveVault));
        uint256 vaultHoneyBefore = honey.balanceOf(address(reserveVault));
        
        vm.prank(admin);
        vm.expectEmit(true, true, false, false);
        emit StablecoinSwappedToToken(address(honey), address(wbtc), honeyAmount, expectedWBTC, block.timestamp);
        
        reserveVault.swapStablecoinToToken(
            honeyAmount,
            expectedWBTC - 100000, // Allow slippage
            address(wbtc),
            address(aggregator),
            abi.encode("swap")
        );
        
        uint256 vaultWBTCAfter = wbtc.balanceOf(address(reserveVault));
        uint256 vaultHoneyAfter = honey.balanceOf(address(reserveVault));
        
        // Check HONEY decreased
        assertEq(vaultHoneyAfter, vaultHoneyBefore - honeyAmount);
        
        // Check WBTC increased
        assertGt(vaultWBTCAfter, vaultWBTCBefore);
    }
    
    function testSwapStablecoinToToken_SlippageTooHigh() public {
        uint256 honeyAmount = 10000e18;
        uint256 unrealisticMinWBTC = 100e8; // Expecting 100 WBTC (unrealistic)
        
        vm.prank(admin);
        vm.expectRevert();
        reserveVault.swapStablecoinToToken(
            honeyAmount,
            unrealisticMinWBTC,
            address(wbtc),
            address(aggregator),
            abi.encode("swap")
        );
    }
    
    function testSwapStablecoinToToken_InsufficientBalance() public {
        uint256 tooMuchHoney = 1000000e18; // More than vault has
        
        vm.prank(admin);
        vm.expectRevert();
        reserveVault.swapStablecoinToToken(
            tooMuchHoney,
            1e8,
            address(wbtc),
            address(aggregator),
            abi.encode("swap")
        );
    }
    
    function testSwapStablecoinToToken_ZeroAmount() public {
        vm.prank(admin);
        vm.expectRevert();
        reserveVault.swapStablecoinToToken(
            0,
            1e8,
            address(wbtc),
            address(aggregator),
            abi.encode("swap")
        );
    }
    
    function testSwapStablecoinToToken_OnlyAdmin() public {
        vm.prank(user);
        vm.expectRevert();
        reserveVault.swapStablecoinToToken(
            1000e18,
            1e7,
            address(wbtc),
            address(aggregator),
            abi.encode("swap")
        );
    }
    
    // ============================================
    // rescueAndSwapHookTokenToStablecoin() Tests
    // ============================================
    
    function testRescueAndSwapHookTokenToStablecoin_Success() public {
        uint256 wbtcAmount = 1e7; // 0.1 WBTC
        uint256 expectedHoney = 5000e18; // ~$5k
        
        uint256 vaultHoneyBefore = honey.balanceOf(address(reserveVault));
        
        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit HookTokenSwappedToStablecoin(address(wbtc), wbtcAmount, expectedHoney, block.timestamp);
        
        reserveVault.rescueAndSwapHookTokenToStablecoin(
            address(wbtc),
            wbtcAmount,
            expectedHoney - 100e18, // Allow slippage
            address(aggregator),
            abi.encode("swap")
        );
        
        uint256 vaultHoneyAfter = honey.balanceOf(address(reserveVault));
        
        // Check HONEY increased
        assertGt(vaultHoneyAfter, vaultHoneyBefore);
    }
    
    function testRescueAndSwapHookTokenToStablecoin_SlippageTooHigh() public {
        uint256 wbtcAmount = 1e7;
        uint256 unrealisticMinHoney = 1000000e18; // Expecting $1M (unrealistic)
        
        vm.prank(admin);
        vm.expectRevert();
        reserveVault.rescueAndSwapHookTokenToStablecoin(
            address(wbtc),
            wbtcAmount,
            unrealisticMinHoney,
            address(aggregator),
            abi.encode("swap")
        );
    }
    
    function testRescueAndSwapHookTokenToStablecoin_ZeroAmount() public {
        vm.prank(admin);
        vm.expectRevert();
        reserveVault.rescueAndSwapHookTokenToStablecoin(
            address(wbtc),
            0,
            1000e18,
            address(aggregator),
            abi.encode("swap")
        );
    }
    
    function testRescueAndSwapHookTokenToStablecoin_OnlyAdmin() public {
        vm.prank(user);
        vm.expectRevert();
        reserveVault.rescueAndSwapHookTokenToStablecoin(
            address(wbtc),
            1e7,
            1000e18,
            address(aggregator),
            abi.encode("swap")
        );
    }
    
    // ============================================
    // rescueTokenFromHook() Tests
    // ============================================
    
    function testRescueTokenFromHook_Success() public {
        uint256 wbtcAmount = 1e8; // 1 WBTC
        
        uint256 vaultWBTCBefore = wbtc.balanceOf(address(reserveVault));
        uint256 hookWBTCBefore = wbtc.balanceOf(address(hook));
        
        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit TokenRescuedFromHook(address(wbtc), wbtcAmount, block.timestamp);
        
        reserveVault.rescueTokenFromHook(address(wbtc), wbtcAmount);
        
        uint256 vaultWBTCAfter = wbtc.balanceOf(address(reserveVault));
        uint256 hookWBTCAfter = wbtc.balanceOf(address(hook));
        
        // Check WBTC moved from hook to vault
        assertEq(vaultWBTCAfter, vaultWBTCBefore + wbtcAmount);
        assertEq(hookWBTCAfter, hookWBTCBefore - wbtcAmount);
    }
    
    function testRescueTokenFromHook_RescueAll() public {
        uint256 hookWBTCBefore = wbtc.balanceOf(address(hook));
        
        vm.prank(admin);
        reserveVault.rescueTokenFromHook(address(wbtc), 0); // 0 = rescue all
        
        uint256 hookWBTCAfter = wbtc.balanceOf(address(hook));
        
        // Check all WBTC removed from hook
        assertEq(hookWBTCAfter, 0);
    }
    
    function testRescueTokenFromHook_InsufficientBalance() public {
        uint256 tooMuchWBTC = 1000e8; // More than hook has
        
        vm.prank(admin);
        vm.expectRevert();
        reserveVault.rescueTokenFromHook(address(wbtc), tooMuchWBTC);
    }
    
    function testRescueTokenFromHook_ZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert();
        reserveVault.rescueTokenFromHook(address(0), 1e8);
    }
    
    function testRescueTokenFromHook_OnlyAdmin() public {
        vm.prank(user);
        vm.expectRevert();
        reserveVault.rescueTokenFromHook(address(wbtc), 1e8);
    }
    
    // ============================================
    // exitLPToToken() Tests
    // ============================================
    
    function testExitLPToToken_Success() public {
        uint256 lpAmount = 1000e18;
        uint256 expectedHoney = 2000e18; // Expecting ~$2k worth
        
        uint256 vaultHoneyBefore = honey.balanceOf(address(reserveVault));
        uint256 hookLPBefore = hook.getIslandLPBalance();
        
        vm.prank(admin);
        vm.expectEmit(false, true, false, false);
        emit LPExitedToToken(lpAmount, address(honey), expectedHoney, block.timestamp);
        
        reserveVault.exitLPToToken(
            lpAmount,
            address(honey),
            expectedHoney - 100e18, // Allow slippage
            address(aggregator),
            abi.encode("swap")
        );
        
        uint256 vaultHoneyAfter = honey.balanceOf(address(reserveVault));
        uint256 hookLPAfter = hook.getIslandLPBalance();
        
        // Check HONEY increased in vault
        assertGt(vaultHoneyAfter, vaultHoneyBefore);
        
        // Check LP decreased in hook
        assertLt(hookLPAfter, hookLPBefore);
    }
    
    function testExitLPToToken_ExitAll() public {
        uint256 hookLPBefore = hook.getIslandLPBalance();
        assertGt(hookLPBefore, 0);
        
        vm.prank(admin);
        reserveVault.exitLPToToken(
            0, // 0 = exit all
            address(honey),
            1000e18,
            address(aggregator),
            abi.encode("swap")
        );
        
        uint256 hookLPAfter = hook.getIslandLPBalance();
        
        // Check all LP exited
        assertLt(hookLPAfter, hookLPBefore);
    }
    
    function testExitLPToToken_SlippageTooHigh() public {
        uint256 unrealisticMinHoney = 1000000e18; // Expecting $1M (unrealistic)
        
        vm.prank(admin);
        vm.expectRevert();
        reserveVault.exitLPToToken(
            1000e18,
            address(honey),
            unrealisticMinHoney,
            address(aggregator),
            abi.encode("swap")
        );
    }
    
    function testExitLPToToken_ZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert();
        reserveVault.exitLPToToken(
            1000e18,
            address(0),
            1000e18,
            address(aggregator),
            abi.encode("swap")
        );
    }
    
    function testExitLPToToken_OnlyAdmin() public {
        vm.prank(user);
        vm.expectRevert();
        reserveVault.exitLPToToken(
            1000e18,
            address(honey),
            1000e18,
            address(aggregator),
            abi.encode("swap")
        );
    }
    
    // ============================================
    // investInKodiak() Tests (Existing Function)
    // ============================================
    
    function testInvestInKodiak_Success() public {
        uint256 wbtcAmount = 1e8; // 1 WBTC
        uint256 minLP = 1000e18;
        
        uint256 hookLPBefore = hook.getIslandLPBalance();
        uint256 vaultWBTCBefore = wbtc.balanceOf(address(reserveVault));
        
        vm.prank(admin);
        vm.expectEmit(true, true, false, false);
        emit KodiakInvestment(address(lpToken), address(wbtc), wbtcAmount, 0, block.timestamp);
        
        reserveVault.investInKodiak(
            address(lpToken), // island
            address(wbtc),
            wbtcAmount,
            minLP,
            address(aggregator),
            abi.encode("swap0"),
            address(aggregator),
            abi.encode("swap1")
        );
        
        uint256 hookLPAfter = hook.getIslandLPBalance();
        uint256 vaultWBTCAfter = wbtc.balanceOf(address(reserveVault));
        
        // Check WBTC moved from vault
        assertEq(vaultWBTCAfter, vaultWBTCBefore - wbtcAmount);
        
        // Check LP increased in hook
        assertGt(hookLPAfter, hookLPBefore);
    }
    
    function testInvestInKodiak_SlippageTooHigh() public {
        uint256 wbtcAmount = 1e8;
        uint256 unrealisticMinLP = 1000000e18; // Expecting 1M LP (unrealistic)
        
        vm.prank(admin);
        vm.expectRevert();
        reserveVault.investInKodiak(
            address(lpToken),
            address(wbtc),
            wbtcAmount,
            unrealisticMinLP,
            address(aggregator),
            abi.encode("swap0"),
            address(aggregator),
            abi.encode("swap1")
        );
    }
    
    function testInvestInKodiak_InsufficientBalance() public {
        uint256 tooMuchWBTC = 1000e8; // More than vault has
        
        vm.prank(admin);
        vm.expectRevert();
        reserveVault.investInKodiak(
            address(lpToken),
            address(wbtc),
            tooMuchWBTC,
            1000e18,
            address(aggregator),
            abi.encode("swap0"),
            address(aggregator),
            abi.encode("swap1")
        );
    }
    
    function testInvestInKodiak_ZeroAmount() public {
        vm.prank(admin);
        vm.expectRevert();
        reserveVault.investInKodiak(
            address(lpToken),
            address(wbtc),
            0,
            1000e18,
            address(aggregator),
            abi.encode("swap0"),
            address(aggregator),
            abi.encode("swap1")
        );
    }
    
    function testInvestInKodiak_OnlyAdmin() public {
        vm.prank(user);
        vm.expectRevert();
        reserveVault.investInKodiak(
            address(lpToken),
            address(wbtc),
            1e8,
            1000e18,
            address(aggregator),
            abi.encode("swap0"),
            address(aggregator),
            abi.encode("swap1")
        );
    }
    
    // ============================================
    // Integration Tests (Multi-Step Workflows)
    // ============================================
    
    function testWorkflow_SwapHoneyToWBTC_ThenInvest() public {
        // Step 1: Swap HONEY → WBTC in vault
        uint256 honeyAmount = 10000e18;
        
        vm.prank(admin);
        reserveVault.swapStablecoinToToken(
            honeyAmount,
            1e7,
            address(wbtc),
            address(aggregator),
            abi.encode("swap")
        );
        
        uint256 vaultWBTC = wbtc.balanceOf(address(reserveVault));
        assertGt(vaultWBTC, 10e8); // Should have more than 10 WBTC now
        
        // Step 2: Invest WBTC → LP
        vm.prank(admin);
        reserveVault.investInKodiak(
            address(lpToken),
            address(wbtc),
            1e8,
            1000e18,
            address(aggregator),
            abi.encode("swap0"),
            address(aggregator),
            abi.encode("swap1")
        );
        
        uint256 hookLP = hook.getIslandLPBalance();
        assertGt(hookLP, 10000e18); // Should have gained LP
    }
    
    function testWorkflow_ExitLP_ThenSwapToWBTC() public {
        // Step 1: Exit LP → Get HONEY in vault
        uint256 vaultHoneyBefore = honey.balanceOf(address(reserveVault));
        
        vm.prank(admin);
        reserveVault.exitLPToToken(
            1000e18,
            address(honey),
            1000e18,
            address(aggregator),
            abi.encode("swap")
        );
        
        uint256 vaultHoneyAfter = honey.balanceOf(address(reserveVault));
        assertGt(vaultHoneyAfter, vaultHoneyBefore);
        
        // Step 2: Swap HONEY → WBTC in vault
        uint256 vaultWBTCBefore = wbtc.balanceOf(address(reserveVault));
        
        vm.prank(admin);
        reserveVault.swapStablecoinToToken(
            5000e18,
            1e7,
            address(wbtc),
            address(aggregator),
            abi.encode("swap")
        );
        
        uint256 vaultWBTCAfter = wbtc.balanceOf(address(reserveVault));
        assertGt(vaultWBTCAfter, vaultWBTCBefore);
    }
    
    function testWorkflow_RescueWBTCDust_ThenInvest() public {
        // Step 1: Rescue WBTC from hook
        uint256 vaultWBTCBefore = wbtc.balanceOf(address(reserveVault));
        
        vm.prank(admin);
        reserveVault.rescueTokenFromHook(address(wbtc), 1e8);
        
        uint256 vaultWBTCAfter = wbtc.balanceOf(address(reserveVault));
        assertGt(vaultWBTCAfter, vaultWBTCBefore);
        
        // Step 2: Invest rescued WBTC → LP
        vm.prank(admin);
        reserveVault.investInKodiak(
            address(lpToken),
            address(wbtc),
            1e8,
            1000e18,
            address(aggregator),
            abi.encode("swap0"),
            address(aggregator),
            abi.encode("swap1")
        );
    }
}

// ============================================
// Mock Contracts
// ============================================

contract MockKodiakHook {
    address public vault;
    address public lpToken;
    address public honey;
    address public wbtc;
    uint256 public lpBalance;
    
    constructor(address _vault, address _lpToken, address _honey, address _wbtc) {
        vault = _vault;
        lpToken = _lpToken;
        honey = _honey;
        wbtc = _wbtc;
        lpBalance = IERC20(_lpToken).balanceOf(address(this));
    }
    
    function getIslandLPBalance() external view returns (uint256) {
        return IERC20(lpToken).balanceOf(address(this));
    }
    
    function onAfterDepositWithSwaps(
        uint256 amount,
        address,
        bytes calldata,
        address,
        bytes calldata
    ) external {
        // Mock: Receive WBTC, mint LP (1:50000 ratio, 1 WBTC = 50k LP)
        uint256 lpToMint = (amount * 50000e18) / 1e8;
        MockERC20(lpToken).mint(address(this), lpToMint);
    }
    
    function adminSwapAndReturnToVault(
        address tokenIn,
        uint256 amountIn,
        bytes calldata,
        address
    ) external {
        // Mock: Swap WBTC → HONEY and send to vault
        if (tokenIn == wbtc) {
            // Burn WBTC from hook
            MockERC20(wbtc).burn(address(this), amountIn);
            
            // Mint HONEY to vault (1 WBTC = 50k HONEY)
            uint256 honeyOut = (amountIn * 50000e18) / 1e8;
            MockERC20(honey).mint(vault, honeyOut);
        }
    }
    
    function adminRescueTokens(
        address token,
        address to,
        uint256 amount
    ) external {
        if (amount == 0) {
            amount = IERC20(token).balanceOf(address(this));
        }
        IERC20(token).transfer(to, amount);
    }
    
    function adminLiquidateAll(
        bytes calldata,
        address
    ) external {
        // Mock: Burn all LP, send HONEY to vault
        uint256 lpBal = IERC20(lpToken).balanceOf(address(this));
        if (lpBal > 0) {
            MockERC20(lpToken).burn(address(this), lpBal);
            
            // Send HONEY to vault (1 LP = 2 HONEY)
            uint256 honeyOut = lpBal * 2;
            MockERC20(honey).mint(vault, honeyOut);
        }
    }
}

contract MockAggregator {
    address public honey;
    address public wbtc;
    
    constructor(address _honey, address _wbtc) {
        honey = _honey;
        wbtc = _wbtc;
    }
    
    // Mock swap function
    fallback() external {
        // Check who called us (the vault)
        address caller = msg.sender;
        
        // Get allowances (vault approved us)
        uint256 honeyAllowance = IERC20(honey).allowance(caller, address(this));
        uint256 wbtcAllowance = IERC20(wbtc).allowance(caller, address(this));
        
        // If caller approved HONEY, swap HONEY → WBTC
        if (honeyAllowance > 0) {
            // Transfer HONEY from caller to us, then burn it
            IERC20(honey).transferFrom(caller, address(this), honeyAllowance);
            MockERC20(honey).burn(address(this), honeyAllowance);
            
            // Mint WBTC to caller (1 HONEY = 0.00002 WBTC at $50k/BTC)
            uint256 wbtcOut = (honeyAllowance * 1e8) / 50000e18;
            MockERC20(wbtc).mint(caller, wbtcOut);
        }
        // If caller approved WBTC, swap WBTC → HONEY
        else if (wbtcAllowance > 0) {
            // Transfer WBTC from caller to us, then burn it
            IERC20(wbtc).transferFrom(caller, address(this), wbtcAllowance);
            MockERC20(wbtc).burn(address(this), wbtcAllowance);
            
            // Mint HONEY to caller (1 WBTC = 50k HONEY)
            uint256 honeyOut = (wbtcAllowance * 50000e18) / 1e8;
            MockERC20(honey).mint(caller, honeyOut);
        }
    }
}

