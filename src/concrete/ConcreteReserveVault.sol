// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReserveVault} from "../abstract/ReserveVault.sol";

/**
 * @title ConcreteReserveVault
 * @notice Concrete implementation of Reserve vault (ERC4626)
 * @dev No additional logic needed - receives spillover, provides primary backstop
 * @dev Upgradeable using UUPS proxy pattern
 */
contract ConcreteReserveVault is ReserveVault {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @notice Initialize Reserve vault (for proxy deployment)
     * @param stablecoin_ Stablecoin address (e.g., USDe-SAIL)
     * @param seniorVault_ Senior vault address
     * @param initialValue_ Initial vault value in USD
     */
    function initialize(
        address stablecoin_,
        address seniorVault_,
        uint256 initialValue_
    ) external initializer {
        __ReserveVault_init(
            stablecoin_,
            "Reserve Tranche Shares",
            "rTRN",
            seniorVault_,
            initialValue_
        );
    }
}

