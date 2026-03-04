# orlimeth

> A Limit Order Protocol on Ethereum Sepolia — ported from [orlim](https://github.com/Vietnam-Sui-Builders/orlim) on Sui.

[![CI](https://github.com/bernieweb3/orlimeth/actions/workflows/ci.yml/badge.svg)](https://github.com/bernieweb3/orlimeth/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## Overview

**orlimeth** ports the Sui-native `orlim` limit order protocol to EVM, enabling trustless peer-to-peer token swaps at user-defined prices on Ethereum Sepolia.

- **Smart Contracts:** Solidity 0.8.20, Foundry, OpenZeppelin
- **Indexer:** Envio HyperIndex (real-time order book)
- **Frontend:** Vite + React + TypeScript + wagmi/viem
- **Design System:** "Obsidian & Neon" — dark mode trading terminal aesthetic

---

## Project Structure

```
orlimeth/
├── contracts/          # Solidity smart contracts (Foundry project)
│   ├── src/
│   │   ├── interfaces/IOrlim.sol      # Protocol ABI
│   │   ├── libraries/Errors.sol       # Custom errors
│   │   ├── OrlimStorage.sol           # State management
│   │   ├── Vault.sol                  # ERC-20 escrow
│   │   └── OrderManager.sol           # Core contract ⭐
│   ├── test/
│   │   ├── OrderManager.t.sol         # 32 unit tests
│   │   ├── OrderManager.fuzz.t.sol    # 5 fuzz tests (1000 runs)
│   │   └── invariants/                # 4 invariant tests
│   ├── script/Deploy.s.sol            # Deployment script
│   ├── abi/OrderManager.json          # Compiled ABI
│   └── foundry.toml
├── indexer/            # Envio HyperIndex
│   ├── config.yaml
│   ├── schema.graphql
│   ├── src/EventHandlers.ts
│   └── queries.graphql
├── frontend/           # React trading dashboard
│   └── src/
│       ├── components/ # UI components
│       ├── config/     # wagmi + contract config
│       ├── hooks/      # Custom React hooks
│       └── styles/     # Obsidian & Neon CSS
└── .docs/CONTEXT.md    # Full SRS, SAD, SDD, TDD, UI/UX specs
```

---

## Deployed Contract

| Network | Address |
|:---|:---|
| **Ethereum Sepolia** | [`0x3ced97b7001bbd567563fb6efdf16709dddd10f7`](https://sepolia.etherscan.io/address/0x3ced97b7001bbd567563fb6efdf16709dddd10f7) |

---

## Quick Start

### 1. Contracts

```bash
cd contracts
forge build
forge test -vv          # 41 tests (unit + fuzz + invariant)
forge test --gas-report
```

### 2. Indexer

```bash
cd indexer
npm install
# Update contracts[0].address in config.yaml with deployed address
npx envio dev
```

### 3. Frontend

```bash
cd frontend
npm install
npm run dev             # http://localhost:5173
```

---

## Architecture

```
User Wallet
    │
    ▼ (wagmi/viem)
OrderManager.sol ◄──── Envio Indexer ◄──── React Frontend
    │                        │
    ▼                        ▼
Vault (escrow)         GraphQL API
OrlimStorage           (order book, fills,
                        portfolio stats)
```

### Sui → EVM Mapping

| Sui Concept | EVM Equivalent |
|:---|:---|
| `Object<OrderReceipt>` | `mapping(bytes32 => Order)` |
| `Coin<T>` transfer | `SafeERC20.transferFrom` |
| `Table<u64, OrderData>` | `mapping + bytes32[] userOrders` |
| `TxContext.sender()` | `msg.sender` |
| `Clock.timestamp_ms()` | `block.timestamp` (seconds) |

---

## Testing Summary

| Suite | Count | Runs |
|:---|:---|:---|
| Unit Tests | 32 | 1× |
| Fuzz Tests | 5 | 1000+ each |
| Invariant Tests | 4 | 256 runs × depth 15 |
| **Total** | **41** | **All Pass ✅** |

> **Edge case found by fuzzing:** When `fillAmount` is too small relative to `amountIn`, proportional `fillAmountOut` rounds to 0. Fixed with explicit guard → `if (fillAmountOut == 0) revert Orlim__ZeroAmount()`.

---

## Gas Benchmarks

| Function | Median | Max |
|:---|:---|:---|
| `createOrder` | 247,074 | 247,086 |
| `fillOrder` | 116,439 | 148,024 |
| `cancelOrder` | 45,653 | 45,653 |

---

## License

MIT © 2026 orlimeth contributors
