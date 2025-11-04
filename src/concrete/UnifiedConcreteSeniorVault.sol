// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UnifiedSeniorVault} from "../abstract/UnifiedSeniorVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title UnifiedConcreteSeniorVault
 * @notice Concrete implementation of unified Senior vault (IS snrUSD token)
 * @dev Single contract = vault + token logic (RECOMMENDED ARCHITECTURE)
 * @dev Upgradeable using UUPS proxy pattern
 * 
 * Architecture Benefits:
 * - Simpler: One contract instead of two
 * - More secure: No cross-contract synchronization
 * - Better UX: Users hold snrUSD directly
 * - Gas efficient: No external calls for token operations
 * - Battle-tested: Pattern used by successful rebasing tokens
 */
contract UnifiedConcreteSeniorVault is UnifiedSeniorVault {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @notice Initialize unified Senior vault (IS snrUSD)
     * @param lpToken_ LP token address (e.g., USDe-SAIL)
     * @param tokenName_ Token name ("Senior USD")
     * @param tokenSymbol_ Token symbol ("snrUSD")
     * @param juniorVault_ Junior vault address
     * @param reserveVault_ Reserve vault address
     * @param treasury_ Treasury address
     * @param initialValue_ Initial vault value in USD
     */
    function initialize(
        address lpToken_,
        string memory tokenName_,
        string memory tokenSymbol_,
        address juniorVault_,
        address reserveVault_,
        address treasury_,
        uint256 initialValue_
    ) external initializer {
        __UnifiedSeniorVault_init(
            lpToken_,
            tokenName_,
            tokenSymbol_,
            juniorVault_,
            reserveVault_,
            treasury_,
            initialValue_
        );
    }
    
    // ============================================
    // Asset Transfer Implementation
    // ============================================
    
    /**
     * @notice Transfer LP tokens to Junior vault
     * @dev Reference: Three-Zone System - Profit Spillover (80% to Junior)
     */
    function _transferToJunior(uint256 amount) internal override {
        if (amount == 0) return;
        
        // Transfer LP tokens from this vault to Junior vault
        _lpToken.transfer(address(_juniorVault), amount);
        
        // Update Junior vault value (they track USD value internally)
        _juniorVault.receiveSpillover(amount);
    }
    
    /**
     * @notice Transfer LP tokens to Reserve vault
     * @dev Reference: Three-Zone System - Profit Spillover (20% to Reserve)
     */
    function _transferToReserve(uint256 amount) internal override {
        if (amount == 0) return;
        
        // Transfer LP tokens from this vault to Reserve vault
        _lpToken.transfer(address(_reserveVault), amount);
        
        // Update Reserve vault value (they track USD value internally)
        _reserveVault.receiveSpillover(amount);
    }
    
    /**
     * @notice Pull LP tokens from Reserve vault
     * @dev Reference: Three-Zone System - Primary Backstop (Reserve first)
     * Uses transferToSenior to avoid approval requirements (fix issue #2)
     */
    function _pullFromReserve(uint256 amount) internal override {
        if (amount == 0) return;
        
        // Request backstop from Reserve (updates their _vaultValue AND transfers LP tokens)
        _reserveVault.provideBackstop(amount);
        
        // No need for transferFrom - Reserve calls transferToSenior internally
    }
    
    /**
     * @notice Pull LP tokens from Junior vault
     * @dev Reference: Three-Zone System - Secondary Backstop (Junior if Reserve depleted)
     * Uses transferToSenior to avoid approval requirements (fix issue #2)
     */
    function _pullFromJunior(uint256 amount) internal override {
        if (amount == 0) return;
        
        // Request backstop from Junior (updates their _vaultValue AND transfers LP tokens)
        _juniorVault.provideBackstop(amount);
        
        // No need for transferFrom - Junior calls transferToSenior internally
    }
}

