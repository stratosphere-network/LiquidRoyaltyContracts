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
    
    /// @dev Fee tracking
    struct FeeData {
        uint256 managementFeeTokens;   // Management fee this epoch
        uint256 performanceFeeTokens;  // Performance fee this epoch
        uint256 totalFeesThisEpoch;    // Total fees this epoch
        uint256 cumulativeFees;        // Cumulative fees collected
        uint256 feeYieldBps;           // Fee yield as % of AUM (in BPS)
    }
    
    /// @dev User wallet action
    struct UserAction {
        uint256 timestamp;
        uint256 epoch;
        address user;
        string actionType;             // "DEPOSIT", "WITHDRAW", "TRADE"
        string vault;                  // "SENIOR", "JUNIOR", "RESERVE"
        uint256 amount;
        uint256 shares;
        string reason;                 // Description of why action happened
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
        FeeData fees;                  // Fee tracking data
    }
    
    // Current state
    PoolState public pool;
    VaultState public vaults;
    
    // Time-series data
    Snapshot[] public snapshots;
    uint256 public currentEpoch;
    uint256 public startTime;
    
    // Fee tracking
    uint256 public cumulativeFees;
    uint256 public totalManagementFees;
    uint256 public totalPerformanceFees;
    
    // User action tracking
    UserAction[] public userActions;
    
    // Simulated users/whales
    address constant WHALE_1 = address(0x1111);
    address constant WHALE_2 = address(0x2222);
    address constant RETAIL_1 = address(0x3333);
    address constant RETAIL_2 = address(0x4444);
    address constant RETAIL_3 = address(0x5555);
    
    // User balances (tracks shares in each vault)
    mapping(address => uint256) public seniorBalances;
    mapping(address => uint256) public juniorBalances;
    mapping(address => uint256) public reserveBalances;
    
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
        _takeSnapshot(vaults.seniorBackingRatio, 0, 0, 0, 0, 0, 0, 0);
    }
    
    // ============================================
    // User Action Simulation Functions
    // ============================================
    
    /**
     * @notice Simulate a user deposit into a vault
     * @param user Address of the user
     * @param vault "SENIOR", "JUNIOR", or "RESERVE"
     * @param amount Amount to deposit (in USD for Senior/Junior, in SAIL for Reserve)
     * @param reason Description of why deposit happened
     */
     
    function simulateDeposit(address user, string memory vault, uint256 amount, string memory reason) public {
        uint256 shares;
        
        if (keccak256(bytes(vault)) == keccak256(bytes("SENIOR"))) {
            // Senior: 1:1 deposit
            shares = amount;
            vaults.seniorSupply += amount;
            vaults.seniorShares += shares;
            vaults.seniorValue += amount;
            seniorBalances[user] += shares;
        } else if (keccak256(bytes(vault)) == keccak256(bytes("JUNIOR"))) {
            // Junior: ERC4626 style (shares = amount * totalShares / totalAssets)
            shares = vaults.juniorShares > 0 
                ? (amount * vaults.juniorShares) / vaults.juniorValue
                : amount;
            vaults.juniorShares += shares;
            vaults.juniorValue += amount;
            juniorBalances[user] += shares;
        } else if (keccak256(bytes(vault)) == keccak256(bytes("RESERVE"))) {
            // Reserve: deposit SAIL tokens (amount is in SAIL, not USD)
            shares = vaults.reserveShares > 0
                ? (amount * vaults.reserveShares) / vaults.reserveSailAmount
                : amount;
            vaults.reserveSailAmount += amount;
            vaults.reserveValue += (amount * pool.sailPrice) / 1e18;
            vaults.reserveShares += shares;
            reserveBalances[user] += shares;
        }
        
        // Record action
        userActions.push(UserAction({
            timestamp: block.timestamp,
            epoch: currentEpoch,
            user: user,
            actionType: "DEPOSIT",
            vault: vault,
            amount: amount,
            shares: shares,
            reason: reason
        }));
        
        console.log("USER ACTION: Deposit");
        console.log("  User:", user);
        console.log("  Vault:", vault);
        console.log("  Amount:", amount / 1e18);
        console.log("  Shares:", shares / 1e18);
        console.log("  Reason:", reason);
    }
    
    /**
     * @notice Simulate a user withdrawal from a vault
     * @param user Address of the user
     * @param vault "SENIOR", "JUNIOR", or "RESERVE"
     * @param shares Amount of shares to redeem
     * @param reason Description of why withdrawal happened
     */
    function simulateWithdraw(address user, string memory vault, uint256 shares, string memory reason) public {
        uint256 amount;
        
        if (keccak256(bytes(vault)) == keccak256(bytes("SENIOR"))) {
            require(seniorBalances[user] >= shares, "Insufficient balance");
            // Senior: 1:1 redemption (simplified, no penalties)
            amount = shares;
            vaults.seniorSupply -= amount;
            vaults.seniorShares -= shares;
            vaults.seniorValue -= amount;
            seniorBalances[user] -= shares;
        } else if (keccak256(bytes(vault)) == keccak256(bytes("JUNIOR"))) {
            require(juniorBalances[user] >= shares, "Insufficient balance");
            // Junior: shares * totalAssets / totalShares
            amount = (shares * vaults.juniorValue) / vaults.juniorShares;
            vaults.juniorShares -= shares;
            vaults.juniorValue -= amount;
            juniorBalances[user] -= shares;
        } else if (keccak256(bytes(vault)) == keccak256(bytes("RESERVE"))) {
            require(reserveBalances[user] >= shares, "Insufficient balance");
            // Reserve: shares * totalSAIL / totalShares
            amount = (shares * vaults.reserveSailAmount) / vaults.reserveShares;
            vaults.reserveSailAmount -= amount;
            vaults.reserveValue -= (amount * pool.sailPrice) / 1e18;
            vaults.reserveShares -= shares;
            reserveBalances[user] -= shares;
        }
        
        // Record action
        userActions.push(UserAction({
            timestamp: block.timestamp,
            epoch: currentEpoch,
            user: user,
            actionType: "WITHDRAW",
            vault: vault,
            amount: amount,
            shares: shares,
            reason: reason
        }));
        
        console.log("USER ACTION: Withdraw");
        console.log("  User:", user);
        console.log("  Vault:", vault);
        console.log("  Shares Redeemed:", shares / 1e18);
        console.log("  Amount Received:", amount / 1e18);
        console.log("  Reason:", reason);
    }
    
    /**
     * @notice Simulate a trade (whale or retail)
     * @param trader Address of the trader
     * @param sailAmountIn Amount of SAIL (negative = buy SAIL)
     * @param reason Description of trade
     */
    function simulateTradeWithUser(address trader, int256 sailAmountIn, string memory reason) public {
        // Execute the trade
        simulateTrade(sailAmountIn, 0);
        
        // Record action
        userActions.push(UserAction({
            timestamp: block.timestamp,
            epoch: currentEpoch,
            user: trader,
            actionType: "TRADE",
            vault: "POOL",
            amount: sailAmountIn > 0 ? uint256(sailAmountIn) : uint256(-sailAmountIn),
            shares: 0,
            reason: reason
        }));
        
        console.log("USER ACTION: Trade");
        console.log("  Trader:", trader);
        console.log("  SAIL Amount:", uint256(sailAmountIn > 0 ? sailAmountIn : -sailAmountIn) / 1e18);
        console.log("  Direction:", sailAmountIn > 0 ? "SELL" : "BUY");
        console.log("  Reason:", reason);
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
        totalManagementFees += mgmtFeeTokens;
        
        // Step 2-3: Dynamic APY selection
        RebaseLib.APYSelection memory selection = RebaseLib.selectDynamicAPY(
            vaults.seniorSupply,
            vaults.seniorValue
        );
        
        vaults.seniorAPY = selection.apyTier;
        
        // Track performance fees
        totalPerformanceFees += selection.feeTokens;
        uint256 totalFeesThisEpoch = mgmtFeeTokens + selection.feeTokens;
        cumulativeFees += totalFeesThisEpoch;
        
        console.log("APY Selected:", selection.apyTier == 3 ? "13%" : selection.apyTier == 2 ? "12%" : "11%");
        console.log("User Tokens:", selection.userTokens / 1e18);
        console.log("Performance Fee Tokens:", selection.feeTokens / 1e18);
        console.log("Management Fee Tokens:", mgmtFeeTokens / 1e18);
        console.log("Total Fees This Epoch:", totalFeesThisEpoch / 1e18);
        console.log("Cumulative Fees:", cumulativeFees / 1e18);
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
        _takeSnapshot(preRebaseBackingRatio, spilloverJunior, spilloverReserve, backstopReserve, backstopJunior, 0, mgmtFeeTokens, selection.feeTokens);
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
        int256 sailPriceChange,
        uint256 mgmtFeeTokens,
        uint256 perfFeeTokens
    ) internal {
        string memory zoneStr;
        SpilloverLib.Zone zone = SpilloverLib.determineZone(preRebaseBackingRatio);
        if (zone == SpilloverLib.Zone.SPILLOVER) zoneStr = "SPILLOVER";
        else if (zone == SpilloverLib.Zone.HEALTHY) zoneStr = "HEALTHY";
        else zoneStr = "BACKSTOP";
        
        // Store pre-rebase backing ratio in vaults struct temporarily
        uint256 postRebaseBackingRatio = vaults.seniorBackingRatio;
        vaults.seniorBackingRatio = preRebaseBackingRatio; // Use pre-rebase for snapshot
        
        // Calculate fee yield (total fees / AUM)
        uint256 totalFeesThisEpoch = mgmtFeeTokens + perfFeeTokens;
        uint256 feeYieldBps = vaults.seniorValue > 0 
            ? (totalFeesThisEpoch * 10000) / vaults.seniorValue 
            : 0;
        
        FeeData memory feeData = FeeData({
            managementFeeTokens: mgmtFeeTokens,
            performanceFeeTokens: perfFeeTokens,
            totalFeesThisEpoch: totalFeesThisEpoch,
            cumulativeFees: cumulativeFees,
            feeYieldBps: feeYieldBps
        });
        
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
            lpPriceChange: 0,
            fees: feeData
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
            json = string.concat(json, '      },\n');
            
            // Fees
            json = string.concat(json, '      "fees": {\n');
            json = string.concat(json, '        "managementFeeTokens": ', vm.toString(s.fees.managementFeeTokens / 1e18), ',\n');
            json = string.concat(json, '        "performanceFeeTokens": ', vm.toString(s.fees.performanceFeeTokens / 1e18), ',\n');
            json = string.concat(json, '        "totalFeesThisEpoch": ', vm.toString(s.fees.totalFeesThisEpoch / 1e18), ',\n');
            json = string.concat(json, '        "cumulativeFees": ', vm.toString(s.fees.cumulativeFees / 1e18), ',\n');
            json = string.concat(json, '        "feeYieldBps": ', vm.toString(s.fees.feeYieldBps), '\n');
            json = string.concat(json, '      }\n');
            
            json = string.concat(json, '    }');
            if (i < snapshots.length - 1) json = string.concat(json, ',');
            json = string.concat(json, '\n');
        }
        
        json = string.concat(json, '  ]\n}');
        return json;
    }
    
    /**
     * @notice Export user actions to JSON format
     */
    function exportUserActionsToJSON() public view returns (string memory) {
        string memory json = '{\n  "userActions": [\n';
        
        for (uint256 i = 0; i < userActions.length; i++) {
            UserAction memory action = userActions[i];
            
            json = string.concat(json, '    {\n');
            json = string.concat(json, '      "timestamp": ', vm.toString(action.timestamp), ',\n');
            json = string.concat(json, '      "epoch": ', vm.toString(action.epoch), ',\n');
            json = string.concat(json, '      "user": "', vm.toString(action.user), '",\n');
            json = string.concat(json, '      "actionType": "', action.actionType, '",\n');
            json = string.concat(json, '      "vault": "', action.vault, '",\n');
            json = string.concat(json, '      "amount": ', vm.toString(action.amount / 1e18), ',\n');
            json = string.concat(json, '      "shares": ', vm.toString(action.shares / 1e18), ',\n');
            json = string.concat(json, '      "reason": "', action.reason, '"\n');
            json = string.concat(json, '    }');
            
            if (i < userActions.length - 1) json = string.concat(json, ',');
            json = string.concat(json, '\n');
        }
        
        json = string.concat(json, '  ]\n}');
        return json;
    }
    
    /**
     * @notice Get user balances across all vaults
     */
    function getUserBalances(address user) public view returns (uint256 senior, uint256 junior, uint256 reserve) {
        return (seniorBalances[user], juniorBalances[user], reserveBalances[user]);
    }
    
    /**
     * @notice Get summary of all user actions
     */
    function getUserActionCount() public view returns (uint256) {
        return userActions.length;
    }
    
    /**
     * @notice Get fee summary
     */
    function getFeeSummary() public view returns (
        uint256 totalMgmt,
        uint256 totalPerf,
        uint256 cumulative,
        uint256 avgYieldBps
    ) {
        totalMgmt = totalManagementFees;
        totalPerf = totalPerformanceFees;
        cumulative = cumulativeFees;
        avgYieldBps = currentEpoch > 0 ? cumulativeFees * 10000 / vaults.seniorValue / currentEpoch : 0;
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

