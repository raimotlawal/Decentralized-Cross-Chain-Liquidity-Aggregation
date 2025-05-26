;; Arbitrage Optimization Contract
;; Exploits price differences across venues

(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-OPPORTUNITY-NOT-FOUND (err u401))
(define-constant ERR-INSUFFICIENT-PROFIT (err u402))

(define-data-var contract-owner principal tx-sender)
(define-data-var min-profit-threshold uint u100) ;; Minimum profit in basis points

(define-map arbitrage-operators
  { operator: principal }
  { is-authorized: bool }
)

(define-map arbitrage-opportunities
  { opportunity-id: uint }
  {
    token-pair: (string-ascii 32),
    buy-venue: (string-ascii 64),
    sell-venue: (string-ascii 64),
    buy-price: uint,
    sell-price: uint,
    profit-margin: uint,
    max-amount: uint,
    created-at: uint,
    is-active: bool
  }
)

(define-data-var opportunity-nonce uint u0)

;; Initialize contract owner as operator
(map-set arbitrage-operators { operator: tx-sender } { is-authorized: true })

(define-read-only (get-opportunity (opportunity-id uint))
  (map-get? arbitrage-opportunities { opportunity-id: opportunity-id })
)

(define-read-only (calculate-profit (buy-price uint) (sell-price uint) (amount uint))
  (if (> sell-price buy-price)
    (- (* (- sell-price buy-price) amount) (* buy-price amount))
    u0
  )
)

(define-public (add-arbitrage-operator (operator principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (ok (map-set arbitrage-operators { operator: operator } { is-authorized: true }))
  )
)

(define-public (create-arbitrage-opportunity
  (token-pair (string-ascii 32))
  (buy-venue (string-ascii 64))
  (sell-venue (string-ascii 64))
  (buy-price uint)
  (sell-price uint)
  (max-amount uint))
  (let ((operator-auth (default-to { is-authorized: false }
                                  (map-get? arbitrage-operators { operator: tx-sender })))
        (opportunity-id (+ (var-get opportunity-nonce) u1))
        (profit-margin (if (> sell-price buy-price)
                         (* (/ (- sell-price buy-price) buy-price) u10000)
                         u0)))
    (asserts! (get is-authorized operator-auth) ERR-NOT-AUTHORIZED)
    (asserts! (>= profit-margin (var-get min-profit-threshold)) ERR-INSUFFICIENT-PROFIT)
    (var-set opportunity-nonce opportunity-id)
    (ok (map-set arbitrage-opportunities
      { opportunity-id: opportunity-id }
      {
        token-pair: token-pair,
        buy-venue: buy-venue,
        sell-venue: sell-venue,
        buy-price: buy-price,
        sell-price: sell-price,
        profit-margin: profit-margin,
        max-amount: max-amount,
        created-at: block-height,
        is-active: true
      }
    ))
  )
)

(define-public (execute-arbitrage (opportunity-id uint) (amount uint))
  (let ((operator-auth (default-to { is-authorized: false }
                                  (map-get? arbitrage-operators { operator: tx-sender })))
        (opportunity (unwrap! (map-get? arbitrage-opportunities { opportunity-id: opportunity-id }) ERR-OPPORTUNITY-NOT-FOUND)))
    (asserts! (get is-authorized operator-auth) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active opportunity) ERR-OPPORTUNITY-NOT-FOUND)
    (asserts! (<= amount (get max-amount opportunity)) ERR-INSUFFICIENT-PROFIT)
    ;; In a real implementation, this would execute the actual trades
    (ok (map-set arbitrage-opportunities
      { opportunity-id: opportunity-id }
      (merge opportunity { is-active: false })
    ))
  )
)

(define-public (set-min-profit-threshold (threshold uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (ok (var-set min-profit-threshold threshold))
  )
)
