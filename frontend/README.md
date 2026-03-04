# frontend — orlimeth Trading Dashboard

React + TypeScript frontend for the orlimeth Limit Order Protocol. Built with Vite, wagmi, and viem. Features the "Obsidian & Neon" design system.

---

## Tech Stack

| Tool | Version | Purpose |
|:---|:---|:---|
| [Vite](https://vitejs.dev/) | 7.x | Build tool + dev server |
| [React](https://react.dev/) | 19.x | UI framework |
| [TypeScript](https://www.typescriptlang.org/) | 5.x | Type safety |
| [wagmi](https://wagmi.sh/) | 2.x | Ethereum React hooks |
| [viem](https://viem.sh/) | 2.x | Ethereum TypeScript client |
| [@tanstack/react-query](https://tanstack.com/query) | 5.x | Async state management |

---

## Setup

```bash
cd frontend
npm install
npm run dev     # http://localhost:5173
```

**Required:** A browser with MetaMask or Coinbase Wallet installed and set to **Sepolia** testnet.

---

## Project Structure

```
frontend/
├── src/
│   ├── components/
│   │   ├── layout/
│   │   │   └── Header.tsx          # Logo, Sepolia badge, connect button
│   │   ├── trading/
│   │   │   ├── OrderForm.tsx       # Create order (approve → create 2-step)
│   │   │   ├── OrderBook.tsx       # Order table with status badges
│   │   │   └── ProtocolStats.tsx   # Fee, treasury, links
│   │   ├── portfolio/
│   │   │   └── ActiveOrders.tsx    # My orders + cancel + progress bar
│   │   └── wallet/
│   │       └── ConnectButton.tsx   # Wallet state + network switch
│   ├── config/
│   │   ├── wagmi.ts                # Wagmi config (Sepolia + connectors)
│   │   └── contracts.ts            # OrderManager ABI + address
│   ├── types/
│   │   └── order.ts                # TypeScript interfaces
│   ├── styles/
│   │   └── global.css              # Obsidian & Neon design system
│   ├── App.tsx                     # 12-column grid layout
│   └── main.tsx                    # Entry point
├── index.html
├── vite.config.ts
├── tsconfig.json
└── package.json
```

---

## Dashboard Layout

The dashboard uses a **12-column responsive grid** per the design spec:

```
┌─────────────────────────────────────────────────────────────┐
│  HEADER: Logo | Sepolia | Contract ↗ | [Connect Wallet]     │
├──────────────┬────────────────────────────┬─────────────────┤
│              │                            │                 │
│ CREATE ORDER │       ORDER BOOK           │  PROTOCOL INFO  │
│  (3 cols)    │        (6 cols)            │    (3 cols)     │
│              │                            │                 │
├──────────────┴────────────────────────────┴─────────────────┤
│                       MY ORDERS                             │
│                      (12 cols)                              │
└─────────────────────────────────────────────────────────────┘
```

| Breakpoint | Behavior |
|:---|:---|
| Desktop (>1024px) | Full 12-column grid |
| Tablet (768-1024px) | 2-column stacked |
| Mobile (<768px) | Single column |

---

## Design System — "Obsidian & Neon"

Defined in `src/styles/global.css`.

### Color Palette

| Variable | Hex | Usage |
|:---|:---|:---|
| `--obsidian-deep` | `#050505` | Page background |
| `--obsidian-surface` | `#121212` | Cards, header |
| `--obsidian-border` | `#2A2A2A` | Dividers |
| `--neon-mint` | `#00FF9D` | Buy / Success / OPEN badge |
| `--neon-magenta` | `#FF007A` | Sell / Danger / CANCELLED |
| `--neon-cyan` | `#00D1FF` | Primary actions, focus rings |
| `--neon-amber` | `#FFB800` | Warnings, PENDING states |

### Typography

| Font | Usage |
|:---|:---|
| `Outfit` | UI labels, headings |
| `JetBrains Mono` | All numbers, order IDs, addresses |

### Micro-interactions

- **Hover:** `box-shadow: 0 0 8px <accent-color>` — elements "glow in"
- **Active:** `transform: scale(0.98)` — tactile "click" feedback
- **Tx Signing:** Scanning line animation on button (Neon Cyan sweep)
- **OPEN badge:** Pulsing dot animation

---

## Contract Integration

The frontend connects to:

```
OrderManager: 0x3ced97b7001bbd567563fb6efdf16709dddd10f7 (Sepolia)
```

Defined in `src/config/contracts.ts`. To point to a different deployment, update `ORDER_MANAGER_ADDRESS`.

### Order Creation Flow

```
User fills form
    │
    ▼
Step 1: ERC-20 approve(OrderManager, amountIn)
    │   (wagmi writeContract + wait for receipt)
    ▼
Step 2: OrderManager.createOrder(params)
    │   (wagmi writeContract + wait for receipt)
    ▼
UI shows "Order Created" + Etherscan link
```

---

## Available Scripts

```bash
npm run dev       # Start dev server (HMR)
npm run build     # TypeScript check + Vite production build
npm run preview   # Preview production build locally
npm run lint      # ESLint
```

---

## Environment

No `.env` required for the frontend — the contract address is hardcoded in `src/config/contracts.ts` since it's a public, deployed contract on Sepolia.

The wagmi config uses **public RPC** (no API key needed for basic usage). For production, update the transport in `src/config/wagmi.ts` with an Alchemy/Infura RPC URL.
