// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {OrderManager} from "../../src/OrderManager.sol";
import {IOrlim} from "../../src/interfaces/IOrlim.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

/// @title OrderManagerHandler - Target contract for invariant testing
/// @dev Exposes bounded actions that the invariant fuzzer can call
contract OrderManagerHandler is Test {
    OrderManager public orderManager;
    MockERC20 public tokenA;
    MockERC20 public tokenB;

    address[] public actors;
    bytes32[] public createdOrderIds;
    mapping(bytes32 => bool) public orderIsOpen;

    // Track total escrowed for solvency invariant
    uint256 public totalEscrowed;

    // Ghost variables for nonce tracking
    mapping(address => uint256) public lastKnownNonce;

    constructor(OrderManager _om, MockERC20 _tokenA, MockERC20 _tokenB) {
        orderManager = _om;
        tokenA = _tokenA;
        tokenB = _tokenB;

        // Create distinct actors
        for (uint256 i = 0; i < 5; i++) {
            address actor = makeAddr(string(abi.encodePacked("actor", i)));
            actors.push(actor);
            tokenA.mint(actor, type(uint128).max);
            tokenB.mint(actor, type(uint128).max);
            vm.prank(actor);
            tokenA.approve(address(orderManager), type(uint256).max);
            vm.prank(actor);
            tokenB.approve(address(orderManager), type(uint256).max);
        }
    }

    function createOrder(uint256 actorSeed, uint128 amountIn, uint128 amountOut) external {
        address actor = actors[actorSeed % actors.length];
        amountIn = uint128(bound(amountIn, 1e6, 100 ether));
        amountOut = uint128(bound(amountOut, 1e6, 100 ether));

        vm.prank(actor);
        bytes32 orderId = orderManager.createOrder(
            IOrlim.CreateOrderParams({
                tokenIn: address(tokenA),
                tokenOut: address(tokenB),
                amountIn: amountIn,
                amountOut: amountOut,
                expiry: uint64(block.timestamp) + 1 days
            })
        );

        createdOrderIds.push(orderId);
        orderIsOpen[orderId] = true;
        totalEscrowed += amountIn;

        // Track nonce
        uint256 currentNonce = orderManager.getNonce(actor);
        lastKnownNonce[actor] = currentNonce;
    }

    function fillOrder(uint256 orderSeed, uint128 fillAmount) external {
        if (createdOrderIds.length == 0) return;

        bytes32 orderId = createdOrderIds[orderSeed % createdOrderIds.length];
        IOrlim.Order memory order = orderManager.getOrder(orderId);
        uint128 remaining = orderManager.getRemainingAmount(orderId);

        if (order.status != IOrlim.OrderStatus.OPEN || remaining == 0) return;
        if (block.timestamp > order.expiry) return;

        fillAmount = uint128(bound(fillAmount, 1, remaining));

        // Use a different actor as filler
        address fillerActor = actors[(orderSeed + 1) % actors.length];

        vm.prank(fillerActor);
        orderManager.fillOrder(orderId, fillAmount);

        totalEscrowed -= fillAmount;

        if (remaining - fillAmount == 0) {
            orderIsOpen[orderId] = false;
        }
    }

    function cancelOrder(uint256 orderSeed) external {
        if (createdOrderIds.length == 0) return;

        bytes32 orderId = createdOrderIds[orderSeed % createdOrderIds.length];
        IOrlim.Order memory order = orderManager.getOrder(orderId);
        uint128 remaining = orderManager.getRemainingAmount(orderId);

        if (order.status != IOrlim.OrderStatus.OPEN) return;

        vm.prank(order.maker);
        orderManager.cancelOrder(orderId);

        totalEscrowed -= remaining;
        orderIsOpen[orderId] = false;
    }

    // View helpers for invariant assertions
    function getCreatedOrderCount() external view returns (uint256) {
        return createdOrderIds.length;
    }

    function getOrderId(uint256 index) external view returns (bytes32) {
        return createdOrderIds[index];
    }

    function getActorCount() external view returns (uint256) {
        return actors.length;
    }

    function getActor(uint256 index) external view returns (address) {
        return actors[index];
    }
}

