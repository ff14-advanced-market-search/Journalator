---@class Journalator.InvestONator
---@field portfolios table<number, PortfolioData>
---@field nextPortfolioId number
Journalator.InvestONator = {}

---@class PortfolioData
---@field name string
---@field totalInvestment number
---@field items table<number, ItemData>
---@field createdTime number

---@class ItemData
---@field name string
---@field targetAmount number
---@field purchasedAmount number
---@field remainingAmount number
---@field lastPurchaseTime number|nil
---@field purchaseHistory PurchaseRecord[]

---@class PurchaseRecord
---@field amount number
---@field time number
---@field price number
---@field quantity number

-- Investment Portfolio Data Structure
-- JOURNALATOR_INVEST_O_NATOR_DATA = {
--   portfolios = {
--     [portfolioId] = {
--       name = "Portfolio Name",
--       totalInvestment = 3000000, -- 3 million gold
--       items = {
--         [itemId] = {
--           name = "Item Name",
--           targetAmount = 10000, -- 10k gold worth
--           purchasedAmount = 5000, -- 5k gold already spent
--           remainingAmount = 5000, -- 5k gold left to spend
--           lastPurchaseTime = timestamp,
--           purchaseHistory = {
--             {amount = 5000, time = timestamp, price = 50, quantity = 100}
--           }
--         }
--       }
--     }
--   }
-- }

---Initialize the Invest-O-Nator data structure
-- Initializes the global JOURNALATOR_INVEST_O_NATOR_DATA table if it does not exist.
-- When created, the table contains:
--   portfolios: table mapping portfolio IDs to portfolio data
--   nextPortfolioId: number starting at 1
function Journalator.InvestONator.Initialize()
  if JOURNALATOR_INVEST_O_NATOR_DATA == nil then
    JOURNALATOR_INVEST_O_NATOR_DATA = {
      portfolios = {},
      nextPortfolioId = 1
    }
  end
end

---Create a new investment portfolio
---@param name string The name of the portfolio
---@param totalInvestment number The total investment budget in copper
-- Creates a new investment portfolio with the given name and total investment.
-- @param name string The portfolio's display name (must be non-empty).
-- @param totalInvestment number The portfolio's total investment amount in copper (must be greater than 0).
-- @return number|nil The numeric ID of the newly created portfolio, or `nil` if the input was invalid.
function Journalator.InvestONator.CreatePortfolio(name, totalInvestment)
  if not name or name == "" then
    Journalator.Debug.Message("InvestONator: Portfolio name cannot be empty")
    return nil
  end
  
  if not totalInvestment or totalInvestment <= 0 then
    Journalator.Debug.Message("InvestONator: Total investment must be greater than 0")
    return nil
  end
  
  local portfolioId = JOURNALATOR_INVEST_O_NATOR_DATA.nextPortfolioId
  JOURNALATOR_INVEST_O_NATOR_DATA.nextPortfolioId = JOURNALATOR_INVEST_O_NATOR_DATA.nextPortfolioId + 1
  
  JOURNALATOR_INVEST_O_NATOR_DATA.portfolios[portfolioId] = {
    name = name,
    totalInvestment = totalInvestment,
    items = {},
    createdTime = time()
  }
  
  return portfolioId
end

---Add an item to a portfolio with a target investment amount
---@param portfolioId number The ID of the portfolio
---@param itemId number The item ID
---@param itemName string The name of the item
---@param targetAmount number The target investment amount in copper
-- Adds a new item to the specified portfolio with initial tracking fields.
-- @param portfolioId number The ID of the portfolio to add the item to.
-- @param itemId number The ID to assign to the new item within the portfolio.
-- @param itemName string The item's display name; must be non-empty.
-- @param targetAmount number The target amount for the item (must be greater than 0).
-- @return boolean `true` if the item was added successfully, `false` otherwise.
function Journalator.InvestONator.AddItemToPortfolio(portfolioId, itemId, itemName, targetAmount)
  if not JOURNALATOR_INVEST_O_NATOR_DATA.portfolios[portfolioId] then
    Journalator.Debug.Message("InvestONator: Portfolio " .. tostring(portfolioId) .. " not found")
    return false
  end
  
  if not itemName or itemName == "" then
    Journalator.Debug.Message("InvestONator: Item name cannot be empty")
    return false
  end
  
  if not targetAmount or targetAmount <= 0 then
    Journalator.Debug.Message("InvestONator: Target amount must be greater than 0")
    return false
  end
  
  JOURNALATOR_INVEST_O_NATOR_DATA.portfolios[portfolioId].items[itemId] = {
    name = itemName,
    targetAmount = targetAmount,
    purchasedAmount = 0,
    remainingAmount = targetAmount,
    lastPurchaseTime = nil,
    purchaseHistory = {}
  }
  
  return true
