# 🍽️ Meal NFT with Delivery Tracker

A Stacks blockchain smart contract that creates NFTs for meal orders, providing complete delivery tracking from kitchen to doorstep with freshness guarantees.

## 🚀 Features

- 🍕 **NFT Meal Orders**: Each meal order becomes a unique NFT
- 📍 **Real-time Tracking**: Track meals through 5 distinct statuses
- 🕒 **Freshness Guarantees**: Time-based freshness validation
- 🏪 **Restaurant Management**: Register and manage restaurants
- 🚚 **Delivery Network**: Manage delivery personnel
- 👤 **Customer Orders**: Track all customer order history

## 📋 Meal Status Flow

1. **Ordered** (0) → Customer places order
2. **Preparing** (1) → Restaurant starts cooking
3. **Ready** (2) → Meal is ready for pickup
4. **Out for Delivery** (3) → Delivery person picked up
5. **Delivered** (4) → Meal delivered to customer

## 🛠️ Setup & Usage

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation
```bash
git clone <repository-url>
cd Meal-NFT-delivery-Tracker
clarinet check
```

## 📖 Contract Functions

### 🏪 Restaurant Operations

#### Register Restaurant
```clarity
(contract-call? .Meal-NFT-Delivery-Tracker register-restaurant "Pizza Palace")
```

#### Start Meal Preparation
```clarity
(contract-call? .Meal-NFT-Delivery-Tracker start-preparation u1)
```

#### Mark Meal Ready
```clarity
(contract-call? .Meal-NFT-Delivery-Tracker mark-ready u1)
```

### 🚚 Delivery Operations

#### Register Delivery Person
```clarity
(contract-call? .Meal-NFT-Delivery-Tracker register-delivery-person "John Driver")
```

#### Assign Delivery
```clarity
(contract-call? .Meal-NFT-Delivery-Tracker assign-delivery u1 'SP1DELIVERY...)
```

#### Pickup Meal
```clarity
(contract-call? .Meal-NFT-Delivery-Tracker pickup-meal u1)
```

#### Deliver Meal
```clarity
(contract-call? .Meal-NFT-Delivery-Tracker deliver-meal u1)
```

### 👤 Customer Operations

#### Place Order
```clarity
(contract-call? .Meal-NFT-Delivery-Tracker place-order 
    'SP1RESTAURANT... 
    "Margherita Pizza" 
    u500000 
    u144)
```
*Parameters: restaurant, meal-name, price (microSTX), freshness-guarantee (blocks)*

#### Claim Delivered Meal
```clarity
(contract-call? .Meal-NFT-Delivery-Tracker claim-meal u1)
```

## 🔍 Read-Only Functions

### Get Meal Information
```clarity
(contract-call? .Meal-NFT-Delivery-Tracker get-meal-info u1)
```

### Check Meal Freshness
```clarity
(contract-call? .Meal-NFT-Delivery-Tracker check-freshness u1)
```

### Get Delivery Time Estimate
```clarity
(contract-call? .Meal-NFT-Delivery-Tracker get-delivery-time-estimate u1)
```

### Get Customer Orders
```clarity
(contract-call? .Meal-NFT-Delivery-Tracker get-customer-orders 'SP1CUSTOMER...)
```

## ⚡ Key Concepts

### 🕰️ Freshness Guarantees
- Freshness is measured in blocks from order time
- Default window: 144 blocks (~24 hours)
- Expired meals cannot be picked up or delivered

### 🎯 Authorization
- Only contract owner can register restaurants and delivery persons
- Restaurants control their meal preparation flow
- Delivery persons can only handle assigned meals
- Customers own their meal NFTs

### 📊 Tracking Data
Each meal NFT stores:
- Customer, restaurant, and delivery person principals
- Timestamps for each status change
- Meal details and pricing
- Freshness guarantee period

## 🧪 Testing

Run contract checks:
```bash
clarinet check
```

Run tests:
```bash
clarinet test
```

## 🏗️ Architecture

The contract uses three main data structures:
- **meals**: Maps NFT IDs to complete meal data
- **restaurants**: Restaurant registration and stats
- **delivery-persons**: Delivery personnel management
- **customer-orders**: Customer order history tracking

## 🔒 Error Codes

- `u100`: Not authorized
- `u101`: NFT not found
- `u102`: Already claimed
- `u103`: Invalid status
- `u104`: Meal expired
- `u105`: Not a restaurant
- `u106`: Not a delivery person
- `u107`: Invalid recipient
- `u108`: Meal not ready

## 🎉 Example Workflow

1. **Setup**: Contract owner registers restaurants and delivery persons
2. **Order**: Customer places meal order, receives NFT
3. **Prepare**: Restaurant starts preparation, updates status
4. **Ready**: Restaurant marks meal ready for pickup
5. **Assign**: Restaurant assigns delivery person
6. **Pickup**: Delivery person picks up meal
7. **Deliver**: Delivery person completes delivery
8. **Claim**: Customer claims their delivered meal

## 🤝 Contributing

Feel free to submit issues and pull requests to improve the contract functionality.

## 📄 License

This project is open source and available under standard licensing terms.
