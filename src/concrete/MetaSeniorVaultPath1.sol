// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {MetaSeniorVault} from "./MetaSeniorVault.sol";
import {IBurnMintERC20} from "../interfaces/IBurnMintERC20.sol";

/// @title MetaSeniorVaultPath1
/// @notice Path1 CCT upgrade for live Berachain Meta Senior: token-pool burn-mint only (no cross-chain NAV sleeve).
/// @dev No new storage slots beyond `MetaSeniorVault` (MINTER/BURNER roles use AccessControl slots). Constructor disables initializers.
contract MetaSeniorVaultPath1 is MetaSeniorVault, IBurnMintERC20 {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    event TokenPoolMint(address indexed to, uint256 amount);
    event TokenPoolBurn(address indexed from, uint256 amount);
    event Path1Initialized();

    constructor() {
        _disableInitializers();
    }

    /// @notice Path1 reinitializer — required on upgrade (do not use empty upgradeToAndCall).
    /// @dev Opens vault to match live behavior before public-gate getters existed on 0xa4e99….
    function initializePath1() external reinitializer(2) onlyRole(DEFAULT_ADMIN_ROLE) {
        vaultOpenToPublic = true;
        depositCap = 0;
        emit VaultOpenToPublicSet(true);
        emit DepositCapSet(0, 0);
        emit Path1Initialized();
    }

    function grantMintAndBurnRoles(address tokenPool) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(tokenPool != address(0), "Invalid pool");
        _grantRole(MINTER_ROLE, tokenPool);
        _grantRole(BURNER_ROLE, tokenPool);
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