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
