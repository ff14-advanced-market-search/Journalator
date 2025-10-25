# Invest-o-nator Feature for Journalator

## Overview
The Invest-o-nator is a new feature for Journalator that helps you track investment portfolios in World of Warcraft. It allows you to set up investment targets for specific items and track your purchases against those targets.

## Features

### Portfolio Management
- Create multiple investment portfolios
- Set total investment budget for each portfolio
- Add items to portfolios with target investment amounts
- Track progress against investment targets

### Purchase Tracking
- Automatically tracks auction house purchases
- Records purchase history with timestamps and prices
- Shows remaining budget for each item
- Displays completion percentage for portfolios

### User Interface
- New "Invest-o-nator" tab in the main Journalator window
- Portfolio list with progress indicators
- Create/delete portfolios and items
- Real-time purchase notifications

## Usage

### Slash Commands
- `/jnr invest create <name> <investment>` - Create a new portfolio
- `/jnr invest add <portfolioId> <itemName> <amount>` - Add item to portfolio
- `/jnr invest list` - List all portfolios

### Example Usage
```
/jnr invest create "Materials" 3000000
/jnr invest add 1 "Iron Ore" 100000
/jnr invest add 1 "Copper Ore" 50000
```

### Gold Amount Formats
The system supports various gold input formats:
- `100g` - 100 gold
- `10000s` - 100 silver (10,000 copper)
- `1000000c` - 1,000,000 copper
- `1000000` - 1,000,000 copper (default)

## Data Structure
Portfolio data is stored in `JOURNALATOR_INVEST_O_NATOR_DATA` with the following structure:
```lua
{
  portfolios = {
    [portfolioId] = {
      name = "Portfolio Name",
      totalInvestment = 3000000,
      items = {
        [itemId] = {
          name = "Item Name",
          targetAmount = 10000,
          purchasedAmount = 5000,
          remainingAmount = 5000,
          lastPurchaseTime = timestamp,
          purchaseHistory = {
            {amount = 5000, time = timestamp, price = 50, quantity = 100}
          }
        }
      }
    }
  }
}
```

## Integration
The feature integrates with Journalator's existing monitoring system:
- Uses the auction house monitor to detect purchases
- Follows Journalator's configuration system
- Integrates with the main display UI
- Supports localization

## Configuration
The feature can be enabled/disabled via the Journalator configuration:
- `monitor_invest_o_nator` - Enable/disable the invest-o-nator monitor

## Future Enhancements
- Item ID lookup from item names
- Import/export portfolio data
- Advanced filtering and sorting
- Investment analytics and reporting
- Integration with other add-ons