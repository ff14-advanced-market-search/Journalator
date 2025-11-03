# Journalator
![Curse Build Status](https://github.com/Auctionator/Journalator/workflows/Curse%20Build/badge.svg)
[![Auctionator Discord](https://img.shields.io/badge/discord-auctionator-blue.svg)](https://discord.gg/xgz75Pp)


An addon that keeps track of all your sales and postings on the Auction House,
sales and purchases with vendors, crafting orders, quest rewards, item drops,
trades and mails, provides a summary view, sales percentage stats for the last
month, and lets you export the data to your favourite spreadsheet program. Works
on Retail, SoM, and Wrath.

To see your summary click the minimap icon or run the slash command `/jnr`.

## Slash Commands

Journalator provides several slash commands for quick access to features and configuration:

### Main Commands
- `/journalator` or `/jnr` - Toggle the Journalator view window (opens/closes the main interface)

### Configuration Commands
- `/jnr config` or `/jnr c` - Manage configuration options
  - `/jnr config` - List all configuration options and their current values
  - `/jnr config <optionName>` - View the current value of a specific option
  - `/jnr config <optionName> <value>` - Set a configuration option to a new value
    - For boolean options: use `true` or `false`
    - For number options: use a numeric value
    - For string options: use text (spaces allowed)
  
  Example: `/jnr config monitor_auction_house true`

### Debug Commands
- `/jnr debug` or `/jnr d` - Toggle debug mode on/off

### Invest-O-Nator Commands
- `/jnr invest create <name> <investment>` - Create a new investment portfolio
  - `<name>` - The name of the portfolio (use quotes if it contains spaces)
  - `<investment>` - Initial investment amount (supports formats: `100g`, `10000s`, `1000000c`, or plain numbers in copper)
  - Example: `/jnr invest create "Materials" 3000000`
  - Example: `/jnr invest create Trading 50000g`

- `/jnr invest add <portfolioId> <itemLink|itemID> <amount>` - Add an item to a portfolio
  - `<portfolioId>` - The ID of the portfolio (use `/jnr invest list` to see IDs)
  - `<itemLink|itemID>` - Item link (shift-click item to paste) or numeric item ID (e.g., `3575` for Iron Bar)
  - `<amount>` - Target investment amount for this item (supports gold formats: `100g`, `10000s`, `1000000c`, or plain numbers)
  - Example: `/jnr invest add 1 3575 100000` (adds Iron Bar with 1000g target to portfolio 1)
  - Example: `/jnr invest add 1 |cff9d9d9d|Hitem:3575|h[Iron Bar]|h|r 50g`

- `/jnr invest list` - List all portfolios with their progress
  - Shows portfolio ID, name, spent amount, target amount, and completion percentage

## Views
* Summary: See which sections gave/lost the most gold.
* Auction House: Auction mail, posting, sale rates, expired/cancelled items and (retail only) WoW tokens purchased.
* Vendors: Items sold to and purchased from vendors, gear repairs and flight master costs.
* Crafting Orders: Crafting orders created by you, including the reagents submitted and items crafted to fulfil crafting orders, including reagents used (retail only).
* Trading Post: Items purchased from the trading post (retail only)
* Questing: Quest rewards you have received (including reputation gains)
* Looting: Drops (gold, items and currency) from monsters and chests
* Mail: Gold received from and sent to other players
* Trades: Items and gold traded with other players

## Options for tracking
Different categories of items can be ignored by Journalator's tracking system if you're not interested in them. Turn the category off in the options under Journalator -> Monitors

## Comments are on Discord
Visit our discord at  [https://discord.gg/xgz75Pp](https://discord.gg/xgz75Pp) (look for Journalator -> #general-jnr)
