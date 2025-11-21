// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {MathLib} from "../../src/libraries/MathLib.sol";
import {RebaseLib} from "../../src/libraries/RebaseLib.sol";
import {SpilloverLib} from "../../src/libraries/SpilloverLib.sol";
import {FeeLib} from "../../src/libraries/FeeLib.sol";

/**
 * @title RebaseSimulation
 * @notice Simulates price changes in SAIL/USDE pool and their effects on vault rebases
 * @dev Generates comprehensive time-series JSON data
 * 
 * Initial Setup:
 * - Pool: 1M USDE + 100K SAIL (SAIL = $10)
 * - LP Token Price: ~$6.32
 * - Senior: $1.5M in LP tokens
 * - Junior: $1.5M in LP tokens
 * - Reserve: $750K in SAIL tokens (NOT LP, just SAIL)
 */
contract RebaseSimulation is Test {
    using MathLib for uint256;
    
    // ============================================
    // State Variables
    // ============================================
    
    /// @dev Pool state (Constant Product AMM: x * y = k)
    struct PoolState {
        uint256 usdeReserve;     // Amount of USDE in pool
        uint256 sailReserve;     // Amount of SAIL in pool
        uint256 k;               // Constant product
        uint256 totalLPSupply;   // Total LP tokens issued
        uint256 sailPrice;       // SAIL price in USDE (18 decimals)
        uint256 lpTokenPrice;    // LP token price in USD (18 decimals)
    }
    
    /// @dev Vault state
    struct VaultState {
        // Senior vault
        uint256 seniorLPAmount;        // LP tokens held
        uint256 seniorValue;           // USD value
        uint256 seniorSupply;          // snrUSD supply
        uint256 seniorShares;          // Total shares
        uint256 seniorRebaseIndex;     // Rebase index
        uint256 seniorBackingRatio;    // Backing ratio (18 decimals)
        uint8 seniorAPY;               // Selected APY tier (1=11%, 2=12%, 3=13%)
        
        // Junior vault
        uint256 juniorLPAmount;        // LP tokens held
        uint256 juniorValue;           // USD value
        uint256 juniorShares;          // ERC4626 shares
        
        // Reserve vault
        uint256 reserveSailAmount;     // SAIL tokens held (NOT LP!)
        uint256 reserveValue;          // USD value
        uint256 reserveShares;         // ERC4626 shares
    }
    
    /// @dev Snapshot for time-series tracking
    struct Snapshot {
        uint256 timestamp;
        uint256 epoch;
        PoolState pool;
        VaultState vaults;
        string zone;                   // "SPILLOVER", "HEALTHY", "BACKSTOP"
        uint256 spilloverToJunior;     // Amount spilled to Junior this epoch
        uint256 spilloverToReserve;    // Amount spilled to Reserve this epoch
        uint256 backstopFromReserve;   // Amount from Reserve this epoch
        uint256 backstopFromJunior;    // Amount from Junior this epoch
        int256 sailPriceChange;        // % change from previous (in BPS)
        int256 lpPriceChange;          // % change from previous (in BPS)
    }
    
    // Current state
    PoolState public pool;
    VaultState public vaults;
    
    // Time-series data
    Snapshot[] public snapshots;
    uint256 public currentEpoch;
    uint256 public startTime;
    
    // Constants
    uint256 constant INITIAL_USDE = 1_000_000e18;      // 1M USDE
    uint256 constant INITIAL_SAIL = 100_000e18;        // 100K SAIL
    uint256 constant INITIAL_SENIOR_VALUE = 1_500_000e18;  // $1.5M
    uint256 constant INITIAL_JUNIOR_VALUE = 1_500_000e18;  // $1.5M
    uint256 constant INITIAL_RESERVE_SAIL = 75_000e18;     // 75K SAIL = $750K at $10
    
    uint256 constant REBASE_INTERVAL = 30 days;
    
    // ============================================
    // Setup
    // ============================================
    
    function setUp() public {
        startTime = block.timestamp;
        currentEpoch = 0;
        
        // Initialize pool (Constant Product AMM)
        pool.usdeReserve = INITIAL_USDE;
        pool.sailReserve = INITIAL_SAIL;
        pool.k = pool.usdeReserve * pool.sailReserve;
        
        // Calculate initial SAIL price: 1M USDE / 100K SAIL = 10 USDE/SAIL
        pool.sailPrice = (pool.usdeReserve * 1e18) / pool.sailReserve;
        
        // Calculate pool TVL and LP token price
        uint256 poolTVL = pool.usdeReserve + (pool.sailReserve * pool.sailPrice / 1e18);
        
        // For initial mint, LP supply = sqrt(usde * sail)
        pool.totalLPSupply = sqrt(pool.usdeReserve * pool.sailReserve);
        pool.lpTokenPrice = (poolTVL * 1e18) / pool.totalLPSupply;
        
        console.log("Initial Pool State:");
        console.log("  USDE Reserve:", pool.usdeReserve / 1e18);
        console.log("  SAIL Reserve:", pool.sailReserve / 1e18);
        console.log("  SAIL Price:", pool.sailPrice / 1e18);
        console.log("  LP Token Price:", pool.lpTokenPrice / 1e18);
        console.log("  Total LP Supply:", pool.totalLPSupply / 1e18);
        
        // Initialize Senior vault
        vaults.seniorLPAmount = (INITIAL_SENIOR_VALUE * 1e18) / pool.lpTokenPrice;
        vaults.seniorValue = INITIAL_SENIOR_VALUE;
        vaults.seniorSupply = INITIAL_SENIOR_VALUE; // 1:1 initial mint
        vaults.seniorShares = INITIAL_SENIOR_VALUE; // Initial shares = supply
        vaults.seniorRebaseIndex = MathLib.PRECISION; // 1.0
        vaults.seniorBackingRatio = MathLib.PRECISION; // 100%
        vaults.seniorAPY = 0; // No rebase yet
        
        // Initialize Junior vault
        vaults.juniorLPAmount = (INITIAL_JUNIOR_VALUE * 1e18) / pool.lpTokenPrice;
        vaults.juniorValue = INITIAL_JUNIOR_VALUE;
        vaults.juniorShares = INITIAL_JUNIOR_VALUE; // 1:1 initial mint
        
        // Initialize Reserve vault (holds SAIL, NOT LP!)
        vaults.reserveSailAmount = INITIAL_RESERVE_SAIL;
        vaults.reserveValue = (INITIAL_RESERVE_SAIL * pool.sailPrice) / 1e18;
        vaults.reserveShares = vaults.reserveValue; // 1:1 initial mint
        
        console.log("\nInitial Vault States:");
        console.log("  Senior LP Amount:", vaults.seniorLPAmount / 1e18);
        console.log("  Senior Value:", vaults.seniorValue / 1e18);
        console.log("  Senior Supply:", vaults.seniorSupply / 1e18);
        console.log("  Junior LP Amount:", vaults.juniorLPAmount / 1e18);
        console.log("  Junior Value:", vaults.juniorValue / 1e18);
        console.log("  Reserve SAIL Amount:", vaults.reserveSailAmount / 1e18);
        console.log("  Reserve Value:", vaults.reserveValue / 1e18);
        
        // Take initial snapshot (initial backing ratio is 100%, no price change yet)
        _takeSnapshot(vaults.seniorBackingRatio, 0, 0, 0, 0, 0);
    }
    
    // ============================================
    // Simulation Functions
    // ============================================
    
    /**
     * @notice Simulate a trade in the pool (changes SAIL price)
     * @param sailAmountIn Amount of SAIL to sell (negative = buy SAIL with USDE)
     */
    function simulateTrade(int256 sailAmountIn, int256 /* priceImpactBps */) public {
        if (sailAmountIn > 0) {
            // Sell SAIL for USDE (SAIL price decreases)
            uint256 sailIn = uint256(sailAmountIn);
            // Safety: don't allow trades that would deplete reserves too much
            if (sailIn > pool.sailReserve / 2) {
                sailIn = pool.sailReserve / 2; // Max 50% of reserve
            }
            
            uint256 newSailReserve = pool.sailReserve + sailIn;
            uint256 newUsdeReserve = pool.k / newSailReserve;
            
            pool.sailReserve = newSailReserve;
            pool.usdeReserve = newUsdeReserve;
        } else if (sailAmountIn < 0) {
            // Buy SAIL with USDE (SAIL price increases)
            uint256 sailOut = uint256(-sailAmountIn);
            // Safety: don't allow trades that would deplete reserves too much
            if (sailOut > pool.sailReserve / 3) {
                sailOut = pool.sailReserve / 3; // Max 33% of reserve
            }
            if (sailOut >= pool.sailReserve) {
                sailOut = pool.sailReserve - 1e18; // Leave at least 1 SAIL
            }
            
            uint256 newSailReserve = pool.sailReserve - sailOut;
            uint256 newUsdeReserve = pool.k / newSailReserve;
            
            pool.sailReserve = newSailReserve;
            pool.usdeReserve = newUsdeReserve;
        }
        
        // Update prices with safety checks
        pool.sailPrice = (pool.usdeReserve * 1e18) / pool.sailReserve;
        
        // Cap SAIL price at reasonable maximum (1000x initial = $10,000)
        uint256 maxSailPrice = 10_000e18;
        if (pool.sailPrice > maxSailPrice) {
            pool.sailPrice = maxSailPrice;
        }
        
        uint256 poolTVL = pool.usdeReserve + (pool.sailReserve * pool.sailPrice / 1e18);
        pool.lpTokenPrice = (poolTVL * 1e18) / pool.totalLPSupply;
        
        // Update vault values based on new LP price (with bounds)
        vaults.seniorValue = (vaults.seniorLPAmount * pool.lpTokenPrice) / 1e18;
        vaults.juniorValue = (vaults.juniorLPAmount * pool.lpTokenPrice) / 1e18;
        
        // Reserve value based on SAIL holdings
        uint256 reserveValueFromSail = (vaults.reserveSailAmount * pool.sailPrice) / 1e18;
        // Cap reserve value to prevent overflow
        vaults.reserveValue = reserveValueFromSail > 100_000_000e18 ? 100_000_000e18 : reserveValueFromSail;
        
        // Update backing ratio (with safety check)
        if (vaults.seniorSupply > 0) {
            vaults.seniorBackingRatio = MathLib.calculateBackingRatio(vaults.seniorValue, vaults.seniorSupply);
        }
        
        console.log("\nTrade Executed - SAIL Amount:", uint256(sailAmountIn >= 0 ? sailAmountIn : -sailAmountIn) / 1e18);
        console.log("  New SAIL Price:", pool.sailPrice / 1e18);
        console.log("  New LP Price:", pool.lpTokenPrice / 1e18);
        console.log("  Senior Backing Ratio:", vaults.seniorBackingRatio * 100 / 1e18);
    }
    
    /**
     * @notice Execute monthly rebase following math spec
     */
    function executeRebase() public {
        console.log("\n========== EXECUTING REBASE ==========");
        console.log("Epoch:", currentEpoch + 1);
        console.log("Current Backing Ratio:", vaults.seniorBackingRatio * 100 / 1e18, "%");
        
        // Move time forward
        vm.warp(block.timestamp + REBASE_INTERVAL);
        
        // Step 1: Calculate management fee tokens to mint
        uint256 mgmtFeeTokens = FeeLib.calculateManagementFeeTokens(vaults.seniorValue);
        
        // Step 2-3: Dynamic APY selection
        RebaseLib.APYSelection memory selection = RebaseLib.selectDynamicAPY(
            vaults.seniorSupply,
            vaults.seniorValue
        );
        
        vaults.seniorAPY = selection.apyTier;
        
        console.log("APY Selected:", selection.apyTier == 3 ? "13%" : selection.apyTier == 2 ? "12%" : "11%");
        console.log("User Tokens:", selection.userTokens / 1e18);
        console.log("Performance Fee Tokens:", selection.feeTokens / 1e18);
        console.log("Management Fee Tokens:", mgmtFeeTokens / 1e18);
        console.log("New Supply:", selection.newSupply / 1e18);
        
        // Step 4: Determine zone and execute spillover/backstop
        uint256 preRebaseBackingRatio = MathLib.calculateBackingRatio(vaults.seniorValue, selection.newSupply);
        SpilloverLib.Zone zone = SpilloverLib.determineZone(preRebaseBackingRatio);
        
        console.log("Pre-Rebase Backing Ratio:", preRebaseBackingRatio * 100 / 1e18, "%");
        
        uint256 spilloverJunior = 0;
        uint256 spilloverReserve = 0;
        uint256 backstopReserve = 0;
        uint256 backstopJunior = 0;
        
        if (zone == SpilloverLib.Zone.SPILLOVER) {
            console.log("Zone: SPILLOVER (>110%)");
            (spilloverJunior, spilloverReserve) = _executeProfitSpillover(vaults.seniorValue, selection.newSupply);
        } else if (zone == SpilloverLib.Zone.BACKSTOP || selection.backstopNeeded) {
            console.log("Zone: BACKSTOP (<100%)");
            (backstopReserve, backstopJunior) = _executeBackstop(vaults.seniorValue, selection.newSupply);
        } else {
            console.log("Zone: HEALTHY (100-110%)");
        }
        
        // Step 5: Update rebase index
        uint256 oldIndex = vaults.seniorRebaseIndex;
        vaults.seniorRebaseIndex = FeeLib.calculateNewRebaseIndex(oldIndex, selection.selectedRate);
        
        // Step 6: Update supply (includes user tokens + performance fee + mgmt fee)
        vaults.seniorSupply = selection.newSupply + mgmtFeeTokens;
        
        // Update backing ratio after all changes (post-rebase)
        uint256 postRebaseBackingRatio = MathLib.calculateBackingRatio(vaults.seniorValue, vaults.seniorSupply);
        vaults.seniorBackingRatio = postRebaseBackingRatio;
        
        console.log("Post-Rebase Backing Ratio:", postRebaseBackingRatio * 100 / 1e18, "%");
        console.log("New Rebase Index:", vaults.seniorRebaseIndex * 100 / 1e18, "%");
        console.log("======================================\n");
        
        // Take snapshot with PRE-rebase backing ratio (shows real market impact)
        currentEpoch++;
        _takeSnapshot(preRebaseBackingRatio, spilloverJunior, spilloverReserve, backstopReserve, backstopJunior, 0);
    }
    
    /**
     * @notice Execute profit spillover (Zone 1: >110%)
     */
    function _executeProfitSpillover(uint256 netValue, uint256 newSupply) 
        internal 
        returns (uint256 toJunior, uint256 toReserve) 
    {
        SpilloverLib.ProfitSpillover memory spillover = 
            SpilloverLib.calculateProfitSpillover(netValue, newSupply);
        
        if (spillover.excessAmount == 0) return (0, 0);
        
        console.log("Spillover Excess:", spillover.excessAmount / 1e18);
        console.log("To Junior (80%):", spillover.toJunior / 1e18);
        console.log("To Reserve (20%):", spillover.toReserve / 1e18);
        
        // Convert USD amounts to LP tokens
        uint256 lpToJunior = (spillover.toJunior * 1e18) / pool.lpTokenPrice;
        uint256 lpToReserve = (spillover.toReserve * 1e18) / pool.lpTokenPrice;
        
        // Safety check: don't transfer more LP than available
        uint256 totalLPNeeded = lpToJunior + lpToReserve;
        if (totalLPNeeded > vaults.seniorLPAmount) {
            // Scale down proportionally
            lpToJunior = (vaults.seniorLPAmount * spillover.toJunior) / spillover.excessAmount;
            lpToReserve = vaults.seniorLPAmount - lpToJunior;
            totalLPNeeded = vaults.seniorLPAmount;
        }
        
        // Transfer LP tokens
        vaults.seniorLPAmount -= totalLPNeeded;
        vaults.juniorLPAmount += lpToJunior;
        vaults.reserveSailAmount += (spillover.toReserve * 1e18) / pool.sailPrice; // Reserve gets SAIL value
        
        // Update values
        vaults.seniorValue = spillover.seniorFinalValue;
        vaults.juniorValue += spillover.toJunior;
        vaults.reserveValue += spillover.toReserve;
        
        return (spillover.toJunior, spillover.toReserve);
    }
    
    /**
     * @notice Execute backstop (Zone 3: <100%)
     */
    function _executeBackstop(uint256 netValue, uint256 newSupply) 
        internal 
        returns (uint256 fromReserve, uint256 fromJunior) 
    {
        SpilloverLib.BackstopResult memory backstop = 
            SpilloverLib.calculateBackstop(netValue, newSupply, vaults.reserveValue, vaults.juniorValue);
        
        if (backstop.deficitAmount == 0) return (0, 0);
        
        console.log("Backstop Deficit:", backstop.deficitAmount / 1e18);
        console.log("From Reserve:", backstop.fromReserve / 1e18);
        console.log("From Junior:", backstop.fromJunior / 1e18);
        console.log("Fully Restored:", backstop.fullyRestored);
        
        // Reserve provides SAIL tokens (convert to USD value)
        if (backstop.fromReserve > 0) {
            uint256 sailToSenior = (backstop.fromReserve * 1e18) / pool.sailPrice;
            // Safety check: don't transfer more SAIL than available
            if (sailToSenior > vaults.reserveSailAmount) {
                sailToSenior = vaults.reserveSailAmount;
                backstop.fromReserve = (sailToSenior * pool.sailPrice) / 1e18;
            }
            vaults.reserveSailAmount -= sailToSenior;
            vaults.reserveValue -= backstop.fromReserve;
        }
        
        // Junior provides LP tokens (convert to LP amount)
        if (backstop.fromJunior > 0) {
            uint256 lpToSenior = (backstop.fromJunior * 1e18) / pool.lpTokenPrice;
            // Safety check: don't transfer more LP than available
            if (lpToSenior > vaults.juniorLPAmount) {
                lpToSenior = vaults.juniorLPAmount;
                backstop.fromJunior = (lpToSenior * pool.lpTokenPrice) / 1e18;
            }
            vaults.juniorLPAmount -= lpToSenior;
            vaults.seniorLPAmount += lpToSenior;
            vaults.juniorValue -= backstop.fromJunior;
        }
        
        // Update Senior value
        vaults.seniorValue = backstop.seniorFinalValue;
        
        return (backstop.fromReserve, backstop.fromJunior);
    }
    
    // ============================================
    // Snapshot & JSON Export
    // ============================================
    
    /**
     * @notice Take snapshot of current state
     */
    function _takeSnapshot(
        uint256 preRebaseBackingRatio,
        uint256 spilloverJunior,
        uint256 spilloverReserve,
        uint256 backstopReserve,
        uint256 backstopJunior,
        int256 sailPriceChange
    ) internal {
        string memory zoneStr;
        SpilloverLib.Zone zone = SpilloverLib.determineZone(preRebaseBackingRatio);
        if (zone == SpilloverLib.Zone.SPILLOVER) zoneStr = "SPILLOVER";
        else if (zone == SpilloverLib.Zone.HEALTHY) zoneStr = "HEALTHY";
        else zoneStr = "BACKSTOP";
        
        // Store pre-rebase backing ratio in vaults struct temporarily
        uint256 postRebaseBackingRatio = vaults.seniorBackingRatio;
        vaults.seniorBackingRatio = preRebaseBackingRatio; // Use pre-rebase for snapshot
        
        Snapshot memory snap = Snapshot({
            timestamp: block.timestamp,
            epoch: currentEpoch,
            pool: pool,
            vaults: vaults,
            zone: zoneStr,
            spilloverToJunior: spilloverJunior,
            spilloverToReserve: spilloverReserve,
            backstopFromReserve: backstopReserve,
            backstopFromJunior: backstopJunior,
            sailPriceChange: sailPriceChange,
            lpPriceChange: 0
        });
        
        // Restore post-rebase backing ratio
        vaults.seniorBackingRatio = postRebaseBackingRatio;
        
        snapshots.push(snap);
    }
    
    /**
     * @notice Export all snapshots to JSON format
     */
    function exportToJSON() public view returns (string memory) {
        string memory json = '{\n  "simulation": "Rebase Time Series",\n  "snapshots": [\n';
        
        for (uint256 i = 0; i < snapshots.length; i++) {
            Snapshot memory s = snapshots[i];
            
            json = string.concat(json, '    {\n');
            json = string.concat(json, '      "epoch": ', vm.toString(s.epoch), ',\n');
            json = string.concat(json, '      "timestamp": ', vm.toString(s.timestamp), ',\n');
            json = string.concat(json, '      "zone": "', s.zone, '",\n');
            
            // Pool state
            json = string.concat(json, '      "pool": {\n');
            json = string.concat(json, '        "usdeReserve": ', vm.toString(s.pool.usdeReserve / 1e18), ',\n');
            json = string.concat(json, '        "sailReserve": ', vm.toString(s.pool.sailReserve / 1e18), ',\n');
            json = string.concat(json, '        "sailPrice": ', vm.toString(s.pool.sailPrice / 1e15), ',\n'); // 3 decimals
            json = string.concat(json, '        "lpTokenPrice": ', vm.toString(s.pool.lpTokenPrice / 1e15), ',\n'); // 3 decimals
            json = string.concat(json, '        "totalLPSupply": ', vm.toString(s.pool.totalLPSupply / 1e18), '\n');
            json = string.concat(json, '      },\n');
            
            // Senior state
            json = string.concat(json, '      "senior": {\n');
            json = string.concat(json, '        "lpAmount": ', vm.toString(s.vaults.seniorLPAmount / 1e18), ',\n');
            json = string.concat(json, '        "value": ', vm.toString(s.vaults.seniorValue / 1e18), ',\n');
            json = string.concat(json, '        "supply": ', vm.toString(s.vaults.seniorSupply / 1e18), ',\n');
            json = string.concat(json, '        "backingRatio": ', vm.toString(s.vaults.seniorBackingRatio / 1e16), ',\n'); // %
            json = string.concat(json, '        "rebaseIndex": ', vm.toString(s.vaults.seniorRebaseIndex / 1e15), ',\n'); // 3 decimals
            json = string.concat(json, '        "apy": ', vm.toString(uint256(s.vaults.seniorAPY)), '\n');
            json = string.concat(json, '      },\n');
            
            // Junior state
            json = string.concat(json, '      "junior": {\n');
            json = string.concat(json, '        "lpAmount": ', vm.toString(s.vaults.juniorLPAmount / 1e18), ',\n');
            json = string.concat(json, '        "value": ', vm.toString(s.vaults.juniorValue / 1e18), ',\n');
            json = string.concat(json, '        "shares": ', vm.toString(s.vaults.juniorShares / 1e18), '\n');
            json = string.concat(json, '      },\n');
            
            // Reserve state
            json = string.concat(json, '      "reserve": {\n');
            json = string.concat(json, '        "sailAmount": ', vm.toString(s.vaults.reserveSailAmount / 1e18), ',\n');
            json = string.concat(json, '        "value": ', vm.toString(s.vaults.reserveValue / 1e18), ',\n');
            json = string.concat(json, '        "shares": ', vm.toString(s.vaults.reserveShares / 1e18), '\n');
            json = string.concat(json, '      },\n');
            
            // Spillover/Backstop
            json = string.concat(json, '      "transfers": {\n');
            json = string.concat(json, '        "spilloverToJunior": ', vm.toString(s.spilloverToJunior / 1e18), ',\n');
            json = string.concat(json, '        "spilloverToReserve": ', vm.toString(s.spilloverToReserve / 1e18), ',\n');
            json = string.concat(json, '        "backstopFromReserve": ', vm.toString(s.backstopFromReserve / 1e18), ',\n');
            json = string.concat(json, '        "backstopFromJunior": ', vm.toString(s.backstopFromJunior / 1e18), '\n');
            json = string.concat(json, '      }\n');
            
            json = string.concat(json, '    }');
            if (i < snapshots.length - 1) json = string.concat(json, ',');
            json = string.concat(json, '\n');
        }
        
        json = string.concat(json, '  ]\n}');
        return json;
    }
    
    // ============================================
    // Helper Functions
    // ============================================
    
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
    
    // ============================================
    // View Functions
    // ============================================
    
    function getSnapshotCount() public view returns (uint256) {
        return snapshots.length;
    }
    
    function getSnapshot(uint256 index) public view returns (Snapshot memory) {
        return snapshots[index];
    }
}

