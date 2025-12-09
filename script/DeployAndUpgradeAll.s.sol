// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {UnifiedConcreteSeniorVault} from "../src/concrete/UnifiedConcreteSeniorVault.sol";
import {ConcreteJuniorVault} from "../src/concrete/ConcreteJuniorVault.sol";
import {ConcreteReserveVault} from "../src/concrete/ConcreteReserveVault.sol";

/**
 * @title DeployAndUpgradeAll
 * @notice Deploy new implementations and upgrade all three vaults
 * 
 * Usage:
 *   forge script script/DeployAndUpgradeAll.s.sol:DeployAndUpgradeAll \
 *     --rpc-url $RPC_URL \
 *     --broadcast \
 *     --verify \
 *     --etherscan-api-key $ETHERSCAN_API_KEY
 */
contract DeployAndUpgradeAll is Script {
    address constant SENIOR_PROXY = 0x49298F4314eb127041b814A2616c25687Db6b650;
    address constant JUNIOR_PROXY = 0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883;
    address constant RESERVE_PROXY = 0x7754272c866892CaD4a414C76f060645bDc27203;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("=================================================");
        console2.log("DEPLOY & UPGRADE ALL VAULTS");
        console2.log("=================================================");
        console2.log("Deployer:", deployer);
        console2.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Deploy new implementations
        console2.log("Step 1: Deploying new implementations...");
        console2.log("");
        
        UnifiedConcreteSeniorVault seniorImpl = new UnifiedConcreteSeniorVault();
        console2.log("[OK] Senior:  ", address(seniorImpl));
        
        ConcreteJuniorVault juniorImpl = new ConcreteJuniorVault();
        console2.log("[OK] Junior:  ", address(juniorImpl));
        
        ConcreteReserveVault reserveImpl = new ConcreteReserveVault();
        console2.log("[OK] Reserve: ", address(reserveImpl));
        console2.log("");
        
        // Step 2: Upgrade all proxies
        console2.log("Step 2: Upgrading proxies...");
        console2.log("");
        
        bytes memory emptyData = "";
        
        UnifiedConcreteSeniorVault(payable(SENIOR_PROXY)).upgradeToAndCall(address(seniorImpl), emptyData);
        console2.log("[OK] Senior proxy upgraded");
        
        ConcreteJuniorVault(JUNIOR_PROXY).upgradeToAndCall(address(juniorImpl), emptyData);
        console2.log("[OK] Junior proxy upgraded");
        
        ConcreteReserveVault(RESERVE_PROXY).upgradeToAndCall(address(reserveImpl), emptyData);
        console2.log("[OK] Reserve proxy upgraded");
        console2.log("");
        
        vm.stopBroadcast();
        
        // Verification
        console2.log("=================================================");
        console2.log("VERIFICATION");
        console2.log("=================================================");
        
        UnifiedConcreteSeniorVault senior = UnifiedConcreteSeniorVault(payable(SENIOR_PROXY));
        ConcreteJuniorVault junior = ConcreteJuniorVault(JUNIOR_PROXY);
        ConcreteReserveVault reserve = ConcreteReserveVault(RESERVE_PROXY);
        
        console2.log("Senior:");
        console2.log("  Total Supply:", senior.totalSupply());
        console2.log("  Vault Value:", senior.vaultValue());
        console2.log("");
        
        console2.log("Junior:");
        console2.log("  Total Supply:", junior.totalSupply());
        console2.log("  Vault Value:", junior.vaultValue());
        console2.log("");
        
        console2.log("Reserve:");
        console2.log("  Total Supply:", reserve.totalSupply());
        console2.log("  Vault Value:", reserve.vaultValue());
        console2.log("");
        
        console2.log("=================================================");
        console2.log("SUCCESS");
        console2.log("=================================================");
        console2.log("New Implementations:");
        console2.log("  Senior:  ", address(seniorImpl));
        console2.log("  Junior:  ", address(juniorImpl));
        console2.log("  Reserve: ", address(reserveImpl));
        console2.log("");
        console2.log("Proxies:");
        console2.log("  Senior:  ", SENIOR_PROXY);
        console2.log("  Junior:  ", JUNIOR_PROXY);
        console2.log("  Reserve: ", RESERVE_PROXY);
        console2.log("=================================================");
    }
}

