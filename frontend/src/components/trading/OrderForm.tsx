import { useState } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseUnits } from 'viem';
import { ORDER_MANAGER_ADDRESS, ORDER_MANAGER_ABI, ERC20_ABI } from '../../config/contracts';
import { FiArrowDown } from 'react-icons/fi';

// Demo token addresses on Sepolia (replace with actual deployed mock tokens)
const TOKENS: Record<string, { address: `0x${string}`; symbol: string; decimals: number }> = {
    WETH: { address: '0x0000000000000000000000000000000000000001', symbol: 'WETH', decimals: 18 },
    USDC: { address: '0x0000000000000000000000000000000000000002', symbol: 'USDC', decimals: 6 },
};

export function OrderForm() {
    const { address, isConnected } = useAccount();
    const [tokenIn, setTokenIn] = useState('WETH');
    const [tokenOut, setTokenOut] = useState('USDC');
    const [amountIn, setAmountIn] = useState('');
    const [amountOut, setAmountOut] = useState('');
    const [expiry, setExpiry] = useState('24'); // hours
    const [step, setStep] = useState<'idle' | 'approving' | 'creating'>('idle');

    const { writeContract: approve, data: approveTxHash } = useWriteContract();
    const { writeContract: createOrder, data: createTxHash } = useWriteContract();

    const { isLoading: isApproving, isSuccess: isApproved } = useWaitForTransactionReceipt({
        hash: approveTxHash,
    });

    const { isLoading: isCreating, isSuccess: isCreated } = useWaitForTransactionReceipt({
        hash: createTxHash,
    });

    const handleSwapTokens = () => {
        setTokenIn(tokenOut);
        setTokenOut(tokenIn);
        setAmountIn(amountOut);
        setAmountOut(amountIn);
    };

    const handleSubmit = async () => {
        if (!address || !amountIn || !amountOut) return;

        const tokenInInfo = TOKENS[tokenIn];
        const tokenOutInfo = TOKENS[tokenOut];
        if (!tokenInInfo || !tokenOutInfo) return;

        const parsedAmountIn = parseUnits(amountIn, tokenInInfo.decimals);

        // Step 1: Approve
        setStep('approving');
        approve({
            address: tokenInInfo.address,
            abi: ERC20_ABI,
            functionName: 'approve',
            args: [ORDER_MANAGER_ADDRESS, parsedAmountIn],
        });
    };

    // Step 2: After approval, create order
    const handleCreateOrder = () => {
        if (!amountIn || !amountOut) return;
        const tokenInInfo = TOKENS[tokenIn];
        const tokenOutInfo = TOKENS[tokenOut];
        if (!tokenInInfo || !tokenOutInfo) return;

        const parsedAmountIn = parseUnits(amountIn, tokenInInfo.decimals);
        const parsedAmountOut = parseUnits(amountOut, tokenOutInfo.decimals);
        const expiryTimestamp = BigInt(Math.floor(Date.now() / 1000) + Number(expiry) * 3600);

        setStep('creating');
        createOrder({
            address: ORDER_MANAGER_ADDRESS,
            abi: ORDER_MANAGER_ABI,
            functionName: 'createOrder',
            args: [{
                tokenIn: tokenInInfo.address,
                tokenOut: tokenOutInfo.address,
                amountIn: parsedAmountIn,
                amountOut: parsedAmountOut,
                expiry: expiryTimestamp,
            }],
        });
    };

    const isLoading = isApproving || isCreating;

    return (
        <div className="card" style={{ height: '100%' }}>
            <div className="card-header">
                <h3>Create Order</h3>
            </div>
            <div className="card-body" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                {/* Token In */}
                <div className="input-group">
                    <label>You Pay</label>
                    <div className="input-wrapper">
                        <input
                            type="number"
                            placeholder="0.00"
                            value={amountIn}
                            onChange={(e) => setAmountIn(e.target.value)}
                            disabled={isLoading}
                        />
                        <select
                            value={tokenIn}
                            onChange={(e) => setTokenIn(e.target.value)}
                            style={{
                                background: 'var(--obsidian-elevated)',
                                border: 'none',
                                color: 'var(--obsidian-text)',
                                fontFamily: 'var(--font-data)',
                                fontSize: '12px',
                                padding: '8px',
                                cursor: 'pointer',
                            }}
                        >
                            {Object.keys(TOKENS).map((t) => (
                                <option key={t} value={t}>{t}</option>
                            ))}
                        </select>
                    </div>
                </div>

                {/* Swap Button */}
                <div style={{ display: 'flex', justifyContent: 'center' }}>
                    <button className="btn btn-ghost btn-sm" onClick={handleSwapTokens} disabled={isLoading}>
                        <FiArrowDown size={16} />
                    </button>
                </div>

                {/* Token Out */}
                <div className="input-group">
                    <label>You Receive</label>
                    <div className="input-wrapper">
                        <input
                            type="number"
                            placeholder="0.00"
                            value={amountOut}
                            onChange={(e) => setAmountOut(e.target.value)}
                            disabled={isLoading}
                        />
                        <select
                            value={tokenOut}
                            onChange={(e) => setTokenOut(e.target.value)}
                            style={{
                                background: 'var(--obsidian-elevated)',
                                border: 'none',
                                color: 'var(--obsidian-text)',
                                fontFamily: 'var(--font-data)',
                                fontSize: '12px',
                                padding: '8px',
                                cursor: 'pointer',
                            }}
                        >
                            {Object.keys(TOKENS).map((t) => (
                                <option key={t} value={t}>{t}</option>
                            ))}
                        </select>
                    </div>
                </div>

                {/* Expiry */}
                <div className="input-group">
                    <label>Expiry</label>
                    <div className="input-wrapper">
                        <input
                            type="number"
                            placeholder="24"
                            value={expiry}
                            onChange={(e) => setExpiry(e.target.value)}
                            disabled={isLoading}
                        />
                        <span className="input-suffix">Hours</span>
                    </div>
                </div>

                {/* Price Display */}
                {amountIn && amountOut && Number(amountIn) > 0 && (
                    <div style={{
                        padding: '10px 12px',
                        background: 'var(--obsidian-deep)',
                        borderRadius: 'var(--radius-sm)',
                        fontFamily: 'var(--font-data)',
                        fontSize: '12px',
                        color: 'var(--obsidian-text-muted)',
                    }}>
                        <div className="flex-between">
                            <span>Rate</span>
                            <span style={{ color: 'var(--obsidian-text)' }}>
                                1 {tokenIn} = {(Number(amountOut) / Number(amountIn)).toFixed(4)} {tokenOut}
                            </span>
                        </div>
                        <div className="flex-between" style={{ marginTop: '4px' }}>
                            <span>Fee (0.3%)</span>
                            <span>{(Number(amountIn) * 0.003).toFixed(6)} {tokenIn}</span>
                        </div>
                    </div>
                )}

                {/* Submit */}
                {!isConnected ? (
                    <div style={{ textAlign: 'center', padding: '16px', color: 'var(--obsidian-text-muted)', fontSize: '13px' }}>
                        Connect wallet to create orders
                    </div>
                ) : step === 'idle' || (!isApproving && !isApproved) ? (
                    <button
                        className={`btn btn-buy btn-lg ${isLoading ? 'btn-loading' : ''}`}
                        onClick={handleSubmit}
                        disabled={!amountIn || !amountOut || isLoading}
                    >
                        {isApproving ? 'Approving...' : 'Approve & Create Order'}
                    </button>
                ) : isApproved && !isCreated ? (
                    <button
                        className={`btn btn-primary btn-lg ${isCreating ? 'btn-loading' : ''}`}
                        onClick={handleCreateOrder}
                        disabled={isCreating}
                    >
                        {isCreating ? 'Creating Order...' : 'Confirm Order'}
                    </button>
                ) : isCreated ? (
                    <div style={{
                        textAlign: 'center',
                        padding: '12px',
                        color: 'var(--neon-mint)',
                        fontWeight: 600,
                    }}>
                        ✓ Order Created Successfully!
                    </div>
                ) : null}

                {createTxHash && (
                    <a
                        href={`https://sepolia.etherscan.io/tx/${createTxHash}`}
                        target="_blank"
                        rel="noreferrer"
                        style={{ textAlign: 'center', fontSize: '11px', fontFamily: 'var(--font-data)' }}
                    >
                        View on Etherscan ↗
                    </a>
                )}
            </div>
        </div>
    );
}
