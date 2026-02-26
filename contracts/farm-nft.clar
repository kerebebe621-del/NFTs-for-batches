(define-non-fungible-token farm-batch uint)

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-BATCH-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-VERIFIED (err u102))
(define-constant ERR-INVALID-PRICE (err u103))
(define-constant ERR-TRANSFER-FAILED (err u104))
(define-constant ERR-NOT-OWNER (err u105))
(define-constant ERR-BATCH-NOT-FOR-SALE (err u106))
(define-constant ERR-INVALID-INPUT (err u107))

(define-data-var last-batch-id uint u0)
(define-data-var platform-fee-bps uint u250)
(define-data-var platform-treasury principal CONTRACT-OWNER)

(define-map batch-metadata
  uint
  {
    farmer: principal,
    crop-type: (string-ascii 64),
    harvest-date: uint,
    weight-kg: uint,
    location: (string-ascii 128),
    quality-grade: (string-ascii 16),
    certifications: (string-ascii 128),
    batch-uri: (string-ascii 256),
    minted-at: uint,
    verified: bool
  }
)

(define-map batch-pricing
  uint
  {
    price-ustx: uint,
    for-sale: bool,
    payment-token: (string-ascii 8)
  }
)

(define-map batch-verification
  uint
  {
    verifier: principal,
    verified-at: uint,
    verification-note: (string-ascii 256)
  }
)

(define-map farmer-batch-count principal uint)
(define-map qr-scan-count uint uint)
(define-map buyer-purchases principal uint)

(define-private (get-farmer-count (farmer principal))
  (default-to u0 (map-get? farmer-batch-count farmer))
)

(define-private (get-next-id)
  (let ((next (+ (var-get last-batch-id) u1)))
    (var-set last-batch-id next)
    next
  )
)

(define-private (calculate-fee (amount uint))
  (/ (* amount (var-get platform-fee-bps)) u10000)
)

(define-public (mint-batch
    (crop-type (string-ascii 64))
    (harvest-date uint)
    (weight-kg uint)
    (location (string-ascii 128))
    (quality-grade (string-ascii 16))
    (certifications (string-ascii 128))
    (batch-uri (string-ascii 256))
  )
  (let (
    (batch-id (get-next-id))
    (farmer tx-sender)
  )
    (asserts! (> (len crop-type) u0) ERR-INVALID-INPUT)
    (asserts! (> weight-kg u0) ERR-INVALID-INPUT)
    (asserts! (> harvest-date u0) ERR-INVALID-INPUT)
    (try! (nft-mint? farm-batch batch-id farmer))
    (map-set batch-metadata batch-id {
      farmer: farmer,
      crop-type: crop-type,
      harvest-date: harvest-date,
      weight-kg: weight-kg,
      location: location,
      quality-grade: quality-grade,
      certifications: certifications,
      batch-uri: batch-uri,
      minted-at: burn-block-height,
      verified: false
    })
    (map-set farmer-batch-count farmer (+ (get-farmer-count farmer) u1))
    (map-set qr-scan-count batch-id u0)
    (print {
      event: "batch-minted",
      batch-id: batch-id,
      farmer: farmer,
      crop-type: crop-type,
      harvest-date: harvest-date,
      weight-kg: weight-kg,
      location: location,
      quality-grade: quality-grade
    })
    (ok batch-id)
  )
)

