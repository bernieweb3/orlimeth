import { useAccount, useConnect, useDisconnect, useChainId, useSwitchChain } from 'wagmi';
import { sepolia } from 'wagmi/chains';
import { FiLogOut, FiAlertTriangle } from 'react-icons/fi';

export function ConnectButton() {
    const { address, isConnected } = useAccount();
    const { connect, connectors } = useConnect();
    const { disconnect } = useDisconnect();
    const chainId = useChainId();
    const { switchChain } = useSwitchChain();

    const isWrongNetwork = isConnected && chainId !== sepolia.id;

    if (!isConnected) {
        return (
            <div style={{ display: 'flex', gap: '8px' }}>
                {connectors.map((connector) => (
                    <button
                        key={connector.uid}
                        className="btn btn-primary btn-sm"
                        onClick={() => connect({ connector })}
                    >
                        {connector.name === 'Injected' ? 'MetaMask' : connector.name}
                    </button>
                ))}
            </div>
        );
    }

    if (isWrongNetwork) {
        return (
            <button
                className="btn btn-sm"
                style={{ borderColor: 'var(--neon-amber)', color: 'var(--neon-amber)' }}
                onClick={() => switchChain({ chainId: sepolia.id })}
            >
                <FiAlertTriangle /> Switch to Sepolia
            </button>
        );
    }

    return (
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{
                padding: '6px 12px',
                background: 'var(--obsidian-elevated)',
                border: '1px solid var(--obsidian-border)',
                borderRadius: 'var(--radius-sm)',
                fontFamily: 'var(--font-data)',
                fontSize: '12px',
            }}>
                <span style={{ color: 'var(--neon-mint)', marginRight: '6px' }}>●</span>
                {address?.slice(0, 6)}...{address?.slice(-4)}
            </div>
            <button className="btn btn-ghost btn-sm" onClick={() => disconnect()}>
                <FiLogOut size={14} />
            </button>
        </div>
    );
}
