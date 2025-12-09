// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {UnifiedConcreteSeniorVault} from "../src/concrete/UnifiedConcreteSeniorVault.sol";
import {ConcreteJuniorVault} from "../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../src/concrete/ConcreteReserveVault.sol";

/**
 * @title UpgradeToNewImplementations
 * @notice Upgrade all three vault proxies to new implementations
 * 
 * Usage:
 *   1. Set implementation addresses in this file
 *   2. Run: forge script script/UpgradeToNewImplementations.s.sol:UpgradeToNewImplementations \
 *            --rpc-url $RPC_URL --broadcast
 */
contract UpgradeToNewImplementations is Script {
    // Proxy addresses
    address constant SENIOR_PROXY = 0x49298F4314eb127041b814A2616c25687Db6b650;
    address constant JUNIOR_PROXY = 0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883;
    address constant RESERVE_PROXY = 0x7754272c866892CaD4a414C76f060645bDc27203;
    
    // TODO: Set these to your newly deployed implementation addresses
    address constant NEW_SENIOR_IMPL = address(0);  // SET THIS
    address constant NEW_JUNIOR_IMPL = address(0);  // SET THIS
    address constant NEW_RESERVE_IMPL = address(0); // SET THIS
    
    function run() external {
        require(NEW_SENIOR_IMPL != address(0), "Set NEW_SENIOR_IMPL");
        require(NEW_JUNIOR_IMPL != address(0), "Set NEW_JUNIOR_IMPL");
        require(NEW_RESERVE_IMPL != address(0), "Set NEW_RESERVE_IMPL");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("=================================================");
        console2.log("UPGRADE VAULTS TO NEW IMPLEMENTATIONS");
        console2.log("=================================================");
        console2.log("Deployer:", deployer);
        console2.log("");
        console2.log("Proxies:");
        console2.log("  Senior: ", SENIOR_PROXY);
        console2.log("  Junior: ", JUNIOR_PROXY);
        console2.log("  Reserve:", RESERVE_PROXY);
        console2.log("");
        console2.log("New Implementations:");
        console2.log("  Senior: ", NEW_SENIOR_IMPL);
        console2.log("  Junior: ", NEW_JUNIOR_IMPL);
        console2.log("  Reserve:", NEW_RESERVE_IMPL);
        console2.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        bytes memory emptyData = "";
        
        console2.log("Upgrading Senior...");
        UnifiedConcreteSeniorVault(payable(SENIOR_PROXY)).upgradeToAndCall(NEW_SENIOR_IMPL, emptyData);
        console2.log("[OK] Senior upgraded");
        
        console2.log("Upgrading Junior...");
        ConcreteJuniorVault(JUNIOR_PROXY).upgradeToAndCall(NEW_JUNIOR_IMPL, emptyData);
        console2.log("[OK] Junior upgraded");
        
        console2.log("Upgrading Reserve...");
        ConcreteReserveVault(RESERVE_PROXY).upgradeToAndCall(NEW_RESERVE_IMPL, emptyData);
        console2.log("[OK] Reserve upgraded");
        
        vm.stopBroadcast();
        
        console2.log("");
        console2.log("=================================================");
        console2.log("UPGRADES COMPLETE");
        console2.log("=================================================");
        console2.log("Verify state:");
        console2.log("  Senior totalSupply:", UnifiedConcreteSeniorVault(payable(SENIOR_PROXY)).totalSupply());
        console2.log("  Junior totalSupply:", ConcreteJuniorVault(JUNIOR_PROXY).totalSupply());
        console2.log("  Reserve totalSupply:", ConcreteReserveVault(RESERVE_PROXY).totalSupply());
        console2.log("=================================================");
    }
}

