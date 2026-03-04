# contracts — orlimeth Smart Contracts

Foundry project containing the core Solidity smart contracts for the orlimeth Limit Order Protocol.

---

## Deployed Contract

| Network | Address | Status |
|:---|:---|:---|
| **Ethereum Sepolia** | [`0x3ced97b7001bbd567563fb6efdf16709dddd10f7`](https://sepolia.etherscan.io/address/0x3ced97b7001bbd567563fb6efdf16709dddd10f7) | ✅ Verified |

---

## Contract Architecture

```
OrderManager (deployed)
├── inherits: OrlimStorage    # State: _orders, _nonces, _remainingAmounts
├── inherits: Vault           # ERC-20 escrow: _deposit(), _withdraw()
├── inherits: ReentrancyGuard # OpenZeppelin
├── inherits: Ownable         # OpenZeppelin
├── inherits: Pausable        # OpenZeppelin
└── implements: IOrlim        # Public ABI
```

> `OrlimStorage`, `Vault`, `Errors`, and `IOrlim` are **not deployed separately** — they are abstract contracts/libraries compiled into `OrderManager`.

---

## Source Files

| File | Type | Description |
|:---|:---|:---|
| `src/interfaces/IOrlim.sol` | Interface | Slot-packed `Order` struct, events, public API |
| `src/libraries/Errors.sol` | Library | 9 custom errors (gas-efficient reverts) |
| `src/OrlimStorage.sol` | Abstract | State mappings, constants, 44-slot storage gap |
| `src/Vault.sol` | Abstract | `SafeERC20` deposit/withdraw for token escrow |
| `src/OrderManager.sol` | Contract ⭐ | Full order lifecycle: create, fill (partial), cancel |
| `script/Deploy.s.sol` | Script | Foundry deployment script (fee + treasury from env) |
| `test/mocks/MockERC20.sol` | Mock | ERC-20 mock for testing |

---

## Setup

**Prerequisites:** [Foundry](https://book.getfoundry.sh/getting-started/installation)

```bash
cd contracts
forge install      # Install OpenZeppelin (already in lib/)
forge build        # Compile all contracts
```

---

## Testing

```bash
# Run all 41 tests
forge test -vv

# Unit tests only
forge test --match-contract OrderManagerTest -vv

# Fuzz tests (1000 runs each)
forge test --match-contract OrderManagerFuzzTest -vv

# Invariant tests (256 runs × depth 15)
forge test --match-contract OrderManagerInvariantTest -vv

# Gas report
forge test --gas-report

# Coverage
forge coverage
```

### Test Results

| Suite | File | Tests | Status |
|:---|:---|:---|:---|
| Unit | `test/OrderManager.t.sol` | 32 | ✅ All pass |
| Fuzz | `test/OrderManager.fuzz.t.sol` | 5 | ✅ 1000+ runs |
| Invariant | `test/invariants/OrderManagerInvariant.t.sol` | 4 | ✅ 256 runs |

### Invariants Tested

1. **Solvency** — Contract balance always ≥ sum of open order `remainingAmount`
2. **Status Monotonicity** — FILLED/CANCELLED orders never re-open
3. **Nonce Monotonicity** — User nonces never decrease
4. **No Orphaned Funds** — Closed orders always have `remainingAmount == 0`

---

## Deployment

```bash
# 1. Set environment variables
cp ../.env.example .env
# Fill in: PRIVATE_KEY, SEPOLIA_RPC_URL, ETHERSCAN_API_KEY, TREASURY_ADDRESS, FEE_BPS

# 2. Deploy + Verify in one step
source .env
forge script script/Deploy.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  -vvv
```

---

## Order Lifecycle

```
createOrder(params)
  └── Escrows tokenIn → status: OPEN

fillOrder(orderId, fillAmount)
  ├── Partial: remainingAmount -= fillAmount, status stays OPEN
  └── Full:    remainingAmount = 0, status: FILLED

cancelOrder(orderId)
  └── Refunds remainingAmount → status: CANCELLED
```

**Fee mechanics:** On each fill, `feeAmount = fillAmount * feeBps / 10000` is deducted from the tokenIn sent to the filler and transferred to the treasury.

---

## Key Design Decisions

| Decision | Rationale |
|:---|:---|
| `orderId = keccak256(maker, nonce, timestamp)` | Unique, deterministic, no centralized counter |
| `_remainingAmounts` stored separately | Avoids re-packing `Order` struct on every partial fill |
| CEI pattern enforced | Prevents reentrancy without `nonReentrant` on all paths |
| `SafeERC20` | Handles non-standard ERC-20 tokens (e.g., USDT) |
| `unchecked` arithmetic | Gas optimization where overflow is mathematically impossible |
| 44-slot storage gap | Future UUPS upgradability |

---

## Configuration (`foundry.toml`)

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
evm_version = "shanghai"
optimizer = true
optimizer_runs = 200

[fuzz]
runs = 1000

[invariant]
runs = 256
depth = 15
```

---

## ABI

The compiled ABI is exported to `abi/OrderManager.json` after `forge build`.

```bash
cat abi/OrderManager.json   # Full ABI
```
