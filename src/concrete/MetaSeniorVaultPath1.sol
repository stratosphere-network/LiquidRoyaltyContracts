// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {MetaSeniorVault} from "./MetaSeniorVault.sol";
import {IBurnMintERC20} from "../interfaces/IBurnMintERC20.sol";

/// @title MetaSeniorVaultPath1
/// @notice Path1 CCT upgrade for live Berachain Meta Senior: pool burn-mint + keeper-reported Base sleeve NAV.
/// @dev Append-only storage past `MetaSeniorVault` layout. Constructor disables initializers (impl-only deploy).
contract MetaSeniorVaultPath1 is MetaSeniorVault, IBurnMintERC20 {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    uint256 private _reportedBaseSleeveAssets;
    uint64 private _baseSleeveUpdatedAt;
    uint16 public maxBaseSleeveDeltaBps;
    uint32 public baseSleeveMaxStaleness;

    event TokenPoolMint(address indexed to, uint256 amount);
    event TokenPoolBurn(address indexed from, uint256 amount);
    event BaseSleeveAssetsUpdated(uint256 previous, uint256 updated, address indexed reporter);
    event Path1Initialized(uint16 maxDeltaBps, uint32 maxStaleness);

    error BaseSleeveDeltaExceeded(uint256 previous, uint256 next, uint16 maxDeltaBps);
    error BaseSleeveReportStale(uint64 lastUpdate, uint32 maxStaleness);

    constructor() {
        _disableInitializers();
    }

    /// @notice Path1 reinitializer — required on upgrade (do not use empty upgradeToAndCall).
    /// @dev Opens vault to match live behavior before public-gate getters existed on 0xa4e99….
    function initializePath1(uint16 maxDeltaBps, uint32 maxStaleness) external reinitializer(2) onlyRole(DEFAULT_ADMIN_ROLE) {
        vaultOpenToPublic = true;
        depositCap = 0;
        maxBaseSleeveDeltaBps = maxDeltaBps;
        baseSleeveMaxStaleness = maxStaleness;
        emit VaultOpenToPublicSet(true);
        emit DepositCapSet(0, 0);
        emit Path1Initialized(maxDeltaBps, maxStaleness);
    }

    function grantMintAndBurnRoles(address tokenPool) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(tokenPool != address(0), "Invalid pool");
        _grantRole(MINTER_ROLE, tokenPool);
        _grantRole(BURNER_ROLE, tokenPool);
    }

    /// @notice Keeper/admin reports Base snrUSD sleeve `totalAssets()` into hub NAV (no token movement on Berachain).
    modifier onlyKeeperOrAdmin() {
        require(
            hasRole(OPERATOR_ROLE, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not keeper/admin"
        );
        _;
    }

    function setBaseSleeveAssets(uint256 assets) external onlyKeeperOrAdmin {
        uint256 previous = _reportedBaseSleeveAssets;
        if (maxBaseSleeveDeltaBps > 0 && previous > 0) {
            uint256 diff = assets > previous ? assets - previous : previous - assets;
            uint256 maxDiff = (previous * maxBaseSleeveDeltaBps) / BPS_DENOMINATOR;
            if (diff > maxDiff) {
                revert BaseSleeveDeltaExceeded(previous, assets, maxBaseSleeveDeltaBps);
            }
        }
        _reportedBaseSleeveAssets = assets;
        _baseSleeveUpdatedAt = uint64(block.timestamp);
        emit BaseSleeveAssetsUpdated(previous, assets, msg.sender);
    }

    function setBaseSleeveGuards(uint16 maxDeltaBps, uint32 maxStaleness)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        maxBaseSleeveDeltaBps = maxDeltaBps;
        baseSleeveMaxStaleness = maxStaleness;
    }

    function reportedBaseSleeveAssets() external view returns (uint256) {
        return _reportedBaseSleeveAssets;
    }

    function baseSleeveUpdatedAt() external view returns (uint64) {
        return _baseSleeveUpdatedAt;
    }

    function localVaultValue() public view returns (uint256) {
        return super.getVaultValue();
    }

  /// @inheritdoc MetaSeniorVault
    function getVaultValue() public view override returns (uint256) {
        uint256 local = super.getVaultValue();
        if (baseSleeveMaxStaleness > 0 && _baseSleeveUpdatedAt > 0) {
            if (block.timestamp > _baseSleeveUpdatedAt + baseSleeveMaxStaleness) {
                return local;
            }
        }
        return local + _reportedBaseSleeveAssets;
    }

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
}