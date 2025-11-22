// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./RebaseSimulation.t.sol";

/**
 * @title SimulationScenarios
 * @notice Various market scenarios for rebase simulation
 * @dev Run these to generate comprehensive time-series data
 */
contract SimulationScenarios is RebaseSimulation {
    
    /**
     * @notice Scenario 1: Moderate Bull Market - SAIL $10 → $16 (realistic)
     * Simulates steady growth with minor pullbacks
     */
    function test_Scenario1_BullMarket() public {
        console.log("\n======================================");
        console.log("SCENARIO 1: MODERATE BULL MARKET");
        console.log("SAIL: $10 -> $16 (realistic range)");
        console.log("WITH USER ACTIONS");
        console.log("======================================\n");
        
        // Initial user positions (day 1)
        simulateDeposit(WHALE_1, "SENIOR", 50_000e18, "Whale 1 initial Senior position");
        simulateDeposit(WHALE_2, "JUNIOR", 30_000e18, "Whale 2 initial Junior position");
        simulateDeposit(RETAIL_1, "SENIOR", 5_000e18, "Retail 1 initial Senior position");
        simulateDeposit(RETAIL_2, "RESERVE", 10_000e18, "Retail 2 initial Reserve position (SAIL)");
        
        // Month 1: +3% (buy 3K SAIL) - $10 → $10.30
        simulateTradeWithUser(WHALE_1, -3_000e18, "Whale 1 buying SAIL (bullish)");
        simulateDeposit(RETAIL_3, "SENIOR", 2_000e18, "Retail 3 entering Senior vault");
        executeRebase();
        
        // Month 2: +4% (buy 4K SAIL) - $10.30 → $10.71
        simulateTradeWithUser(WHALE_2, -4_000e18, "Whale 2 accumulating SAIL");
        simulateDeposit(RETAIL_1, "JUNIOR", 3_000e18, "Retail 1 adding to Junior for higher yield");
        executeRebase();
        
        // Month 3: -2% pullback (sell 2K SAIL) - $10.71 → $10.49
        simulateTradeWithUser(RETAIL_2, 2_000e18, "Retail 2 taking profit");
        executeRebase();
        
        // Month 4: +5% (buy 5K SAIL) - $10.49 → $11.02
        simulateTradeWithUser(WHALE_1, -5_000e18, "Whale 1 buying the dip");
        simulateDeposit(WHALE_1, "SENIOR", 10_000e18, "Whale 1 increasing Senior position");
        executeRebase();
        
        // Month 5: +6% (buy 6K SAIL) - $11.02 → $11.68
        simulateTradeWithUser(WHALE_2, -6_000e18, "Whale 2 aggressive buy");
        simulateDeposit(RETAIL_3, "JUNIOR", 1_500e18, "Retail 3 diversifying to Junior");
        executeRebase();
        
        // Month 6: -3% correction (sell 3K SAIL) - $11.68 → $11.33
        simulateTradeWithUser(RETAIL_1, 3_000e18, "Retail 1 profit taking");
        simulateWithdraw(RETAIL_2, "RESERVE", 2_000e18, "Retail 2 partial exit");
        executeRebase();
        
        // Month 7: +7% rally (buy 7K SAIL) - $11.33 → $12.12
        simulateTradeWithUser(WHALE_1, -7_000e18, "Whale 1 all in on rally");
        simulateDeposit(RETAIL_2, "SENIOR", 5_000e18, "Retail 2 re-entering Senior");
        executeRebase();
        
        // Month 8: +5% (buy 5K SAIL) - $12.12 → $12.73
        simulateTradeWithUser(WHALE_2, -5_000e18, "Whale 2 continuing accumulation");
        executeRebase();
        
        // Month 9: -2% consolidation (sell 2K SAIL) - $12.73 → $12.47
        simulateTradeWithUser(RETAIL_3, 2_000e18, "Retail 3 taking chips off table");
        executeRebase();
        
        // Month 10: +8% surge (buy 8K SAIL) - $12.47 → $13.47
        simulateTradeWithUser(WHALE_1, -8_000e18, "Whale 1 euphoria buy");
        simulateDeposit(WHALE_2, "JUNIOR", 15_000e18, "Whale 2 max leverage in Junior");
        executeRebase();
        
        // Month 11: +10% final push (buy 10K SAIL) - $13.47 → $14.82
        simulateTradeWithUser(WHALE_2, -10_000e18, "Whale 2 FOMO buying");
        simulateDeposit(RETAIL_1, "SENIOR", 8_000e18, "Retail 1 chasing gains");
        executeRebase();
        
        // Month 12: +8% peak (buy 8K SAIL) - $14.82 → $16.00
        simulateTradeWithUser(WHALE_1, -8_000e18, "Whale 1 top signal");
        simulateWithdraw(WHALE_2, "JUNIOR", 5_000e18, "Whale 2 taking profit at top");
        executeRebase();
        
        // Export vault snapshots to JSON
        string memory json = exportToJSON();
        vm.writeFile("./simulation_output/scenario1_bull_market.json", json);
        
        // Export user actions to separate JSON file
        string memory userJson = exportUserActionsToJSON();
        vm.writeFile("./simulation_output/scenario1_user_actions.json", userJson);
        
        // Print fee summary
        (uint256 totalMgmt, uint256 totalPerf, uint256 cumulative, uint256 avgYieldBps) = getFeeSummary();
        console.log("\n=== FEE SUMMARY ===");
        console.log("Total Management Fees:", totalMgmt / 1e18);
        console.log("Total Performance Fees:", totalPerf / 1e18);
        console.log("Cumulative Fees:", cumulative / 1e18);
        console.log("Average Fee Yield (BPS):", avgYieldBps);
        console.log("Total User Actions:", getUserActionCount());
        
        console.log("\nScenario 1 complete.");
        console.log("  Snapshots: simulation_output/scenario1_bull_market.json");
        console.log("  User Actions: simulation_output/scenario1_user_actions.json\n");
    }
    
    /**
     * @notice Scenario 2: Moderate Bear Market - SAIL $10 → $6 (realistic)
     * Simulates gradual decline with relief rallies
     */
    function test_Scenario2_BearMarket() public {
        console.log("\n======================================");
        console.log("SCENARIO 2: MODERATE BEAR MARKET");
        console.log("SAIL: $10 -> $6 (realistic range)");
        console.log("WITH USER PANIC & CAPITULATION");
        console.log("======================================\n");
        
        // Initial positions
        simulateDeposit(WHALE_1, "SENIOR", 100_000e18, "Whale 1 large Senior position");
        simulateDeposit(WHALE_2, "JUNIOR", 50_000e18, "Whale 2 Junior position");
        simulateDeposit(RETAIL_1, "SENIOR", 10_000e18, "Retail 1 in Senior");
        simulateDeposit(RETAIL_2, "JUNIOR", 5_000e18, "Retail 2 in Junior");
        simulateDeposit(RETAIL_3, "RESERVE", 8_000e18, "Retail 3 in Reserve (SAIL)");
        
        // Month 1: -5% (sell 5K SAIL) - $10 → $9.50
        simulateTradeWithUser(RETAIL_1, 5_000e18, "Retail 1 selling SAIL (bearish)");
        simulateWithdraw(RETAIL_2, "JUNIOR", 1_000e18, "Retail 2 nervous exit");
        executeRebase();
        
        // Month 2: -6% (sell 6K SAIL) - $9.50 → $8.93
        simulateTradeWithUser(WHALE_2, 6_000e18, "Whale 2 panic selling");
        simulateWithdraw(RETAIL_1, "SENIOR", 3_000e18, "Retail 1 fear exit");
        executeRebase();
        
        // Month 3: +3% relief rally (buy 3K SAIL) - $8.93 → $9.20
        simulateTradeWithUser(WHALE_1, -3_000e18, "Whale 1 buying the dip");
        executeRebase();
        
        // Month 4: -7% selloff (sell 7K SAIL) - $9.20 → $8.56
        simulateTradeWithUser(RETAIL_2, 7_000e18, "Retail 2 capitulation");
        simulateWithdraw(WHALE_2, "JUNIOR", 10_000e18, "Whale 2 cutting losses");
        executeRebase();
        
        // Month 5: -4% (sell 4K SAIL) - $8.56 → $8.22
        simulateTradeWithUser(RETAIL_3, 4_000e18, "Retail 3 panic sell");
        executeRebase();
        
        // Month 6: +2% dead cat bounce (buy 2K SAIL) - $8.22 → $8.38
        simulateTrade(-2_000e18, 200);
        executeRebase();
        
        // Month 7: -8% capitulation (sell 8K SAIL) - $8.38 → $7.71
        simulateTradeWithUser(WHALE_2, 8_000e18, "Whale 2 full capitulation");
        simulateWithdraw(RETAIL_2, "JUNIOR", 2_000e18, "Retail 2 exit");
        executeRebase();
        
        // Month 8: -5% (sell 5K SAIL) - $7.71 → $7.32
        simulateTradeWithUser(RETAIL_1, 5_000e18, "Retail 1 giving up");
        executeRebase();
        
        // Month 9: +4% relief (buy 4K SAIL) - $7.32 → $7.61
        simulateTradeWithUser(WHALE_1, -4_000e18, "Whale 1 brave dip buy");
        simulateDeposit(WHALE_1, "SENIOR", 20_000e18, "Whale 1 accumulating at bottom");
        executeRebase();
        
        // Month 10: -6% (sell 6K SAIL) - $7.61 → $7.15
        simulateTradeWithUser(RETAIL_3, 6_000e18, "Retail 3 final sell");
        simulateWithdraw(RETAIL_3, "RESERVE", 3_000e18, "Retail 3 full exit");
        executeRebase();
        
        // Month 11: -8% final leg down (sell 8K SAIL) - $7.15 → $6.58
        simulateTradeWithUser(RETAIL_2, 8_000e18, "Retail 2 selling at bottom");
        executeRebase();
        
        // Month 12: -4% bottom (sell 4K SAIL) - $6.58 → $6.32
        simulateTradeWithUser(WHALE_2, 4_000e18, "Whale 2 final capitulation");
        simulateDeposit(WHALE_1, "JUNIOR", 30_000e18, "Whale 1 contrarian bet at bottom");
        executeRebase();
        
        // Export vault snapshots to JSON
        string memory json = exportToJSON();
        vm.writeFile("./simulation_output/scenario2_bear_market.json", json);
        
        // Export user actions to separate JSON file
        string memory userJson = exportUserActionsToJSON();
        vm.writeFile("./simulation_output/scenario2_user_actions.json", userJson);
        
        // Print fee summary
        (uint256 totalMgmt, uint256 totalPerf, uint256 cumulative, uint256 avgYieldBps) = getFeeSummary();
        console.log("\n=== FEE SUMMARY ===");
        console.log("Total Management Fees:", totalMgmt / 1e18);
        console.log("Total Performance Fees:", totalPerf / 1e18);
        console.log("Cumulative Fees:", cumulative / 1e18);
        console.log("Average Fee Yield (BPS):", avgYieldBps);
        console.log("Total User Actions:", getUserActionCount());
        
        console.log("\nScenario 2 complete.");
        console.log("  Snapshots: simulation_output/scenario2_bear_market.json");
        console.log("  User Actions: simulation_output/scenario2_user_actions.json\n");
    }
    
    /**
     * @notice Scenario 3: Choppy/Volatile Market - SAIL $8-$13 range
     * Simulates high volatility with frequent reversals (realistic)
     */
    function test_Scenario3_VolatileMarket() public {
        console.log("\n======================================");
        console.log("SCENARIO 3: CHOPPY/VOLATILE MARKET");
        console.log("SAIL: $8-$13 range (realistic volatility)");
        console.log("======================================\n");
        
        // Month 1: +8% rally (buy 8K) - $10 → $10.80
        simulateTrade(-8_000e18, 800);
        executeRebase();
        
        // Month 2: -12% dump (sell 12K) - $10.80 → $9.50
        simulateTrade(12_000e18, -1200);
        executeRebase();
        
        // Month 3: +15% pump (buy 15K) - $9.50 → $10.93
        simulateTrade(-15_000e18, 1500);
        executeRebase();
        
        // Month 4: -8% sell (sell 8K) - $10.93 → $10.05
        simulateTrade(8_000e18, -800);
        executeRebase();
        
        // Month 5: +12% recovery (buy 12K) - $10.05 → $11.26
        simulateTrade(-12_000e18, 1200);
        executeRebase();
        
        // Month 6: -5% dip (sell 5K) - $11.26 → $10.70
        simulateTrade(5_000e18, -500);
        executeRebase();
        
        // Month 7: +10% breakout (buy 10K) - $10.70 → $11.77
        simulateTrade(-10_000e18, 1000);
        executeRebase();
        
        // Month 8: -15% crash (sell 15K) - $11.77 → $10.00
        simulateTrade(15_000e18, -1500);
        executeRebase();
        
        // Month 9: +18% v-shape (buy 18K) - $10.00 → $11.80
        simulateTrade(-18_000e18, 1800);
        executeRebase();
        
        // Month 10: -7% pullback (sell 7K) - $11.80 → $10.97
        simulateTrade(7_000e18, -700);
        executeRebase();
        
        // Month 11: +9% push (buy 9K) - $10.97 → $11.96
        simulateTrade(-9_000e18, 900);
        executeRebase();
        
        // Month 12: -5% fade (sell 5K) - $11.96 → $11.36
        simulateTrade(5_000e18, -500);
        executeRebase();
        
        // Export to JSON
        string memory json = exportToJSON();
        vm.writeFile("./simulation_output/scenario3_volatile_market.json", json);
        
        console.log("Scenario 3 complete. Output: simulation_output/scenario3_volatile_market.json\n");
    }
    
    /**
     * @notice Scenario 4: Sideways/Stable Market - SAIL $9-$11 range
     * Simulates low volatility consolidation (realistic)
     */
    function test_Scenario4_StableMarket() public {
        console.log("\n======================================");
        console.log("SCENARIO 4: SIDEWAYS/STABLE MARKET");
        console.log("SAIL: $9-$11 range (realistic consolidation)");
        console.log("======================================\n");
        
        // Month 1: +2% (buy 2K) - $10 → $10.20
        simulateTrade(-2_000e18, 200);
        executeRebase();
        
        // Month 2: -3% (sell 3K) - $10.20 → $9.89
        simulateTrade(3_000e18, -300);
        executeRebase();
        
        // Month 3: +2.5% (buy 2.5K) - $9.89 → $10.14
        simulateTrade(-2_500e18, 250);
        executeRebase();
        
        // Month 4: -1% (sell 1K) - $10.14 → $10.04
        simulateTrade(1_000e18, -100);
        executeRebase();
        
        // Month 5: +3% (buy 3K) - $10.04 → $10.34
        simulateTrade(-3_000e18, 300);
        executeRebase();
        
        // Month 6: -2% (sell 2K) - $10.34 → $10.13
        simulateTrade(2_000e18, -200);
        executeRebase();
        
        // Month 7: +1.5% (buy 1.5K) - $10.13 → $10.28
        simulateTrade(-1_500e18, 150);
        executeRebase();
        
        // Month 8: -2.5% (sell 2.5K) - $10.28 → $10.02
        simulateTrade(2_500e18, -250);
        executeRebase();
        
        // Month 9: +4% (buy 4K) - $10.02 → $10.42
        simulateTrade(-4_000e18, 400);
        executeRebase();
        
        // Month 10: -3% (sell 3K) - $10.42 → $10.11
        simulateTrade(3_000e18, -300);
        executeRebase();
        
        // Month 11: +2% (buy 2K) - $10.11 → $10.31
        simulateTrade(-2_000e18, 200);
        executeRebase();
        
        // Month 12: -1.5% (sell 1.5K) - $10.31 → $10.16
        simulateTrade(1_500e18, -150);
        executeRebase();
        
        // Export to JSON
        string memory json = exportToJSON();
        vm.writeFile("./simulation_output/scenario4_stable_market.json", json);
        
        console.log("\nScenario 4 complete. Output: simulation_output/scenario4_stable_market.json\n");
    }
    
    /**
     * @notice Scenario 5: Flash Crash Recovery - SAIL $10 → $6.50 → $11.50 (realistic)
     * Simulates sudden crash followed by gradual recovery
     */
    function test_Scenario5_FlashCrashRecovery() public {
        console.log("\n======================================");
        console.log("SCENARIO 5: FLASH CRASH & RECOVERY");
        console.log("SAIL: $10 -> $6.50 -> $11.50 (realistic)");
        console.log("======================================\n");
        
        // Month 1: +3% normal (buy 3K) - $10 → $10.30
        simulateTrade(-3_000e18, 300);
        executeRebase();
        
        // Month 2: +4% normal (buy 4K) - $10.30 → $10.71
        simulateTrade(-4_000e18, 400);
        executeRebase();
        
        // Month 3: +2% normal (buy 2K) - $10.71 → $10.93
        simulateTrade(-2_000e18, 200);
        executeRebase();
        
        // Month 4: -20% FLASH CRASH (sell 20K) - $10.93 → $8.74
        simulateTrade(20_000e18, -2000);
        executeRebase();
        
        // Month 5: -12% panic continues (sell 12K) - $8.74 → $7.69
        simulateTrade(12_000e18, -1200);
        executeRebase();
        
        // Month 6: -8% capitulation (sell 8K) - $7.69 → $7.08
        simulateTrade(8_000e18, -800);
        executeRebase();
        
        // Month 7: +6% relief bounce (buy 6K) - $7.08 → $7.50
        simulateTrade(-6_000e18, 600);
        executeRebase();
        
        // Month 8: +10% recovery starts (buy 10K) - $7.50 → $8.25
        simulateTrade(-10_000e18, 1000);
        executeRebase();
        
        // Month 9: +12% momentum (buy 12K) - $8.25 → $9.24
        simulateTrade(-12_000e18, 1200);
        executeRebase();
        
        // Month 10: +10% strong recovery (buy 10K) - $9.24 → $10.16
        simulateTrade(-10_000e18, 1000);
        executeRebase();
        
        // Month 11: +8% (buy 8K) - $10.16 → $10.97
        simulateTrade(-8_000e18, 800);
        executeRebase();
        
        // Month 12: +6% final push (buy 6K) - $10.97 → $11.63
        simulateTrade(-6_000e18, 600);
        executeRebase();
        
        // Export to JSON
        string memory json = exportToJSON();
        vm.writeFile("./simulation_output/scenario5_flash_crash_recovery.json", json);
        
        console.log("\nScenario 5 complete. Output: simulation_output/scenario5_flash_crash_recovery.json\n");
    }
    
    /**
     * @notice Scenario 6: Slow Bleed - SAIL $10 → $7 (realistic)
     * Gradual decline with small relief rallies over 12 months
     */
    function test_Scenario6_SlowBleed_24Months() public {
        console.log("\n======================================");
        console.log("SCENARIO 6: SLOW BLEED");
        console.log("SAIL: $10 -> $7 with relief rallies (realistic)");
        console.log("======================================\n");
        
        // Month 1: -4% (sell 4K) - $10 → $9.60
        simulateTrade(4_000e18, -400);
        executeRebase();
        
        // Month 2: -5% (sell 5K) - $9.60 → $9.12
        simulateTrade(5_000e18, -500);
        executeRebase();
        
        // Month 3: +2% relief (buy 2K) - $9.12 → $9.30
        simulateTrade(-2_000e18, 200);
        executeRebase();
        
        // Month 4: -6% (sell 6K) - $9.30 → $8.74
        simulateTrade(6_000e18, -600);
        executeRebase();
        
        // Month 5: -4% (sell 4K) - $8.74 → $8.39
        simulateTrade(4_000e18, -400);
        executeRebase();
        
        // Month 6: +3% relief (buy 3K) - $8.39 → $8.64
        simulateTrade(-3_000e18, 300);
        executeRebase();
        
        // Month 7: -5% (sell 5K) - $8.64 → $8.21
        simulateTrade(5_000e18, -500);
        executeRebase();
        
        // Month 8: -4% (sell 4K) - $8.21 → $7.88
        simulateTrade(4_000e18, -400);
        executeRebase();
        
        // Month 9: +2% relief (buy 2K) - $7.88 → $8.04
        simulateTrade(-2_000e18, 200);
        executeRebase();
        
        // Month 10: -6% (sell 6K) - $8.04 → $7.56
        simulateTrade(6_000e18, -600);
        executeRebase();
        
        // Month 11: -4% (sell 4K) - $7.56 → $7.26
        simulateTrade(4_000e18, -400);
        executeRebase();
        
        // Month 12: +1% weak bounce (buy 1K) - $7.26 → $7.33
        simulateTrade(-1_000e18, 100);
        executeRebase();
        
        // Export to JSON
        string memory json = exportToJSON();
        vm.writeFile("./simulation_output/scenario6_slow_bleed_24m.json", json);
        
        console.log("\nScenario 6 complete. Output: simulation_output/scenario6_slow_bleed_24m.json\n");
    }
    
    /**
     * @notice Scenario 7: Strong Bull Run - SAIL $10 → $18 (realistic)
     * Strong uptrend with healthy corrections
     */
    function test_Scenario7_ParabolicBullRun() public {
        console.log("\n======================================");
        console.log("SCENARIO 7: STRONG BULL RUN");
        console.log("SAIL: $10 -> $18 (realistic)");
        console.log("======================================\n");
        
        // Month 1: +5% (buy 5K) - $10 → $10.50
        simulateTrade(-5_000e18, 500);
        executeRebase();
        
        // Month 2: +6% (buy 6K) - $10.50 → $11.13
        simulateTrade(-6_000e18, 600);
        executeRebase();
        
        // Month 3: +8% acceleration (buy 8K) - $11.13 → $12.02
        simulateTrade(-8_000e18, 800);
        executeRebase();
        
        // Month 4: -4% healthy correction (sell 4K) - $12.02 → $11.54
        simulateTrade(4_000e18, -400);
        executeRebase();
        
        // Month 5: +10% strong rally (buy 10K) - $11.54 → $12.69
        simulateTrade(-10_000e18, 1000);
        executeRebase();
        
        // Month 6: +12% momentum (buy 12K) - $12.69 → $14.21
        simulateTrade(-12_000e18, 1200);
        executeRebase();
        
        // Month 7: -5% pullback (sell 5K) - $14.21 → $13.50
        simulateTrade(5_000e18, -500);
        executeRebase();
        
        // Month 8: +10% resumption (buy 10K) - $13.50 → $14.85
        simulateTrade(-10_000e18, 1000);
        executeRebase();
        
        // Month 9: +12% strong (buy 12K) - $14.85 → $16.63
        simulateTrade(-12_000e18, 1200);
        executeRebase();
        
        // Month 10: +8% (buy 8K) - $16.63 → $17.96
        simulateTrade(-8_000e18, 800);
        executeRebase();
        
        // Month 11: -3% consolidation (sell 3K) - $17.96 → $17.42
        simulateTrade(3_000e18, -300);
        executeRebase();
        
        // Month 12: +5% final push (buy 5K) - $17.42 → $18.29
        simulateTrade(-5_000e18, 500);
        executeRebase();
        
        // Export to JSON
        string memory json = exportToJSON();
        vm.writeFile("./simulation_output/scenario7_parabolic_bull.json", json);
        
        console.log("\nScenario 7 complete. Output: simulation_output/scenario7_parabolic_bull.json\n");
    }
    
    /**
     * @notice Run all scenarios
     */
    function test_RunAllScenarios() public {
        console.log("Running all simulation scenarios...");
        
        // Create output directory
        string[] memory inputs = new string[](3);
        inputs[0] = "mkdir";
        inputs[1] = "-p";
        inputs[2] = "./simulation_output";
        vm.ffi(inputs);
        
        // Run each scenario
        test_Scenario1_BullMarket();
        setUp(); // Reset
        test_Scenario2_BearMarket();
        setUp(); // Reset
        test_Scenario3_VolatileMarket();
        setUp(); // Reset
        test_Scenario4_StableMarket();
        setUp(); // Reset
        test_Scenario5_FlashCrashRecovery();
        setUp(); // Reset
        test_Scenario6_SlowBleed_24Months();
        setUp(); // Reset
        test_Scenario7_ParabolicBullRun();
        
        console.log("\nALL SCENARIOS COMPLETE!");
        console.log("JSON files saved in: ./simulation_output/\n");
    }
}

