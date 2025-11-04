// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {JuniorVault} from "../abstract/JuniorVault.sol";

/**
 * @title ConcreteJuniorVault
 * @notice Concrete implementation of Junior vault (ERC4626)
 * @dev No additional logic needed - receives spillover, provides secondary backstop
 * @dev Upgradeable using UUPS proxy pattern
 */
contract ConcreteJuniorVault is JuniorVault {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @notice Initialize Junior vault (for proxy deployment)
     * @param lpToken_ LP token address (e.g., USDe-SAIL)
     * @param seniorVault_ Senior vault address
     * @param initialValue_ Initial vault value in USD
     */
    function initialize(
        address lpToken_,
        address seniorVault_,
        uint256 initialValue_
    ) external initializer {
        __JuniorVault_init(
            lpToken_,
            "Junior Tranche Shares",
            "jTRN",
            seniorVault_,
            initialValue_
        );
    }
}

