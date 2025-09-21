# AuditorCredibility

AuditorCredibility is an address reputation system smart contract for smart contract auditor reliability scoring on the Stacks blockchain. This contract provides a decentralized platform for managing auditor profiles, tracking audit history, and maintaining reputation scores to help users identify reliable smart contract auditors.

## Features

- **Auditor Registration**: Comprehensive auditor profile management with name, bio, and website
- **Audit Tracking**: Complete audit lifecycle management from submission to completion
- **Reputation System**: Dynamic scoring algorithm based on audit history, ratings, and performance
- **Client Rating System**: Allows clients to rate auditor performance on completed audits
- **Profile Management**: Auditors can update profiles and deactivate accounts
- **Transparency**: All audit records and ratings are stored on-chain for verification
- **Anti-Gaming Protection**: Prevents self-rating and duplicate ratings

## Technical Specifications

- **Blockchain**: Stacks
- **Language**: Clarity 2.0
- **Epoch**: 2.5
- **Contract Version**: 1.0.0
- **Reputation Scale**: 100-1000 points
- **Rating Scale**: 1-5 stars
- **Average Rating Precision**: 2 decimal places (multiplied by 100)

## Installation

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js (for development tools)
- Stacks CLI (for deployment)

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd AuditorCredibility
```

2. Navigate to the contract directory:
```bash
cd AuditorCredibility_contract
```

3. Install dependencies:
```bash
npm install
```

4. Run Clarinet check:
```bash
clarinet check
```

5. Run tests:
```bash
clarinet test
```

## Usage Examples

### Register as an Auditor

```clarity
(contract-call? .AuditorCredibility register-auditor
  "Alice Security"
  "Experienced smart contract auditor specializing in DeFi protocols"
  "https://alicesecurity.com")
