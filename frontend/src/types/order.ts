export const OrderStatus = {
    OPEN: 0,
    FILLED: 1,
    CANCELLED: 2,
} as const;

export type OrderStatus = (typeof OrderStatus)[keyof typeof OrderStatus];

export interface Order {
    orderId: `0x${string}`;
    maker: `0x${string}`;
    expiry: bigint;
    status: OrderStatus;
    tokenIn: `0x${string}`;
    tokenOut: `0x${string}`;
    amountIn: bigint;
    amountOut: bigint;
    remainingAmount: bigint;
}

export interface CreateOrderParams {
    tokenIn: `0x${string}`;
    tokenOut: `0x${string}`;
    amountIn: bigint;
    amountOut: bigint;
    expiry: bigint;
}

export type TxStatus = 'idle' | 'approving' | 'pending' | 'success' | 'error';
