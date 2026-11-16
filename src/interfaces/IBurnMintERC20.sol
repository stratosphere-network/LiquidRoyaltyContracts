// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @notice CCT / TokenPool burn-mint surface (distinct from ERC-4626 `mint(shares, receiver)`).
interface IBurnMintERC20 {
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
}