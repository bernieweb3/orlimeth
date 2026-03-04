// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Errors} from "./libraries/Errors.sol";

/// @title Vault - Secure ERC-20 token escrow for the Orlimeth protocol
/// @author orlimeth team
/// @notice Handles deposit and withdrawal of ERC-20 tokens during the order lifecycle
/// @dev Sui→EVM transition: replaces `Coin<T>` split/merge with SafeERC20 transferFrom/transfer.
///      Uses SafeERC20 to handle tokens that don't return bool (e.g., USDT). (TDD §5 Checklist)
abstract contract Vault {
    using SafeERC20 for IERC20;

    // ═══════════════════════════════════════════════════════════════════
    //                     INTERNAL FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Deposits tokens from a user into the contract (escrow)
    /// @dev Called during order creation. Requires prior ERC-20 approval.
    /// @param token The ERC-20 token address
    /// @param from The address to pull tokens from
    /// @param amount The amount to deposit
    function _deposit(address token, address from, uint128 amount) internal {
        if (amount == 0) revert Errors.Orlim__ZeroAmount();
        IERC20(token).safeTransferFrom(from, address(this), amount);
    }

    /// @notice Withdraws tokens from the contract to a recipient
    /// @dev Called during order cancellation or fill settlement
    /// @param token The ERC-20 token address
    /// @param to The recipient address
    /// @param amount The amount to withdraw
    function _withdraw(address token, address to, uint128 amount) internal {
        if (amount == 0) revert Errors.Orlim__ZeroAmount();
        if (to == address(0)) revert Errors.Orlim__ZeroAddress();
        IERC20(token).safeTransfer(to, amount);
    }
}
