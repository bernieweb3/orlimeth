// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {OrderManager} from "../src/OrderManager.sol";
import {IOrlim} from "../src/interfaces/IOrlim.sol";
import {Errors} from "../src/libraries/Errors.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

/// @title OrderManagerFuzzTest - Fuzz tests for the OrderManager
/// @dev Task 3.2: Fuzz 1000+ runs per function (configured in foundry.toml)
///      Input ranges bounded per Implementation Plan specifications
contract OrderManagerFuzzTest is Test {
    OrderManager public orderManager;
    MockERC20 public tokenA;
    MockERC20 public tokenB;

    address public maker = makeAddr("maker");
    address public filler = makeAddr("filler");
    address public treasury = makeAddr("treasury");
    address public admin = makeAddr("admin");

    uint256 public constant FEE_BPS = 30;

    function setUp() public {
        vm.startPrank(admin);
        tokenA = new MockERC20("Wrapped Ether", "WETH", 18);
        tokenB = new MockERC20("USD Coin", "USDC", 6);
        orderManager = new OrderManager(FEE_BPS, treasury);
        vm.stopPrank();

        // Fund with max to support any fuzz amount
        tokenA.mint(maker, type(uint128).max);
        tokenB.mint(filler, type(uint128).max);

        vm.prank(maker);
        tokenA.approve(address(orderManager), type(uint256).max);
        vm.prank(filler);
        tokenB.approve(address(orderManager), type(uint256).max);
    }

    // ═══════════════════════════════════════════════════════════════════
    //  FUZZ 1: testFuzz_CreateOrder — amount ∈ [1, uint128.max], expiry ∈ [now+1, now+365d]
    // ═══════════════════════════════════════════════════════════════════

    function testFuzz_CreateOrder(uint128 amountIn, uint128 amountOut, uint64 expiryDelta) public {
        // Bound inputs to valid ranges
        amountIn = uint128(bound(amountIn, 1, type(uint128).max / 2));
        amountOut = uint128(bound(amountOut, 1, type(uint128).max / 2));
        expiryDelta = uint64(bound(expiryDelta, 1, 365 days));

        uint64 expiry = uint64(block.timestamp) + expiryDelta;

        uint256 makerBalBefore = tokenA.balanceOf(maker);

        vm.prank(maker);
        bytes32 orderId = orderManager.createOrder(
            IOrlim.CreateOrderParams({
                tokenIn: address(tokenA),
                tokenOut: address(tokenB),
                amountIn: amountIn,
                amountOut: amountOut,
                expiry: expiry
            })
        );

        // Verify: order stored correctly
        IOrlim.Order memory order = orderManager.getOrder(orderId);
        assertEq(order.maker, maker, "Maker mismatch");
        assertEq(order.amountIn, amountIn, "AmountIn mismatch");
        assertEq(order.amountOut, amountOut, "AmountOut mismatch");
        assertEq(order.expiry, expiry, "Expiry mismatch");
        assertEq(uint8(order.status), uint8(IOrlim.OrderStatus.OPEN), "Status not OPEN");

        // Verify: tokens escrowed
        assertEq(tokenA.balanceOf(maker), makerBalBefore - amountIn, "Maker balance incorrect");
        assertEq(orderManager.getRemainingAmount(orderId), amountIn, "Remaining mismatch");
    }

    // ═══════════════════════════════════════════════════════════════════
    //  FUZZ 2: testFuzz_FillOrder — fillAmount ∈ [1, order.amountIn]
    // ═══════════════════════════════════════════════════════════════════

    function testFuzz_FillOrder(uint128 fillAmount) public {
        uint128 amountIn = 10 ether;
        uint128 amountOut = 30000 * 1e6;

        // Create an order first
        vm.prank(maker);
        bytes32 orderId = orderManager.createOrder(
            IOrlim.CreateOrderParams({
                tokenIn: address(tokenA),
                tokenOut: address(tokenB),
                amountIn: amountIn,
                amountOut: amountOut,
                expiry: uint64(block.timestamp) + 1 days
            })
        );

        // Bound fillAmount to valid range [minFill, amountIn]
        // minFill ensures proportional amountOut >= 1
        uint128 minFill = uint128((uint256(amountIn) / uint256(amountOut)) + 1);
        fillAmount = uint128(bound(fillAmount, minFill, amountIn));

        uint256 makerTokenBBefore = tokenB.balanceOf(maker);
        uint256 fillerTokenABefore = tokenA.balanceOf(filler);

        vm.prank(filler);
        orderManager.fillOrder(orderId, fillAmount);

        // Verify: proportional tokenOut sent to maker
        uint128 expectedOut = uint128((uint256(fillAmount) * uint256(amountOut)) / uint256(amountIn));
        assertEq(tokenB.balanceOf(maker), makerTokenBBefore + expectedOut, "Maker tokenOut incorrect");

        // Verify: filler received tokenIn minus fee
        uint128 feeAmount = uint128((uint256(fillAmount) * FEE_BPS) / 10_000);
        uint128 fillerReceives = fillAmount - feeAmount;
        assertEq(tokenA.balanceOf(filler), fillerTokenABefore + fillerReceives, "Filler tokenIn incorrect");

        // Verify: remaining updated
        uint128 expectedRemaining = amountIn - fillAmount;
        assertEq(orderManager.getRemainingAmount(orderId), expectedRemaining, "Remaining incorrect");

        // Verify: status
        IOrlim.Order memory order = orderManager.getOrder(orderId);
        if (expectedRemaining == 0) {
            assertEq(uint8(order.status), uint8(IOrlim.OrderStatus.FILLED), "Should be FILLED");
        } else {
            assertEq(uint8(order.status), uint8(IOrlim.OrderStatus.OPEN), "Should still be OPEN");
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  FUZZ 3: testFuzz_PartialFill_Accounting — sequential partial fills
    // ═══════════════════════════════════════════════════════════════════

    function testFuzz_PartialFill_Accounting(uint128 fill1, uint128 fill2) public {
        uint128 amountIn = 100 ether;
        uint128 amountOut = 300000 * 1e6;

        vm.prank(maker);
        bytes32 orderId = orderManager.createOrder(
            IOrlim.CreateOrderParams({
                tokenIn: address(tokenA),
                tokenOut: address(tokenB),
                amountIn: amountIn,
                amountOut: amountOut,
                expiry: uint64(block.timestamp) + 1 days
            })
        );

        // minFill ensures proportional amountOut >= 1
        uint128 minFill = uint128((uint256(amountIn) / uint256(amountOut)) + 1);

        // Bound: fill1 + fill2 <= amountIn, both >= minFill
        fill1 = uint128(bound(fill1, minFill, amountIn - minFill));
        fill2 = uint128(bound(fill2, minFill, amountIn - fill1));

        // First partial fill
        vm.prank(filler);
        orderManager.fillOrder(orderId, fill1);
        assertEq(orderManager.getRemainingAmount(orderId), amountIn - fill1, "Remaining after fill1");

        // Second partial fill
        vm.prank(filler);
        orderManager.fillOrder(orderId, fill2);
        assertEq(orderManager.getRemainingAmount(orderId), amountIn - fill1 - fill2, "Remaining after fill2");

        // Total escrowed should decrease by fill1 + fill2
        uint128 totalFilled = fill1 + fill2;
        uint128 expectedRemaining = amountIn - totalFilled;
        assertEq(orderManager.getRemainingAmount(orderId), expectedRemaining, "Final remaining incorrect");

        // Status check
        IOrlim.Order memory order = orderManager.getOrder(orderId);
        if (expectedRemaining == 0) {
            assertEq(uint8(order.status), uint8(IOrlim.OrderStatus.FILLED));
        } else {
            assertEq(uint8(order.status), uint8(IOrlim.OrderStatus.OPEN));
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  FUZZ 4: testFuzz_Fee_NeverExceedsBasis — feeBps ∈ [0, MAX_FEE_BPS]
    // ═══════════════════════════════════════════════════════════════════

    function testFuzz_Fee_NeverExceedsBasis(uint256 feeBps) public {
        feeBps = bound(feeBps, 0, 500); // MAX_FEE_BPS

        // Deploy with fuzzed fee
        vm.prank(admin);
        OrderManager om = new OrderManager(feeBps, treasury);

        uint128 amountIn = 10 ether;
        uint128 amountOut = 30000 * 1e6;

        // Fund and approve for this new contract
        tokenA.mint(maker, amountIn);
        tokenB.mint(filler, amountOut);
        vm.prank(maker);
        tokenA.approve(address(om), type(uint256).max);
        vm.prank(filler);
        tokenB.approve(address(om), type(uint256).max);

        // Create and fill
        vm.prank(maker);
        bytes32 orderId = om.createOrder(
            IOrlim.CreateOrderParams({
                tokenIn: address(tokenA),
                tokenOut: address(tokenB),
                amountIn: amountIn,
                amountOut: amountOut,
                expiry: uint64(block.timestamp) + 1 days
            })
        );

        uint256 treasuryBefore = tokenA.balanceOf(treasury);

        vm.prank(filler);
        om.fillOrder(orderId, amountIn);

        uint256 treasuryReceived = tokenA.balanceOf(treasury) - treasuryBefore;

        // Fee must never exceed feeBps/10000 of amountIn
        uint256 expectedMaxFee = (uint256(amountIn) * feeBps) / 10_000;
        assertLe(treasuryReceived, expectedMaxFee, "Fee exceeds maximum");

        // Fee should equal expected fee (exact, no rounding issue for these amounts)
        assertEq(treasuryReceived, expectedMaxFee, "Fee not exact");
    }

    // ═══════════════════════════════════════════════════════════════════
    //  FUZZ 5: testFuzz_CancelOrder_RefundsCorrectly
    // ═══════════════════════════════════════════════════════════════════

    function testFuzz_CancelOrder_RefundsCorrectly(uint128 amountIn, uint128 fillFirst) public {
        amountIn = uint128(bound(amountIn, 2, type(uint128).max / 2));
        uint128 amountOut = uint128(bound(uint256(amountIn), 1, type(uint128).max / 2));

        vm.prank(maker);
        bytes32 orderId = orderManager.createOrder(
            IOrlim.CreateOrderParams({
                tokenIn: address(tokenA),
                tokenOut: address(tokenB),
                amountIn: amountIn,
                amountOut: amountOut,
                expiry: uint64(block.timestamp) + 1 days
            })
        );

        // Optionally partial fill first
        fillFirst = uint128(bound(fillFirst, 0, amountIn - 1));
        if (fillFirst > 0) {
            vm.prank(filler);
            orderManager.fillOrder(orderId, fillFirst);
        }

        uint128 remaining = orderManager.getRemainingAmount(orderId);
        uint256 makerBalBefore = tokenA.balanceOf(maker);

        // Cancel
        vm.prank(maker);
        orderManager.cancelOrder(orderId);

        // Verify full remaining refunded
        assertEq(tokenA.balanceOf(maker), makerBalBefore + remaining, "Refund incorrect");
        assertEq(orderManager.getRemainingAmount(orderId), 0, "Remaining not zeroed");
    }
}
