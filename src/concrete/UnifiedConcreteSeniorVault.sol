// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UnifiedSeniorVault} from "../abstract/UnifiedSeniorVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
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
    using SafeERC20 for IERC20;
    
    /// @dev NEW role management (V2 upgrade)
    /// These are added here instead of AdminControlled to preserve storage layout
    address private _liquidityManager;
    address private _priceFeedManager;
    address private _contractUpdater;
    
    /// @dev Reentrancy guard state (V3 upgrade - MUST be in concrete contract)
    uint256 private _status;
    IRewardVault private _rewardVault;
    /// @dev Action enum for reward vault actions
    enum Action {
        STAKE,
        WITHDRAW
      
    }
    
    /// @dev Role types for consolidated role setter
    enum RoleType {
        LIQUIDITY_MANAGER,
        PRICE_FEED_MANAGER,
        CONTRACT_UPDATER
    }

    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    error RewardVaultNotSet();
    error InvalidAction();
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
    
    /**
     * @notice Set role address (consolidated setter to reduce contract size)
     * @dev Replaces setLiquidityManager, setPriceFeedManager, setContractUpdater
     * @param role The role type to set
     * @param account The address to assign the role to
     */
    function setRole(RoleType role, address account) external onlyAdmin {
        if (account == address(0)) revert ZeroAddress();
        
        if (role == RoleType.LIQUIDITY_MANAGER) {
            _liquidityManager = account;
        } else if (role == RoleType.PRICE_FEED_MANAGER) {
            _priceFeedManager = account;
        } else if (role == RoleType.CONTRACT_UPDATER) {
            _contractUpdater = account;
        }
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
    
    function _getRewardVault() internal view override returns (IRewardVault) {
        return _rewardVault;
    }
 
    function _transferToJunior(uint256 amountUSD, uint256 lpPrice) internal override {
       
        if (amountUSD == 0) return;
        
        if (lpPrice == 0) revert InvalidLPPrice();
        if (address(kodiakHook) == address(0)) revert KodiakHookNotSet();
      
        address lpToken = address(kodiakHook.island());
        uint8 lpDecimals = IERC20Metadata(lpToken).decimals();
        
        // Calculate LP amount needed from USD
        uint256 lpAmount = Math.mulDiv(amountUSD, 10 ** lpDecimals, lpPrice);
        
        // Check Senior Hook's LP token balance
        uint256 lpBalance = kodiakHook.getIslandLPBalance();
        
        // If hook doesn't have enough LP, try to withdraw from reward vault
        if (lpBalance < lpAmount && address(_rewardVault) != address(0)) {
            uint256 lpDeficit = lpAmount - lpBalance;
            // Check staked balance before withdrawing
            uint256 stakedBalance = _rewardVault.getTotalDelegateStaked(admin());
            uint256 lpToWithdraw = lpDeficit > stakedBalance ? stakedBalance : lpDeficit;
            
            if (lpToWithdraw > 0) {
                // Withdraw LP from reward vault to this contract
                _rewardVault.delegateWithdraw(admin(), lpToWithdraw);
                // Transfer LP tokens to kodiakHook
                IERC20(lpToken).safeTransfer(address(kodiakHook), lpToWithdraw);
                // Update lpBalance after withdrawal
                lpBalance = kodiakHook.getIslandLPBalance();
            }
        }
        
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
        uint256 lpAmount = Math.mulDiv(amountUSD, 10 ** lpDecimals, lpPrice);
        
        // Check Senior Hook's LP token balance
        uint256 lpBalance = kodiakHook.getIslandLPBalance();
        
        // If hook doesn't have enough LP, try to withdraw from reward vault
        if (lpBalance < lpAmount && address(_rewardVault) != address(0)) {
            uint256 lpDeficit = lpAmount - lpBalance;
            // Check staked balance before withdrawing
            uint256 stakedBalance = _rewardVault.getTotalDelegateStaked(admin());
            uint256 lpToWithdraw = lpDeficit > stakedBalance ? stakedBalance : lpDeficit;
            
            if (lpToWithdraw > 0) {
                // Withdraw LP from reward vault to this contract
                _rewardVault.delegateWithdraw(admin(), lpToWithdraw);
                // Transfer LP tokens to kodiakHook
                IERC20(lpToken).safeTransfer(address(kodiakHook), lpToWithdraw);
                // Update lpBalance after withdrawal
                lpBalance = kodiakHook.getIslandLPBalance();
            }
        }
        
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
     * @notice Execute reward vault actions (stake, withdraw, or claim BGT)
     * @dev Consolidated function to reduce bytecode size
     * @param action The action to perform (STAKE, WITHDRAW, or CLAIM_BGT)
     * @param amount Amount for stake/withdraw (ignored for CLAIM_BGT)
     */
    function executeRewardVaultActions(Action action, uint256 amount) external onlyAdmin nonReentrant {
        // Common check: reward vault must be set
        if (address(_rewardVault) == address(0)) revert RewardVaultNotSet();
        
        if (action == Action.STAKE) {
            if (amount == 0) revert InvalidAmount();
            if (address(kodiakHook) == address(0)) revert KodiakHookNotSet();
            
            address lpToken = address(kodiakHook.island());
            kodiakHook.transferIslandLP(address(this), amount);
            IERC20(lpToken).approve(address(_rewardVault), amount);
            _rewardVault.delegateStake(admin(), amount);
            
            emit StakedIntoRewardVault(amount);
        } else if (action == Action.WITHDRAW) {
            if (amount == 0) revert InvalidAmount();
            if (address(kodiakHook) == address(0)) revert KodiakHookNotSet();
            
            _rewardVault.delegateWithdraw(admin(), amount);
            IERC20(address(kodiakHook.island())).safeTransfer(address(kodiakHook), amount);
            
            emit WithdrawnFromRewardVault(amount);
        }  else {
            revert InvalidAction();
        }
    }
}
    





    
  





