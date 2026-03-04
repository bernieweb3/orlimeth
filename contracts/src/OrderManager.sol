// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IOrlim} from "./interfaces/IOrlim.sol";
import {OrlimStorage} from "./OrlimStorage.sol";
import {Vault} from "./Vault.sol";
import {Errors} from "./libraries/Errors.sol";

/// @title OrderManager - Core limit order protocol for orlimeth
/// @author orlimeth team
/// @notice Manages the full lifecycle of limit orders: create, fill (full/partial), and cancel
/// @dev Sui→EVM transition notes:
///      - Sui `OrderManager` object → single contract instance
///      - Sui `Table<u64, OrderReceiptData>` → `mapping(bytes32 => Order)`
///      - Sui `vector<u64> active_orders` → off-chain indexer (Envio) for order book
///      - Sui `Coin<T>` → ERC-20 `transferFrom` via SafeERC20 (in Vault)
///      - Sui `TxContext.sender()` → `msg.sender`
///      - Sui `Clock.timestamp_ms()` → `block.timestamp` (seconds)
///      Implements Checks-Effects-Interactions (CEI) pattern — CTO Golden Rule #1
contract OrderManager is IOrlim, OrlimStorage, Vault, ReentrancyGuard, Ownable, Pausable {
    // ═══════════════════════════════════════════════════════════════════
    //                        CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Initializes the OrderManager with fee configuration
    /// @param _feeBps Initial fee in basis points (max 500 = 5%)
    /// @param _treasury Address to receive protocol fees
    constructor(uint256 _feeBps, address _treasury) Ownable(msg.sender) {
        if (_feeBps > MAX_FEE_BPS) revert Errors.Orlim__FeeExceedsMax();
        if (_treasury == address(0)) revert Errors.Orlim__ZeroAddress();
        feeBps = _feeBps;
        treasury = _treasury;
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     EXTERNAL FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Creates a new limit order and escrows the maker's tokens
    /// @dev Generates a unique orderId from keccak256(maker, nonce, block.timestamp)
    ///      Sui equivalent: `place_limit_order()` which creates an OrderReceipt object
    /// @param params The order creation parameters (tokenIn, tokenOut, amountIn, amountOut, expiry)
    /// @return orderId The unique hash identifying this order
    function createOrder(CreateOrderParams calldata params)
        external
        nonReentrant
        whenNotPaused
        returns (bytes32 orderId)
    {
        // ── Checks ──────────────────────────────────────────────────
        if (params.amountIn == 0) revert Errors.Orlim__ZeroAmount();
        if (params.amountOut == 0) revert Errors.Orlim__ZeroAmount();
        if (params.expiry <= uint64(block.timestamp)) revert Errors.Orlim__InvalidExpiry();
        if (params.tokenIn == address(0) || params.tokenOut == address(0)) revert Errors.Orlim__ZeroAddress();
        if (params.tokenIn == params.tokenOut) revert Errors.Orlim__SameToken();

        // ── Effects ─────────────────────────────────────────────────
        uint256 nonce;
        unchecked {
            nonce = _nonces[msg.sender]++;
        }

        orderId = keccak256(abi.encode(msg.sender, nonce, block.timestamp));

        _orders[orderId] = Order({
            maker: msg.sender,
            expiry: params.expiry,
            status: OrderStatus.OPEN,
            tokenIn: params.tokenIn,
            tokenOut: params.tokenOut,
            amountIn: params.amountIn,
            amountOut: params.amountOut
        });

        _remainingAmounts[orderId] = params.amountIn;
        _userOrders[msg.sender].push(orderId);

        // ── Interactions ────────────────────────────────────────────
        _deposit(params.tokenIn, msg.sender, params.amountIn);

        emit OrderCreated(
            orderId, msg.sender, params.tokenIn, params.tokenOut, params.amountIn, params.amountOut, params.expiry
        );
    }

    /// @notice Fills an existing order (full or partial)
    /// @dev CEI pattern enforced. The filler provides tokenOut; receives proportional tokenIn.
    ///      Sui equivalent: `handle_oco_fill()` / market fill via DeepBook
    ///      Fee is deducted from the tokenIn amount going to the filler.
    /// @param orderId The unique hash of the order to fill
    /// @param fillAmount The amount of tokenIn to fill (must be <= remainingAmount)
    function fillOrder(bytes32 orderId, uint128 fillAmount) external nonReentrant whenNotPaused {
        Order storage order = _orders[orderId];
        uint128 remaining = _remainingAmounts[orderId];

        // ── Checks ──────────────────────────────────────────────────
        if (order.status != OrderStatus.OPEN) revert Errors.Orlim__InvalidStatus();
        if (uint64(block.timestamp) > order.expiry) revert Errors.Orlim__OrderExpired();
        if (fillAmount == 0) revert Errors.Orlim__ZeroAmount();
        if (fillAmount > remaining) revert Errors.Orlim__FillExceedsRemaining();

        // ── Effects ─────────────────────────────────────────────────
        // Calculate proportional amountOut the filler must provide to the maker
        // fillAmountOut = (fillAmount * order.amountOut) / order.amountIn
        uint128 fillAmountOut = uint128((uint256(fillAmount) * uint256(order.amountOut)) / uint256(order.amountIn));
        if (fillAmountOut == 0) revert Errors.Orlim__ZeroAmount();

        // Calculate fee on the tokenIn going to filler
        uint128 feeAmount = 0;
        if (feeBps > 0) {
            feeAmount = uint128((uint256(fillAmount) * feeBps) / _BPS_DENOMINATOR);
        }
        uint128 fillerReceives = fillAmount - feeAmount;

        unchecked {
            remaining -= fillAmount;
        }
        _remainingAmounts[orderId] = remaining;

        if (remaining == 0) {
            order.status = OrderStatus.FILLED;
        }

        // ── Interactions ────────────────────────────────────────────
        // 1. Filler sends tokenOut to maker (proportional to fill)
        _deposit(order.tokenOut, msg.sender, fillAmountOut);
        _withdraw(order.tokenOut, order.maker, fillAmountOut);

        // 2. Contract sends tokenIn to filler (minus fee)
        _withdraw(order.tokenIn, msg.sender, fillerReceives);

        // 3. Send fee to treasury (if any)
        if (feeAmount > 0) {
            _withdraw(order.tokenIn, treasury, feeAmount);
        }

        emit OrderFilled(orderId, msg.sender, fillAmount);
    }

    /// @notice Cancels an open order and refunds escrowed tokens to the maker
    /// @dev Only the original maker can cancel. Refunds the remaining unfilled amount.
    ///      Sui equivalent: `cancel_order_by_id()` / `cancel_order_by_object()`
    /// @param orderId The unique hash of the order to cancel
    function cancelOrder(bytes32 orderId) external nonReentrant {
        Order storage order = _orders[orderId];

        // ── Checks ──────────────────────────────────────────────────
        if (msg.sender != order.maker) revert Errors.Orlim__Unauthorized();
        if (order.status != OrderStatus.OPEN) revert Errors.Orlim__InvalidStatus();

        uint128 remaining = _remainingAmounts[orderId];

        // ── Effects ─────────────────────────────────────────────────
        order.status = OrderStatus.CANCELLED;
        _remainingAmounts[orderId] = 0;

        // ── Interactions ────────────────────────────────────────────
        if (remaining > 0) {
            _withdraw(order.tokenIn, order.maker, remaining);
        }

        emit OrderCancelled(orderId);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                       VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Returns the full order details for a given orderId
    /// @param orderId The unique hash of the order
    /// @return order The Order struct
    function getOrder(bytes32 orderId) external view returns (Order memory order) {
        return _orders[orderId];
    }

    /// @notice Returns the remaining fillable amount for an order
    /// @param orderId The unique hash of the order
    /// @return remaining The remaining amount of tokenIn
    function getRemainingAmount(bytes32 orderId) external view returns (uint128 remaining) {
        return _remainingAmounts[orderId];
    }

    /// @notice Returns all order IDs for a given user
    /// @param user The user's address
    /// @return orderIds Array of order hashes
    function getUserOrders(address user) external view returns (bytes32[] memory orderIds) {
        return _userOrders[user];
    }

    /// @notice Returns the current nonce for a user
    /// @param user The user's address
    /// @return nonce The user's current nonce
    function getNonce(address user) external view returns (uint256 nonce) {
        return _nonces[user];
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Updates the protocol fee
    /// @dev Only callable by the contract owner (NFR-SEC-02)
    /// @param _newFeeBps New fee in basis points
    function setFee(uint256 _newFeeBps) external onlyOwner {
        if (_newFeeBps > MAX_FEE_BPS) revert Errors.Orlim__FeeExceedsMax();
        uint256 oldFee = feeBps;
        feeBps = _newFeeBps;
        emit FeeUpdated(oldFee, _newFeeBps);
    }

    /// @notice Updates the treasury address for fee collection
    /// @dev Only callable by the contract owner
    /// @param _newTreasury New treasury address
    function setTreasury(address _newTreasury) external onlyOwner {
        if (_newTreasury == address(0)) revert Errors.Orlim__ZeroAddress();
        address oldTreasury = treasury;
        treasury = _newTreasury;
        emit TreasuryUpdated(oldTreasury, _newTreasury);
    }

    /// @notice Pauses the protocol (emergency stop)
    /// @dev Only callable by the contract owner. Blocks createOrder and fillOrder.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the protocol
    /// @dev Only callable by the contract owner
    function unpause() external onlyOwner {
        _unpause();
    }
}
