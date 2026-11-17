// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/// @notice Sub-vault surface used by Meta Senior (StrategyManagerVault) for Berachain sleeve positions.
interface ISubVault is IERC4626 {
    // Sub-vaults must whitelist Meta Senior as strategyManager where applicable.
}