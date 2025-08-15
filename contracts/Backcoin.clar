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
(define-constant ERR_INVALID_REFERRAL_RATE (err u109))
(define-constant ERR_SELF_REFERRAL (err u110))
(define-constant ERR_ALREADY_REFERRED (err u111))
(define-constant ERR_REFERRER_NOT_FOUND (err u112))
(define-constant ERR_MINIMUM_CASHBACK_NOT_MET (err u113))
(define-constant ERR_REFERRAL_REWARD_ALREADY_CLAIMED (err u114))
(define-constant ERR_REFERRAL_NOT_QUALIFIED (err u115))
(define-constant ERR_INVALID_TIER (err u116))
(define-constant ERR_TIER_REQUIREMENT_NOT_MET (err u117))
(define-constant ERR_TIER_BONUS_NOT_FOUND (err u118))

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

(define-map merchant-referrals
  { referrer: principal, referee: principal }
  {
    referral-id: uint,
    referral-block: uint,
    referee-cashback-issued: uint,
    total-rewards-earned: uint,
    last-reward-claim-block: uint,
    is-qualified: bool,
    referrer: principal,
    referee: principal
  }
)

(define-map referral-rewards
  { referral-id: uint }
  {
    referrer: principal,
    referee: principal,
    rewards-available: uint,
    rewards-claimed: uint,
    creation-block: uint,
    last-update-block: uint
  }
)

(define-map merchant-referral-stats
  { merchant: principal }
  {
    total-referrals: uint,
    qualified-referrals: uint,
    total-rewards-earned: uint,
    total-rewards-claimed: uint
  }
)

(define-map referee-lookup
  { referee: principal }
  { referrer: principal }
)

;; Customer loyalty tier system
(define-map customer-tiers
  { customer: principal }
  {
    current-tier: uint, ;; 0=Bronze, 1=Silver, 2=Gold, 3=Platinum
    tier-since-block: uint,
    total-tier-purchases: uint,
    tier-cashback-earned: uint,
    tier-bonus-earned: uint,
    last-tier-update: uint
  }
)

(define-map tier-requirements
  { tier-level: uint }
  {
    min-purchases: uint,
    min-cashback: uint,
    multiplier-bonus: uint, ;; basis points (e.g., 500 = 5% bonus)
    tier-name: (string-ascii 10)
  }
)

(define-map merchant-tier-bonuses
  { merchant: principal, tier-level: uint }
  {
    additional-bonus: uint, ;; extra basis points for this tier
    is-active: bool,
    bonus-description: (string-ascii 50)
  }
)

(define-data-var next-purchase-id uint u1)
(define-data-var referral-reward-rate uint u500)
(define-data-var minimum-cashback-threshold uint u100000000)
(define-data-var next-referral-id uint u1)

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

