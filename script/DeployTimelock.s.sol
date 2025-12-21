// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title DeployTimelock
 * @notice Deploys OpenZeppelin TimelockController for vault protection
 * @dev Usage:
 *   forge script script/DeployTimelock.s.sol:DeployTimelock \
 *     --rpc-url $RPC_URL \
 *     --broadcast \
 *     --verify \
 *     -vvvv
 * 
 * Environment Variables:
 *   PRIVATE_KEY          - Deployer private key
 *   PROPOSER_ADDRESS     - Address that can propose (e.g., priceFeedManager, seeder)
 *   ADMIN_ADDRESS        - Address that can cancel proposals (your admin/multisig)
 *   MIN_DELAY            - Minimum delay in seconds (e.g., 86400 for 24 hours)
 */
contract DeployTimelock is Script {
    function run() external {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proposer = vm.envAddress("PROPOSER_ADDRESS");
        address admin = vm.envAddress("ADMIN_ADDRESS");
        uint256 minDelay = vm.envOr("MIN_DELAY", uint256(24 hours));
        
        console.log("=== Deploying TimelockController ===");
        console.log("Proposer:", proposer);
        console.log("Admin (canceller):", admin);
        console.log("Min Delay:", minDelay, "seconds");
        console.log("Min Delay:", minDelay / 3600, "hours");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Setup roles
        // Proposers: who can schedule operations
        address[] memory proposers = new address[](1);
        proposers[0] = proposer;
        
        // Executors: address(0) means anyone can execute after delay
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        
        // Deploy TimelockController
        // Constructor: (minDelay, proposers, executors, admin)
        // admin can cancel proposals and manage roles
        TimelockController timelock = new TimelockController(
            minDelay,
            proposers,
            executors,
            admin
        );
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("=== Deployment Complete ===");
        console.log("TimelockController deployed at:", address(timelock));
        console.log("");
        console.log("=== Next Steps ===");
        console.log("1. Set timelock on Senior vault:");
        console.log("   seniorVault.setTimelock(", address(timelock), ")");
        console.log("");
        console.log("2. Set timelock on Junior vault:");
        console.log("   juniorVault.setTimelock(", address(timelock), ")");
        console.log("");
        console.log("3. Set timelock on Reserve vault:");
        console.log("   reserveVault.setTimelock(", address(timelock), ")");
        console.log("");
        console.log("=== Timelock Roles ===");
        console.log("PROPOSER_ROLE holder:", proposer);
        console.log("EXECUTOR_ROLE: Open (anyone can execute after delay)");
        console.log("CANCELLER_ROLE holder:", admin);
        console.log("");
        console.log("=== How to Use ===");
        console.log("For large value changes (>5%) or large seeds (>10%):");
        console.log("1. Proposer schedules: timelock.schedule(target, 0, data, 0, salt, delay)");
        console.log("2. Wait", minDelay / 3600, "hours");
        console.log("3. Anyone executes: timelock.execute(target, 0, data, 0, salt)");
    }
}

/**
 * @title SetTimelockOnVaults
 * @notice Sets the timelock address on all vaults
 * @dev Run after deploying timelock:
 *   forge script script/DeployTimelock.s.sol:SetTimelockOnVaults \
 *     --rpc-url $RPC_URL \
 *     --broadcast \
 *     -vvvv
 */
contract SetTimelockOnVaults is Script {
    function run() external {
        uint256 adminPrivateKey = vm.envUint("ADMIN_PRIVATE_KEY");
        address timelockAddress = vm.envAddress("TIMELOCK_ADDRESS");
        address seniorVault = vm.envAddress("SENIOR_VAULT");
        address juniorVault = vm.envAddress("JUNIOR_VAULT");
        address reserveVault = vm.envAddress("RESERVE_VAULT");
        
        console.log("=== Setting Timelock on Vaults ===");
        console.log("Timelock:", timelockAddress);
        
        vm.startBroadcast(adminPrivateKey);
        
        // Set timelock on Senior
        if (seniorVault != address(0)) {
            (bool success,) = seniorVault.call(
                abi.encodeWithSignature("setTimelock(address)", timelockAddress)
            );
            require(success, "Failed to set timelock on Senior");
            console.log("Senior vault timelock set:", seniorVault);
        }
        
        // Set timelock on Junior
        if (juniorVault != address(0)) {
            (bool success,) = juniorVault.call(
                abi.encodeWithSignature("setTimelock(address)", timelockAddress)
            );
            require(success, "Failed to set timelock on Junior");
            console.log("Junior vault timelock set:", juniorVault);
        }
        
        // Set timelock on Reserve
        if (reserveVault != address(0)) {
            (bool success,) = reserveVault.call(
                abi.encodeWithSignature("setTimelock(address)", timelockAddress)
            );
            require(success, "Failed to set timelock on Reserve");
            console.log("Reserve vault timelock set:", reserveVault);
        }
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("=== Complete ===");
        console.log("All vaults now protected by timelock for large operations");
    }
}

