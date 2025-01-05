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

;; Borrow against collateral
(define-public (borrow (amount uint))
    (let (
        (current-position (unwrap! (map-get? positions tx-sender) ERR-POSITION-NOT-FOUND))
        (state (unwrap! (map-get? protocol-state {version: "1.0.0"}) ERR-NOT-INITIALIZED))
        (new-borrowed-amount (+ (get borrowed-amount current-position) amount))
        (collateral-value (get collateral-amount current-position))
    )
        (asserts! (not (var-get protocol-paused)) ERR-NOT-AUTHORIZED)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        
        ;; Check if position would be healthy after borrow
        (asserts! (is-position-healthy collateral-value new-borrowed-amount) ERR-INSUFFICIENT-COLLATERAL)
        
        ;; Transfer stablecoin to borrower
        (try! (contract-call? .xusd mint amount tx-sender))
        
        ;; Update position
        (map-set positions tx-sender
            {
                collateral-amount: collateral-value,
                borrowed-amount: new-borrowed-amount,
                last-update-block: block-height
            }
        )
        
        ;; Update protocol state
        (map-set protocol-state 
            {version: "1.0.0"}
            {
                total-collateral: (get total-collateral state),
                total-borrowed: (+ (get total-borrowed state) amount),
                interest-rate: (get interest-rate state),
                last-rate-update: (get last-rate-update state)
            }
        )
        
        (ok true)
    )
)

;; Repay borrowed amount
(define-public (repay (amount uint))
    (let (
        (current-position (unwrap! (map-get? positions tx-sender) ERR-POSITION-NOT-FOUND))
        (state (unwrap! (map-get? protocol-state {version: "1.0.0"}) ERR-NOT-INITIALIZED))
        (borrowed-amount (get borrowed-amount current-position))
    )
        (asserts! (not (var-get protocol-paused)) ERR-NOT-AUTHORIZED)
        (asserts! (>= borrowed-amount amount) ERR-INVALID-AMOUNT)
        
        ;; Burn stablecoin from repayer
        (try! (contract-call? .xusd burn amount tx-sender))
        
        ;; Update position
        (map-set positions tx-sender
            {
                collateral-amount: (get collateral-amount current-position),
                borrowed-amount: (- borrowed-amount amount),
                last-update-block: block-height
            }
        )
        
        ;; Update protocol state
        (map-set protocol-state 
            {version: "1.0.0"}
            {
                total-collateral: (get total-collateral state),
                total-borrowed: (- (get total-borrowed state) amount),
                interest-rate: (get interest-rate state),
                last-rate-update: (get last-rate-update state)
            }
        )
        
        (ok true)
    )
)

;; Liquidate unhealthy position
(define-public (liquidate (borrower principal))
    (let (
        (position (unwrap! (map-get? positions borrower) ERR-POSITION-NOT-FOUND))
        (state (unwrap! (map-get? protocol-state {version: "1.0.0"}) ERR-NOT-INITIALIZED))
        (collateral-amount (get collateral-amount position))
        (borrowed-amount (get borrowed-amount position))
    )
        (asserts! (not (var-get protocol-paused)) ERR-NOT-AUTHORIZED)
        (asserts! (not (is-position-healthy collateral-amount borrowed-amount)) ERR-POSITION-HEALTHY)
        
        ;; Calculate liquidation amounts
        (let (
            (liquidation-amount (/ (* borrowed-amount LIQUIDATION-PENALTY) u100))
            (reward-amount (/ (* collateral-amount LIQUIDATION-PENALTY) u100))
        )
            ;; Transfer liquidation reward to liquidator
            (try! (contract-call? .sbtc transfer reward-amount (as-contract tx-sender) tx-sender))
            
            ;; Burn debt
            (try! (contract-call? .xusd burn liquidation-amount tx-sender))
            
            ;; Update position
            (map-set positions borrower
                {
                    collateral-amount: (- collateral-amount reward-amount),
                    borrowed-amount: (- borrowed-amount liquidation-amount),
                    last-update-block: block-height
                }
            )
            
            ;; Update protocol state
            (map-set protocol-state 
                {version: "1.0.0"}
                {
                    total-collateral: (- (get total-collateral state) reward-amount),
                    total-borrowed: (- (get total-borrowed state) liquidation-amount),
                    interest-rate: (get interest-rate state),
                    last-rate-update: (get last-rate-update state)
                }
            )
            
            (ok true)
        )
    )
)

;; Withdraw collateral
(define-public (withdraw-collateral (amount uint))
    (let (
        (current-position (unwrap! (map-get? positions tx-sender) ERR-POSITION-NOT-FOUND))
        (state (unwrap! (map-get? protocol-state {version: "1.0.0"}) ERR-NOT-INITIALIZED))
        (collateral-amount (get collateral-amount current-position))
        (borrowed-amount (get borrowed-amount current-position))
    )
        (asserts! (not (var-get protocol-paused)) ERR-NOT-AUTHORIZED)
        (asserts! (<= amount collateral-amount) ERR-INVALID-AMOUNT)
        
        ;; Check if position would remain healthy after withdrawal
        (asserts! 
            (is-position-healthy 
                (- collateral-amount amount)
                borrowed-amount
            )
            ERR-INSUFFICIENT-COLLATERAL
        )
        
        ;; Transfer sBTC back to user
        (try! (contract-call? .sbtc transfer amount (as-contract tx-sender) tx-sender))
        
        ;; Update position
        (map-set positions tx-sender
            {
                collateral-amount: (- collateral-amount amount),
                borrowed-amount: borrowed-amount,
                last-update-block: block-height
            }
        )
        
        ;; Update protocol state
        (map-set protocol-state 
            {version: "1.0.0"}
            {
                total-collateral: (- (get total-collateral state) amount),
                total-borrowed: (get total-borrowed state),
                interest-rate: (get interest-rate state),
                last-rate-update: (get last-rate-update state)
            }
        )
        
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-position (user principal))
    (map-get? positions user)
)

(define-read-only (get-protocol-state)
    (map-get? protocol-state {version: "1.0.0"})
)

(define-read-only (get-collateral-ratio (collateral uint) (borrowed uint))
    (if (is-eq borrowed u0)
        (ok u0)
        (ok (/ (* collateral u100) borrowed))
    )
)

(define-read-only (is-position-healthy (collateral uint) (borrowed uint))
    (if (is-eq borrowed u0)
        true
        (>= (unwrap! (get-collateral-ratio collateral borrowed) false) COLLATERAL-RATIO)
    )
)

;; Admin functions
(define-public (set-protocol-owner (new-owner principal))
    (begin
        (asserts! (is-protocol-owner) ERR-NOT-AUTHORIZED)
        (ok (var-set protocol-owner new-owner))
    )
)

(define-public (set-interest-rate (new-rate uint))
    (begin
        (asserts! (is-protocol-owner) ERR-NOT-AUTHORIZED)
        (ok (var-set interest-rate new-rate))
    )
)

(define-public (toggle-protocol-pause)
    (begin
        (asserts! (is-protocol-owner) ERR-NOT-AUTHORIZED)
        (ok (var-set protocol-paused (not (var-get protocol-paused))))
    )
)