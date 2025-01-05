;; Mock sBTC Implementation with input validation
(impl-trait .sip-010-trait.sip-010-trait)
(define-fungible-token sbtc)

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-INVALID-AMOUNT (err u402))
(define-constant ERR-INSUFFICIENT-BALANCE (err u403))
(define-constant ERR-INVALID-RECIPIENT (err u404))
(define-constant CONTRACT-OWNER tx-sender)

;; Authorization check
(define-private (is-contract-owner)
    (is-eq tx-sender CONTRACT-OWNER)
)

;; Principal validation - check if recipient is not the contract itself
(define-private (is-valid-recipient (recipient principal))
    (not (is-eq recipient (as-contract tx-sender)))
)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        ;; Enhanced input validation
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        (asserts! (not (is-eq sender recipient)) ERR-INVALID-AMOUNT)
        (asserts! (>= (ft-get-balance sbtc sender) amount) ERR-INSUFFICIENT-BALANCE)
        (asserts! (is-valid-recipient recipient) ERR-INVALID-RECIPIENT)
        
        (ft-transfer? sbtc amount sender recipient)
    )
)

;; Read-only functions
(define-read-only (get-name) 
    (ok "Wrapped Bitcoin")
)

(define-read-only (get-symbol) 
    (ok "sBTC")
)

(define-read-only (get-decimals) 
    (ok u8)
)

(define-read-only (get-balance (who principal))
    (ok (ft-get-balance sbtc who))
)

(define-read-only (get-total-supply)
    (ok (ft-get-supply sbtc))
)

(define-read-only (get-token-uri)
    (ok none)
)

;; Secure mint function
(define-public (mint (amount uint) (recipient principal))
    (begin
        ;; Enhanced input validation
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (is-valid-recipient recipient) ERR-INVALID-RECIPIENT)
        
        (ft-mint? sbtc amount recipient)
    )
)