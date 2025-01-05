;; Bitcoin-backed Lending Protocol
;; Description: A decentralized lending protocol allowing users to collateralize sBTC to borrow stablecoins

;; Constants for protocol parameters
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u101))
(define-constant ERR-POSITION-NOT-FOUND (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-UNHEALTHY-POSITION (err u104))
(define-constant ERR-ALREADY-INITIALIZED (err u105))
(define-constant ERR-NOT-INITIALIZED (err u106))
(define-constant ERR-POSITION-HEALTHY (err u107))

;; Protocol configuration
(define-constant COLLATERAL-RATIO u150) ;; 150% minimum collateral ratio
(define-constant LIQUIDATION-THRESHOLD u130) ;; 130% liquidation threshold
(define-constant LIQUIDATION-PENALTY u10) ;; 10% liquidation penalty
(define-constant PROTOCOL-FEE u1) ;; 1% protocol fee

;; Data maps and variables
(define-map positions 
    principal 
    {
        collateral-amount: uint,
        borrowed-amount: uint,
        last-update-block: uint
    }
)

(define-map protocol-state
    {version: (string-ascii 10)}
    {
        total-collateral: uint,
        total-borrowed: uint,
        interest-rate: uint,
        last-rate-update: uint
    }
)

(define-data-var protocol-owner principal tx-sender)
(define-data-var protocol-paused bool false)
(define-data-var interest-rate uint u500) ;; 5% base interest rate (basis points)

;; Authorization check
(define-private (is-protocol-owner)
    (is-eq tx-sender (var-get protocol-owner))
)

;; Initialization
(define-public (initialize)
    (begin
        (asserts! (is-protocol-owner) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? protocol-state {version: "1.0.0"})) ERR-ALREADY-INITIALIZED)
        (ok (map-set protocol-state 
            {version: "1.0.0"}
            {
                total-collateral: u0,
                total-borrowed: u0,
                interest-rate: (var-get interest-rate),
                last-rate-update: block-height
            }
        ))
    )
)

;; Deposit collateral
(define-public (deposit-collateral (amount uint))
    (let (
        (current-position (default-to 
            {collateral-amount: u0, borrowed-amount: u0, last-update-block: block-height}
            (map-get? positions tx-sender)
        ))
        (state (unwrap! (map-get? protocol-state {version: "1.0.0"}) ERR-NOT-INITIALIZED))
    )
        (asserts! (not (var-get protocol-paused)) ERR-NOT-AUTHORIZED)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        
        ;; Transfer sBTC from user to contract
        (try! (contract-call? .sbtc transfer amount tx-sender (as-contract tx-sender)))
        
        ;; Update position
        (map-set positions tx-sender
            {
                collateral-amount: (+ (get collateral-amount current-position) amount),
                borrowed-amount: (get borrowed-amount current-position),
                last-update-block: block-height
            }
        )
        
        ;; Update protocol state
        (map-set protocol-state 
            {version: "1.0.0"}
            {
                total-collateral: (+ (get total-collateral state) amount),
                total-borrowed: (get total-borrowed state),
                interest-rate: (get interest-rate state),
                last-rate-update: (get last-rate-update state)
            }
        )
        
        (ok true)
    )
)