(define-public (list-batch-for-sale (batch-id uint) (price-ustx uint) (payment-token (string-ascii 8)))
  (let (
    (owner (unwrap! (nft-get-owner? farm-batch batch-id) ERR-BATCH-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender owner) ERR-NOT-OWNER)
    (asserts! (> price-ustx u0) ERR-INVALID-PRICE)
    (map-set batch-pricing batch-id {
      price-ustx: price-ustx,
      for-sale: true,
      payment-token: payment-token
    })
    (print {
      event: "batch-listed",
      batch-id: batch-id,
      price-ustx: price-ustx,
      payment-token: payment-token,
      seller: tx-sender
    })
    (ok true)
  )
)

(define-public (delist-batch (batch-id uint))
  (let (
    (owner (unwrap! (nft-get-owner? farm-batch batch-id) ERR-BATCH-NOT-FOUND))
    (pricing (unwrap! (map-get? batch-pricing batch-id) ERR-BATCH-NOT-FOR-SALE))
  )
    (asserts! (is-eq tx-sender owner) ERR-NOT-OWNER)
    (map-set batch-pricing batch-id (merge pricing { for-sale: false }))
    (print { event: "batch-delisted", batch-id: batch-id, seller: tx-sender })
    (ok true)
  )
)

(define-public (buy-batch (batch-id uint))
  (let (
    (owner (unwrap! (nft-get-owner? farm-batch batch-id) ERR-BATCH-NOT-FOUND))
    (pricing (unwrap! (map-get? batch-pricing batch-id) ERR-BATCH-NOT-FOR-SALE))
    (price (get price-ustx pricing))
    (fee (calculate-fee price))
    (seller-proceeds (- price fee))
    (buyer tx-sender)
  )
    (asserts! (get for-sale pricing) ERR-BATCH-NOT-FOR-SALE)
    (asserts! (not (is-eq buyer owner)) ERR-NOT-AUTHORIZED)
    (try! (stx-transfer? seller-proceeds buyer owner))
    (try! (stx-transfer? fee buyer (var-get platform-treasury)))
    (try! (nft-transfer? farm-batch batch-id owner buyer))
    (map-set batch-pricing batch-id (merge pricing { for-sale: false }))
    (map-set buyer-purchases buyer (+ (default-to u0 (map-get? buyer-purchases buyer)) u1))
    (print {
      event: "batch-purchased",
      batch-id: batch-id,
      buyer: buyer,
      seller: owner,
      price-ustx: price,
      fee: fee,
      seller-proceeds: seller-proceeds
    })
    (ok true)
  )
)

(define-public (verify-batch (batch-id uint) (note (string-ascii 256)))
  (let (
    (meta (unwrap! (map-get? batch-metadata batch-id) ERR-BATCH-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (not (get verified meta)) ERR-ALREADY-VERIFIED)
    (map-set batch-metadata batch-id (merge meta { verified: true }))
    (map-set batch-verification batch-id {
      verifier: tx-sender,
      verified-at: burn-block-height,
      verification-note: note
    })
    (print {
      event: "batch-verified",
      batch-id: batch-id,
      verifier: tx-sender,
      verified-at: burn-block-height
    })
    (ok true)
  )
)

(define-public (record-qr-scan (batch-id uint))
  (let (
    (current-scans (default-to u0 (map-get? qr-scan-count batch-id)))
  )
    (asserts! (is-some (map-get? batch-metadata batch-id)) ERR-BATCH-NOT-FOUND)
    (map-set qr-scan-count batch-id (+ current-scans u1))
    (print {
      event: "qr-scanned",
      batch-id: batch-id,
      scanner: tx-sender,
      total-scans: (+ current-scans u1)
    })
    (ok (+ current-scans u1))
  )
)

(define-public (transfer-batch (batch-id uint) (recipient principal))
  (let (
    (owner (unwrap! (nft-get-owner? farm-batch batch-id) ERR-BATCH-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender owner) ERR-NOT-OWNER)
    (try! (nft-transfer? farm-batch batch-id owner recipient))
    (print {
      event: "batch-transferred",
      batch-id: batch-id,
      from: owner,
      to: recipient
    })
    (ok true)
  )
)

(define-public (update-batch-uri (batch-id uint) (new-uri (string-ascii 256)))
  (let (
    (owner (unwrap! (nft-get-owner? farm-batch batch-id) ERR-BATCH-NOT-FOUND))
    (meta (unwrap! (map-get? batch-metadata batch-id) ERR-BATCH-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender owner) ERR-NOT-OWNER)
    (map-set batch-metadata batch-id (merge meta { batch-uri: new-uri }))
    (print { event: "uri-updated", batch-id: batch-id, new-uri: new-uri })
    (ok true)
  )
)

(define-public (set-platform-fee (new-fee-bps uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee-bps u1000) ERR-INVALID-INPUT)
    (var-set platform-fee-bps new-fee-bps)
    (ok true)
  )
)

(define-public (set-platform-treasury (new-treasury principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set platform-treasury new-treasury)
    (ok true)
  )
)

(define-read-only (get-batch-metadata (batch-id uint))
  (map-get? batch-metadata batch-id)
)

(define-read-only (get-batch-pricing (batch-id uint))
  (map-get? batch-pricing batch-id)
)

(define-read-only (get-batch-verification (batch-id uint))
  (map-get? batch-verification batch-id)
)

(define-read-only (get-batch-owner (batch-id uint))
  (nft-get-owner? farm-batch batch-id)
)

(define-read-only (get-qr-scan-count (batch-id uint))
  (default-to u0 (map-get? qr-scan-count batch-id))
)

(define-read-only (get-farmer-batch-count (farmer principal))
  (get-farmer-count farmer)
)

(define-read-only (get-buyer-purchases (buyer principal))
  (default-to u0 (map-get? buyer-purchases buyer))
)

(define-read-only (get-total-batches)
  (var-get last-batch-id)
)

(define-read-only (get-platform-fee)
  (var-get platform-fee-bps)
)

(define-read-only (get-platform-treasury)
  (var-get platform-treasury)
)

(define-read-only (is-batch-verified (batch-id uint))
  (match (map-get? batch-metadata batch-id)
    meta (get verified meta)
    false
  )
)

(define-read-only (get-batch-full-info (batch-id uint))
  {
    metadata: (map-get? batch-metadata batch-id),
    pricing: (map-get? batch-pricing batch-id),
    verification: (map-get? batch-verification batch-id),
    owner: (nft-get-owner? farm-batch batch-id),
    scan-count: (default-to u0 (map-get? qr-scan-count batch-id))
  }
)