end

---Record a purchase for an item in a portfolio
---@param portfolioId number The ID of the portfolio
---@param itemId number The item ID
---@param amount number The total amount spent in copper
---@param price number The price per unit in copper
---@param quantity number The quantity purchased
-- Records a purchase for an item and updates the item's purchase history, totals, remaining amount, and last purchase time.
-- @param portfolioId number ID of the portfolio containing the item.
-- @param itemId number ID of the item within the portfolio.
-- @param amount number Amount purchased (in copper).
-- @param price number Price paid for the purchase (per unit or total as used by caller).
-- @param quantity number Quantity purchased.
-- @return `true` if the purchase was recorded successfully, `false` otherwise.
function Journalator.InvestONator.RecordPurchase(portfolioId, itemId, amount, price, quantity)
  if not JOURNALATOR_INVEST_O_NATOR_DATA.portfolios[portfolioId] then
    return false
  end
  
  local portfolio = JOURNALATOR_INVEST_O_NATOR_DATA.portfolios[portfolioId]
  if not portfolio.items[itemId] then
    return false
  end
  
  local item = portfolio.items[itemId]
  local purchaseTime = time()
  
  -- Record the purchase
  table.insert(item.purchaseHistory, {
    amount = amount,
    time = purchaseTime,
    price = price,
    quantity = quantity
  })
  
  -- Update amounts
  item.purchasedAmount = item.purchasedAmount + amount
  item.remainingAmount = math.max(0, item.targetAmount - item.purchasedAmount)
  item.lastPurchaseTime = purchaseTime
  
  return true
end

---Get a specific portfolio by ID
---@param portfolioId number The ID of the portfolio
-- Retrieves the portfolio data for the given portfolio ID.
-- @param portfolioId number The ID of the portfolio to retrieve.
-- @return PortfolioData|nil The portfolio data for the specified ID, or `nil` if no portfolio exists with that ID.
function Journalator.InvestONator.GetPortfolio(portfolioId)
  return JOURNALATOR_INVEST_O_NATOR_DATA.portfolios[portfolioId]
end

---Get all portfolios
-- Retrieves all stored portfolios indexed by portfolio ID.
-- @return table<number, PortfolioData> A table mapping portfolio ID to its PortfolioData.
function Journalator.InvestONator.GetAllPortfolios()
  return JOURNALATOR_INVEST_O_NATOR_DATA.portfolios
end

---Get progress information for a portfolio
---@param portfolioId number The ID of the portfolio
-- Computes progress metrics for the specified portfolio.
-- @param portfolioId The numeric ID of the portfolio to evaluate.
-- @return A table with the fields:
--   totalSpent (number) — sum of purchased amounts for all items;
--   totalTarget (number) — sum of target amounts for all items;
--   remainingBudget (number) — portfolio totalInvestment minus totalSpent;
--   completedItems (number) — count of items with remainingAmount <= 0;
--   totalItems (number) — total number of items in the portfolio;
--   completionPercentage (number) — (totalSpent / totalTarget) * 100, or 0 when totalTarget is 0.
--   Returns nil if the portfolio does not exist.
function Journalator.InvestONator.GetPortfolioProgress(portfolioId)
  if not JOURNALATOR_INVEST_O_NATOR_DATA.portfolios[portfolioId] then
    return nil
  end
  
  local portfolio = JOURNALATOR_INVEST_O_NATOR_DATA.portfolios[portfolioId]
  local totalSpent = 0
  local totalTarget = 0
  local completedItems = 0
  local totalItems = 0
  
  for itemId, item in pairs(portfolio.items) do
    totalSpent = totalSpent + item.purchasedAmount
    totalTarget = totalTarget + item.targetAmount
    totalItems = totalItems + 1
    if item.remainingAmount <= 0 then
      completedItems = completedItems + 1
    end
  end
  
  return {
    totalSpent = totalSpent,
    totalTarget = totalTarget,
    remainingBudget = portfolio.totalInvestment - totalSpent,
    completedItems = completedItems,
    totalItems = totalItems,
    completionPercentage = totalTarget > 0 and (totalSpent / totalTarget) * 100 or 0
  }
