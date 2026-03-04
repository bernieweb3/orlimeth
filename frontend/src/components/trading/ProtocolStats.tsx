import { useReadContract } from 'wagmi';
import { ORDER_MANAGER_ADDRESS, ORDER_MANAGER_ABI } from '../../config/contracts';

export function ProtocolStats() {
    const { data: feeBps } = useReadContract({
        address: ORDER_MANAGER_ADDRESS,
        abi: ORDER_MANAGER_ABI,
        functionName: 'feeBps',
    });

    const { data: treasury } = useReadContract({
        address: ORDER_MANAGER_ADDRESS,
        abi: ORDER_MANAGER_ABI,
        functionName: 'treasury',
    });

    return (
        <div className="card" style={{ height: '100%' }}>
            <div className="card-header">
                <h3>Protocol Info</h3>
            </div>
            <div className="card-body" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                {/* Stats */}
                <div style={{
                    display: 'grid',
                    gridTemplateColumns: '1fr 1fr',
                    gap: '12px',
                }}>
                    <StatBox label="Protocol Fee" value={feeBps ? `${Number(feeBps) / 100}%` : '...'} />
                    <StatBox label="Network" value="Sepolia" color="var(--neon-cyan)" />
                    <StatBox label="Version" value="v1.0.0" />
                    <StatBox label="Status" value="Active" color="var(--neon-mint)" />
                </div>

                {/* Treasury */}
                <div style={{
                    padding: '12px',
                    background: 'var(--obsidian-deep)',
                    borderRadius: 'var(--radius-sm)',
                }}>
                    <div style={{ fontSize: '10px', color: 'var(--obsidian-text-muted)', textTransform: 'uppercase', marginBottom: '4px' }}>
                        Treasury
                    </div>
                    <a
                        href={treasury ? `https://sepolia.etherscan.io/address/${treasury}` : '#'}
                        target="_blank"
                        rel="noreferrer"
                        className="data"
                        style={{ fontSize: '11px', color: 'var(--neon-cyan)', wordBreak: 'break-all' }}
                    >
                        {treasury ?? '...'}
                    </a>
                </div>

                {/* Links */}
                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', marginTop: 'auto' }}>
                    <a
                        href="https://sepolia.etherscan.io/address/0x3ced97b7001bbd567563fb6efdf16709dddd10f7"
                        target="_blank" rel="noreferrer"
                        className="btn btn-ghost btn-sm"
                        style={{ justifyContent: 'flex-start', textDecoration: 'none' }}
                    >
                        📄 Contract on Etherscan
                    </a>
                    <a
                        href="https://github.com/bernieweb3/orlimeth"
                        target="_blank" rel="noreferrer"
                        className="btn btn-ghost btn-sm"
                        style={{ justifyContent: 'flex-start', textDecoration: 'none' }}
                    >
                        💻 Source (orlimeth)
                    </a>
                </div>
            </div>
        </div>
    );
}

function StatBox({ label, value, color }: { label: string; value: string; color?: string }) {
    return (
        <div style={{
            padding: '12px',
            background: 'var(--obsidian-deep)',
            borderRadius: 'var(--radius-sm)',
            border: '1px solid var(--obsidian-border)',
        }}>
            <div style={{ fontSize: '10px', color: 'var(--obsidian-text-muted)', textTransform: 'uppercase', marginBottom: '4px' }}>
                {label}
            </div>
            <div className="data-lg" style={{ color: color ?? 'var(--obsidian-text)', fontWeight: 600 }}>
                {value}
            </div>
        </div>
    );
}
