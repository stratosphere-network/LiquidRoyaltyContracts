// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../../src/concrete/UnifiedConcreteSeniorVault.sol";
import "../../src/concrete/ConcreteJuniorVault.sol";
import "../../src/concrete/ConcreteReserveVault.sol";
import "../../src/integrations/KodiakVaultHook.sol";
import "../../src/mocks/MockERC20.sol";
import "../../src/integrations/IKodiakIsland.sol";

/**
 * @title Reserve Depletion Simulation
 * @notice Simulates realistic trading scenarios to test vault sustainability
 * 
 * SCENARIO:
 * - Stablecoin: USDE (18 decimals)
 * - Non-stablecoin: SAIL (18 decimals)
 * - Initial SAIL price: 10 USDE per SAIL
 * - Pool: 1,000,000 USDE + 100,000 SAIL
 * - Senior Vault: 1.5M USDE
 * - Junior Vault: 1.5M USDE
 * - Reserve Vault: 750K USDE
 * 
 * SIMULATIONS:
 * 1. SAIL pumps to 12 USDE (LP value increases)
 * 2. SAIL dumps to 8 USDE (LP value decreases)
 * 3. High volatility (SAIL swings between 8-15 USDE)
 * 4. Gradual decline (SAIL slowly bleeds to 5 USDE)
 * 5. Black swan (SAIL crashes to 2 USDE)
 * 6. Extended bear market (30 days of losses)
 */
