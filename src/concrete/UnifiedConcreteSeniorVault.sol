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
    /// @dev NEW role management (V2 upgrade)
    /// These are added here instead of AdminControlled to preserve storage layout
    address private _liquidityManager;
    address private _priceFeedManager;
    address private _contractUpdater;
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @notice Initialize unified Senior vault (IS snrUSD)
     * @param stablecoin_ Stablecoin address (e.g., USDe-SAIL)
     * @param tokenName_ Token name ("Senior USD")
     * @param tokenSymbol_ Token symbol ("snrUSD")
     * @param juniorVault_ Junior vault address
     * @param reserveVault_ Reserve vault address
     * @param treasury_ Treasury address
     * @param initialValue_ Initial vault value in USD
     * @param liquidityManager_ Liquidity manager address (N1 FIX: moved from V2)
     * @param priceFeedManager_ Price feed manager address (N1 FIX: moved from V2)
     * @param contractUpdater_ Contract updater address (N1 FIX: moved from V2)
     */
    function initialize(
        address stablecoin_,
        string memory tokenName_,
        string memory tokenSymbol_,
        address juniorVault_,
        address reserveVault_,
        address treasury_,
        uint256 initialValue_,
        address liquidityManager_,
        address priceFeedManager_,
        address contractUpdater_
    ) external initializer {
        __UnifiedSeniorVault_init(
            stablecoin_,
            tokenName_,
            tokenSymbol_,
            juniorVault_,
            reserveVault_,
            treasury_,
            initialValue_
        );
        
        // N1 FIX: Set roles during initialization (consolidated from initializeV2)
        _liquidityManager = liquidityManager_;
        _priceFeedManager = priceFeedManager_;
        _contractUpdater = contractUpdater_;
    }
    
    /**
     * @notice Initialize V2 - DEPRECATED (kept for backward compatibility)
     * @dev N1: Redundant - new deployments should use initialize() with all params
     * @dev Only kept for contracts already deployed with V1 initialize()
     */
    function initializeV2(
        address liquidityManager_,
        address priceFeedManager_,
        address contractUpdater_
    ) external reinitializer(2) {
        _liquidityManager = liquidityManager_;
        _priceFeedManager = priceFeedManager_;
        _contractUpdater = contractUpdater_;
    }
    
    // Role getters (override base)
    function liquidityManager() public view override returns (address) {
        return _liquidityManager;
    }
    
    function priceFeedManager() public view override returns (address) {
        return _priceFeedManager;
    }
    
    function contractUpdater() public view override returns (address) {
        return _contractUpdater;
    }
    
    // Role setters
    function setLiquidityManager(address liquidityManager_) external onlyAdmin {
        _liquidityManager = liquidityManager_;
    }
    
    function setPriceFeedManager(address priceFeedManager_) external onlyAdmin {
        _priceFeedManager = priceFeedManager_;
    }
    
    function setContractUpdater(address contractUpdater_) external onlyAdmin {
        _contractUpdater = contractUpdater_;
    }
    
    // ============================================
    // Asset Transfer Implementation
    // ============================================
    
    /**
     * @notice Transfer LP tokens to Junior vault
     * @dev Reference: Three-Zone System - Profit Spillover (80% to Junior)
     * @param amountUSD Amount in USD to transfer
     * @param lpPrice Current LP token price in USD (18 decimals)
     */
    function _transferToJunior(uint256 amountUSD, uint256 lpPrice) internal override {
        if (amountUSD == 0) return;
        if (lpPrice == 0) return;
        if (address(kodiakHook) == address(0)) return;
        
        // Calculate LP amount from USD amount
        // LP amount = (amountUSD * 1e18) / lpPrice
        uint256 lpAmount = (amountUSD * 1e18) / lpPrice;
        
        // Check Senior Hook's LP token balance
        uint256 lpBalance = kodiakHook.getIslandLPBalance();
        uint256 actualLPAmount = lpAmount > lpBalance ? lpBalance : lpAmount;
        
        if (actualLPAmount == 0) return; // No LP tokens available
        
        // Get Junior's hook address
        address juniorHook = address(_juniorVault.kodiakHook());
        if (juniorHook == address(0)) return;
        
        // Transfer LP tokens from Senior Hook to Junior Hook
        kodiakHook.transferIslandLP(juniorHook, actualLPAmount);
        
        // Update Junior vault value (they track USD value internally)
        uint256 actualUSDAmount = (actualLPAmount * lpPrice) / 1e18;
        _juniorVault.receiveSpillover(actualUSDAmount);
    }
    
    /**
     * @notice Transfer LP tokens to Reserve vault
     * @dev Reference: Three-Zone System - Profit Spillover (20% to Reserve)
     * @param amountUSD Amount in USD to transfer
     * @param lpPrice Current LP token price in USD (18 decimals)
     */
    function _transferToReserve(uint256 amountUSD, uint256 lpPrice) internal override {
        if (amountUSD == 0) return;
        if (lpPrice == 0) return;
        if (address(kodiakHook) == address(0)) return;
        
        // Calculate LP amount from USD amount
        // LP amount = (amountUSD * 1e18) / lpPrice
        uint256 lpAmount = (amountUSD * 1e18) / lpPrice;
        
        // Check Senior Hook's LP token balance
        uint256 lpBalance = kodiakHook.getIslandLPBalance();
        uint256 actualLPAmount = lpAmount > lpBalance ? lpBalance : lpAmount;
        
        if (actualLPAmount == 0) return; // No LP tokens available
        
        // Get Reserve's hook address
        address reserveHook = address(_reserveVault.kodiakHook());
        if (reserveHook == address(0)) return;
        
        // Transfer LP tokens from Senior Hook to Reserve Hook
        kodiakHook.transferIslandLP(reserveHook, actualLPAmount);
        
        // Update Reserve vault value (they track USD value internally)
        uint256 actualUSDAmount = (actualLPAmount * lpPrice) / 1e18;
        _reserveVault.receiveSpillover(actualUSDAmount);
    }
    
    /**
     * @notice Pull LP tokens from Reserve vault
     * @dev Reference: Three-Zone System - Primary Backstop (Reserve first)
     * @param amountUSD Amount in USD to receive
     * @param lpPrice Current LP token price in USD (18 decimals)
     */
    function _pullFromReserve(uint256 amountUSD, uint256 lpPrice) internal override {
        if (amountUSD == 0) return;
        
        // Request backstop from Reserve (transfers LP tokens based on USD amount and LP price)
        _reserveVault.provideBackstop(amountUSD, lpPrice);
    }
    
    /**
     * @notice Pull LP tokens from Junior vault
     * @dev Reference: Three-Zone System - Secondary Backstop (Junior if Reserve depleted)
     * @param amountUSD Amount in USD to receive
     * @param lpPrice Current LP token price in USD (18 decimals)
     */
    function _pullFromJunior(uint256 amountUSD, uint256 lpPrice) internal override {
        if (amountUSD == 0) return;
        
        // Request backstop from Junior (transfers LP tokens based on USD amount and LP price)
        _juniorVault.provideBackstop(amountUSD, lpPrice);
    }
}