/// @title OrderManagerInvariantTest - Invariant tests for protocol safety
/// @dev Task 3.3: 4 invariants — Solvency, Status Monotonicity, Nonce Monotonicity, No Orphaned Funds
///      Configured in foundry.toml: 256 runs × depth 15
contract OrderManagerInvariantTest is Test {
    OrderManager public orderManager;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    OrderManagerHandler public handler;

    address public treasury = makeAddr("treasury");
    address public admin = makeAddr("admin");

    function setUp() public {
        vm.startPrank(admin);
        tokenA = new MockERC20("WETH", "WETH", 18);
        tokenB = new MockERC20("USDC", "USDC", 6);
        orderManager = new OrderManager(30, treasury); // 0.3% fee
        vm.stopPrank();

        handler = new OrderManagerHandler(orderManager, tokenA, tokenB);

        // Target only the handler for invariant testing
        targetContract(address(handler));
    }

    // ═══════════════════════════════════════════════════════════════════
    //  INVARIANT 1: Solvency — contract always holds enough tokenIn
    //  ∑ escrowed tokenIn ≤ contract.balanceOf(tokenIn)
    // ═══════════════════════════════════════════════════════════════════

    function invariant_Solvency() public view {
        uint256 contractBalance = tokenA.balanceOf(address(orderManager));
        // The contract balance should be >= totalEscrowed minus fees sent to treasury
        // Since fees are sent to treasury during fills, the contract balance should
        // cover all remaining open order amounts
        uint256 totalRemainingInOpenOrders = 0;
        uint256 count = handler.getCreatedOrderCount();
        for (uint256 i = 0; i < count; i++) {
            bytes32 orderId = handler.getOrderId(i);
            IOrlim.Order memory order = orderManager.getOrder(orderId);
            if (order.status == IOrlim.OrderStatus.OPEN) {
                totalRemainingInOpenOrders += orderManager.getRemainingAmount(orderId);
            }
        }
        assertGe(contractBalance, totalRemainingInOpenOrders, "INVARIANT VIOLATED: Solvency");
    }

    // ═══════════════════════════════════════════════════════════════════
    //  INVARIANT 2: Status Monotonicity — OPEN → FILLED or OPEN → CANCELLED only
    //  A FILLED or CANCELLED order must never become OPEN again
    // ═══════════════════════════════════════════════════════════════════

    function invariant_StatusMonotonicity() public view {
        uint256 count = handler.getCreatedOrderCount();
        for (uint256 i = 0; i < count; i++) {
            bytes32 orderId = handler.getOrderId(i);
            IOrlim.Order memory order = orderManager.getOrder(orderId);
            bool handlerTracksAsOpen = handler.orderIsOpen(orderId);

            if (!handlerTracksAsOpen) {
                // If handler says it's no longer open, contract must agree
                assertTrue(
                    order.status != IOrlim.OrderStatus.OPEN,
                    "INVARIANT VIOLATED: StatusMonotonicity - closed order re-opened"
                );
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  INVARIANT 3: Nonce Monotonicity — nonce never decreases
    // ═══════════════════════════════════════════════════════════════════

    function invariant_NonceMonotonicity() public view {
        uint256 actorCount = handler.getActorCount();
        for (uint256 i = 0; i < actorCount; i++) {
            address actor = handler.getActor(i);
            uint256 currentNonce = orderManager.getNonce(actor);
            uint256 lastKnown = handler.lastKnownNonce(actor);
            assertGe(currentNonce, lastKnown, "INVARIANT VIOLATED: NonceMonotonicity");
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  INVARIANT 4: No Orphaned Funds — remaining amount is 0 for closed orders
    // ═══════════════════════════════════════════════════════════════════

    function invariant_NoOrphanedFunds() public view {
        uint256 count = handler.getCreatedOrderCount();
        for (uint256 i = 0; i < count; i++) {
            bytes32 orderId = handler.getOrderId(i);
            IOrlim.Order memory order = orderManager.getOrder(orderId);
            uint128 remaining = orderManager.getRemainingAmount(orderId);

            if (order.status == IOrlim.OrderStatus.FILLED || order.status == IOrlim.OrderStatus.CANCELLED) {
                assertEq(remaining, 0, "INVARIANT VIOLATED: NoOrphanedFunds - closed order has remaining");
            }
        }
    }
}