(define-public (register-merchant-with-referral (name (string-ascii 50)) (cashback-rate uint) (referrer principal))
  (let
    (
      (referrer-info (unwrap! (map-get? merchants { merchant-id: referrer }) ERR_REFERRER_NOT_FOUND))
      (referral-id (var-get next-referral-id))
      (merchant-data {
        name: name,
        cashback-rate: cashback-rate,
        is-active: true,
        total-cashback-issued: u0,
        registration-block: stacks-block-height
      })
      (referral-data {
        referral-id: referral-id,
        referral-block: stacks-block-height,
        referee-cashback-issued: u0,
        total-rewards-earned: u0,
        last-reward-claim-block: u0,
        is-qualified: false,
        referrer: referrer,
        referee: tx-sender
      })
      (reward-data {
        referrer: referrer,
        referee: tx-sender,
        rewards-available: u0,
        rewards-claimed: u0,
        creation-block: stacks-block-height,
        last-update-block: stacks-block-height
      })
    )
    (asserts! (<= cashback-rate u1000) ERR_INVALID_CASHBACK_RATE)
    (asserts! (not (is-eq referrer tx-sender)) ERR_SELF_REFERRAL)
    (asserts! (is-none (map-get? merchant-referrals { referrer: referrer, referee: tx-sender })) ERR_ALREADY_REFERRED)
    (asserts! (get is-active referrer-info) ERR_MERCHANT_INACTIVE)
    
    (map-set merchants { merchant-id: tx-sender } merchant-data)
    (map-set merchant-referrals { referrer: referrer, referee: tx-sender } referral-data)
    (map-set referral-rewards { referral-id: referral-id } reward-data)
    (map-set referee-lookup { referee: tx-sender } { referrer: referrer })
    (var-set next-referral-id (+ referral-id u1))
    
    (update-referrer-stats referrer u1 u0 u0 u0)
    (ok referral-id)
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
    (unwrap-panic (update-referral-progress tx-sender cashback-amount))
    (unwrap-panic (update-customer-tier customer amount cashback-amount))
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

(define-public (claim-referral-rewards (referral-id uint))
  (let
    (
      (reward-info (unwrap! (map-get? referral-rewards { referral-id: referral-id }) ERR_PURCHASE_NOT_FOUND))
      (referral-key { referrer: (get referrer reward-info), referee: (get referee reward-info) })
      (referral-info (unwrap! (map-get? merchant-referrals referral-key) ERR_PURCHASE_NOT_FOUND))
      (rewards-to-claim (get rewards-available reward-info))
    )
    (asserts! (is-eq tx-sender (get referrer reward-info)) ERR_NOT_TOKEN_OWNER)
    (asserts! (get is-qualified referral-info) ERR_REFERRAL_NOT_QUALIFIED)
    (asserts! (> rewards-to-claim u0) ERR_REFERRAL_REWARD_ALREADY_CLAIMED)
    
    (try! (ft-mint? backcoin rewards-to-claim tx-sender))
    (var-set total-supply (+ (var-get total-supply) rewards-to-claim))
    
    (map-set referral-rewards
      { referral-id: referral-id }
      (merge reward-info {
        rewards-available: u0,
        rewards-claimed: (+ (get rewards-claimed reward-info) rewards-to-claim),
        last-update-block: stacks-block-height
      })
    )
    
    (map-set merchant-referrals
      referral-key
      (merge referral-info {
        total-rewards-earned: (+ (get total-rewards-earned referral-info) rewards-to-claim),
        last-reward-claim-block: stacks-block-height
      })
    )
    
    (update-referrer-stats (get referrer reward-info) u0 u0 rewards-to-claim rewards-to-claim)
    (ok rewards-to-claim)
  )
)

(define-public (set-referral-reward-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
    (asserts! (<= new-rate u1000) ERR_INVALID_REFERRAL_RATE)
    (var-set referral-reward-rate new-rate)
    (ok true)
  )
)

(define-public (set-minimum-cashback-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
    (asserts! (> new-threshold u0) ERR_INVALID_AMOUNT)
    (var-set minimum-cashback-threshold new-threshold)
    (ok true)
  )
)

(define-read-only (get-referral-info (referrer principal) (referee principal))
  (map-get? merchant-referrals { referrer: referrer, referee: referee })
)

(define-read-only (get-referral-reward-info (referral-id uint))
  (map-get? referral-rewards { referral-id: referral-id })
)

(define-read-only (get-merchant-referral-stats (merchant principal))
  (map-get? merchant-referral-stats { merchant: merchant })
)

(define-read-only (get-referral-settings)
  (ok {
    reward-rate: (var-get referral-reward-rate),
    minimum-threshold: (var-get minimum-cashback-threshold),
    next-referral-id: (var-get next-referral-id)
  })
)

(define-read-only (calculate-referral-rewards (referrer principal) (referee principal))
  (match (map-get? merchant-referrals { referrer: referrer, referee: referee })
    referral-info 
    (let
      (
        (cashback-issued (get referee-cashback-issued referral-info))
        (reward-rate (var-get referral-reward-rate))
      )
      (ok (/ (* cashback-issued reward-rate) u10000))
    )
    ERR_PURCHASE_NOT_FOUND
  )
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

(define-private (update-referral-progress (merchant principal) (cashback-amount uint))
  (let
    (
      (referral-lookup (find-referral-by-referee merchant))
    )
    (match referral-lookup
      referral-data
      (let
        (
          (referrer (get referrer referral-data))
          (referee (get referee referral-data))
          (referral-id (get referral-id referral-data))
          (current-cashback (get referee-cashback-issued referral-data))
          (new-cashback (+ current-cashback cashback-amount))
          (threshold (var-get minimum-cashback-threshold))
          (reward-rate (var-get referral-reward-rate))
          (new-rewards (/ (* cashback-amount reward-rate) u10000))
          (should-qualify (>= new-cashback threshold))
          (referral-key { referrer: referrer, referee: referee })
        )
        (map-set merchant-referrals
          referral-key
          (merge referral-data {
            referee-cashback-issued: new-cashback,
            is-qualified: should-qualify
          })
        )
        
        (match (map-get? referral-rewards { referral-id: referral-id })
          reward-info
          (map-set referral-rewards
            { referral-id: referral-id }
            (merge reward-info {
              rewards-available: (+ (get rewards-available reward-info) new-rewards),
              last-update-block: stacks-block-height
            })
          )
          false
        )
        
        (if (and should-qualify (not (get is-qualified referral-data)))
          (update-referrer-stats referrer u0 u1 u0 u0)
          true
        )
        
        (ok u0)
      )
      (ok u0)
    )
  )
)

(define-private (find-referral-by-referee (referee principal))
  (match (map-get? referee-lookup { referee: referee })
    lookup-data
    (let
      (
        (referrer (get referrer lookup-data))
      )
      (map-get? merchant-referrals { referrer: referrer, referee: referee })
    )
    none
  )
)

(define-private (update-referrer-stats (referrer principal) (new-referrals uint) (new-qualified uint) (new-earned uint) (new-claimed uint))
  (let
    (
      (current-stats (default-to
        { total-referrals: u0, qualified-referrals: u0, total-rewards-earned: u0, total-rewards-claimed: u0 }
        (map-get? merchant-referral-stats { merchant: referrer })
      ))
    )
    (map-set merchant-referral-stats
      { merchant: referrer }
      {
        total-referrals: (+ (get total-referrals current-stats) new-referrals),
        qualified-referrals: (+ (get qualified-referrals current-stats) new-qualified),
        total-rewards-earned: (+ (get total-rewards-earned current-stats) new-earned),
        total-rewards-claimed: (+ (get total-rewards-claimed current-stats) new-claimed)
      }
    )
  )
)

;; Initialize default tier requirements
(define-private (initialize-tier-requirements)
  (begin
    ;; Bronze tier (default)
    (map-set tier-requirements { tier-level: u0 } {
      min-purchases: u0,
      min-cashback: u0,
      multiplier-bonus: u0,
      tier-name: "Bronze"
    })
    ;; Silver tier
    (map-set tier-requirements { tier-level: u1 } {
      min-purchases: u500000000, ;; 5 BACK in purchases  
      min-cashback: u50000000,   ;; 0.5 BACK earned
      multiplier-bonus: u250,    ;; 2.5% bonus
      tier-name: "Silver"
    })
    ;; Gold tier
    (map-set tier-requirements { tier-level: u2 } {
      min-purchases: u2000000000, ;; 20 BACK in purchases
      min-cashback: u200000000,   ;; 2 BACK earned  
      multiplier-bonus: u500,     ;; 5% bonus
      tier-name: "Gold"
    })
    ;; Platinum tier
    (map-set tier-requirements { tier-level: u3 } {
      min-purchases: u5000000000, ;; 50 BACK in purchases
      min-cashback: u500000000,   ;; 5 BACK earned
      multiplier-bonus: u1000,    ;; 10% bonus
      tier-name: "Platinum"
    })
  )
)

;; Initialize customer tier (called on first purchase)
(define-private (initialize-customer-tier (customer principal))
  (if (is-none (map-get? customer-tiers { customer: customer }))
    (map-set customer-tiers { customer: customer } {
      current-tier: u0,
      tier-since-block: stacks-block-height,
      total-tier-purchases: u0,
      tier-cashback-earned: u0,
      tier-bonus-earned: u0,
      last-tier-update: stacks-block-height
    })
    true
  )
)

;; Update customer tier based on activity
(define-private (update-customer-tier (customer principal) (purchase-amount uint) (cashback-amount uint))
  (let
    (
      (tier-info (default-to {
        current-tier: u0,
        tier-since-block: stacks-block-height,
        total-tier-purchases: u0,
        tier-cashback-earned: u0,
        tier-bonus-earned: u0,
        last-tier-update: stacks-block-height
      } (map-get? customer-tiers { customer: customer })))
      (new-purchases (+ (get total-tier-purchases tier-info) purchase-amount))
      (new-cashback (+ (get tier-cashback-earned tier-info) cashback-amount))
      (current-tier (get current-tier tier-info))
      (qualified-tier (determine-qualified-tier new-purchases new-cashback))
    )
    (initialize-tier-requirements)
    (initialize-customer-tier customer)
    
    (if (> qualified-tier current-tier)
      ;; Tier promotion
      (map-set customer-tiers { customer: customer } {
        current-tier: qualified-tier,
        tier-since-block: stacks-block-height,
        total-tier-purchases: new-purchases,
        tier-cashback-earned: new-cashback,
        tier-bonus-earned: (get tier-bonus-earned tier-info),
        last-tier-update: stacks-block-height
      })
      ;; Regular update
      (map-set customer-tiers { customer: customer } {
        current-tier: current-tier,
        tier-since-block: (get tier-since-block tier-info),
        total-tier-purchases: new-purchases,
        tier-cashback-earned: new-cashback,
        tier-bonus-earned: (get tier-bonus-earned tier-info),
        last-tier-update: stacks-block-height
      })
    )
    (ok qualified-tier)
  )
)

;; Determine highest qualifying tier
(define-private (determine-qualified-tier (total-purchases uint) (total-cashback uint))
  (if (and (>= total-purchases u5000000000) (>= total-cashback u500000000))
    u3 ;; Platinum
    (if (and (>= total-purchases u2000000000) (>= total-cashback u200000000))
      u2 ;; Gold
      (if (and (>= total-purchases u500000000) (>= total-cashback u50000000))
        u1 ;; Silver
        u0 ;; Bronze
      )
    )
  )
)

;; Calculate tier bonus for customer
(define-read-only (calculate-tier-bonus (customer principal) (base-cashback uint))
  (let
    (
      (tier-info (map-get? customer-tiers { customer: customer }))
    )
    (match tier-info
      tier-data
      (let
        (
          (tier-level (get current-tier tier-data))
          (tier-req (map-get? tier-requirements { tier-level: tier-level }))
        )
        (match tier-req
          req-data
          (let
            (
              (multiplier (get multiplier-bonus req-data))
            )
            (ok (/ (* base-cashback multiplier) u10000))
          )
          (ok u0)
        )
      )
      (ok u0)
    )
  )
)

;; Set merchant-specific tier bonus
(define-public (set-merchant-tier-bonus (tier-level uint) (additional-bonus uint) (description (string-ascii 50)))
  (let
    (
      (merchant-info (unwrap! (map-get? merchants { merchant-id: tx-sender }) ERR_MERCHANT_NOT_FOUND))
    )
    (asserts! (< tier-level u4) ERR_INVALID_TIER)
    (asserts! (<= additional-bonus u2000) ERR_INVALID_AMOUNT) ;; Max 20% additional bonus
    (asserts! (get is-active merchant-info) ERR_MERCHANT_INACTIVE)
    
    (map-set merchant-tier-bonuses 
      { merchant: tx-sender, tier-level: tier-level }
      {
        additional-bonus: additional-bonus,
        is-active: true,
        bonus-description: description
      }
    )
    (ok true)
  )
)

;; Claim tier bonus rewards
(define-public (claim-tier-bonus (merchant principal) (base-cashback uint))
  (let
    (
      (tier-info (unwrap! (map-get? customer-tiers { customer: tx-sender }) ERR_INVALID_TIER))
      (tier-level (get current-tier tier-info))
      (tier-bonus-info (map-get? merchant-tier-bonuses { merchant: merchant, tier-level: tier-level }))
      (base-tier-bonus (unwrap-panic (calculate-tier-bonus tx-sender base-cashback)))
    )
    (match tier-bonus-info
      bonus-data
      (if (get is-active bonus-data)
        (let
          (
            (additional-bonus (/ (* base-cashback (get additional-bonus bonus-data)) u10000))
            (total-bonus (+ base-tier-bonus additional-bonus))
          )
          (try! (ft-mint? backcoin total-bonus tx-sender))
          (var-set total-supply (+ (var-get total-supply) total-bonus))
          
          ;; Update tier bonus earned
          (map-set customer-tiers { customer: tx-sender }
            (merge tier-info { tier-bonus-earned: (+ (get tier-bonus-earned tier-info) total-bonus) })
          )
          
          (ok total-bonus)
        )
        (ok base-tier-bonus)
      )
      (if (> base-tier-bonus u0)
        (begin
          (try! (ft-mint? backcoin base-tier-bonus tx-sender))
          (var-set total-supply (+ (var-get total-supply) base-tier-bonus))
          (ok base-tier-bonus)
        )
        (ok u0)
      )
    )
  )
)

;; Get customer tier information
(define-read-only (get-customer-tier (customer principal))
  (map-get? customer-tiers { customer: customer })
)

;; Get tier requirements
(define-read-only (get-tier-requirements (tier-level uint))
  (map-get? tier-requirements { tier-level: tier-level })
)

;; Get all tier requirements
(define-read-only (get-all-tier-requirements)
  (ok {
    bronze: (unwrap-panic (get-tier-requirements u0)),
    silver: (unwrap-panic (get-tier-requirements u1)),
    gold: (unwrap-panic (get-tier-requirements u2)),
    platinum: (unwrap-panic (get-tier-requirements u3))
  })
)

;; Get merchant tier bonus
(define-read-only (get-merchant-tier-bonus (merchant principal) (tier-level uint))
  (map-get? merchant-tier-bonuses { merchant: merchant, tier-level: tier-level })
)

;; Check if customer qualifies for tier
(define-read-only (check-tier-qualification (customer principal) (target-tier uint))
  (let
    (
      (customer-stats-info (map-get? customer-stats { customer: customer }))
    )
    (match customer-stats-info
      stats-data
      (let
        (
          (total-purchases (get total-purchases stats-data))
          (total-cashback (get total-cashback-earned stats-data))
          (tier-req (map-get? tier-requirements { tier-level: target-tier }))
        )
        (match tier-req
          req-data
          (ok (and 
            (>= total-purchases (get min-purchases req-data))
            (>= total-cashback (get min-cashback req-data))
          ))
          ERR_INVALID_TIER
        )
      )
      (ok false)
    )
  )
)






