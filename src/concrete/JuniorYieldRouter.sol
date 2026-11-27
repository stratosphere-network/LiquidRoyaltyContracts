// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title JuniorYieldRouter
/// @notice Permissionless USDe forwarding to the Junior Safe on Base. Non-upgradeable; destination is immutable.
contract JuniorYieldRouter is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable USDE;
    address public immutable DESTINATION;

    event USDeRouted(address indexed sender, address indexed router, uint256 amount, address indexed destination);
    event USDeFlushed(address indexed router, uint256 amount, address indexed destination);
    event TokenRescued(address indexed token, address indexed to, uint256 amount);
    event EthRescued(address indexed to, uint256 amount);

    error ZeroAddress();
    error ZeroAmount();
    error UsdeRescueDestinationForbidden(address to, address allowed);

    /// @param usde_ Base USDe token
    /// @param destination_ Junior Safe; sole recipient of routed USDe
    /// @param admin_ Receives `DEFAULT_ADMIN_ROLE` (pause / rescue)
    constructor(address usde_, address destination_, address admin_) {
        if (usde_ == address(0) || destination_ == address(0) || admin_ == address(0)) {
            revert ZeroAddress();
        }

        USDE = IERC20(usde_);
        DESTINATION = destination_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
    }

    /// @notice Pull `amount` USDe from the caller and forward to the Junior Safe
    function route(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();

        USDE.safeTransferFrom(msg.sender, DESTINATION, amount);

        emit USDeRouted(msg.sender, address(this), amount, DESTINATION);
    }

    /// @notice Forward all USDe held by this router to the Junior Safe
    function flush() external whenNotPaused nonReentrant {
        uint256 balance = USDE.balanceOf(address(this));
        if (balance == 0) revert ZeroAmount();

        USDE.safeTransfer(DESTINATION, balance);

        emit USDeFlushed(address(this), balance, DESTINATION);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /// @notice Rescue ERC20 tokens other than USDe, or USDe only to the immutable Junior Safe
    function rescueERC20(address token, address to, uint256 amount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        if (token == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        if (token == address(USDE) && to != DESTINATION) {
            revert UsdeRescueDestinationForbidden(to, DESTINATION);
        }

        IERC20(token).safeTransfer(to, amount);

        emit TokenRescued(token, to, amount);
    }

    /// @notice Rescue native ETH (e.g. accidental transfer)
    function rescueETH(address payable to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        (bool ok,) = to.call{value: amount}("");
        require(ok, "ETH transfer failed");

        emit EthRescued(to, amount);
    }

    receive() external payable {}
}