end

---Delete a portfolio and all its items
---@param portfolioId number The ID of the portfolio to delete
-- Deletes the portfolio with the given ID from stored data.
-- @param portfolioId number The numeric ID of the portfolio to remove.
-- @return boolean `true` if the portfolio existed and was deleted, `false` otherwise.
function Journalator.InvestONator.DeletePortfolio(portfolioId)
  if JOURNALATOR_INVEST_O_NATOR_DATA.portfolios[portfolioId] then
    JOURNALATOR_INVEST_O_NATOR_DATA.portfolios[portfolioId] = nil
    return true
  end
  return false
end

---Delete an item from a portfolio
---@param portfolioId number The ID of the portfolio
---@param itemId number The ID of the item to delete
-- Removes the specified item from a portfolio.
-- @param portfolioId The ID of the portfolio containing the item.
-- @param itemId The ID of the item to remove.
-- @return `true` if the item was deleted, `false` if the portfolio or item was not found.
function Journalator.InvestONator.DeleteItemFromPortfolio(portfolioId, itemId)
  if JOURNALATOR_INVEST_O_NATOR_DATA.portfolios[portfolioId] and 
     JOURNALATOR_INVEST_O_NATOR_DATA.portfolios[portfolioId].items[itemId] then
    JOURNALATOR_INVEST_O_NATOR_DATA.portfolios[portfolioId].items[itemId] = nil
    return true
  end
  return false
end

---Format a copper amount into a readable gold/silver/copper string
---@param amount number The amount in copper
-- Format a copper amount into a human-readable gold/silver/copper string.
-- @param amount The amount in copper (integer).
-- @return The formatted string (e.g., "100g 50s 25c").
function Journalator.InvestONator.FormatGold(amount)
  local gold = math.floor(amount / 10000)
  local silver = math.floor((amount % 10000) / 100)
  local copper = amount % 100
  
  if gold > 0 then
    return string.format("%dg %ds %dc", gold, silver, copper)
  elseif silver > 0 then
    return string.format("%ds %dc", silver, copper)
  else
    return string.format("%dc", copper)
  end
end

---Parse gold input string into copper amount
---Supports formats like "100g", "10000s", "1000000c", or plain numbers
---@param input string|nil The input string to parse
-- Parses a gold/silver/copper input string and returns the total amount in copper.
-- Accepts formats like "100g 50s 25c", "100g50s25c", or a plain number (treated as copper). Nil or invalid input yields 0.
-- @param input string|nil The input string to parse (may be nil).
-- @return number The parsed amount in copper.
function Journalator.InvestONator.ParseGoldInput(input)
  if not input or input == "" then
    return 0
  end
  
  -- Trim whitespace
  input = input:match("^%s*(.-)%s*$")
  
  local amount = 0
  
  -- Try to parse gold/silver/copper format (e.g., "100g 50s 25c" or "100g50s25c")
  local gold, silver, copper = input:match("(%d*)g%s*(%d*)s%s*(%d*)c")
  
  if gold or silver or copper then
    amount = amount + (tonumber(gold) or 0) * 10000
    amount = amount + (tonumber(silver) or 0) * 100
    amount = amount + (tonumber(copper) or 0)
  else
    -- Try to parse as a single number (assume copper)
    local numValue = tonumber(input)
    if numValue then
      amount = numValue
    else
      Journalator.Debug.Message("InvestONator: Invalid gold input format: " .. tostring(input))
      return 0
    end
  end
  
  return amount
end