// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {UnifiedConcreteSeniorVault} from "../src/concrete/UnifiedConcreteSeniorVault.sol";
import {ConcreteJuniorVault} from "../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../src/concrete/ConcreteReserveVault.sol";

/**
 * @title DeployNewImplementations
 * @notice Deploy new implementations for all three vaults
 * 
 * Usage:
 *   forge script script/DeployNewImplementations.s.sol:DeployNewImplementations \
 *     --rpc-url $RPC_URL \
 *     --broadcast \
 *     --verify \
 *     --etherscan-api-key $ETHERSCAN_API_KEY
 */
contract DeployNewImplementations is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("=================================================");
        console2.log("DEPLOY NEW IMPLEMENTATIONS");
        console2.log("=================================================");
        console2.log("Deployer:", deployer);
        console2.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        console2.log("Deploying Senior implementation...");
        UnifiedConcreteSeniorVault seniorImpl = new UnifiedConcreteSeniorVault();
        console2.log("[OK] Senior:", address(seniorImpl));
        
        console2.log("Deploying Junior implementation...");
        ConcreteJuniorVault juniorImpl = new ConcreteJuniorVault();
        console2.log("[OK] Junior:", address(juniorImpl));
        
        console2.log("Deploying Reserve implementation...");
        ConcreteReserveVault reserveImpl = new ConcreteReserveVault();
        console2.log("[OK] Reserve:", address(reserveImpl));
        
        vm.stopBroadcast();
        
        console2.log("");
        console2.log("=================================================");
        console2.log("DEPLOYMENT COMPLETE");
        console2.log("=================================================");
        console2.log("Senior:  ", address(seniorImpl));
        console2.log("Junior:  ", address(juniorImpl));
        console2.log("Reserve: ", address(reserveImpl));
        console2.log("=================================================");
    }
}

