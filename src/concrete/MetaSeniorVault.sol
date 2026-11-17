// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ISubVault} from "../interfaces/ISubVault.sol";

/// @title MetaSeniorVault
/// @notice Live Berachain Meta Senior (Senior Vault Master / snrUSD) — StrategyManagerVault lineage.
/// @dev Storage is append-only past the marker below; Path1 features live in `MetaSeniorVaultPath1`.
contract MetaSeniorVault is
    ERC4626Upgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    uint256 public constant COOLDOWN_PERIOD = 7 days;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    address public feeAddress;

    struct CooldownInfo {
        uint256 sharesToBurn;
        uint256 rate;
        uint256 cooldownEnd;
        bool active;
    }

    mapping(address => CooldownInfo) public cooldowns;

    struct SubVaultConfig {
        bool isStable;
        bool whitelisted;
    }

    mapping(address => SubVaultConfig) public subVaultConfigs;
    address[] public subVaultList;

    mapping(address => bool) public whitelistedMintAddresses;

    // --- APPEND-ONLY: new production storage MUST be added below (never insert above) ---
    uint256 public unstakingFeeBps;
    mapping(address => bool) public whitelistedUsers;
    bool public vaultOpenToPublic;
    uint256 public depositCap;

    event UserWhitelisted(address indexed user, bool whitelisted);
    event VaultOpenToPublicSet(bool open);
    event DepositCapSet(uint256 oldCap, uint256 newCap);
    event UnstakingFeeChanged(uint256 oldBps, uint256 newBps);
    event SubVaultSet(address indexed vault, bool isStable, bool whitelisted);
    event MintAddressWhitelisted(address indexed mintAddress, bool whitelisted);
    event SharesMinted(address indexed to, uint256 shares, string reason);
    event AllocateDeposit(address indexed vault, uint256 assets, uint256 shares);
    event AllocateWithdraw(address indexed vault, uint256 shares, uint256 assets);
    event CooldownInitiated(address indexed user, uint256 shares, uint256 rate, uint256 cooldownEnd);
    event FeeAddressChanged(address indexed oldFee, address indexed newFee);
    event EmergencyWithdraw(address indexed receiver, address indexed token, uint256 amount);

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _usde,
        address _operator,
        address _feeAddress,
        string memory _name,
        string memory _symbol,
        uint256 _unstakingFeeBps
    ) external initializer {
        __ERC20_init(_name, _symbol);
        __ERC4626_init(IERC20(_usde));
        __AccessControl_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, _operator);
        require(_usde != address(0), "Invalid USDe");
        require(_feeAddress != address(0), "Invalid fee address");
        require(_unstakingFeeBps <= 1000, "Fee too high");
        feeAddress = _feeAddress;
        unstakingFeeBps = _unstakingFeeBps;
    }

    function setUnstakingFeeBps(uint256 _unstakingFeeBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_unstakingFeeBps <= 1000, "Fee too high");
        uint256 old = unstakingFeeBps;
        unstakingFeeBps = _unstakingFeeBps;
        emit UnstakingFeeChanged(old, _unstakingFeeBps);
    }

    function setFeeAddress(address _feeAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_feeAddress != address(0), "Invalid fee address");
        address old = feeAddress;
        feeAddress = _feeAddress;
        emit FeeAddressChanged(old, _feeAddress);
    }

    function setSubVault(address _vault, bool _isStable) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_vault != address(0), "Invalid vault");
        if (!subVaultConfigs[_vault].whitelisted) {
            subVaultList.push(_vault);
        }
        subVaultConfigs[_vault] = SubVaultConfig({isStable: _isStable, whitelisted: true});
        emit SubVaultSet(_vault, _isStable, true);
    }

    function removeSubVault(address _vault) external onlyRole(DEFAULT_ADMIN_ROLE) {
        subVaultConfigs[_vault].whitelisted = false;
        emit SubVaultSet(_vault, false, false);
    }

    function setWhitelistedMintAddress(address _mintAddress, bool _whitelisted)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        whitelistedMintAddresses[_mintAddress] = _whitelisted;
        emit MintAddressWhitelisted(_mintAddress, _whitelisted);
    }

    function setWhitelistedUser(address _user, bool _whitelisted) external onlyRole(DEFAULT_ADMIN_ROLE) {
        whitelistedUsers[_user] = _whitelisted;
        emit UserWhitelisted(_user, _whitelisted);
    }

    function setVaultOpenToPublic(bool _open) external onlyRole(DEFAULT_ADMIN_ROLE) {
        vaultOpenToPublic = _open;
        emit VaultOpenToPublicSet(_open);
    }

    function setDepositCap(uint256 _depositCap) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 oldCap = depositCap;
        depositCap = _depositCap;
        emit DepositCapSet(oldCap, _depositCap);
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

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function emergencyWithdraw(address token, uint256 amount, address receiver)
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
        emit EmergencyWithdraw(receiver, token, withdrawAmount);
    }

    function depositToSubVault(address _vault, uint256 _assets)
        external
        onlyRole(OPERATOR_ROLE)
        nonReentrant
        whenNotPaused
    {
        require(subVaultConfigs[_vault].whitelisted, "Vault not whitelisted");
        require(_assets > 0, "Amount must be > 0");
        require(IERC20(asset()).balanceOf(address(this)) >= _assets, "Insufficient USDe");
        SafeERC20.forceApprove(IERC20(asset()), _vault, _assets);
        uint256 shares = ISubVault(_vault).deposit(_assets, address(this));
        SafeERC20.forceApprove(IERC20(asset()), _vault, 0);
        emit AllocateDeposit(_vault, _assets, shares);
    }

    function withdrawFromSubVault(address _vault, uint256 _shares)
        external
        onlyRole(OPERATOR_ROLE)
        nonReentrant
        whenNotPaused
    {
        require(subVaultConfigs[_vault].whitelisted, "Vault not whitelisted");
        require(_shares > 0, "Shares must be > 0");
        require(IERC20(_vault).balanceOf(address(this)) >= _shares, "Insufficient sub-vault shares");
        uint256 assets = ISubVault(_vault).redeem(_shares, address(this), address(this));
        emit AllocateWithdraw(_vault, _shares, assets);
    }

    function deposit(uint256 assets, address receiver)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        if (!vaultOpenToPublic) {
            require(whitelistedUsers[msg.sender], "User not whitelisted for deposits");
            require(whitelistedUsers[receiver], "Receiver not whitelisted for deposits");
        }
        if (depositCap > 0) {
            require(totalAssets() + assets <= depositCap, "Deposit cap exceeded");
        }
        return super.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        if (!vaultOpenToPublic) {
            require(whitelistedUsers[msg.sender], "User not whitelisted for deposits");
            require(whitelistedUsers[receiver], "Receiver not whitelisted for deposits");
        }
        if (depositCap > 0) {
            require(totalAssets() + previewMint(shares) <= depositCap, "Deposit cap exceeded");
        }
        return super.mint(shares, receiver);
    }

    function withdraw(uint256, address, address) public pure override returns (uint256) {
        revert("Use initiateCooldown then redeem");
    }

    function initiateCooldown(uint256 shares) external whenNotPaused nonReentrant {
        if (!vaultOpenToPublic) {
            require(whitelistedUsers[msg.sender], "User not whitelisted");
        }
        require(shares > 0, "Shares must be > 0");
        require(balanceOf(msg.sender) >= shares, "Insufficient shares");
        require(
            !cooldowns[msg.sender].active || block.timestamp >= cooldowns[msg.sender].cooldownEnd,
            "Cooldown active"
        );

        uint256 rate = totalSupply() > 0 ? (getVaultValue() * 1e18) / totalSupply() : 1e18;

        cooldowns[msg.sender] = CooldownInfo({
            sharesToBurn: shares,
            rate: rate,
            cooldownEnd: block.timestamp + COOLDOWN_PERIOD,
            active: true
        });
        emit CooldownInitiated(msg.sender, shares, rate, cooldowns[msg.sender].cooldownEnd);
    }

    function redeem(uint256 shares, address receiver, address owner)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 assets)
    {
        if (!vaultOpenToPublic) {
            require(whitelistedUsers[owner], "Owner not whitelisted for redeems");
            require(whitelistedUsers[receiver], "Receiver not whitelisted for redeems");
        }
        CooldownInfo memory cooldown = cooldowns[owner];
        require(cooldown.active, "No active cooldown");
        require(block.timestamp >= cooldown.cooldownEnd, "Cooldown not ended");
        require(shares <= cooldown.sharesToBurn, "Exceeds cooldown shares");

        uint256 assetsBeforeFee = (shares * cooldown.rate) / 1e18;
        uint256 fee = (assetsBeforeFee * unstakingFeeBps) / BPS_DENOMINATOR;
        uint256 assetsAfterFee = assetsBeforeFee - fee;

        _withdraw(_msgSender(), receiver, owner, assetsAfterFee, shares);

        if (fee > 0) {
            IERC20(asset()).safeTransfer(feeAddress, fee);
        }
        delete cooldowns[owner];
        return assetsAfterFee;
    }

    /// @notice On-chain Berachain sleeve NAV (USDe + sub-vaults). Path1 adds reported Base sleeve in the child.
    function getVaultValue() public view virtual returns (uint256) {
        uint256 usdeBalance = IERC20(asset()).balanceOf(address(this));
        for (uint256 i = 0; i < subVaultList.length; i++) {
            address v = subVaultList[i];
            if (subVaultConfigs[v].whitelisted) {
                usdeBalance += _getSubVaultValue(v, subVaultConfigs[v].isStable);
            }
        }
        return usdeBalance;
    }

  /// @inheritdoc ERC4626Upgradeable
    function totalAssets() public view virtual override returns (uint256) {
        return getVaultValue();
    }

    function getCooldown(address user) external view returns (CooldownInfo memory) {
        return cooldowns[user];
    }

    function maxRedeem(address owner) public view override returns (uint256) {
        CooldownInfo memory c = cooldowns[owner];
        if (!c.active || block.timestamp < c.cooldownEnd) return 0;
        return c.sharesToBurn;
    }

    function maxDeposit(address) public view override returns (uint256) {
        if (depositCap == 0) return type(uint256).max;
        uint256 assets = totalAssets();
        return assets >= depositCap ? 0 : depositCap - assets;
    }

    function maxWithdraw(address) public pure override returns (uint256) {
        return 0;
    }

    function previewRedeem(uint256 shares) public view override returns (uint256) {
        uint256 assetsBeforeFee = super.previewRedeem(shares);
        uint256 fee = (assetsBeforeFee * unstakingFeeBps) / BPS_DENOMINATOR;
        return assetsBeforeFee - fee;
    }

    function getSubVaultList() external view returns (address[] memory) {
        return subVaultList;
    }

    function _getSubVaultValue(address _vault, bool _isStable) internal view returns (uint256) {
        uint256 shares = IERC20(_vault).balanceOf(address(this));
        if (shares == 0) return 0;
        if (_isStable) return shares;
        uint256 subTotalSupply = IERC20(_vault).totalSupply();
        if (subTotalSupply == 0) return 0;
        uint256 subTotalAssets = ISubVault(_vault).totalAssets();
        return Math.mulDiv(shares, subTotalAssets, subTotalSupply);
    }

    function _authorizeUpgrade(address) internal view override onlyRole(DEFAULT_ADMIN_ROLE) {}
}