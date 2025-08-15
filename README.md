# Backcoin

# 🪙 Backcoin - Tokenized Cashback System

A blockchain-based merchant loyalty program that revolutionizes how businesses reward their customers through tokenized cashback.

## 🌟 Features

- **🏪 Merchant Registration**: Businesses can register and set custom cashback rates
- **💰 Purchase Recording**: Track customer purchases and calculate cashback automatically  
- **🎁 Cashback Claims**: Customers can claim their earned cashback as BACK tokens
- **💳 Token Spending**: Use earned tokens for future purchases at participating merchants
- **📊 Analytics**: Track customer and merchant statistics
- **🔒 Secure**: Built on Stacks blockchain with proper access controls

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

1. Clone this repository
2. Navigate to the project directory
3. Run clarinet console to interact with the contract

```bash
clarinet console
```

## 📖 Usage

### For Merchants

#### 1. Register as a Merchant
```clarity
(contract-call? .Backcoin register-merchant "Coffee Shop" u500)
```
*Sets cashback rate to 5% (500 basis points)*

#### 2. Record Customer Purchases
```clarity
(contract-call? .Backcoin record-purchase 'ST1CUSTOMER123 u10000000)
```
*Records a purchase of 100 STX (10000000 microSTX)*

### For Customers

#### 1. Claim Cashback
```clarity
(contract-call? .Backcoin claim-cashback u1)
```
*Claims cashback for purchase ID 1*

#### 2. Check Balance
```clarity
(contract-call? .Backcoin get-balance 'ST1CUSTOMER123)
```

#### 3. Spend Cashback
```clarity
(contract-call? .Backcoin spend-cashback u50000 'ST1MERCHANT456)
```

### Read-Only Functions

#### Get Merchant Information
```clarity
(contract-call? .Backcoin get-merchant-info 'ST1MERCHANT456)
```

#### Calculate Potential Cashback
```clarity
(contract-call? .Backcoin calculate-cashback 'ST1MERCHANT456 u10000000)
```

#### View Customer Statistics
```clarity
(contract-call? .Backcoin get-customer-stats 'ST1CUSTOMER123)
```

## 🏗️ Contract Architecture

### Core Components

- **SIP-010 Token Standard**: BACK tokens are fully compliant fungible tokens
- **Merchant Management**: Registration, status updates, and cashback rate configuration
- **Purchase Tracking**: Immutable record of all transactions and cashback calculations
- **Customer Analytics**: Comprehensive statistics for spending and earning patterns

### Data Structures

- **Merchants**: Store business information, cashback rates, and activity status
- **Purchases**: Track individual transactions and cashback eligibility
- **Customer Stats**: Aggregate data for customer behavior analysis

## 🔧 Configuration

### Cashback Rates
- Rates are set in basis points (1% = 100 basis points)
- Maximum rate: 10% (1000 basis points)
- Merchants can update rates by re-registering

### Error Codes
- `u100`: Owner only operation
- `u101`: Not token owner
- `u102`: Insufficient balance
- `u103`: Merchant not found
- `u104`: Merchant inactive
- `u105`: Invalid amount
- `u106`: Purchase not found
- `u107`: Cashback already claimed
- `u108`: Invalid cashback rate

## 🧪 Testing

Run the test suite:

```bash
clarinet test
```

Check contract syntax:

```bash
clarinet check
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

For questions and support, please open an issue in the GitHub repository.


