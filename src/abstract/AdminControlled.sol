// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title AdminControlled
 * @notice Base contract for admin and deployer role management
 * @dev Provides two-tier access control:
 *      - Deployer: Can set admin once
 *      - Admin: Can call privileged functions (rebases, updates, emergencies)
 * @dev Upgradeable version using Initializable
 */
abstract contract AdminControlled is Initializable {
    /// @dev Roles
    address private _deployer;
    address private _admin;
    
    /// @dev Events
    event AdminSet(address indexed previousAdmin, address indexed newAdmin);
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);
    
    /// @dev Errors
    error OnlyDeployer();
    error OnlyAdmin();
    error ZeroAddress();
    error AdminAlreadySet();
    
    /// @dev Modifiers
    modifier onlyDeployer() {
        if (msg.sender != _deployer) revert OnlyDeployer();
        _;
    }
    
    modifier onlyAdmin() {
        if (msg.sender != _admin) revert OnlyAdmin();
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
}

