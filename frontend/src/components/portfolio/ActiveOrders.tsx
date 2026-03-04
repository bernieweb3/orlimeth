import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { useReadContract } from 'wagmi';
import { ORDER_MANAGER_ADDRESS, ORDER_MANAGER_ABI } from '../../config/contracts';
import { OrderStatus } from '../../types/order';
import { formatUnits } from 'viem';

export function ActiveOrders() {
    const { address } = useAccount();

    const { data: orderIds, refetch } = useReadContract({
        address: ORDER_MANAGER_ADDRESS,
        abi: ORDER_MANAGER_ABI,
        functionName: 'getUserOrders',
        args: address ? [address] : undefined,
        query: { enabled: !!address },
    });

    return (
        <div className="card">
            <div className="card-header">
                <h3>My Orders</h3>
                <button className="btn btn-ghost btn-sm" onClick={() => refetch()}>
                    ↻ Refresh
                </button>
            </div>
            <div style={{ maxHeight: '300px', overflow: 'auto' }}>
                <table className="data-table">
                    <thead>
                        <tr>
                            <th>Order ID</th>
                            <th>Amount In</th>
                            <th>Amount Out</th>
                            <th>Remaining</th>
                            <th>Progress</th>
                            <th>Status</th>
                            <th>Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        {!orderIds || orderIds.length === 0 ? (
                            <tr>
                                <td colSpan={7} style={{ textAlign: 'center', padding: '32px', color: 'var(--obsidian-text-dim)' }}>
                                    {address ? 'No orders found' : 'Connect wallet to see orders'}
                                </td>
                            </tr>
                        ) : (
                            [...orderIds].reverse().map((orderId) => (
                                <ActiveOrderRow key={orderId} orderId={orderId} />
                            ))
                        )}
                    </tbody>
                </table>
            </div>
        </div>
    );
}

function ActiveOrderRow({ orderId }: { orderId: `0x${string}` }) {
    const { data: order } = useReadContract({
        address: ORDER_MANAGER_ADDRESS,
        abi: ORDER_MANAGER_ABI,
        functionName: 'getOrder',
        args: [orderId],
    });

    const { data: remaining } = useReadContract({
        address: ORDER_MANAGER_ADDRESS,
        abi: ORDER_MANAGER_ABI,
        functionName: 'getRemainingAmount',
        args: [orderId],
    });

    const { writeContract: cancelOrder, data: cancelTxHash } = useWriteContract();
    const { isLoading: isCancelling } = useWaitForTransactionReceipt({
        hash: cancelTxHash,
    });

    if (!order) return null;

    const status = Number(order.status) as OrderStatus;
    const statusLabel = ['OPEN', 'FILLED', 'CANCELLED'][status] ?? 'UNKNOWN';
    const statusClass = ['badge-open', 'badge-filled', 'badge-cancelled'][status] ?? '';

    const filledPercent = remaining !== undefined && order.amountIn > 0n
        ? Number((order.amountIn - remaining) * 100n / order.amountIn)
        : 0;

    const handleCancel = () => {
        cancelOrder({
            address: ORDER_MANAGER_ADDRESS,
            abi: ORDER_MANAGER_ABI,
            functionName: 'cancelOrder',
            args: [orderId],
        });
    };

    return (
        <tr>
            <td className="data" style={{ color: 'var(--neon-cyan)' }}>
                {orderId.slice(0, 10)}...
            </td>
            <td className="data">{formatUnits(order.amountIn, 18)}</td>
            <td className="data">{formatUnits(order.amountOut, 6)}</td>
            <td className="data">
                {remaining !== undefined ? formatUnits(remaining, 18) : '...'}
            </td>
            <td style={{ minWidth: '80px' }}>
                <div className="progress-bar">
                    <div className="progress-bar-fill" style={{ width: `${filledPercent}%` }} />
                </div>
                <span className="data text-muted" style={{ fontSize: '10px' }}>{filledPercent}%</span>
            </td>
            <td>
                <span className={`badge ${statusClass}`}>{statusLabel}</span>
            </td>
            <td>
                {status === OrderStatus.OPEN && (
                    <button
                        className={`btn btn-sell btn-sm ${isCancelling ? 'btn-loading' : ''}`}
                        onClick={handleCancel}
                        disabled={isCancelling}
                    >
                        {isCancelling ? '...' : 'Cancel'}
                    </button>
                )}
            </td>
        </tr>
    );
}
