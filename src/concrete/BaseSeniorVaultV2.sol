// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {BaseSeniorVault} from "./BaseSeniorVault.sol";

/// @dev UUPS upgrade target; storage layout must stay compatible with `BaseSeniorVault`.
contract BaseSeniorVaultV2 is BaseSeniorVault {
    uint256 public versionMarker;

    constructor(address initialAdmin) BaseSeniorVault(initialAdmin) {}

    function bumpVersion() external onlyRole(DEFAULT_ADMIN_ROLE) {
        versionMarker = block.timestamp;
    }
}