contract ReserveDepletionSimulation is Test {
    // Contracts
    UnifiedConcreteSeniorVault public seniorVault;
    ConcreteJuniorVault public juniorVault;
    ConcreteReserveVault public reserveVault;
    KodiakVaultHook public seniorHook;
    KodiakVaultHook public juniorHook;
    KodiakVaultHook public reserveHook;
    
    // Tokens
    MockERC20 public usde;  // Stablecoin
    MockERC20 public sail;  // Non-stablecoin
    MockERC20 public lpToken;  // Simulated LP token
    
    // Mock Island (simulates Kodiak pool)
    MockKodiakIsland public island;
    address public router = address(0x999);
    
    // Actors
    address public admin = address(0x1);
    address public deployer = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);
    address public trader = address(0x5);  // Simulates market trading
    
    // Initial state
    uint256 constant INITIAL_SAIL_PRICE = 10e18;  // 10 USDE per SAIL
    uint256 constant POOL_USDE = 1_000_000e18;
    uint256 constant POOL_SAIL = 100_000e18;
    uint256 constant SENIOR_SIZE = 1_500_000e18;
    uint256 constant JUNIOR_SIZE = 1_500_000e18;
    uint256 constant RESERVE_SIZE = 750_000e18;
    
    // State tracking for JSON export
    struct StateSnapshot {
        uint256 day;
        uint256 timestamp;
        uint256 sailPrice;
        uint256 lpPrice;
        uint256 seniorTotalSupply;
        uint256 seniorVaultValue;
        uint256 seniorBackingRatio;
        uint256 juniorTotalAssets;
        uint256 juniorTotalSupply;
        uint256 juniorUnstakingRatio;
        uint256 reserveTotalAssets;
        uint256 reserveTotalSupply;
        uint256 poolUsdeReserve;
        uint256 poolSailReserve;
        string description;
    }
    
    StateSnapshot[] public stateHistory;
    string public currentScenarioName;
    
    // Events for logging
    event SimulationStep(
        uint256 day,
        uint256 sailPrice,
        uint256 lpPrice,
        uint256 seniorBackingRatio,
        uint256 juniorUnstakingRatio,
        uint256 reserveValue,
        string event_description
    );

    function setUp() public {
        vm.startPrank(deployer);
        
        // 1. Deploy tokens
        usde = new MockERC20("USDE Stablecoin", "USDE", 18);
        sail = new MockERC20("SAIL Token", "SAIL", 18);
        lpToken = new MockERC20("LP Token", "LP", 18);
        
        // 2. Deploy mock island (simulates Kodiak pool)
        island = new MockKodiakIsland(address(usde), address(sail), address(lpToken));
        
        // 3. Fund the pool (1M USDE + 100K SAIL = balanced at 10 USDE/SAIL)
        usde.mint(address(island), POOL_USDE);
        sail.mint(address(island), POOL_SAIL);
        
        // 4. Deploy vault implementations
        seniorVault = new UnifiedConcreteSeniorVault();
        juniorVault = new ConcreteJuniorVault();
        reserveVault = new ConcreteReserveVault();
        
        // 5. Initialize vaults
        seniorVault.initialize(address(usde), deployer, 0);
        juniorVault.initialize(address(usde), deployer, 0);
        reserveVault.initialize(address(usde), deployer, 0);
        
        // 6. Set admin
        seniorVault.setAdmin(admin);
        juniorVault.setAdmin(admin);
        reserveVault.setAdmin(admin);
        
        vm.stopPrank();
        
        // 7. Deploy hooks
        vm.startPrank(admin);
        seniorHook = new KodiakVaultHook(address(seniorVault), address(island), address(lpToken));
        juniorHook = new KodiakVaultHook(address(juniorVault), address(island), address(lpToken));
        reserveHook = new KodiakVaultHook(address(reserveVault), address(island), address(lpToken));
        
        // 8. Configure vaults
        seniorVault.setKodiakHook(address(seniorHook));
        juniorVault.setKodiakHook(address(juniorHook));
        reserveVault.setKodiakHook(address(reserveHook));
        
        seniorVault.setJuniorVault(address(juniorVault));
        seniorVault.setReserveVault(address(reserveVault));
        juniorVault.setSeniorVault(address(seniorVault));
        juniorVault.setReserveVault(address(reserveVault));
        reserveVault.setSeniorVault(address(seniorVault));
        reserveVault.setJuniorVault(address(juniorVault));
        
        // 9. Whitelist LP token
        seniorVault.whitelistLPToken(address(lpToken), true);
        juniorVault.whitelistLPToken(address(lpToken), true);
        reserveVault.whitelistLPToken(address(lpToken), true);
        
        // 10. Configure oracles (simplified - we'll calculate LP price manually)
        seniorVault.setOracleConfig(address(island), 500, true, false);  // 5% max deviation
        juniorVault.setOracleConfig(address(island), 500, true, false);
        reserveVault.setOracleConfig(address(island), 500, true, false);
        
        vm.stopPrank();
        
        // 11. Fund vaults with initial deposits
        _fundVaults();
        
        console.log("\n==================================================");
        console.log("INITIAL STATE");
        console.log("==================================================");
        _logState(0, "Initial Setup");
    }
    
    function _fundVaults() internal {
        // Mint USDE for users
        usde.mint(user1, 10_000_000e18);
        usde.mint(user2, 10_000_000e18);
        
        // User1 deposits into Senior
        vm.startPrank(user1);
        usde.approve(address(seniorVault), SENIOR_SIZE);
        seniorVault.deposit(SENIOR_SIZE, user1);
        vm.stopPrank();
        
        // User2 deposits into Junior
        vm.startPrank(user2);
        usde.approve(address(juniorVault), JUNIOR_SIZE);
        juniorVault.deposit(JUNIOR_SIZE, user2);
        vm.stopPrank();
        
        // User1 also deposits into Reserve
        vm.startPrank(user1);
        usde.approve(address(reserveVault), RESERVE_SIZE);
        reserveVault.deposit(RESERVE_SIZE, user1);
        vm.stopPrank();
    }
    
    function _getSailPrice() internal view returns (uint256) {
        // Calculate SAIL price from pool reserves
        // Price = USDE_reserve / SAIL_reserve
        uint256 usdeBalance = usde.balanceOf(address(island));
        uint256 sailBalance = sail.balanceOf(address(island));
        return (usdeBalance * 1e18) / sailBalance;
    }
    
    function _getLPPrice() internal view returns (uint256) {
        // Simplified LP pricing: (USDE_value + SAIL_value) / LP_supply
        uint256 usdeBalance = usde.balanceOf(address(island));
        uint256 sailBalance = sail.balanceOf(address(island));
        uint256 sailPrice = _getSailPrice();
        uint256 sailValueInUsde = (sailBalance * sailPrice) / 1e18;
        uint256 totalValueUsde = usdeBalance + sailValueInUsde;
        uint256 lpSupply = lpToken.totalSupply();
        
        if (lpSupply == 0) return 1e18;  // Default to 1:1
        return (totalValueUsde * 1e18) / lpSupply;
    }
    
    function _logState(uint256 day, string memory description) internal {
        uint256 sailPrice = _getSailPrice();
        uint256 lpPrice = _getLPPrice();
        uint256 seniorBackingRatio = seniorVault.backingRatio();
        uint256 juniorUnstakingRatio = juniorVault.unstakingRatio();
        uint256 reserveValue = reserveVault.totalAssets();
        
        // Capture full state snapshot
        StateSnapshot memory snapshot = StateSnapshot({
            day: day,
            timestamp: block.timestamp,
            sailPrice: sailPrice,
            lpPrice: lpPrice,
            seniorTotalSupply: seniorVault.totalSupply(),
            seniorVaultValue: seniorVault.vaultValue(),
            seniorBackingRatio: seniorBackingRatio,
            juniorTotalAssets: juniorVault.totalAssets(),
            juniorTotalSupply: juniorVault.totalSupply(),
            juniorUnstakingRatio: juniorUnstakingRatio,
            reserveTotalAssets: reserveVault.totalAssets(),
            reserveTotalSupply: reserveVault.totalSupply(),
            poolUsdeReserve: usde.balanceOf(address(island)),
            poolSailReserve: sail.balanceOf(address(island)),
            description: description
        });
        
        stateHistory.push(snapshot);
        
        console.log("\nDay %s: %s", day, description);
        console.log("  SAIL Price: %s USDE", sailPrice / 1e18);
        console.log("  LP Price: %s USDE", lpPrice / 1e18);
        console.log("  Senior Backing: %s%%", seniorBackingRatio / 1e16);
        console.log("  Junior Unstaking: %s%%", juniorUnstakingRatio / 1e16);
        console.log("  Reserve Value: $%s", reserveValue / 1e18);
        
        emit SimulationStep(day, sailPrice, lpPrice, seniorBackingRatio, juniorUnstakingRatio, reserveValue, description);
    }
    
    /// @dev Export state history to JSON file
    function _exportToJson(string memory scenarioName) internal {
        string memory json = "";
        
        // Build JSON array of state snapshots
        json = string(abi.encodePacked(json, '{"scenario":"', scenarioName, '","snapshots":['));
        
        for (uint256 i = 0; i < stateHistory.length; i++) {
            StateSnapshot memory s = stateHistory[i];
            
            string memory snapshot = string(abi.encodePacked(
                '{"day":', vm.toString(s.day),
                ',"timestamp":', vm.toString(s.timestamp),
                ',"sailPrice":', vm.toString(s.sailPrice),
                ',"lpPrice":', vm.toString(s.lpPrice),
                ',"seniorTotalSupply":', vm.toString(s.seniorTotalSupply),
                ',"seniorVaultValue":', vm.toString(s.seniorVaultValue),
                ',"seniorBackingRatio":', vm.toString(s.seniorBackingRatio),
                ',"juniorTotalAssets":', vm.toString(s.juniorTotalAssets),
                ',"juniorTotalSupply":', vm.toString(s.juniorTotalSupply),
                ',"juniorUnstakingRatio":', vm.toString(s.juniorUnstakingRatio),
                ',"reserveTotalAssets":', vm.toString(s.reserveTotalAssets),
                ',"reserveTotalSupply":', vm.toString(s.reserveTotalSupply),
                ',"poolUsdeReserve":', vm.toString(s.poolUsdeReserve),
                ',"poolSailReserve":', vm.toString(s.poolSailReserve),
                ',"description":"', s.description, '"}'
            ));
            
            json = string(abi.encodePacked(json, snapshot));
            
            if (i < stateHistory.length - 1) {
                json = string(abi.encodePacked(json, ','));
            }
        }
        
        json = string(abi.encodePacked(json, ']}'));
        
        // Write to file
        string memory filename = string(abi.encodePacked("simulation_results/", scenarioName, ".json"));
        vm.writeFile(filename, json);
        
        console.log("Exported %s snapshots to %s", stateHistory.length, filename);
    }
    
    /// @dev Clear state history for next scenario
    function _clearHistory() internal {
        delete stateHistory;
    }
    
    /// @dev Simulates a trade that changes SAIL price
    function _simulateTrade(uint256 newSailPrice) internal {
        // Calculate new pool balances to achieve target SAIL price
        // For constant product AMM: x * y = k
        // We keep k constant and adjust balances
        
        uint256 k = POOL_USDE * POOL_SAIL;  // Initial constant product
        
        // New balances: x * y = k, and x/y = newSailPrice
        // y = sqrt(k / newSailPrice)
        // x = k / y
        
        uint256 newSailBalance = sqrt((k * 1e18) / newSailPrice);
        uint256 newUsdeBalance = (k * 1e18) / newSailBalance / 1e18;
        
        // Adjust pool balances
        uint256 currentUsde = usde.balanceOf(address(island));
        uint256 currentSail = sail.balanceOf(address(island));
        
        if (newUsdeBalance > currentUsde) {
            usde.mint(address(island), newUsdeBalance - currentUsde);
        } else if (newUsdeBalance < currentUsde) {
            vm.prank(address(island));
            usde.burn(currentUsde - newUsdeBalance);
        }
        
        if (newSailBalance > currentSail) {
            sail.mint(address(island), newSailBalance - currentSail);
        } else if (newSailBalance < currentSail) {
            vm.prank(address(island));
            sail.burn(currentSail - newSailBalance);
        }
    }
    
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
    
    /// @dev Trigger rebase and backstop if needed
    function _rebase(uint256 lpPrice) internal {
        vm.prank(admin);
        seniorVault.rebase(lpPrice);
    }
    
    // ============================================
    // SIMULATION SCENARIOS
    // ============================================
    
    /// @notice Scenario 1: SAIL pumps to 12 USDE (LP value increases)
    function test_Scenario1_SAILPump() public {
        _clearHistory();
        console.log("\n\n");
        console.log("==================================================");
        console.log("SCENARIO 1: SAIL PUMPS TO 12 USDE");
        console.log("==================================================");
        
        // Mint LP tokens to hooks (simulate deployed capital)
        lpToken.mint(address(seniorHook), 100_000e18);
        lpToken.mint(address(juniorHook), 100_000e18);
        lpToken.mint(address(reserveHook), 50_000e18);
        
        // Day 0: Initial state
        _logState(0, "Initial");
        
        // Day 1: SAIL starts pumping to 10.5 USDE
        vm.warp(block.timestamp + 1 days);
        _simulateTrade(10.5e18);
        _rebase(_getLPPrice());
        _logState(1, "SAIL pumps to 10.5");
        
        // Day 2: SAIL continues to 11 USDE
        vm.warp(block.timestamp + 1 days);
        _simulateTrade(11e18);
        _rebase(_getLPPrice());
        _logState(2, "SAIL reaches 11");
        
        // Day 3: SAIL peaks at 12 USDE
        vm.warp(block.timestamp + 1 days);
        _simulateTrade(12e18);
        _rebase(_getLPPrice());
        _logState(3, "SAIL peaks at 12");
        
        // Expected outcome: Senior backing ratio > 100%, Junior profits, Reserve untouched
        assertGt(seniorVault.backingRatio(), 100e18, "Senior should be over-collateralized");
        assertGt(juniorVault.unstakingRatio(), 100e18, "Junior should be profitable");
        assertEq(reserveVault.totalAssets(), RESERVE_SIZE, "Reserve should be untouched");
        
        console.log("[RESULT] SAIL pump scenario: All vaults healthy, Reserve untouched ");
        
        // Export results to JSON
        _exportToJson("scenario1_sail_pump");
    }
    
    /// @notice Scenario 2: SAIL dumps to 8 USDE (LP value decreases)
    function test_Scenario2_SAILDump() public {
        _clearHistory();
        console.log("\n\n");
        console.log("==================================================");
        console.log("SCENARIO 2: SAIL DUMPS TO 8 USDE");
        console.log("==================================================");
        
        // Mint LP tokens to hooks
        lpToken.mint(address(seniorHook), 100_000e18);
        lpToken.mint(address(juniorHook), 100_000e18);
        lpToken.mint(address(reserveHook), 50_000e18);
        
        _logState(0, "Initial");
        
        // Day 1: SAIL drops to 9.5 USDE
        vm.warp(block.timestamp + 1 days);
        _simulateTrade(9.5e18);
        _rebase(_getLPPrice());
        _logState(1, "SAIL drops to 9.5");
        
        // Day 2: SAIL continues down to 9 USDE
        vm.warp(block.timestamp + 1 days);
        _simulateTrade(9e18);
        _rebase(_getLPPrice());
        _logState(2, "SAIL falls to 9");
        
        // Day 3: SAIL dumps to 8 USDE
        vm.warp(block.timestamp + 1 days);
        _simulateTrade(8e18);
        _rebase(_getLPPrice());
        _logState(3, "SAIL dumps to 8");
        
        // Expected: Senior might need backstop, Junior takes first loss, Reserve might be tapped
        console.log("\n[RESULT] SAIL dump scenario: Backstop may activate, checking vault health...");
        
        if (seniorVault.backingRatio() < 100e18) {
            console.log("   Senior under-collateralized, backstop activated");
        }
        if (juniorVault.totalAssets() < JUNIOR_SIZE) {
            console.log("  Junior absorbed losses: $%s", (JUNIOR_SIZE - juniorVault.totalAssets()) / 1e18);
        }
        if (reserveVault.totalAssets() < RESERVE_SIZE) {
            console.log("  Reserve tapped: $%s used", (RESERVE_SIZE - reserveVault.totalAssets()) / 1e18);
        } else {
            console.log(" Reserve untouched");
        }
        
        _exportToJson("scenario2_sail_dump");
    }
    
    /// @notice Scenario 3: High volatility (SAIL swings 8-15 USDE)
    function test_Scenario3_HighVolatility() public {
        _clearHistory();
        console.log("\n\n");
        console.log("==================================================");
        console.log("SCENARIO 3: HIGH VOLATILITY (8-15 USDE SWINGS)");
        console.log("==================================================");
        
        lpToken.mint(address(seniorHook), 100_000e18);
        lpToken.mint(address(juniorHook), 100_000e18);
        lpToken.mint(address(reserveHook), 50_000e18);
        
        _logState(0, "Initial");
        
        uint256 initialReserve = reserveVault.totalAssets();
        
        // 7 days of chaos
        uint256[7] memory prices = [uint256(12e18), 8e18, 15e18, 9e18, 13e18, 8e18, 11e18];
        
        for (uint256 i = 0; i < 7; i++) {
            vm.warp(block.timestamp + 1 days);
            _simulateTrade(prices[i]);
            _rebase(_getLPPrice());
            _logState(i + 1, string(abi.encodePacked("Volatility day ", vm.toString(i + 1))));
        }
        
        console.log("\n[RESULT] High volatility scenario:");
        console.log("  Initial Reserve: $%s", initialReserve / 1e18);
        console.log("  Final Reserve: $%s", reserveVault.totalAssets() / 1e18);
        console.log("  Reserve Used: $%s", (initialReserve - reserveVault.totalAssets()) / 1e18);
        
        if (reserveVault.totalAssets() < initialReserve / 2) {
            console.log("  CRITICAL: Reserve depleted by >50%!");
        } else if (reserveVault.totalAssets() < initialReserve) {
            console.log("Reserve partially depleted");
        } else {
            console.log(" Reserve survived volatility");
        }
        
        _exportToJson("scenario3_high_volatility");
    }
    
    /// @notice Scenario 4: Gradual decline over 30 days (10 → 5 USDE)
    function test_Scenario4_GradualDecline() public {
        _clearHistory();
        console.log("\n\n");
        console.log("==================================================");
        console.log("SCENARIO 4: GRADUAL DECLINE (30 DAYS)");
        console.log("==================================================");
        
        lpToken.mint(address(seniorHook), 100_000e18);
        lpToken.mint(address(juniorHook), 100_000e18);
        lpToken.mint(address(reserveHook), 50_000e18);
        
        _logState(0, "Initial");
        
        uint256 initialReserve = reserveVault.totalAssets();
        uint256 initialJunior = juniorVault.totalAssets();
        
        // Simulate 30 days of slow bleed (10 → 5 USDE)
        for (uint256 day = 1; day <= 30; day++) {
            vm.warp(block.timestamp + 1 days);
            
            // Linear decline: price = 10 - (5 * day / 30)
            uint256 newPrice = 10e18 - ((5e18 * day) / 30);
            _simulateTrade(newPrice);
            _rebase(_getLPPrice());
            
            // Log every 5 days
            if (day % 5 == 0 || reserveVault.totalAssets() < 1000e18) {
                _logState(day, string(abi.encodePacked("Day ", vm.toString(day))));
            }
            
            // Check if Reserve is depleted
            if (reserveVault.totalAssets() < 1000e18) {
                console.log(" RESERVE DEPLETED ON DAY %s!", day);
                break;
            }
        }
        
        console.log("\n[RESULT] Gradual decline scenario:");
        console.log("  Days simulated: 30");
        console.log("  Initial Junior: $%s", initialJunior / 1e18);
        console.log("  Final Junior: $%s", juniorVault.totalAssets() / 1e18);
        console.log("  Junior Losses: $%s", (initialJunior - juniorVault.totalAssets()) / 1e18);
        console.log("  Initial Reserve: $%s", initialReserve / 1e18);
        console.log("  Final Reserve: $%s", reserveVault.totalAssets() / 1e18);
        console.log("  Reserve Used: $%s", (initialReserve - reserveVault.totalAssets()) / 1e18);
        
        if (reserveVault.totalAssets() < 1000e18) {
            console.log(" CRITICAL: Reserve fully depleted!");
        } else if (reserveVault.totalAssets() < initialReserve / 10) {
            console.log("WARNING: Reserve <10%% remaining");
        } else {
            console.log(" Reserve survived 30-day decline");
        }
        
        _exportToJson("scenario4_gradual_decline");
    }
    
    /// @notice Scenario 5: Black Swan (SAIL crashes to 2 USDE)
    function test_Scenario5_BlackSwan() public {
        _clearHistory();
        console.log("\n\n");
        console.log("==================================================");
        console.log("SCENARIO 5: BLACK SWAN (SAIL CRASHES TO 2 USDE)");
        console.log("==================================================");
        
        lpToken.mint(address(seniorHook), 100_000e18);
        lpToken.mint(address(juniorHook), 100_000e18);
        lpToken.mint(address(reserveHook), 50_000e18);
        
        _logState(0, "Initial");
        
        uint256 initialReserve = reserveVault.totalAssets();
        uint256 initialJunior = juniorVault.totalAssets();
        uint256 initialSenior = seniorVault.totalSupply();  // snrUSD supply
        
        // Sudden crash
        vm.warp(block.timestamp + 1 hours);
        _simulateTrade(2e18);
        _rebase(_getLPPrice());
        _logState(0, "BLACK SWAN EVENT");
        
        console.log("\n[RESULT] Black swan scenario:");
        console.log("SAIL price: 10 → 2 USDE (80%% crash)");
        console.log("  Junior wiped out: $%s → $%s", initialJunior / 1e18, juniorVault.totalAssets() / 1e18);
        console.log("  Reserve remaining: $%s / $%s", reserveVault.totalAssets() / 1e18, initialReserve / 1e18);
        console.log("  Senior backed: %s%%", seniorVault.backingRatio() / 1e16);
        
        if (seniorVault.backingRatio() < 100e18) {
            console.log("  Protocol insolvent - Reserve insufficient");
        } else {
            console.log("  ✅ Senior still fully backed (Reserve absorbed losses)");
        }
        
        _exportToJson("scenario5_black_swan");
    }
    
    /// @notice Scenario 6: Extended bear market with withdrawals
    function test_Scenario6_ExtendedBearMarket() public {
        _clearHistory();
        console.log("\n\n");
        console.log("==================================================");
        console.log("SCENARIO 6: EXTENDED BEAR + WITHDRAWALS");
        console.log("==================================================");
        
        lpToken.mint(address(seniorHook), 100_000e18);
        lpToken.mint(address(juniorHook), 100_000e18);
        lpToken.mint(address(reserveHook), 50_000e18);
        
        _logState(0, "Initial");
        
        uint256 initialReserve = reserveVault.totalAssets();
        uint256 daysDepleted = 0;
        
        // 60 days of bear market + 2% daily Senior withdrawals
        for (uint256 day = 1; day <= 60; day++) {
            vm.warp(block.timestamp + 1 days);
            
            // Gradual price decline: 10 → 6 USDE over 60 days
            uint256 newPrice = 10e18 - ((4e18 * day) / 60);
            _simulateTrade(newPrice);
            
            // Simulate 2% daily withdrawals from Senior
            uint256 seniorBalance = seniorVault.totalSupply();
            uint256 withdrawAmount = seniorBalance * 2 / 100;  // 2% daily
            
            if (withdrawAmount > 0 && withdrawAmount < seniorBalance) {
                vm.prank(user1);
                try seniorVault.withdraw(withdrawAmount, user1, user1) {} catch {}
            }
            
            _rebase(_getLPPrice());
            
            // Log every 10 days or when depleted
            if (day % 10 == 0 || (reserveVault.totalAssets() < 1000e18 && daysDepleted == 0)) {
                _logState(day, string(abi.encodePacked("Bear day ", vm.toString(day))));
            }
            
            // Check depletion
            if (reserveVault.totalAssets() < 1000e18 && daysDepleted == 0) {
                daysDepleted = day;
                console.log("\n🚨 RESERVE DEPLETED ON DAY %s!", day);
            }
        }
        
        console.log("\n[RESULT] Extended bear market scenario:");
        console.log("  Duration: 60 days");
        console.log("  SAIL price: 10 → 6 USDE (40%% decline)");
        console.log("  Daily withdrawals: 2%% of Senior");
        console.log("  Initial Reserve: $%s", initialReserve / 1e18);
        console.log("  Final Reserve: $%s", reserveVault.totalAssets() / 1e18);
        
        if (daysDepleted > 0) {
            console.log("  🚨 Reserve depleted on day %s", daysDepleted);
            console.log("  💀 Protocol survival: %s days", daysDepleted);
        } else {
            console.log("  ✅ Reserve survived 60-day bear market!");
        }
        
        _exportToJson("scenario6_extended_bear_market");
    }
}

/**
 * @dev Mock Kodiak Island for simulation
 * Simulates an AMM pool with token0/token1 reserves
 */
contract MockKodiakIsland {
    address public token0;
    address public token1;
    address public lpToken;
    
    constructor(address _token0, address _token1, address _lpToken) {
        token0 = _token0;
        token1 = _token1;
        lpToken = _lpToken;
    }
    
    function getReserves() external view returns (uint256 reserve0, uint256 reserve1) {
        reserve0 = MockERC20(token0).balanceOf(address(this));
        reserve1 = MockERC20(token1).balanceOf(address(this));
    }
}

