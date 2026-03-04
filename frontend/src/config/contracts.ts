export const ORDER_MANAGER_ADDRESS = '0x3ced97b7001bbd567563fb6efdf16709dddd10f7' as const;

export const ORDER_MANAGER_ABI = [
    // ── Read Functions ──────────────────────────────────────────────
    {
        name: 'getOrder',
        type: 'function',
        stateMutability: 'view',
        inputs: [{ name: 'orderId', type: 'bytes32' }],
        outputs: [{
            name: 'order',
            type: 'tuple',
            components: [
                { name: 'maker', type: 'address' },
                { name: 'expiry', type: 'uint64' },
                { name: 'status', type: 'uint8' },
                { name: 'tokenIn', type: 'address' },
                { name: 'tokenOut', type: 'address' },
                { name: 'amountIn', type: 'uint128' },
                { name: 'amountOut', type: 'uint128' },
            ],
        }],
    },
    {
        name: 'getRemainingAmount',
        type: 'function',
        stateMutability: 'view',
        inputs: [{ name: 'orderId', type: 'bytes32' }],
        outputs: [{ name: 'remaining', type: 'uint128' }],
    },
    {
        name: 'getUserOrders',
        type: 'function',
        stateMutability: 'view',
        inputs: [{ name: 'user', type: 'address' }],
        outputs: [{ name: 'orderIds', type: 'bytes32[]' }],
    },
    {
        name: 'getNonce',
        type: 'function',
        stateMutability: 'view',
        inputs: [{ name: 'user', type: 'address' }],
        outputs: [{ name: 'nonce', type: 'uint256' }],
    },
    {
        name: 'feeBps',
        type: 'function',
        stateMutability: 'view',
        inputs: [],
        outputs: [{ name: '', type: 'uint256' }],
    },
    {
        name: 'treasury',
        type: 'function',
        stateMutability: 'view',
        inputs: [],
        outputs: [{ name: '', type: 'address' }],
    },
    {
        name: 'MAX_FEE_BPS',
        type: 'function',
        stateMutability: 'view',
        inputs: [],
        outputs: [{ name: '', type: 'uint256' }],
    },
    // ── Write Functions ─────────────────────────────────────────────
    {
        name: 'createOrder',
        type: 'function',
        stateMutability: 'nonpayable',
        inputs: [{
            name: 'params',
            type: 'tuple',
            components: [
                { name: 'tokenIn', type: 'address' },
                { name: 'tokenOut', type: 'address' },
                { name: 'amountIn', type: 'uint128' },
                { name: 'amountOut', type: 'uint128' },
                { name: 'expiry', type: 'uint64' },
            ],
        }],
        outputs: [{ name: 'orderId', type: 'bytes32' }],
    },
    {
        name: 'fillOrder',
        type: 'function',
        stateMutability: 'nonpayable',
        inputs: [
            { name: 'orderId', type: 'bytes32' },
            { name: 'fillAmount', type: 'uint128' },
        ],
        outputs: [],
    },
    {
        name: 'cancelOrder',
        type: 'function',
        stateMutability: 'nonpayable',
        inputs: [{ name: 'orderId', type: 'bytes32' }],
        outputs: [],
    },
    // ── Events ──────────────────────────────────────────────────────
    {
        name: 'OrderCreated',
        type: 'event',
        inputs: [
            { name: 'orderId', type: 'bytes32', indexed: true },
            { name: 'maker', type: 'address', indexed: true },
            { name: 'tokenIn', type: 'address', indexed: false },
            { name: 'tokenOut', type: 'address', indexed: false },
            { name: 'amountIn', type: 'uint128', indexed: false },
            { name: 'amountOut', type: 'uint128', indexed: false },
            { name: 'expiry', type: 'uint64', indexed: false },
        ],
    },
    {
        name: 'OrderFilled',
        type: 'event',
        inputs: [
            { name: 'orderId', type: 'bytes32', indexed: true },
            { name: 'filler', type: 'address', indexed: true },
            { name: 'amountFilled', type: 'uint128', indexed: false },
        ],
    },
    {
        name: 'OrderCancelled',
        type: 'event',
        inputs: [
            { name: 'orderId', type: 'bytes32', indexed: true },
        ],
    },
] as const;

export const ERC20_ABI = [
    {
        name: 'approve',
        type: 'function',
        stateMutability: 'nonpayable',
        inputs: [
            { name: 'spender', type: 'address' },
            { name: 'amount', type: 'uint256' },
        ],
        outputs: [{ name: '', type: 'bool' }],
    },
    {
        name: 'allowance',
        type: 'function',
        stateMutability: 'view',
        inputs: [
            { name: 'owner', type: 'address' },
            { name: 'spender', type: 'address' },
        ],
        outputs: [{ name: '', type: 'uint256' }],
    },
    {
        name: 'balanceOf',
        type: 'function',
        stateMutability: 'view',
        inputs: [{ name: 'account', type: 'address' }],
        outputs: [{ name: '', type: 'uint256' }],
    },
    {
        name: 'symbol',
        type: 'function',
        stateMutability: 'view',
        inputs: [],
        outputs: [{ name: '', type: 'string' }],
    },
    {
        name: 'decimals',
        type: 'function',
        stateMutability: 'view',
        inputs: [],
        outputs: [{ name: '', type: 'uint8' }],
    },
    {
        name: 'name',
        type: 'function',
        stateMutability: 'view',
        inputs: [],
        outputs: [{ name: '', type: 'string' }],
    },
] as const;
