// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UnifiedSeniorVault} from "../abstract/UnifiedSeniorVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IRewardVault} from "../integrations/IRewardVault.sol";
import {MathLib} from "../libraries/MathLib.sol";
import {FeeLib} from "../libraries/FeeLib.sol";
import {RebaseLib} from "../libraries/RebaseLib.sol";
import {SpilloverLib} from "../libraries/SpilloverLib.sol";


/// @title UnifiedConcreteSeniorVault - Senior vault with V4 non-rebasing migration
contract UnifiedConcreteSeniorVault is UnifiedSeniorVault {
    using SafeERC20 for IERC20;
    
    address private _liquidityManager;
    address private _priceFeedManager;
    address private _contractUpdater;
    address private _liquidityManagerVault;
    uint256 private _status;
    IRewardVault private _rewardVault;
    
    enum Action { STAKE, WITHDRAW }
    enum RoleType { LIQUIDITY_MANAGER, PRICE_FEED_MANAGER, CONTRACT_UPDATER, LIQUIDITY_MANAGER_VAULT }
    
    constructor() { _disableInitializers(); }
    
    error RewardVaultNotSet();
    
    function initialize(
        address stablecoin_, string memory tokenName_, string memory tokenSymbol_,
        address juniorVault_, address reserveVault_, address treasury_,
        uint256 initialValue_, address lm, address pf, address cu
    ) external initializer {
        __UnifiedSeniorVault_init(stablecoin_, tokenName_, tokenSymbol_, juniorVault_, reserveVault_, treasury_, initialValue_);
        if (lm == address(0) || pf == address(0) || cu == address(0)) revert ZeroAddress();
        _liquidityManager = lm; _priceFeedManager = pf; _contractUpdater = cu;
    }
    
    function initializeV2(address lm, address pf, address cu) external reinitializer(2) onlyAdmin {
        if (lm == address(0) || pf == address(0) || cu == address(0)) revert ZeroAddress();
        _liquidityManager = lm; _priceFeedManager = pf; _contractUpdater = cu;
    }
    
    function liquidityManager() public view override returns (address) { return _liquidityManager; }
    function priceFeedManager() public view override returns (address) { return _priceFeedManager; }
    function contractUpdater() public view override returns (address) { return _contractUpdater; }
    function liquidityManagerVault() public view override returns (address) { return _liquidityManagerVault; }
    
    function setRole(RoleType role, address account) external onlyAdmin {
        if (account == address(0)) revert ZeroAddress();
        if (role == RoleType.LIQUIDITY_MANAGER) _liquidityManager = account;
        else if (role == RoleType.PRICE_FEED_MANAGER) _priceFeedManager = account;
        else if (role == RoleType.CONTRACT_UPDATER) _contractUpdater = account;
        else if (role == RoleType.LIQUIDITY_MANAGER_VAULT) {
            _liquidityManagerVault = account;
            emit AdminControlled.LiquidityManagerVaultSet(account);
        }
    }
    
    function setLiquidityManagerVault(address lm) external onlyAdmin {
        if (lm == address(0)) revert ZeroAddress();
        _liquidityManagerVault = lm;
        emit AdminControlled.LiquidityManagerVaultSet(lm);
    }
    
    function initializeV3() external reinitializer(3) onlyAdmin { _status = 1; }
    
    function _getReentrancyStatus() internal view override returns (uint256) { return _status; }
    function _setReentrancyStatus(uint256 status) internal override { _status = status; }
    function _getRewardVault() internal view override returns (IRewardVault) { return _rewardVault; }
 
    function _transferToJunior(uint256 amountUSD, uint256 lpPrice) internal override {
        address hook = address(_juniorVault.kodiakHook());
        if (hook == address(0)) return;
        (uint256 actualLP, uint8 dec) = _prepareLPTransfer(amountUSD, lpPrice);
        if (actualLP == 0) return;
        kodiakHook.transferIslandLP(hook, actualLP);
        _juniorVault.receiveSpillover(Math.mulDiv(actualLP, lpPrice, 10 ** dec));
    }
    
    function _transferToReserve(uint256 amountUSD, uint256 lpPrice) internal override {
        address hook = address(_reserveVault.kodiakHook());
        if (hook == address(0)) return;
        (uint256 actualLP, uint8 dec) = _prepareLPTransfer(amountUSD, lpPrice);
        if (actualLP == 0) return;
        kodiakHook.transferIslandLP(hook, actualLP);
        _reserveVault.receiveSpillover(Math.mulDiv(actualLP, lpPrice, 10 ** dec));
    }
    
    function _prepareLPTransfer(uint256 amountUSD, uint256 lpPrice) internal returns (uint256 actualLP, uint8 dec) {
        if (amountUSD == 0) return (0, 0);
        if (lpPrice == 0) revert InvalidLPPrice();
        if (address(kodiakHook) == address(0)) revert KodiakHookNotSet();
        address lp = address(kodiakHook.island());
        dec = IERC20Metadata(lp).decimals();
        uint256 need = Math.mulDiv(amountUSD, 10 ** dec, lpPrice);
        uint256 bal = kodiakHook.getIslandLPBalance();
        if (bal < need && address(_rewardVault) != address(0)) {
            uint256 w = need - bal; uint256 s = _rewardVault.getTotalDelegateStaked(admin());
            if (w > s) w = s;
            if (w > 0) { _rewardVault.delegateWithdraw(admin(), w); IERC20(lp).safeTransfer(address(kodiakHook), w); bal = kodiakHook.getIslandLPBalance(); }
        }
        actualLP = need > bal ? bal : need;
    }
    
    function _pullFromReserve(uint256 amountUSD, uint256 lpPrice) internal override returns (uint256) {
        return amountUSD == 0 ? 0 : _reserveVault.provideBackstop(amountUSD, lpPrice);
    }
    
    function _pullFromJunior(uint256 amountUSD, uint256 lpPrice) internal override returns (uint256) {
        return amountUSD == 0 ? 0 : _juniorVault.provideBackstop(amountUSD, lpPrice);
    }
    
    // V4 STORAGE (MUST remain at end)
    bool private _migrated;
    mapping(address => uint256) private _directBalances;
    uint256 private _directTotalSupply;
    uint256 private _frozenRebaseIndex;
    uint256 private _epochAtMigration;
    uint256 private _postMigrationEpochOffset;
    mapping(address => bool) private _userMigrated;
    
    function rewardVault() external view returns (IRewardVault) { return _rewardVault; }
    function setRewardVault(address rv) external onlyAdmin { if (rv == address(0)) revert ZeroAddress(); _rewardVault = IRewardVault(rv); }

    function executeRewardVaultActions(Action action, uint256 amount) external onlyAdmin nonReentrant {
        if (address(_rewardVault) == address(0)) revert RewardVaultNotSet();
        if (amount == 0 || address(kodiakHook) == address(0)) revert InvalidAmount();
        address lp = address(kodiakHook.island());
        if (action == Action.STAKE) { kodiakHook.transferIslandLP(address(this), amount); IERC20(lp).approve(address(_rewardVault), amount); _rewardVault.delegateStake(admin(), amount); }
        else { _rewardVault.delegateWithdraw(admin(), amount); IERC20(lp).safeTransfer(address(kodiakHook), amount); }
    }
    
    error AlreadyMigrated();
    
    function initializeV4() external reinitializer(4) onlyAdmin {}
    
    function migrateToNonRebasing() external onlyAdmin {
        if (_migrated) revert AlreadyMigrated();
        _frozenRebaseIndex = rebaseIndex();
        _epochAtMigration = epoch();
        _directTotalSupply = MathLib.calculateBalanceFromShares(totalShares(), _frozenRebaseIndex);
        _migrated = true;
    }
    
    function migrateUsers(address[] calldata users) external {
        if (msg.sender != admin() && msg.sender != _liquidityManager) revert OnlyAdmin();
        require(_migrated);
        for (uint256 i; i < users.length; ++i) {
            address u = users[i];
            if (_userMigrated[u]) continue;
            uint256 s = super.sharesOf(u);
            if (s > 0) _directBalances[u] = MathLib.calculateBalanceFromShares(s, _frozenRebaseIndex);
            _userMigrated[u] = true;
        }
    }
    
    function balanceOf(address account) public view override returns (uint256) {
        if (!_migrated) return MathLib.calculateBalanceFromShares(super.sharesOf(account), super.rebaseIndex());
        if (_userMigrated[account]) return _directBalances[account];
        return MathLib.calculateBalanceFromShares(super.sharesOf(account), _frozenRebaseIndex);
    }
    
    function totalSupply() public view override returns (uint256) {
        return _migrated ? _directTotalSupply : MathLib.calculateBalanceFromShares(super.totalShares(), super.rebaseIndex());
    }
    
    function rebaseIndex() public view override returns (uint256) {
        return _migrated ? _frozenRebaseIndex : super.rebaseIndex();
    }
    
    function _transfer(address from, address to, uint256 amount) internal override {
        if (!_migrated) { super._transfer(from, to, amount); return; }
        if (from == address(0) || to == address(0)) revert InvalidRecipient();
        _ensureDirectBalance(from); _ensureDirectBalance(to);
        if (_directBalances[from] < amount) revert InvalidAmount();
        _directBalances[from] -= amount;
        _directBalances[to] += amount;
        emit Transfer(from, to, amount);
    }
    
    function _mint(address to, uint256 amount) internal override {
        if (!_migrated) { super._mint(to, amount); return; }
        if (to == address(0)) revert InvalidRecipient();
        _ensureDirectBalance(to);
        _directBalances[to] += amount;
        _directTotalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function _burn(address from, uint256 amount) internal override {
        if (!_migrated) { super._burn(from, amount); return; }
        if (from == address(0)) revert InvalidRecipient();
        _ensureDirectBalance(from);
        if (_directBalances[from] < amount) revert InvalidAmount();
        _directBalances[from] -= amount;
        _directTotalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }
    
    function _ensureDirectBalance(address account) internal {
        if (!_userMigrated[account]) {
            uint256 s = super.sharesOf(account);
            if (s > 0) _directBalances[account] = MathLib.calculateBalanceFromShares(s, _frozenRebaseIndex);
            _userMigrated[account] = true;
        }
    }
    function rebase(uint256 lpPrice) public override onlyAdmin {
        if (!_migrated) { super.rebase(lpPrice); return; }
        if (block.timestamp < _lastRebaseTime + _minRebaseInterval) revert RebaseTooSoon();
        if (lpPrice == 0 || _directTotalSupply == 0) revert InvalidAmount();
        
        uint256 timeElapsed = block.timestamp - _lastRebaseTime;
        uint256 mgmtFee = FeeLib.calculateManagementFeeTokens(_vaultValue, timeElapsed);
        RebaseLib.APYSelection memory sel = RebaseLib.selectDynamicAPY(_directTotalSupply, _vaultValue, timeElapsed, mgmtFee);
        
        uint256 projected = _directTotalSupply + sel.userTokens + sel.feeTokens + mgmtFee;
        SpilloverLib.Zone zone = SpilloverLib.determineZone(MathLib.calculateBackingRatio(_vaultValue, projected));
        
        if (zone == SpilloverLib.Zone.SPILLOVER) _executeProfitSpillover(_vaultValue, projected, lpPrice);
        else if (zone == SpilloverLib.Zone.BACKSTOP || sel.backstopNeeded) _executeBackstop(_vaultValue, projected, lpPrice);
        
        uint256 yield = sel.userTokens + sel.feeTokens + mgmtFee;
        if (yield > 0) { _ensureDirectBalance(admin()); _directBalances[admin()] += yield; _directTotalSupply += yield; emit Transfer(address(0), admin(), yield); }
        _postMigrationEpochOffset++;
        _lastRebaseTime = block.timestamp;
        emit RebaseExecuted(_epochAtMigration + _postMigrationEpochOffset, sel.apyTier, _frozenRebaseIndex, _frozenRebaseIndex, _directTotalSupply, zone);
        emit FeesCollected(mgmtFee, sel.feeTokens);
    }
    
    function epoch() public view override returns (uint256) {
        return _migrated ? _epochAtMigration + _postMigrationEpochOffset : super.epoch();
    }
    
    /**
     * @notice Invest tokens into Kodiak (transfer from LiquidityManagerVault to vault)
     * @dev Only callable by LiquidityManagerVault role
     * @dev Token must be whitelisted (LP token or stablecoin)
     * @param token Token address to invest (USDe, SAIL.r, etc.)
     * @param amount Amount of tokens to transfer
     */
    function investInKodiak(address token, uint256 amount) external onlyLiquidityManagerVault {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        // Check if token is whitelisted LP token or is the stablecoin
        if (!_isWhitelistedLPToken[token] && token != address(_stablecoin)) revert WhitelistedLPNotFound();
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    }
}

