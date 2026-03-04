// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IOrlim} from "./interfaces/IOrlim.sol";

/// @title OrlimStorage - State storage for the Orlimeth protocol
/// @author orlimeth team
/// @notice Contains all state variables and struct definitions. Inherited by logic modules.
/// @dev Sui→EVM transition: replaces Sui's `Table<u64, OrderReceiptData>` with
///      `mapping(bytes32 => Order)` and `vector<u64> active_orders` with off-chain indexer.
abstract contract OrlimStorage {
    // ═══════════════════════════════════════════════════════════════════
    //                         CONSTANTS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Maximum fee in basis points (1% = 100 bps)
    uint256 public constant MAX_FEE_BPS = 500; // 5% max

    /// @notice Protocol version identifier
    string public constant VERSION = "1.0.0";

    /// @notice Basis point denominator
    uint256 internal constant _BPS_DENOMINATOR = 10_000;

    // ═══════════════════════════════════════════════════════════════════
    //                      STATE VARIABLES
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Primary order storage — O(1) lookup by order hash
    /// @dev Replaces Sui's `Table<u64, OrderReceiptData>` (SDD §1.2)
    mapping(bytes32 => IOrlim.Order) internal _orders;

    /// @notice User-specific order history for frontend queries
    mapping(address => bytes32[]) internal _userOrders;

    /// @notice Per-user nonce for unique order ID generation
    mapping(address => uint256) internal _nonces;

    /// @notice Remaining fillable amount per order (supports partial fills)
    /// @dev Stored separately to avoid re-packing the Order struct on partial fills
    mapping(bytes32 => uint128) internal _remainingAmounts;

    /// @notice Protocol fee in basis points
    uint256 public feeBps;

    /// @notice Treasury address for fee collection
    address public treasury;

    // ═══════════════════════════════════════════════════════════════════
    //                         STORAGE GAP
    // ═══════════════════════════════════════════════════════════════════

    /// @dev Reserved storage slots for future upgradability (UUPS)
    uint256[44] private _gap;
}
