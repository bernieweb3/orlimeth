/**
 * EventHandlers.ts — Envio event handlers for orlimeth OrderManager
 *
 * Handles:
 * - OrderCreated: Creates Order + User entities, updates ProtocolMetric
 * - OrderFilled:  Updates Order status/remaining, creates Fill entity, updates ProtocolMetric
 * - OrderCancelled: Updates Order status, updates User + ProtocolMetric
 * - FeeUpdated: Updates ProtocolMetric fee
 *
 * Reference: Implementation Plan Task 4.2 + SDD §4.1
 */

// ── Types ─────────────────────────────────────────────────────────
// These types mirror the schema.graphql entities.
// The Envio codegen (`npx envio codegen`) will generate a fully-typed
// "generated" module. Until then, we use manual declarations.

interface Order {
  id: string;
  maker: string;
  tokenIn: string;
  tokenOut: string;
  amountIn: bigint;
  amountOut: bigint;
  remainingAmount: bigint;
  status: string;
  expiry: bigint;
  createdAt: bigint;
  createdTxHash: string;
  filledAt?: bigint;
  cancelledAt?: bigint;
  filler?: string;
  fillCount: number;
  user_id: string;
}

interface User {
  id: string;
  totalOrders: number;
  activeOrders: number;
  filledOrders: number;
  cancelledOrders: number;
}

interface Fill {
  id: string;
  order_id: string;
  filler: string;
  amountFilled: bigint;
  timestamp: bigint;
  txHash: string;
}

interface ProtocolMetric {
  id: string;
  totalOrders: number;
  totalFilled: number;
  totalCancelled: number;
  totalFillEvents: number;
  totalVolumeTokenIn: bigint;
  currentFeeBps: bigint;
}

interface HandlerArgs {
  event: any;
  context: any;
}

interface EventHandler {
  handler: (fn: (args: HandlerArgs) => Promise<void>) => void;
}

declare const OrderManager: {
  OrderCreated: EventHandler;
  OrderFilled: EventHandler;
  OrderCancelled: EventHandler;
  FeeUpdated: EventHandler;
  TreasuryUpdated: EventHandler;
};

// ═══════════════════════════════════════════════════════════════════
//                    HELPER: getOrCreateUser
// ═══════════════════════════════════════════════════════════════════

async function getOrCreateUser(
  context: any,
  address: string
): Promise<User> {
  const userId = address.toLowerCase();
  let user = await context.User.get(userId);
  if (!user) {
    user = {
      id: userId,
      totalOrders: 0,
      activeOrders: 0,
      filledOrders: 0,
      cancelledOrders: 0,
    };
    context.User.set(user);
  }
  return user;
}

// ═══════════════════════════════════════════════════════════════════
//                 HELPER: getOrCreateProtocolMetric
// ═══════════════════════════════════════════════════════════════════

async function getOrCreateProtocolMetric(
  context: any
): Promise<ProtocolMetric> {
  let metric = await context.ProtocolMetric.get("global");
  if (!metric) {
    metric = {
      id: "global",
      totalOrders: 0,
      totalFilled: 0,
      totalCancelled: 0,
      totalFillEvents: 0,
      totalVolumeTokenIn: 0n,
      currentFeeBps: 0n,
    };
    context.ProtocolMetric.set(metric);
  }
  return metric;
}

// ═══════════════════════════════════════════════════════════════════
//                       OrderCreated Handler
// ═══════════════════════════════════════════════════════════════════

OrderManager.OrderCreated.handler(async ({ event, context }: HandlerArgs) => {
  const orderId = event.params.orderId;
  const makerAddress = event.params.maker.toLowerCase();

  // 1. Create Order entity
  const order: Order = {
    id: orderId,
    maker: makerAddress,
    tokenIn: event.params.tokenIn.toLowerCase(),
    tokenOut: event.params.tokenOut.toLowerCase(),
    amountIn: event.params.amountIn,
    amountOut: event.params.amountOut,
    remainingAmount: event.params.amountIn, // Initially full
    status: "OPEN",
    expiry: event.params.expiry,
    createdAt: BigInt(event.block.timestamp),
    createdTxHash: event.transaction.hash,
    filledAt: undefined,
    cancelledAt: undefined,
    filler: undefined,
    fillCount: 0,
    user_id: makerAddress,
  };
  context.Order.set(order);

  // 2. Update User entity
  const user = await getOrCreateUser(context, makerAddress);
  context.User.set({
    ...user,
    totalOrders: user.totalOrders + 1,
    activeOrders: user.activeOrders + 1,
  });

  // 3. Update ProtocolMetric
  const metric = await getOrCreateProtocolMetric(context);
  context.ProtocolMetric.set({
    ...metric,
    totalOrders: metric.totalOrders + 1,
  });
});

