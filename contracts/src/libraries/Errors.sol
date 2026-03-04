// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Errors - Custom error definitions for the Orlimeth protocol
/// @dev Custom errors save ~200-500 gas compared to require strings (TDD §2.1)
library Errors {
    /// @dev Caller is not the order maker
    error Orlim__Unauthorized();

    /// @dev Order has expired (block.timestamp > expiry)
    error Orlim__OrderExpired();

    /// @dev Token balance or amount is insufficient
    error Orlim__InsufficientBalance();

    /// @dev Order status does not allow the requested operation
    error Orlim__InvalidStatus();

    /// @dev Amount parameter is zero
    error Orlim__ZeroAmount();

    /// @dev Expiry timestamp is in the past
    error Orlim__InvalidExpiry();

    /// @dev Address parameter is the zero address
    error Orlim__ZeroAddress();

    /// @dev Fee exceeds the maximum allowed basis points
    error Orlim__FeeExceedsMax();

    /// @dev Fill amount exceeds remaining order amount
    error Orlim__FillExceedsRemaining();

    /// @dev Tokens in and out cannot be the same
    error Orlim__SameToken();
}
