// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";

interface IKodiakHook {
    function getIslandLPBalance() external view returns (uint256);
    function adminRescueTokens(address token, address to, uint256 amount) external;
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

contract TransferLPToNewHooks is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Old hooks (have LP tokens)
        address OLD_SENIOR_HOOK = 0x84a6b0727A55E9c337d31986098E834eCaD65E9b;
        address OLD_JUNIOR_HOOK = 0x2a3Fa663E1Dd4087A46A27C2aabc94F0Fe0C0892;
        address OLD_RESERVE_HOOK = 0x5f28caF1B54819d24a5CaA58EEBd3272e56DC793;
        
        // New hooks (need LP tokens)
        address NEW_SENIOR_HOOK = 0x5256B4628F4A315c35C77A2DfbE968d9b4C4A261;
        address NEW_JUNIOR_HOOK = 0x4c40B07F9589d3D6DD2996113f1317c64dCB7255;
        address NEW_RESERVE_HOOK = 0xFf046FaF98025817348618615a6eDA91B4f28Bb3;
        
        // Kodiak Island LP token
        address KODIAK_ISLAND = 0xf6b16E73d3b0e2784AAe8C4cd06099BE65d092Bf;
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("=== TRANSFERRING LP TOKENS TO NEW HOOKS ===");
        console.log("");
        
        // Senior Hook
        console.log("=== SENIOR HOOK ===");
        uint256 seniorLP = IKodiakHook(OLD_SENIOR_HOOK).getIslandLPBalance();
        console.log("Old hook LP balance:", seniorLP);
        if (seniorLP > 0) {
            IKodiakHook(OLD_SENIOR_HOOK).adminRescueTokens(KODIAK_ISLAND, NEW_SENIOR_HOOK, seniorLP);
            console.log("Transferred to new hook!");
        } else {
            console.log("No LP to transfer");
        }
        uint256 newSeniorLP = IERC20(KODIAK_ISLAND).balanceOf(NEW_SENIOR_HOOK);
        console.log("New hook LP balance:", newSeniorLP);
        console.log("");
        
        // Junior Hook
        console.log("=== JUNIOR HOOK ===");
        uint256 juniorLP = IKodiakHook(OLD_JUNIOR_HOOK).getIslandLPBalance();
        console.log("Old hook LP balance:", juniorLP);
        if (juniorLP > 0) {
            IKodiakHook(OLD_JUNIOR_HOOK).adminRescueTokens(KODIAK_ISLAND, NEW_JUNIOR_HOOK, juniorLP);
            console.log("Transferred to new hook!");
        } else {
            console.log("No LP to transfer");
        }
        uint256 newJuniorLP = IERC20(KODIAK_ISLAND).balanceOf(NEW_JUNIOR_HOOK);
        console.log("New hook LP balance:", newJuniorLP);
        console.log("");
        
        // Reserve Hook
        console.log("=== RESERVE HOOK ===");
        uint256 reserveLP = IKodiakHook(OLD_RESERVE_HOOK).getIslandLPBalance();
        console.log("Old hook LP balance:", reserveLP);
        if (reserveLP > 0) {
            IKodiakHook(OLD_RESERVE_HOOK).adminRescueTokens(KODIAK_ISLAND, NEW_RESERVE_HOOK, reserveLP);
            console.log("Transferred to new hook!");
        } else {
            console.log("No LP to transfer");
        }
        uint256 newReserveLP = IERC20(KODIAK_ISLAND).balanceOf(NEW_RESERVE_HOOK);
        console.log("New hook LP balance:", newReserveLP);
        console.log("");
        
        vm.stopBroadcast();
        
        console.log("=== TRANSFER COMPLETE ===");
        console.log("New hooks now have LP tokens and can process withdrawals!");
    }
}




