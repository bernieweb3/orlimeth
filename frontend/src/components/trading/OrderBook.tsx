import { useAccount } from 'wagmi';
import { useReadContract } from 'wagmi';
import { ORDER_MANAGER_ADDRESS, ORDER_MANAGER_ABI } from '../../config/contracts';
import { OrderStatus } from '../../types/order';
import { formatUnits } from 'viem';

export function OrderBook() {
    const { address } = useAccount();

    // Fetch user orders (if connected)
    const { data: orderIds } = useReadContract({
        address: ORDER_MANAGER_ADDRESS,
        abi: ORDER_MANAGER_ABI,
        functionName: 'getUserOrders',
        args: address ? [address] : undefined,
        query: { enabled: !!address },
    });

    return (
        <div className="card" style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
            <div className="card-header">
                <h3>Order Book</h3>
                <span className="data text-muted">{orderIds?.length ?? 0} orders</span>
            </div>
            <div style={{ flex: 1, overflow: 'auto' }}>
                <table className="data-table">
                    <thead>
                        <tr>
                            <th>Order ID</th>
                            <th>Pair</th>
                            <th>Amount In</th>
                            <th>Amount Out</th>
                            <th>Expiry</th>
                            <th>Status</th>
                        </tr>
                    </thead>
                    <tbody>
                        {!orderIds || orderIds.length === 0 ? (
                            <tr>
                                <td colSpan={6} style={{ textAlign: 'center', padding: '40px', color: 'var(--obsidian-text-dim)' }}>
                                    {address ? 'No orders yet. Create your first order!' : 'Connect wallet to view orders'}
                                </td>
                            </tr>
                        ) : (
                            orderIds.map((orderId) => (
                                <OrderRow key={orderId} orderId={orderId} />
                            ))
                        )}
                    </tbody>
                </table>
            </div>
        </div>
    );
}

function OrderRow({ orderId }: { orderId: `0x${string}` }) {
    const { data: order } = useReadContract({
        address: ORDER_MANAGER_ADDRESS,
        abi: ORDER_MANAGER_ABI,
        functionName: 'getOrder',
        args: [orderId],
    });

    if (!order) return null;

    const status = Number(order.status) as OrderStatus;
    const statusLabel = ['OPEN', 'FILLED', 'CANCELLED'][status] ?? 'UNKNOWN';
    const statusClass = ['badge-open', 'badge-filled', 'badge-cancelled'][status] ?? '';
    const expiryDate = new Date(Number(order.expiry) * 1000);
    const isExpired = expiryDate < new Date();

    return (
        <tr>
            <td>
                <a
                    href={`https://sepolia.etherscan.io/address/${ORDER_MANAGER_ADDRESS}`}
                    target="_blank" rel="noreferrer"
                    className="data"
                    style={{ color: 'var(--neon-cyan)' }}
                >
                    {orderId.slice(0, 10)}...
                </a>
            </td>
            <td className="data">
                {order.tokenIn.slice(0, 6)}→{order.tokenOut.slice(0, 6)}
            </td>
            <td className="data">{formatUnits(order.amountIn, 18)}</td>
            <td className="data">{formatUnits(order.amountOut, 6)}</td>
            <td className="data" style={{ color: isExpired ? 'var(--neon-magenta)' : 'var(--obsidian-text-muted)' }}>
                {expiryDate.toLocaleDateString()} {expiryDate.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
            </td>
            <td>
                <span className={`badge ${statusClass}`}>{statusLabel}</span>
            </td>
        </tr>
    );
}
