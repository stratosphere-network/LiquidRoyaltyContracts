// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UnifiedSeniorVault} from "../abstract/UnifiedSeniorVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IRewardVault} from "../integrations/IRewardVault.sol";


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
    
    /// @dev Reentrancy guard state (V3 upgrade - MUST be in concrete contract)
    uint256 private _status;
    IRewardVault private _rewardVault;

    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    error RewardVaultNotSet();
    
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
        
       
        if (liquidityManager_ == address(0)) revert ZeroAddress();
        if (priceFeedManager_ == address(0)) revert ZeroAddress();
        if (contractUpdater_ == address(0)) revert ZeroAddress();
        _liquidityManager = liquidityManager_;
        _priceFeedManager = priceFeedManager_;
        _contractUpdater = contractUpdater_;
    }
    
  
    function initializeV2(
        address liquidityManager_,
        address priceFeedManager_,
        address contractUpdater_
    ) external reinitializer(2) onlyAdmin {
        if (liquidityManager_ == address(0)) revert ZeroAddress();
        if (priceFeedManager_ == address(0)) revert ZeroAddress();
        if (contractUpdater_ == address(0)) revert ZeroAddress();
        _liquidityManager = liquidityManager_;
        _priceFeedManager = priceFeedManager_;
        _contractUpdater = contractUpdater_;
    }
    
   
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
        if (liquidityManager_ == address(0)) revert ZeroAddress();
        _liquidityManager = liquidityManager_;
    }
    
    function setPriceFeedManager(address priceFeedManager_) external onlyAdmin {
        if (priceFeedManager_ == address(0)) revert ZeroAddress();
        _priceFeedManager = priceFeedManager_;
    }
    
    function setContractUpdater(address contractUpdater_) external onlyAdmin {
        if (contractUpdater_ == address(0)) revert ZeroAddress();
        _contractUpdater = contractUpdater_;
    }
    
 
    function initializeV3() external reinitializer(3) onlyAdmin {
        
        _status = 1; 
    }
    

    function _getReentrancyStatus() internal view override returns (uint256) {
        return _status;
    }
   
    function _setReentrancyStatus(uint256 status) internal override {
        _status = status;
    }
    
 
    function _transferToJunior(uint256 amountUSD, uint256 lpPrice) internal override {
       
        if (amountUSD == 0) return;
        
        if (lpPrice == 0) revert InvalidLPPrice();
        if (address(kodiakHook) == address(0)) revert KodiakHookNotSet();
      
        address lpToken = address(kodiakHook.island());
        uint8 lpDecimals = IERC20Metadata(lpToken).decimals();
        
      
        uint256 lpAmount = Math.mulDiv(amountUSD, 10 ** lpDecimals, lpPrice);
        
        
        uint256 lpBalance = kodiakHook.getIslandLPBalance();
        uint256 actualLPAmount = lpAmount > lpBalance ? lpBalance : lpAmount;
        
        if (actualLPAmount == 0) return; // No LP tokens available
        
        // Get Junior's hook address
        address juniorHook = address(_juniorVault.kodiakHook());
        if (juniorHook == address(0)) return;
        
        // Transfer LP tokens from Senior Hook to Junior Hook
        kodiakHook.transferIslandLP(juniorHook, actualLPAmount);
        
        // SECURITY FIX: Use Math.mulDiv() for precise USD conversion
        // Update Junior vault value (convert LP amount back to USD, accounting for decimals)
        uint256 actualUSDAmount = Math.mulDiv(actualLPAmount, lpPrice, 10 ** lpDecimals);
        _juniorVault.receiveSpillover(actualUSDAmount);
    }
    
    /**
     * @notice Transfer LP tokens to Reserve vault
     * @dev Reference: Three-Zone System - Profit Spillover (20% to Reserve)
     * @param amountUSD Amount in USD to transfer
     * @param lpPrice Current LP token price in USD (18 decimals)
     */
    function _transferToReserve(uint256 amountUSD, uint256 lpPrice) internal override {
        // Allow graceful exit for zero transfers
        if (amountUSD == 0) return;
        // Critical: LP price must be valid
        if (lpPrice == 0) revert InvalidLPPrice();
        if (address(kodiakHook) == address(0)) revert KodiakHookNotSet();
        
        // LP DECIMALS FIX: Get LP token and its decimals
        address lpToken = address(kodiakHook.island());
        uint8 lpDecimals = IERC20Metadata(lpToken).decimals();
        
        // SECURITY FIX: Use Math.mulDiv() to avoid divide-before-multiply precision loss
        // Calculate LP amount from USD amount (accounting for LP decimals)
        // lpPrice is in 18 decimals (USD per LP token)
        // We need to convert to LP token's actual decimals
        uint256 lpAmount = Math.mulDiv(amountUSD, 10 ** lpDecimals, lpPrice);
        
        // Check Senior Hook's LP token balance
        uint256 lpBalance = kodiakHook.getIslandLPBalance();
        uint256 actualLPAmount = lpAmount > lpBalance ? lpBalance : lpAmount;
        
        if (actualLPAmount == 0) return; // No LP tokens available
        
        // Get Reserve's hook address
        address reserveHook = address(_reserveVault.kodiakHook());
        if (reserveHook == address(0)) return;
        
        // Transfer LP tokens from Senior Hook to Reserve Hook
        kodiakHook.transferIslandLP(reserveHook, actualLPAmount);
        
        // SECURITY FIX: Use Math.mulDiv() for precise USD conversion
        // Update Reserve vault value (convert LP amount back to USD, accounting for decimals)
        uint256 actualUSDAmount = Math.mulDiv(actualLPAmount, lpPrice, 10 ** lpDecimals);
        _reserveVault.receiveSpillover(actualUSDAmount);
    }
    
    /**
     * @notice Pull LP tokens from Reserve vault
     * @dev Reference: Three-Zone System - Primary Backstop (Reserve first)
     * @param amountUSD Amount in USD to receive
     * @param lpPrice Current LP token price in USD (18 decimals)
     * @return actualReceived Actual USD value received from Reserve
     */
    function _pullFromReserve(uint256 amountUSD, uint256 lpPrice) internal override returns (uint256 actualReceived) {
        if (amountUSD == 0) return 0;
        
        // SECURITY FIX: Check actual amount received from backstop
        // Request backstop from Reserve (transfers LP tokens based on USD amount and LP price)
        actualReceived = _reserveVault.provideBackstop(amountUSD, lpPrice);
        
        // PRECISION FIX: Only emit BackstopShortfall if significantly less than requested
        // Small differences (< 0.01%) can occur due to LP price conversion rounding
        // Don't treat rounding errors as Reserve depletion
        uint256 minAcceptable = (amountUSD * 9999) / 10000; // 99.99% of requested
        if (actualReceived < minAcceptable) {
            emit BackstopShortfall(address(_reserveVault), amountUSD, actualReceived);
        }
        
        return actualReceived;
    }
    
    /**
     * @notice Pull LP tokens from Junior vault
     * @dev Reference: Three-Zone System - Secondary Backstop (Junior if Reserve depleted)
     * @param amountUSD Amount in USD to receive
     * @param lpPrice Current LP token price in USD (18 decimals)
     * @return actualReceived Actual USD value received from Junior
     */
    function _pullFromJunior(uint256 amountUSD, uint256 lpPrice) internal override returns (uint256 actualReceived) {
        if (amountUSD == 0) return 0;
        
        // SECURITY FIX: Check actual amount received from backstop
        // Request backstop from Junior (transfers LP tokens based on USD amount and LP price)
        actualReceived = _juniorVault.provideBackstop(amountUSD, lpPrice);
        
        // PRECISION FIX: Only emit BackstopShortfall if significantly less than requested
        // Small differences (< 0.01%) can occur due to LP price conversion rounding
        // Don't treat rounding errors as Junior depletion
        uint256 minAcceptable = (amountUSD * 9999) / 10000; // 99.99% of requested
        if (actualReceived < minAcceptable) {
            emit BackstopShortfall(address(_juniorVault), amountUSD, actualReceived);
        }
        
        return actualReceived;
    }
    
    /// @dev Event for tracking backstop shortfalls
    event BackstopShortfall(address indexed vault, uint256 requested, uint256 received);
    
    /// @dev Event for reward vault changes
    event RewardVaultSet(address indexed oldVault, address indexed newVault);
    event StakedIntoRewardVault(uint256 amount);
    event WithdrawnFromRewardVault(uint256 amount);
    event BGTClaimed(address indexed recipient, uint256 amount);
    
    // ============================================
    // Reward Vault Management
    // ============================================
    
    /**
     * @notice Get the current reward vault address
     * @return rewardVault The reward vault contract
     */
    function rewardVault() external view returns (IRewardVault) {
        return _rewardVault;
    }
    
    /**
     * @notice Set the reward vault address
     * @dev Only admin can set the reward vault
     * @param rewardVault_ Address of the new reward vault
     */
    function setRewardVault(address rewardVault_) external onlyAdmin {
        if (rewardVault_ == address(0)) revert ZeroAddress();
        address oldVault = address(_rewardVault);
        _rewardVault = IRewardVault(rewardVault_);
        emit RewardVaultSet(oldVault, rewardVault_);
    }

    /**
     * @notice Stake LP tokens into the reward vault for BGT emissions
     * @dev Transfers LP from KodiakHook to this contract, approves, then stakes
     * @param amount Amount of LP tokens to stake
     */
    function stakeIntoRewardVault(uint256 amount) external onlyAdmin nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (address(_rewardVault) == address(0)) revert RewardVaultNotSet();
        if (address(kodiakHook) == address(0)) revert KodiakHookNotSet();
        
        address lpToken = address(kodiakHook.island());
        
        // Transfer LP tokens from KodiakHook to this contract
        kodiakHook.transferIslandLP(address(this), amount);
        
        // Approve reward vault to spend LP tokens
        IERC20(lpToken).approve(address(_rewardVault), amount);
        
        // Stake into reward vault (pulls tokens via transferFrom)
        _rewardVault.delegateStake(address(this), amount);
        
        emit StakedIntoRewardVault(amount);
    }
    
    /**
     * @notice Withdraw LP tokens from the reward vault
     * @param amount Amount of LP tokens to withdraw
     */
    function withdrawFromRewardVault(uint256 amount) external onlyAdmin nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (address(_rewardVault) == address(0)) revert RewardVaultNotSet();
        if (address(kodiakHook) == address(0)) revert KodiakHookNotSet();
        
        _rewardVault.delegateWithdraw(address(this), amount);
        IERC20(address(kodiakHook.island())).transfer(address(kodiakHook), amount);
        
        emit WithdrawnFromRewardVault(amount);
    }

    /**
     * @notice Claim BGT emissions from the reward vault
     * @dev Claims all available BGT rewards and sends to admin
     * @return claimed Amount of BGT claimed
     */
    function claimBGT() external onlyAdmin nonReentrant returns (uint256 claimed) {
        if (address(_rewardVault) == address(0)) revert RewardVaultNotSet();
        
        // Claim BGT rewards - sends to msg.sender (admin)
        claimed = _rewardVault.getReward(address(this), msg.sender);
        
        emit BGTClaimed(msg.sender, claimed);
    }
    





    
  
}




