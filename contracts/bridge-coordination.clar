;; Bridge Coordination Contract
;; Manages cross-chain asset transfers

(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-TRANSFER-NOT-FOUND (err u301))
(define-constant ERR-INVALID-AMOUNT (err u302))
(define-constant ERR-TRANSFER-COMPLETED (err u303))

(define-data-var contract-owner principal tx-sender)
(define-data-var transfer-nonce uint u0)

(define-map bridge-operators
  { operator: principal }
  { is-authorized: bool }
)

(define-map cross-chain-transfers
  { transfer-id: uint }
  {
    sender: principal,
    recipient: (string-ascii 128),
    source-chain: uint,
    dest-chain: uint,
    token-address: (string-ascii 128),
    amount: uint,
    status: (string-ascii 16),
    created-at: uint,
    completed-at: (optional uint)
  }
)

;; Initialize contract owner as operator
(map-set bridge-operators { operator: tx-sender } { is-authorized: true })

(define-read-only (get-transfer (transfer-id uint))
  (map-get? cross-chain-transfers { transfer-id: transfer-id })
)

(define-read-only (get-next-transfer-id)
  (+ (var-get transfer-nonce) u1)
)

(define-public (add-bridge-operator (operator principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (ok (map-set bridge-operators { operator: operator } { is-authorized: true }))
  )
)

(define-public (initiate-transfer
  (recipient (string-ascii 128))
  (dest-chain uint)
  (token-address (string-ascii 128))
  (amount uint))
  (let ((transfer-id (get-next-transfer-id)))
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (var-set transfer-nonce transfer-id)
    (ok (map-set cross-chain-transfers
      { transfer-id: transfer-id }
      {
        sender: tx-sender,
        recipient: recipient,
        source-chain: u1, ;; Stacks chain ID
        dest-chain: dest-chain,
        token-address: token-address,
        amount: amount,
        status: "pending",
        created-at: block-height,
        completed-at: none
      }
    ))
  )
)

(define-public (complete-transfer (transfer-id uint))
  (let ((operator-auth (default-to { is-authorized: false }
                                  (map-get? bridge-operators { operator: tx-sender })))
        (transfer (unwrap! (map-get? cross-chain-transfers { transfer-id: transfer-id }) ERR-TRANSFER-NOT-FOUND)))
    (asserts! (get is-authorized operator-auth) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status transfer) "pending") ERR-TRANSFER-COMPLETED)
    (ok (map-set cross-chain-transfers
      { transfer-id: transfer-id }
      (merge transfer {
        status: "completed",
        completed-at: (some block-height)
      })
    ))
  )
)

(define-public (cancel-transfer (transfer-id uint))
  (let ((transfer (unwrap! (map-get? cross-chain-transfers { transfer-id: transfer-id }) ERR-TRANSFER-NOT-FOUND)))
    (asserts! (is-eq (get sender transfer) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status transfer) "pending") ERR-TRANSFER-COMPLETED)
    (ok (map-set cross-chain-transfers
      { transfer-id: transfer-id }
      (merge transfer {
        status: "cancelled",
        completed-at: (some block-height)
      })
    ))
  )
)
