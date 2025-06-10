;; title: Backcoin
;; version: 1.0.0
;; summary: Tokenized cashback system for merchant loyalty programs
;; description: A blockchain-based loyalty system where merchants can offer cashback tokens to customers
;; 
;; (impl-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_OWNER_ONLY (err u100))
(define-constant ERR_NOT_TOKEN_OWNER (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_MERCHANT_NOT_FOUND (err u103))
(define-constant ERR_MERCHANT_INACTIVE (err u104))
(define-constant ERR_INVALID_AMOUNT (err u105))
(define-constant ERR_PURCHASE_NOT_FOUND (err u106))
(define-constant ERR_CASHBACK_ALREADY_CLAIMED (err u107))
(define-constant ERR_INVALID_CASHBACK_RATE (err u108))

(define-fungible-token backcoin)

(define-data-var token-name (string-ascii 32) "Backcoin")
(define-data-var token-symbol (string-ascii 10) "BACK")
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var token-decimals uint u6)
(define-data-var total-supply uint u0)

(define-map merchants
  { merchant-id: principal }
  {
    name: (string-ascii 50),
    cashback-rate: uint,
    is-active: bool,
    total-cashback-issued: uint,
    registration-block: uint
  }
)

(define-map purchases
  { purchase-id: uint }
  {
    customer: principal,
    merchant: principal,
    amount: uint,
    cashback-amount: uint,
    purchase-block: uint,
    is-claimed: bool
  }
)

(define-map customer-stats
  { customer: principal }
  {
    total-purchases: uint,
    total-cashback-earned: uint,
    total-cashback-spent: uint
  }
)

(define-data-var next-purchase-id uint u1)

(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (or (is-eq from tx-sender) (is-eq from contract-caller)) ERR_NOT_TOKEN_OWNER)
    (ft-transfer? backcoin amount from to)
  )
)

(define-read-only (get-name)
  (ok (var-get token-name))
)

(define-read-only (get-symbol)
  (ok (var-get token-symbol))
)

(define-read-only (get-decimals)
  (ok (var-get token-decimals))
)

(define-read-only (get-balance (who principal))
  (ok (ft-get-balance backcoin who))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply backcoin))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

(define-public (register-merchant (name (string-ascii 50)) (cashback-rate uint))
  (let
    (
      (merchant-data {
        name: name,
        cashback-rate: cashback-rate,
        is-active: true,
        total-cashback-issued: u0,
        registration-block: stacks-block-height
      })
    )
    (asserts! (<= cashback-rate u1000) ERR_INVALID_CASHBACK_RATE)
    (map-set merchants { merchant-id: tx-sender } merchant-data)
    (ok true)
  )
)

(define-public (update-merchant-status (merchant principal) (is-active bool))
  (let
    (
      (merchant-info (unwrap! (map-get? merchants { merchant-id: merchant }) ERR_MERCHANT_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
    (map-set merchants 
      { merchant-id: merchant }
      (merge merchant-info { is-active: is-active })
    )
    (ok true)
  )
)

(define-public (record-purchase (customer principal) (amount uint))
  (let
    (
      (merchant-info (unwrap! (map-get? merchants { merchant-id: tx-sender }) ERR_MERCHANT_NOT_FOUND))
      (cashback-amount (/ (* amount (get cashback-rate merchant-info)) u10000))
      (purchase-id (var-get next-purchase-id))
      (purchase-data {
        customer: customer,
        merchant: tx-sender,
        amount: amount,
        cashback-amount: cashback-amount,
        purchase-block: stacks-block-height,
        is-claimed: false
      })
    )
    (asserts! (get is-active merchant-info) ERR_MERCHANT_INACTIVE)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (map-set purchases { purchase-id: purchase-id } purchase-data)
    (var-set next-purchase-id (+ purchase-id u1))
    
    (map-set merchants
      { merchant-id: tx-sender }
      (merge merchant-info { total-cashback-issued: (+ (get total-cashback-issued merchant-info) cashback-amount) })
    )
    
    (update-customer-stats customer amount cashback-amount u0)
    (ok purchase-id)
  )
)

(define-public (claim-cashback (purchase-id uint))
  (let
    (
      (purchase-info (unwrap! (map-get? purchases { purchase-id: purchase-id }) ERR_PURCHASE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get customer purchase-info)) ERR_NOT_TOKEN_OWNER)
    (asserts! (not (get is-claimed purchase-info)) ERR_CASHBACK_ALREADY_CLAIMED)
    
    (try! (ft-mint? backcoin (get cashback-amount purchase-info) tx-sender))
    
    (map-set purchases
      { purchase-id: purchase-id }
      (merge purchase-info { is-claimed: true })
    )
    
    (var-set total-supply (+ (var-get total-supply) (get cashback-amount purchase-info)))
    (ok (get cashback-amount purchase-info))
  )
)

(define-public (spend-cashback (amount uint) (merchant principal))
  (let
    (
      (merchant-info (unwrap! (map-get? merchants { merchant-id: merchant }) ERR_MERCHANT_NOT_FOUND))
      (customer-balance (ft-get-balance backcoin tx-sender))
    )
    (asserts! (get is-active merchant-info) ERR_MERCHANT_INACTIVE)
    (asserts! (>= customer-balance amount) ERR_INSUFFICIENT_BALANCE)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (try! (ft-burn? backcoin amount tx-sender))
    (var-set total-supply (- (var-get total-supply) amount))
    
    (update-customer-stats tx-sender u0 u0 amount)
    (ok true)
  )
)

(define-public (mint-tokens (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
    (try! (ft-mint? backcoin amount recipient))
    (var-set total-supply (+ (var-get total-supply) amount))
    (ok true)
  )
)

(define-public (burn-tokens (amount uint))
  (let
    (
      (sender-balance (ft-get-balance backcoin tx-sender))
    )
    (asserts! (>= sender-balance amount) ERR_INSUFFICIENT_BALANCE)
    (try! (ft-burn? backcoin amount tx-sender))
    (var-set total-supply (- (var-get total-supply) amount))
    (ok true)
  )
)

(define-read-only (get-merchant-info (merchant principal))
  (map-get? merchants { merchant-id: merchant })
)

(define-read-only (get-purchase-info (purchase-id uint))
  (map-get? purchases { purchase-id: purchase-id })
)

(define-read-only (get-customer-stats (customer principal))
  (map-get? customer-stats { customer: customer })
)

(define-read-only (calculate-cashback (merchant principal) (amount uint))
  (match (map-get? merchants { merchant-id: merchant })
    merchant-info (ok (/ (* amount (get cashback-rate merchant-info)) u10000))
    ERR_MERCHANT_NOT_FOUND
  )
)

(define-read-only (get-next-purchase-id)
  (var-get next-purchase-id)
)

(define-private (update-customer-stats (customer principal) (purchase-amount uint) (cashback-earned uint) (cashback-spent uint))
  (let
    (
      (current-stats (default-to 
        { total-purchases: u0, total-cashback-earned: u0, total-cashback-spent: u0 }
        (map-get? customer-stats { customer: customer })
      ))
    )
    (map-set customer-stats
      { customer: customer }
      {
        total-purchases: (+ (get total-purchases current-stats) purchase-amount),
        total-cashback-earned: (+ (get total-cashback-earned current-stats) cashback-earned),
        total-cashback-spent: (+ (get total-cashback-spent current-stats) cashback-spent)
      }
    )
  )
)

(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
    (var-set token-uri new-uri)
    (ok true)
  )
)