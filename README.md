# Bitcoin-backed Lending Protocol

A decentralized lending protocol built on Stacks that enables users to collateralize sBTC (Wrapped Bitcoin) to borrow xUSD stablecoins.

## Overview

This protocol allows users to:

- Deposit sBTC as collateral
- Borrow xUSD against their sBTC collateral
- Repay borrowed xUSD
- Withdraw their sBTC collateral
- Participate in liquidations of unhealthy positions

### Key Features

- 150% minimum collateral ratio
- 130% liquidation threshold
- 10% liquidation penalty
- 1% protocol fee
- Dynamic interest rate mechanism
- Emergency pause functionality
- Secure token implementations (SIP-010 compliant)

## Protocol Parameters

| Parameter                | Value | Description                                                                     |
| ------------------------ | ----- | ------------------------------------------------------------------------------- |
| Minimum Collateral Ratio | 150%  | The minimum ratio of collateral value to borrowed value that must be maintained |
| Liquidation Threshold    | 130%  | The collateral ratio at which positions become eligible for liquidation         |
| Liquidation Penalty      | 10%   | The penalty paid by liquidated positions                                        |
| Protocol Fee             | 1%    | Fee charged on borrowing operations                                             |
| Base Interest Rate       | 5%    | Starting annual interest rate (adjustable by governance)                        |

## Smart Contract Architecture

The protocol consists of three main contracts:

1. **Lending Protocol Core** - Main lending functionality
2. **Mock sBTC** - SIP-010 compliant wrapped Bitcoin implementation
3. **Mock xUSD** - SIP-010 compliant stablecoin implementation

### Core Functions

#### User Operations

```clarity
(deposit-collateral (amount uint))
(borrow (amount uint))
(repay (amount uint))
(withdraw-collateral (amount uint))
```

#### Liquidation Operations

```clarity
(liquidate (borrower principal))
```

#### Administrative Functions

```clarity
(set-protocol-owner (new-owner principal))
(set-interest-rate (new-rate uint))
(toggle-protocol-pause)
```

#### View Functions

```clarity
(get-position (user principal))
(get-protocol-state)
(get-collateral-ratio (collateral uint) (borrowed uint))
(is-position-healthy (collateral uint) (borrowed uint))
```

## Getting Started

### Prerequisites

- Stacks blockchain environment
- Clarity understanding
- Access to sBTC and xUSD tokens

### Deployment

1. Deploy the SIP-010 trait
2. Deploy the mock token contracts (sBTC and xUSD)
3. Deploy the main lending protocol contract
4. Initialize the protocol using `(initialize)`

### Usage Example

```clarity
;; Deposit collateral
(contract-call? .lending-protocol deposit-collateral u1000000)

;; Borrow xUSD
(contract-call? .lending-protocol borrow u500000)

;; Check position
(contract-call? .lending-protocol get-position tx-sender)

;; Repay loan
(contract-call? .lending-protocol repay u500000)

;; Withdraw collateral
(contract-call? .lending-protocol withdraw-collateral u1000000)
```

## Security Considerations

- All functions include comprehensive input validation
- Protocol can be paused in case of emergencies
- Liquidation mechanism ensures protocol solvency
- Access control for administrative functions
- Protection against self-transfers and invalid operations

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
