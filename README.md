# 🌾 Farm NFT Batch Tracker

> On-chain harvest provenance for emerging markets — farmers mint, buyers verify, payments flow instantly.

---

## 📖 Overview

**Farm NFT Batch Tracker** is a Clarity smart contract on the Stacks blockchain that turns agricultural harvest batches into on-chain NFTs. Farmers mint NFTs directly from mobile wallets, embedding harvest data permanently on-chain. Buyers scan QR codes to verify origin and trigger instant STX micropayments — no intermediaries, no trust required.

Unlike typical DeFi or social DApps, this targets **real-world trade in emerging markets** where provenance and trust are mission-critical.

---

## ✨ Key Features

| Feature | Description |
|---|---|
| 🌱 **Batch Minting** | Farmers mint NFTs recording crop type, harvest date, weight, location, grade & certifications |
| 🔍 **QR Verification** | Buyers scan a QR code to call `record-qr-scan`, logging on-chain proof of origin check |
| 💸 **STX Micropayments** | Buying a batch sends STX directly to the farmer with a 2.5% platform fee |
| ✅ **Authority Verification** | Contract owner can officially verify batches, marking them as certified |
| 📦 **Marketplace Listing** | Farmers list batches for sale with a price in µSTX and a payment token label |
| 📊 **Analytics** | Read-only functions expose scan counts, batch counts, and buyer history |
| 🔧 **Admin Controls** | Platform fee (capped at 10%) and treasury address are adjustable by the contract owner |

---

## 🏗️ Contract Architecture

```
farm-nft.clar
├── NFT: farm-batch (uint token-id)
├── Maps
│   ├── batch-metadata      → harvest data per batch
│   ├── batch-pricing       → sale price & status
│   ├── batch-verification  → official verification record
│   ├── farmer-batch-count  → how many batches a farmer has minted
│   ├── qr-scan-count       → total QR scans per batch
│   └── buyer-purchases     → total purchases per buyer
└── Data Vars
    ├── last-batch-id
    ├── platform-fee-bps    (default: 250 = 2.5%)
    └── platform-treasury
```

---

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://docs.hiro.so/clarinet/getting-started) installed
- Stacks wallet (e.g. [Leather](https://leather.io) or [Xverse](https://www.xverse.app))

### Run Locally

```bash
# Clone the repo
git clone <repo-url>
cd NFTs-for-batches

# Check the contract
clarinet check

# Open the REPL
clarinet console
```

---

## 📬 Contract Functions

### 🌾 Farmer Functions

#### `mint-batch`
Mint a new harvest batch NFT.

```clarity
(mint-batch
  "Maize"           ;; crop-type
  u20240115         ;; harvest-date (YYYYMMDD as uint)
  u500              ;; weight-kg
  "Nakuru, Kenya"   ;; location
  "A+"              ;; quality-grade
  "Organic,FairTrade" ;; certifications
  "ipfs://Qm..."    ;; batch-uri (metadata URI)
)
```
Returns: `(ok uint)` — the new batch ID.

#### `list-batch-for-sale`
Put a batch on the marketplace.

```clarity
(list-batch-for-sale u1 u5000000 "STX")
;; batch-id=1, price=5 STX, payment-token="STX"
```

#### `delist-batch`
Remove a batch from sale.

```clarity
(delist-batch u1)
```

#### `update-batch-uri`
Update the metadata URI of a batch you own.

```clarity
(update-batch-uri u1 "ipfs://NewQm...")
```

#### `transfer-batch`
Transfer a batch NFT to another principal.

```clarity
(transfer-batch u1 'SP2...)
```

---

### 🛒 Buyer Functions

#### `buy-batch`
Buy a listed batch. STX is sent directly to the farmer; platform fee goes to treasury.

```clarity
(buy-batch u1)
```

#### `record-qr-scan`
Called when a buyer scans the QR code to verify origin. Increments on-chain scan count.

```clarity
(record-qr-scan u1)
```

---

### 🔐 Admin Functions

#### `verify-batch`
Mark a batch as officially verified (contract owner only).

```clarity
(verify-batch u1 "Inspected on-site, Grade A confirmed")
```

#### `set-platform-fee`
Adjust platform fee in basis points (max 1000 = 10%).

```clarity
(set-platform-fee u300) ;; sets fee to 3%
```

#### `set-platform-treasury`
Change the treasury address.

```clarity
(set-platform-treasury 'SP2...)
```

---

### 📖 Read-Only Functions

| Function | Returns |
|---|---|
| `get-batch-metadata u1` | Full harvest data for batch 1 |
| `get-batch-pricing u1` | Price and sale status |
| `get-batch-verification u1` | Verification record |
| `get-batch-owner u1` | Current NFT owner |
| `get-qr-scan-count u1` | Total QR scans |
| `get-farmer-batch-count 'SP...` | Batches minted by farmer |
| `get-buyer-purchases 'SP...` | Total purchases by buyer |
| `get-total-batches` | Total batches ever minted |
| `is-batch-verified u1` | `true`/`false` |
| `get-batch-full-info u1` | All info in one call |

---

## ⚠️ Error Codes

| Code | Constant | Meaning |
|---|---|---|
| `u100` | `ERR-NOT-AUTHORIZED` | Caller is not the contract owner |
| `u101` | `ERR-BATCH-NOT-FOUND` | Batch ID does not exist |
| `u102` | `ERR-ALREADY-VERIFIED` | Batch is already verified |
| `u103` | `ERR-INVALID-PRICE` | Price must be > 0 |
| `u104` | `ERR-TRANSFER-FAILED` | STX transfer failed |
| `u105` | `ERR-NOT-OWNER` | Caller does not own the NFT |
| `u106` | `ERR-BATCH-NOT-FOR-SALE` | Batch has no active listing |
| `u107` | `ERR-INVALID-INPUT` | A required field was empty or zero |

---

## 💡 Real-World Flow

```
1. 🌾 Farmer harvests maize → mints NFT via mobile wallet
2. 📦 Farmer lists batch for 5 STX
3. 🔗 QR code is printed/shared containing the batch-id
4. 🛒 Buyer scans QR → calls record-qr-scan (provenance logged)
5. 💸 Buyer calls buy-batch → STX flows instantly to farmer
6. ✅ Authority calls verify-batch → batch certified on-chain
```

---

## 📄 License

MIT
