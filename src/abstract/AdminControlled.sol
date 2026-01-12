// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title AdminControlled
 * @notice Base contract for admin and deployer role management
 * @dev Provides two-tier access control:
 *      
 * @dev Upgradeable version using Initializable
 */
abstract contract AdminControlled is Initializable {
    /// @dev 
    /// NEVER add new storage variables here - it will break all inheriting contracts!
    /// Add new storage only in concrete contracts at the END
    address private _deployer;
    address private _admin;
    mapping(address => bool) private _seeders;
    
    /// @dev Events
    event AdminSet(address indexed previousAdmin, address indexed newAdmin);
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);
    event SeederAdded(address indexed seeder);
    event SeederRevoked(address indexed seeder);
    event LiquidityManagerSet(address indexed liquidityManager);
    event PriceFeedManagerSet(address indexed priceFeedManager);
    event ContractUpdaterSet(address indexed contractUpdater);
    event LiquidityManagerVaultSet(address indexed liquidityManagerVault);
    /// @dev Errors
    error OnlyDeployer();
    error OnlyAdmin();
    error OnlySeeder();
    error ZeroAddress();
    error AdminAlreadySet();
    error LiquidityManagerAlreadySet();
    error PriceFeedManagerAlreadySet();
    error ContractUpdaterAlreadySet();
    error SeederAlreadyAdded();
    error SeederNotFound();
    error LiquidityManagerNotSet();
    error PriceFeedManagerNotSet();
    error ContractUpdaterNotSet();
    error OnlyLiquidityManager();
    error OnlyPriceFeedManager();
    error OnlyContractUpdater();
    error OnlyLiquidityManagerVault();
    
    /// @dev Modifiers
    modifier onlyDeployer() {
        if (msg.sender != _deployer) revert OnlyDeployer();
        _;
    }
    
    modifier onlyAdmin() {
        if (msg.sender != _admin) revert OnlyAdmin();
        _;
    }
    
    modifier onlySeeder() {
        if (!_seeders[msg.sender]) revert OnlySeeder();
        _;
    }

    modifier onlyLiquidityManager() {
        if (msg.sender != liquidityManager()) revert OnlyLiquidityManager();
        _;
    }

    modifier onlyPriceFeedManager() {
        if (msg.sender != priceFeedManager()) revert OnlyPriceFeedManager();
        _;
    }

    modifier onlyContractUpdater() {
        if (msg.sender != contractUpdater()) revert OnlyContractUpdater();
        _;
    }

    modifier onlyLiquidityManagerVault() {
        if (msg.sender != liquidityManagerVault()) revert OnlyLiquidityManagerVault();
        _;
    }
    /**
     * @notice Initialize with deployer (replaces constructor)
     * @dev Deployer is set to msg.sender, admin must be set separately
     */
    function __AdminControlled_init() internal onlyInitializing {
        _deployer = msg.sender;
    }
    
    
    /**
     * @notice Set admin address (one-time operation by deployer)
     * @dev Can only be called once by deployer during deployment
     * @param admin_ Address of the admin
     */
    function setAdmin(address admin_) external onlyDeployer {
        if (_admin != address(0)) revert AdminAlreadySet();
        if (admin_ == address(0)) revert ZeroAddress();
        
        emit AdminSet(address(0), admin_);
        _admin = admin_;
    }
    
    /**
     * @notice Transfer admin to new address
     * @dev Can only be called by current admin
     * @param newAdmin Address of the new admin
     */
    function transferAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        
        emit AdminTransferred(_admin, newAdmin);
        _admin = newAdmin;
    }
    
    /**
     * @notice Get deployer address
     */
    function deployer() public view returns (address) {
        return _deployer;
    }
    
    /**
     * @notice Get admin address
     */
    function admin() public view returns (address) {
        return _admin;
    }
    
    /**
     * @notice Check if address is admin
     */
    function isAdmin(address account) public view returns (bool) {
        return account == _admin;
    }
    
    /**
     * @notice Add seeder role to address
     * @dev Only admin can add seeders
     * @param seeder Address to grant seeder role
     */
    function addSeeder(address seeder) external onlyAdmin {
        if (seeder == address(0)) revert ZeroAddress();
        if (_seeders[seeder]) revert SeederAlreadyAdded();
        
        _seeders[seeder] = true;
        emit SeederAdded(seeder);
    }
    
    /**
     * @notice Revoke seeder role from address
     * @dev Only admin can revoke seeders
     * @param seeder Address to revoke seeder role from
     */
    function revokeSeeder(address seeder) external onlyAdmin {
        if (seeder == address(0)) revert ZeroAddress();
        if (!_seeders[seeder]) revert SeederNotFound();
        
        _seeders[seeder] = false;
        emit SeederRevoked(seeder);
    }
    
    /**
     * @notice Check if address has seeder role
     * @param account Address to check
     * @return hasRole True if address is a seeder
     */
    function isSeeder(address account) public view returns (bool) {
        return _seeders[account];
    }
    
    // ============================================
    // Role Management (Virtual - Implemented in Concrete Contracts)
    // ============================================
    
    /**
     * @notice Get liquidity manager address
     * @dev Must be overridden in concrete contracts
     */
    function liquidityManager() public view virtual returns (address) {
        return address(0);
    }
    
    /**
     * @notice Get price feed manager address
     * @dev Must be overridden in concrete contracts
     */
    function priceFeedManager() public view virtual returns (address) {
        return address(0);
    }
    
    /**
     * @notice Get contract updater address
     * @dev Must be overridden in concrete contracts
     */
    function contractUpdater() public view virtual returns (address) {
        return address(0);
    }

    /**
     * @notice Get liquidity manager vault address
     * @dev Must be overridden in concrete contracts
     */
    function liquidityManagerVault() public view virtual returns (address) {
        return address(0);
    }
}

