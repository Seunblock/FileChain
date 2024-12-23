# FileChain Access Protocol (FCAP)

## Overview
FileChain Access Protocol (FCAP) is a decentralized smart contract system built on Stacks blockchain using Clarity language. It enables secure file sharing, access management, and monetization with features like time-based access control, revenue sharing, and usage tracking.

## Features

### Core Functionality
- File Registration and Management
- Granular Access Control
- Pay-per-access Model
- Revenue Sharing System
- Usage Statistics Tracking

### Access Types
- Preview: Limited access for file preview
- Full: Complete access to file content
- Commercial: Access with commercial usage rights

## Smart Contract Structure

### Data Maps
1. `file-registry`: Stores file metadata and ownership information
2. `access-rights`: Manages access permissions and expiration
3. `revenue-sharing`: Handles revenue distribution configuration
4. `user-stats`: Tracks user activity and earnings

### Key Functions

#### Public Functions
1. `register-file`: Register a new file with metadata
   ```clarity
   (register-file file-id file-hash price is-public content-type description)
   ```

2. `request-access`: Purchase access to a file
   ```clarity
   (request-access file-id access-type)
   ```

3. `grant-access`: Grant access rights to a user
   ```clarity
   (grant-access file-id user duration access-type)
   ```

4. `set-revenue-sharing`: Configure revenue sharing for a file
   ```clarity
   (set-revenue-sharing file-id contributors shares)
   ```

#### Read-Only Functions
- `verify-access`: Check access rights
- `get-file-details`: Retrieve file information
- `get-user-stats`: Get user statistics
- `get-revenue-sharing`: View revenue sharing configuration

## Security Features

### Input Validation
- String length and content validation
- Price bounds checking
- Duration limits
- Access type verification
- Revenue share validation

### Access Control
- Owner-only operations
- Time-based access expiration
- Payment verification

## Usage Example

1. Register a File
```clarity
(contract-call? .file-access-protocol register-file
    "file123"
    "QmHash..."
    u1000000
    false
    "pdf"
    "Confidential Report 2024"
)
```

2. Request Access
```clarity
(contract-call? .file-access-protocol request-access
    "file123"
    "full"
)
```

3. Set Up Revenue Sharing
```clarity
(contract-call? .file-access-protocol set-revenue-sharing
    "file123"
    (list tx-sender 'ST1CONTRIBUTOR...)
    (list u5000 u5000)
)
```

## Platform Economics

### Fee Structure
- Platform fee: 0.5% (50 basis points)
- Maximum fee cap: 10% (1000 basis points)
- Fees are automatically calculated and distributed

### Revenue Sharing
- Support for up to 5 contributors
- Customizable share ratios
- Shares must total 100% (10000 basis points)

## Administrative Functions

- `set-platform-fee`: Update platform fee percentage
- `transfer-ownership`: Transfer contract ownership

## Error Handling

### Error Codes
- `ERR_NOT_AUTHORIZED (u100)`: Unauthorized operation
- `ERR_ALREADY_EXISTS (u101)`: Duplicate registration
- `ERR_DOES_NOT_EXIST (u102)`: Resource not found
- `ERR_INVALID_PAYMENT (u103)`: Payment error
- `ERR_EXPIRED_ACCESS (u104)`: Access expired
- `ERR_INVALID_PARAMS (u105)`: Invalid parameters

## Development

### Requirements
- Clarity SDK
- Stacks blockchain environment
- Basic understanding of smart contract development

### Testing
Test the contract using Clarinet:
```bash
clarinet test
```