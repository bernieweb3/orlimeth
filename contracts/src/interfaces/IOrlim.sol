// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IOrlim - Interface for the Orlimeth Limit Order Protocol
/// @author orlimeth team
/// @notice Defines the external API for the limit order system
interface IOrlim {
    // ═══════════════════════════════════════════════════════════════════
    //                            ENUMS
    // ═══════════════════════════════════════════════════════════════════

    enum OrderStatus {
        OPEN, // 0
        FILLED, // 1
        CANCELLED // 2
    }

    // ═══════════════════════════════════════════════════════════════════
    //                           STRUCTS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Core order struct, slot-packed for gas efficiency
    /// @dev Slot 1: maker(20) + expiry(8) + status(1) = 29 bytes
    ///      Slot 2: tokenIn(20) = 20 bytes
    ///      Slot 3: tokenOut(20) = 20 bytes
    ///      Slot 4: amountIn(16) + amountOut(16) = 32 bytes
    struct Order {
        address maker; // 20 bytes | Slot 1
        uint64 expiry; //  8 bytes | Slot 1
        OrderStatus status; //  1 byte  | Slot 1
        address tokenIn; // 20 bytes | Slot 2
        address tokenOut; // 20 bytes | Slot 3
        uint128 amountIn; // 16 bytes | Slot 4
        uint128 amountOut; // 16 bytes | Slot 4
    }

    /// @notice Parameters for creating a new order
    struct CreateOrderParams {
        address tokenIn;
        address tokenOut;
        uint128 amountIn;
        uint128 amountOut;
        uint64 expiry;
    }

    // ═══════════════════════════════════════════════════════════════════
    //                           EVENTS
    // ═══════════════════════════════════════════════════════════════════

    event OrderCreated(
        bytes32 indexed orderId,
        address indexed maker,
        address tokenIn,
        address tokenOut,
        uint128 amountIn,
        uint128 amountOut,
        uint64 expiry
    );

    event OrderFilled(bytes32 indexed orderId, address indexed filler, uint128 amountFilled);

    event OrderCancelled(bytes32 indexed orderId);

    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);

    event TreasuryUpdated(address oldTreasury, address newTreasury);

    // ═══════════════════════════════════════════════════════════════════
    //                      EXTERNAL FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Creates a new limit order and escrows tokens
    /// @param params The order creation parameters
    /// @return orderId The unique hash of the created order
    function createOrder(CreateOrderParams calldata params) external returns (bytes32 orderId);

    /// @notice Fills an existing order (full or partial)
    /// @param orderId The unique hash of the order to fill
    /// @param fillAmount The amount of tokenIn to fill
    function fillOrder(bytes32 orderId, uint128 fillAmount) external;

    /// @notice Cancels an open order and refunds escrowed tokens to the maker
    /// @param orderId The unique hash of the order to cancel
    function cancelOrder(bytes32 orderId) external;

    /// @notice Returns the order details for a given orderId
    /// @param orderId The unique hash of the order
    /// @return order The order struct
    function getOrder(bytes32 orderId) external view returns (Order memory order);
}