```

### Submit Completed Audit

```clarity
(contract-call? .AuditorCredibility submit-audit
  "DeFi Protocol V2"
  (some 'SP1234...CONTRACT)
  "QmX1Y2Z3...IPFSHASH"
  u2
  'SP5678...CLIENT)
```

### Rate an Audit

```clarity
(contract-call? .AuditorCredibility rate-audit
  u1
  u5
  "Excellent audit with thorough documentation and quick turnaround")
```

### Query Auditor Information

```clarity
;; Get auditor profile
(contract-call? .AuditorCredibility get-auditor-profile 'SP1234...AUDITOR)

;; Get auditor statistics
(contract-call? .AuditorCredibility get-auditor-stats 'SP1234...AUDITOR)

;; Get reputation breakdown
(contract-call? .AuditorCredibility get-reputation-breakdown 'SP1234...AUDITOR)
```

## Contract Functions

### Public Functions

#### `register-auditor`
Registers a new auditor with profile information.
- **Parameters**: `name` (string-ascii 50), `bio` (string-ascii 200), `website` (string-ascii 100)
- **Returns**: `(response bool uint)`
- **Errors**: ERR_ALREADY_REGISTERED, ERR_INVALID_PARAMETERS

#### `update-profile`
Updates existing auditor profile information.
- **Parameters**: `name` (string-ascii 50), `bio` (string-ascii 200), `website` (string-ascii 100)
- **Returns**: `(response bool uint)`
- **Errors**: ERR_NOT_REGISTERED, ERR_INVALID_PARAMETERS

#### `submit-audit`
Submits a completed audit record.
- **Parameters**: `project-name`, `project-contract` (optional), `audit-report-hash`, `severity-findings`, `client`
- **Returns**: `(response uint uint)` - Returns audit ID on success
- **Errors**: ERR_NOT_REGISTERED, ERR_UNAUTHORIZED, ERR_INVALID_PARAMETERS

#### `rate-audit`
Allows clients to rate auditor performance on specific audits.
- **Parameters**: `audit-id` (uint), `rating` (uint 1-5), `comment` (string-ascii 200)
- **Returns**: `(response bool uint)`
- **Errors**: ERR_AUDIT_NOT_FOUND, ERR_INVALID_RATING, ERR_CANNOT_RATE_SELF, ERR_ALREADY_RATED

#### `deactivate-profile`
Deactivates auditor profile (can only be called by the auditor).
- **Parameters**: None
- **Returns**: `(response bool uint)`
- **Errors**: ERR_NOT_REGISTERED

### Read-Only Functions

#### `get-auditor-profile`
Returns auditor profile information.
- **Parameters**: `auditor` (principal)
- **Returns**: `(optional {name, bio, website, registration-block, is-active})`

#### `get-auditor-stats`
Returns auditor performance statistics.
- **Parameters**: `auditor` (principal)
- **Returns**: `(optional {total-audits, completed-audits, average-rating, total-ratings, reputation-score})`

#### `get-audit-record`
Returns specific audit record details.
- **Parameters**: `audit-id` (uint)
- **Returns**: `(optional {auditor, project-name, project-contract, audit-report-hash, completion-block, severity-findings, client, status})`

#### `get-reputation-breakdown`
Returns detailed reputation information including display formatting.
- **Parameters**: `auditor` (principal)
- **Returns**: `(optional {reputation-score, completed-audits, average-rating, total-ratings, rating-display})`

#### `is-active-auditor`
Checks if an auditor is registered and active.
- **Parameters**: `auditor` (principal)
- **Returns**: `bool`

#### `has-client-rated-audit`
Checks if a client has already rated a specific audit.
- **Parameters**: `client` (principal), `audit-id` (uint)
- **Returns**: `bool`

## Reputation Scoring Algorithm

The reputation score is calculated using the following factors:

1. **Base Score**: 500 points (neutral starting point)
2. **Audit Bonus**: +10 points per completed audit (capped at 200 points)
3. **Rating Bonus**: Points above 3.0 average rating add bonus points
4. **Severity Penalty**: -5 points per high/critical finding (capped at 100 points)

**Final Score Range**: 100-1000 points

## Deployment Guide

### Testnet Deployment

1. Configure testnet settings in `settings/Testnet.toml`
2. Deploy using Clarinet:
```bash
clarinet deploy --testnet
```

### Mainnet Deployment

1. Configure mainnet settings in `settings/Mainnet.toml`
2. Verify contract with security audit
3. Deploy using Clarinet:
```bash
clarinet deploy --mainnet
```

### Post-Deployment Verification

1. Verify contract deployment on Stacks Explorer
2. Test basic functions with small amounts
3. Monitor for any unexpected behavior

## Security Notes

### Access Controls
- Only registered auditors can submit audits
- Only active auditors can participate in the system
- Auditors cannot rate their own work
- Clients cannot rate the same audit multiple times

### Data Integrity
- All audit records are immutable once submitted
- Reputation scores are calculated deterministically
- Profile updates preserve registration history

### Best Practices
- Verify IPFS hashes for audit reports before trusting content
- Cross-reference multiple data points when evaluating auditors
- Consider both reputation score and number of completed audits
- Review recent audit history for consistency

### Known Limitations
- Reputation scores can be gamed through collusion
- No mechanism for dispute resolution beyond on-chain data
- IPFS content availability depends on pinning services
- Initial auditors start with neutral reputation regardless of off-chain experience

## Error Codes

- `u100`: ERR_UNAUTHORIZED - Insufficient permissions
- `u101`: ERR_ALREADY_REGISTERED - Auditor already registered
- `u102`: ERR_NOT_REGISTERED - Auditor not found
- `u103`: ERR_INVALID_RATING - Rating outside 1-5 range
- `u104`: ERR_AUDIT_NOT_FOUND - Audit record not found
- `u105`: ERR_ALREADY_RATED - Client already rated this audit
- `u106`: ERR_CANNOT_RATE_SELF - Auditors cannot rate themselves
- `u107`: ERR_INVALID_PARAMETERS - Invalid input parameters

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add comprehensive tests for new functionality
4. Ensure all tests pass
5. Submit a pull request with detailed description

## License

This project is open source. Please refer to the LICENSE file for details.