;; Liquidity Discovery Contract
;; Identifies optimal trading venues

(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-VENUE-NOT-FOUND (err u201))
(define-constant ERR-INVALID-LIQUIDITY (err u202))

(define-data-var contract-owner principal tx-sender)

(define-map liquidity-venues
  { venue-id: (string-ascii 64) }
  {
    protocol-id: (string-ascii 64),
    token-pair: (string-ascii 32),
    liquidity-amount: uint,
    price: uint,
    last-updated: uint,
    is-available: bool
  }
)

(define-map venue-operators
  { operator: principal }
  { is-authorized: bool }
)

;; Initialize contract owner as operator
(map-set venue-operators { operator: tx-sender } { is-authorized: true })

(define-read-only (get-venue (venue-id (string-ascii 64)))
  (map-get? liquidity-venues { venue-id: venue-id })
)

(define-read-only (get-best-price (token-pair (string-ascii 32)))
  (let ((venues (list
    "venue-1" "venue-2" "venue-3" "venue-4" "venue-5"
    "venue-6" "venue-7" "venue-8" "venue-9" "venue-10")))
    (fold find-best-venue venues { best-price: u0, best-venue: "" })
  )
)

(define-private (find-best-venue (venue-id (string-ascii 64)) (acc { best-price: uint, best-venue: (string-ascii 64) }))
  (match (map-get? liquidity-venues { venue-id: venue-id })
    venue (if (and (get is-available venue)
                   (> (get price venue) (get best-price acc)))
            { best-price: (get price venue), best-venue: venue-id }
            acc)
    acc
  )
)

(define-public (add-operator (operator principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (ok (map-set venue-operators { operator: operator } { is-authorized: true }))
  )
)

(define-public (register-venue
  (venue-id (string-ascii 64))
  (protocol-id (string-ascii 64))
  (token-pair (string-ascii 32))
  (liquidity-amount uint)
  (price uint))
  (let ((operator-auth (default-to { is-authorized: false }
                                  (map-get? venue-operators { operator: tx-sender }))))
    (asserts! (get is-authorized operator-auth) ERR-NOT-AUTHORIZED)
    (asserts! (> liquidity-amount u0) ERR-INVALID-LIQUIDITY)
    (ok (map-set liquidity-venues
      { venue-id: venue-id }
      {
        protocol-id: protocol-id,
        token-pair: token-pair,
        liquidity-amount: liquidity-amount,
        price: price,
        last-updated: block-height,
        is-available: true
      }
    ))
  )
)

(define-public (update-venue-liquidity (venue-id (string-ascii 64)) (liquidity-amount uint) (price uint))
  (let ((operator-auth (default-to { is-authorized: false }
                                  (map-get? venue-operators { operator: tx-sender })))
        (venue (unwrap! (map-get? liquidity-venues { venue-id: venue-id }) ERR-VENUE-NOT-FOUND)))
    (asserts! (get is-authorized operator-auth) ERR-NOT-AUTHORIZED)
    (asserts! (> liquidity-amount u0) ERR-INVALID-LIQUIDITY)
    (ok (map-set liquidity-venues
      { venue-id: venue-id }
      (merge venue {
        liquidity-amount: liquidity-amount,
        price: price,
        last-updated: block-height
      })
    ))
  )
)
