// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IBurnMintERC20} from "../interfaces/IBurnMintERC20.sol";

/// @title BaseSeniorVault
/// @notice UUPS ERC-4626 snrUSD share on Base (Path1). User flows use 1:1 USDe↔snrUSD — never
///         `convertToShares(totalAssets())`, because CCT bridge mint/burn changes supply without moving USDe.
/// @dev NAV / oracle pricing lives on an off-chain keeper reporting into Meta Senior on Berachain.
contract BaseSeniorVault is
    ERC4626Upgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    IBurnMintERC20
{
    using SafeERC20 for IERC20;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _reentrancyStatus;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    uint256 public constant COOLDOWN_PERIOD = 7 days;
    uint256 public constant REDEEM_FEE_BPS = 30;
    uint256 public constant MANAGEMENT_FEE_BPS = 8;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant REBALANCE_INTERVAL = 30 days;

    address public immutable INITIAL_ADMIN;

    address public usde;
    address public feeAddress;
    address public liquidityManagerVault;
    uint256 public depositCap;
    uint256 public lastRebalanceTimestamp;

    struct CooldownInfo {
        uint256 sharesToBurn;
        uint256 cooldownEnd;
        bool active;
    }

    mapping(address => CooldownInfo) public cooldowns;
    mapping(address => bool) public whitelistedUsers;
    mapping(address => bool) public whitelistedMintAddresses;
    bool public vaultOpenToPublic;

    event CooldownInitiated(address indexed user, uint256 shares, uint256 cooldownEnd);
    event CooldownCleared(address indexed user, address indexed operator);
    event FeeAddressChanged(address indexed oldFeeAddress, address indexed newFeeAddress);
    event LiquidityManagerVaultChanged(address indexed oldVault, address indexed newVault);
    event RebalanceExecuted(uint256 airdropShares, uint256 managementFeeShares, uint256 performanceFeeUSDe);
    event AdminWithdraw(address indexed receiver, address indexed token, uint256 amount);
    event UserWhitelisted(address indexed user, bool whitelisted);
    event MintAddressWhitelisted(address indexed mintAddress, bool whitelisted);
    event SharesMinted(address indexed to, uint256 shares, string reason);
    event SharesBurned(address indexed account, uint256 shares, string reason, address indexed caller);
    event VaultOpenToPublicSet(bool open);
    event DepositCapSet(uint256 oldCap, uint256 newCap);
    event TokensTransferredToLMV(address indexed token, uint256 amount);
    event TokenPoolMint(address indexed to, uint256 amount);
    event TokenPoolBurn(address indexed from, uint256 amount);

    modifier nonReentrant() {
        require(_reentrancyStatus != _ENTERED, "Reentrant call");
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    /// @param initialAdmin Receives `DEFAULT_ADMIN_ROLE` at `initialize` (not the deployer).
    constructor(address initialAdmin) {
        require(initialAdmin != address(0), "Invalid admin");
        INITIAL_ADMIN = initialAdmin;
        _disableInitializers();
    }

    function initialize(
        address _usde,
        address _operator,
        address _feeAddress,
        address _liquidityManagerVault
    ) external initializer {
        require(_usde != address(0), "Invalid USDe address");
        require(_operator != address(0), "Invalid operator");
        require(_feeAddress != address(0), "Invalid fee address");

        __ERC20_init("Senior Vault", "snrUSD");
        __ERC4626_init(IERC20(_usde));
        __AccessControl_init();
        __Pausable_init();

        _reentrancyStatus = _NOT_ENTERED;
        _grantRole(DEFAULT_ADMIN_ROLE, INITIAL_ADMIN);
        _grantRole(OPERATOR_ROLE, _operator);

        usde = _usde;
        feeAddress = _feeAddress;
        liquidityManagerVault = _liquidityManagerVault;
        vaultOpenToPublic = false;
        depositCap = 0;

        lastRebalanceTimestamp =
            block.timestamp > REBALANCE_INTERVAL ? (block.timestamp - REBALANCE_INTERVAL) : 0;
    }

    // ─── Admin ───────────────────────────────────────────────────────────────

    function setFeeAddress(address _feeAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_feeAddress != address(0), "Invalid fee address");
        address old = feeAddress;
        feeAddress = _feeAddress;
        emit FeeAddressChanged(old, _feeAddress);
    }

    function setLiquidityManagerVault(address _liquidityManagerVault) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_liquidityManagerVault != address(0), "Invalid liquidity manager vault");
        address old = liquidityManagerVault;
        liquidityManagerVault = _liquidityManagerVault;
        emit LiquidityManagerVaultChanged(old, _liquidityManagerVault);
    }

    function setDepositCap(uint256 _depositCap) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 old = depositCap;
        depositCap = _depositCap;
        emit DepositCapSet(old, _depositCap);
    }

    function setVaultOpenToPublic(bool _open) external onlyRole(DEFAULT_ADMIN_ROLE) {
        vaultOpenToPublic = _open;
        emit VaultOpenToPublicSet(_open);
    }

    function setWhitelistedUser(address _user, bool _whitelisted) external onlyRole(DEFAULT_ADMIN_ROLE) {
        whitelistedUsers[_user] = _whitelisted;
        emit UserWhitelisted(_user, _whitelisted);
    }

    function setWhitelistedMintAddress(address _mintAddress, bool _whitelisted)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        whitelistedMintAddresses[_mintAddress] = _whitelisted;
        emit MintAddressWhitelisted(_mintAddress, _whitelisted);
    }

    function adminMintShares(address to, uint256 shares, string calldata reason)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(to != address(0), "Invalid address");
        require(shares > 0, "Shares must be > 0");
        require(whitelistedMintAddresses[to], "Address not whitelisted for minting");
        _mint(to, shares);
        emit SharesMinted(to, shares, reason);
    }

    function adminBurnShares(address account, uint256 shares, string calldata reason)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
        whenNotPaused
    {
        require(account != address(0), "Zero account");
        require(shares > 0, "Shares must be > 0");
        require(balanceOf(account) >= shares, "Insufficient shares");

        CooldownInfo storage cd = cooldowns[account];
        if (cd.active) {
            uint256 remaining = balanceOf(account) - shares;
            if (cd.sharesToBurn > remaining) {
                if (remaining == 0) {
                    delete cooldowns[account];
                } else {
                    cd.sharesToBurn = remaining;
                }
            }
        }

        _burn(account, shares);
        emit SharesBurned(account, shares, reason, msg.sender);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function adminWithdraw(address token, uint256 amount, address receiver)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        require(token != address(0), "Invalid token");
        require(receiver != address(0), "Invalid receiver");
        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 withdrawAmount = amount == 0 ? balance : amount;
        require(withdrawAmount > 0, "No balance to withdraw");
        require(withdrawAmount <= balance, "Insufficient balance");
        SafeERC20.safeTransfer(IERC20(token), receiver, withdrawAmount);
        emit AdminWithdraw(receiver, token, withdrawAmount);
    }

    function rebalance(uint256 airdropPercentageBps) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        require(block.timestamp >= lastRebalanceTimestamp + REBALANCE_INTERVAL, "Rebalance interval not met");
        require(airdropPercentageBps >= 1100 && airdropPercentageBps <= 1300, "Airdrop percentage must be between 11-13%");

        uint256 totalSharesBefore = totalSupply();
        if (totalSharesBefore == 0) {
            lastRebalanceTimestamp = block.timestamp;
            return;
        }

        uint256 airdropShares = (totalSharesBefore * airdropPercentageBps) / 120_000;
        if (airdropShares > 0) {
            _mint(msg.sender, airdropShares);
        }

        // Base change: management fee on totalSupply, not getVaultValue().
        uint256 managementFeeShares = (totalSharesBefore * MANAGEMENT_FEE_BPS) / BPS_DENOMINATOR;
        if (managementFeeShares > 0) {
            _mint(feeAddress, managementFeeShares);
        }

        uint256 performanceFeeUSDe = (airdropShares * 2) / 100;
        uint256 performanceFeeTransferred = 0;
        if (performanceFeeUSDe > 0) {
            uint256 usdeBalance = IERC20(usde).balanceOf(address(this));
            uint256 feeToTransfer = performanceFeeUSDe > usdeBalance ? usdeBalance : performanceFeeUSDe;
            if (feeToTransfer > 0) {
                SafeERC20.safeTransfer(IERC20(usde), feeAddress, feeToTransfer);
                performanceFeeTransferred = feeToTransfer;
            }
        }

        lastRebalanceTimestamp = block.timestamp;
        emit RebalanceExecuted(airdropShares, managementFeeShares, performanceFeeTransferred);
    }

    // ─── Operator ────────────────────────────────────────────────────────────

    function clearCooldown(address user) external onlyRole(OPERATOR_ROLE) {
        require(cooldowns[user].active, "No active cooldown");
        delete cooldowns[user];
        emit CooldownCleared(user, msg.sender);
    }

    function transferToLiquidityManager(uint256 amount, address token)
        external
        onlyRole(OPERATOR_ROLE)
        nonReentrant
        whenNotPaused
    {
        require(amount > 0, "Amount must be > 0");
        require(token != address(0), "Invalid token");
        require(liquidityManagerVault != address(0), "Liquidity manager vault not set");
        require(IERC20(token).balanceOf(address(this)) >= amount, "Insufficient token balance");
        SafeERC20.safeTransfer(IERC20(token), liquidityManagerVault, amount);
        emit TokensTransferredToLMV(token, amount);
    }

    // ─── User (1:1 share math) ───────────────────────────────────────────────

    function deposit(uint256 assets, address receiver)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 shares)
    {
        _requireUserAccess(msg.sender);
        _requireUserAccess(receiver);
        _enforceDepositCap(assets);

        SafeERC20.safeTransferFrom(IERC20(usde), msg.sender, address(this), assets);
        shares = assets;
        _mint(receiver, shares);
        return shares;
    }

    /// @inheritdoc ERC4626Upgradeable
    function mint(uint256 shares, address receiver)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 assets)
    {
        _requireUserAccess(msg.sender);
        _requireUserAccess(receiver);
        _enforceDepositCap(shares);

        assets = shares;
        SafeERC20.safeTransferFrom(IERC20(usde), msg.sender, address(this), assets);
        _mint(receiver, shares);
        return assets;
    }

    function withdraw(uint256, address, address) public pure override returns (uint256) {
        revert("Direct withdrawals disabled. Use initiateCooldown() then redeem()");
    }

    function initiateCooldown(uint256 shares) external whenNotPaused nonReentrant {
        require(shares > 0, "Shares must be > 0");
        require(balanceOf(msg.sender) >= shares, "Insufficient shares");
        require(
            !cooldowns[msg.sender].active || block.timestamp >= cooldowns[msg.sender].cooldownEnd,
            "Cooldown already active"
        );

        cooldowns[msg.sender] = CooldownInfo({
            sharesToBurn: shares,
            cooldownEnd: block.timestamp + COOLDOWN_PERIOD,
            active: true
        });

        emit CooldownInitiated(msg.sender, shares, cooldowns[msg.sender].cooldownEnd);
    }

    function redeem(uint256 shares, address receiver, address owner)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 assets)
    {
        _requireUserAccess(owner);
        _requireUserAccess(receiver);

        CooldownInfo memory cooldown = cooldowns[owner];
        require(cooldown.active, "No active cooldown");
        require(block.timestamp >= cooldown.cooldownEnd, "Cooldown not ended");
        require(shares <= cooldown.sharesToBurn, "Exceeds cooldown shares");

        uint256 assetsBeforeFee = shares;
        uint256 fee = (assetsBeforeFee * REDEEM_FEE_BPS) / BPS_DENOMINATOR;
        assets = assetsBeforeFee - fee;

        _withdraw(_msgSender(), receiver, owner, assets, shares);

        if (fee > 0) {
            IERC20(usde).safeTransfer(feeAddress, fee);
        }

        delete cooldowns[owner];
        return assets;
    }

    // ─── CCT / TokenPool (supply-only; does not move USDe) ───────────────────

  /// @inheritdoc IBurnMintERC20
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
        emit TokenPoolMint(to, amount);
    }

  /// @inheritdoc IBurnMintERC20
    function burn(uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(msg.sender, amount);
        emit TokenPoolBurn(msg.sender, amount);
    }

  /// @inheritdoc IBurnMintERC20
    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(from, amount);
        emit TokenPoolBurn(from, amount);
    }

  /// @inheritdoc IBurnMintERC20
    function burnFrom(address account, uint256 amount) external onlyRole(BURNER_ROLE) {
        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
        emit TokenPoolBurn(account, amount);
    }

    // ─── Views ───────────────────────────────────────────────────────────────

    /// @notice Idle vault USDe plus raw USDe on the LMV (no priced island/LP mark).
    function totalAssets() public view override returns (uint256) {
        uint256 vaultUsde = IERC20(usde).balanceOf(address(this));
        address lmv = liquidityManagerVault;
        if (lmv == address(0)) {
            return vaultUsde;
        }
        return vaultUsde + IERC20(usde).balanceOf(lmv);
    }

    function getCooldown(address user) external view returns (CooldownInfo memory) {
        return cooldowns[user];
    }

    function maxRedeem(address owner) public view override returns (uint256) {
        CooldownInfo memory cooldown = cooldowns[owner];
        if (!cooldown.active || block.timestamp < cooldown.cooldownEnd) {
            return 0;
        }
        return cooldown.sharesToBurn;
    }

    function maxWithdraw(address) public pure override returns (uint256) {
        return 0;
    }

    function previewDeposit(uint256 assets) public pure override returns (uint256) {
        return assets;
    }

    function previewMint(uint256 shares) public pure override returns (uint256) {
        return shares;
    }

    function previewRedeem(uint256 shares) public view override returns (uint256) {
        uint256 fee = (shares * REDEEM_FEE_BPS) / BPS_DENOMINATOR;
        return shares - fee;
    }

    function previewWithdraw(uint256) public pure override returns (uint256) {
        revert("Direct withdrawals disabled. Use initiateCooldown() then redeem()");
    }

    function convertToShares(uint256 assets) public pure override returns (uint256) {
        return assets;
    }

    function convertToAssets(uint256 shares) public pure override returns (uint256) {
        return shares;
    }

    function maxDeposit(address receiver) public view override returns (uint256) {
        if (paused() || !_canUserAccess(receiver)) return 0;
        return _remainingDepositCapacity();
    }

    function maxMint(address receiver) public view override returns (uint256) {
        if (paused() || !_canUserAccess(receiver)) return 0;
        return _remainingDepositCapacity();
    }

    // ─── Internal ──────────────────────────────────────────────────────────────

    function _enforceDepositCap(uint256 newShares) internal view {
        if (depositCap > 0) {
            require(totalSupply() + newShares <= depositCap, "Deposit cap exceeded");
        }
    }

    function _remainingDepositCapacity() internal view returns (uint256) {
        if (depositCap == 0) return type(uint256).max;
        if (totalSupply() >= depositCap) return 0;
        return depositCap - totalSupply();
    }

    function _requireUserAccess(address account) internal view {
        if (!vaultOpenToPublic) {
            require(whitelistedUsers[account], "User not whitelisted");
        }
    }

    function _canUserAccess(address account) internal view returns (bool) {
        return vaultOpenToPublic || whitelistedUsers[account];
    }

    function _authorizeUpgrade(address) internal view override onlyRole(DEFAULT_ADMIN_ROLE) {}
}