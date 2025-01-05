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
