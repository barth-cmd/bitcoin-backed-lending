;; Mock xUSD Stablecoin Implementation with input validation
(impl-trait .sip-010-trait.sip-010-trait)
(define-fungible-token xusd)

;; Constants for xUSD
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-INVALID-AMOUNT (err u402))
(define-constant ERR-INSUFFICIENT-BALANCE (err u403))
(define-constant ERR-INVALID-RECIPIENT (err u404))

;; Principal validation for xUSD
(define-private (is-valid-recipient (recipient principal))
    (not (is-eq recipient (as-contract tx-sender)))
)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        (asserts! (not (is-eq sender recipient)) ERR-INVALID-AMOUNT)
        (asserts! (>= (ft-get-balance xusd sender) amount) ERR-INSUFFICIENT-BALANCE)
        (asserts! (is-valid-recipient recipient) ERR-INVALID-RECIPIENT)
        
        (ft-transfer? xusd amount sender recipient)
    )
)

(define-read-only (get-name) 
    (ok "Test USD")
)

(define-read-only (get-symbol) 
    (ok "xUSD")
)

(define-read-only (get-decimals) 
    (ok u6)
)

(define-read-only (get-balance (who principal))
    (ok (ft-get-balance xusd who))
)

(define-read-only (get-total-supply)
    (ok (ft-get-supply xusd))
)

(define-read-only (get-token-uri)
    (ok none)
)

(define-public (mint (amount uint) (recipient principal))
    (begin
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (is-valid-recipient recipient) ERR-INVALID-RECIPIENT)
        
        (ft-mint? xusd amount recipient)
    )
)

(define-public (burn (amount uint) (sender principal))
    (begin
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        (asserts! (>= (ft-get-balance xusd sender) amount) ERR-INSUFFICIENT-BALANCE)
        
        (ft-burn? xusd amount sender)
    )
)