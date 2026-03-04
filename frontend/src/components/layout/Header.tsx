import { ConnectButton } from '../wallet/ConnectButton';

export function Header() {
    return (
        <header style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '0 24px',
            height: '60px',
            borderBottom: '1px solid var(--obsidian-border)',
            background: 'var(--obsidian-surface)',
        }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                <h2 style={{
                    fontSize: '20px',
                    fontWeight: 700,
                    background: 'linear-gradient(135deg, var(--neon-cyan), var(--neon-mint))',
                    WebkitBackgroundClip: 'text',
                    WebkitTextFillColor: 'transparent',
                    letterSpacing: '1px',
                }}>
                    ORLIMETH
                </h2>
                <span style={{
                    fontSize: '10px',
                    padding: '2px 6px',
                    borderRadius: '4px',
                    background: 'var(--neon-cyan-dim)',
                    color: 'var(--neon-cyan)',
                    fontFamily: 'var(--font-data)',
                    fontWeight: 600,
                }}>
                    SEPOLIA
                </span>
            </div>

            <nav style={{ display: 'flex', gap: '24px', alignItems: 'center' }}>
                <a href="https://sepolia.etherscan.io/address/0x3ced97b7001bbd567563fb6efdf16709dddd10f7"
                    target="_blank" rel="noreferrer"
                    style={{ fontSize: '13px', color: 'var(--obsidian-text-muted)' }}>
                    Contract ↗
                </a>
                <ConnectButton />
            </nav>
        </header>
    );
}