// ═══════════════════════════════════════════════════════════════════
//                       OrderFilled Handler
// ═══════════════════════════════════════════════════════════════════

OrderManager.OrderFilled.handler(async ({ event, context }: HandlerArgs) => {
  const orderId = event.params.orderId;
  const fillerAddress = event.params.filler.toLowerCase();
  const amountFilled = event.params.amountFilled;

  // 1. Get existing Order
  const order = await context.Order.get(orderId);
  if (!order) return; // Should not happen if synced from genesis

  // 2. Calculate new remaining
  const newRemaining = order.remainingAmount - amountFilled;
  const isFullyFilled = newRemaining <= 0n;

  // 3. Update Order entity
  context.Order.set({
    ...order,
    remainingAmount: isFullyFilled ? 0n : newRemaining,
    status: isFullyFilled ? "FILLED" : "OPEN",
    filler: fillerAddress,
    filledAt: isFullyFilled ? BigInt(event.block.timestamp) : order.filledAt,
    fillCount: order.fillCount + 1,
  });

  // 4. Create Fill entity (for partial fill tracking)
  const fillId = `${event.transaction.hash}-${event.logIndex}`;
  const fill: Fill = {
    id: fillId,
    order_id: orderId,
    filler: fillerAddress,
    amountFilled: amountFilled,
    timestamp: BigInt(event.block.timestamp),
    txHash: event.transaction.hash,
  };
  context.Fill.set(fill);

  // 5. Update ProtocolMetric
  const metric = await getOrCreateProtocolMetric(context);
  context.ProtocolMetric.set({
    ...metric,
    totalFillEvents: metric.totalFillEvents + 1,
    totalFilled: isFullyFilled
      ? metric.totalFilled + 1
      : metric.totalFilled,
    totalVolumeTokenIn: metric.totalVolumeTokenIn + amountFilled,
  });

  // 6. If fully filled, update maker's User
  if (isFullyFilled) {
    const user = await context.User.get(order.maker);
    if (user) {
      context.User.set({
        ...user,
        activeOrders: Math.max(0, user.activeOrders - 1),
        filledOrders: user.filledOrders + 1,
      });
    }
  }
});

// ═══════════════════════════════════════════════════════════════════
//                     OrderCancelled Handler
// ═══════════════════════════════════════════════════════════════════

OrderManager.OrderCancelled.handler(async ({ event, context }: HandlerArgs) => {
  const orderId = event.params.orderId;

  // 1. Get existing Order
  const order = await context.Order.get(orderId);
  if (!order) return;

  // 2. Update Order entity
  context.Order.set({
    ...order,
    status: "CANCELLED",
    remainingAmount: 0n,
    cancelledAt: BigInt(event.block.timestamp),
  });

  // 3. Update User entity
  const user = await context.User.get(order.maker);
  if (user) {
    context.User.set({
      ...user,
      activeOrders: Math.max(0, user.activeOrders - 1),
      cancelledOrders: user.cancelledOrders + 1,
    });
  }

  // 4. Update ProtocolMetric
  const metric = await getOrCreateProtocolMetric(context);
  context.ProtocolMetric.set({
    ...metric,
    totalCancelled: metric.totalCancelled + 1,
  });
});

// ═══════════════════════════════════════════════════════════════════
//                      FeeUpdated Handler
// ═══════════════════════════════════════════════════════════════════

OrderManager.FeeUpdated.handler(async ({ event, context }: HandlerArgs) => {
  const metric = await getOrCreateProtocolMetric(context);
  context.ProtocolMetric.set({
    ...metric,
    currentFeeBps: event.params.newFeeBps,
  });
});

// ═══════════════════════════════════════════════════════════════════
//                    TreasuryUpdated Handler
// ═══════════════════════════════════════════════════════════════════

OrderManager.TreasuryUpdated.handler(async ({ event, context }: HandlerArgs) => {
  // Log only — treasury address isn't stored in the indexer schema
  // Could be extended to track treasury changes if needed
});
