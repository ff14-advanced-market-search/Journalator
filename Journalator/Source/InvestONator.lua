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

---Recalculate purchased totals from Journalator logs
---@param fromTime number|nil Minimum timestamp to include (defaults to 0 for all time)
function Journalator.InvestONator.RecalculateAllPurchases(fromTime)
  fromTime = fromTime or 0

  -- Build a lookup of total spent per itemID and by item name (fallback)
  local spentByItemId = {}
  local spentByNameLower = {}
  -- Also build detailed purchase histories for stats (unit price + quantity)
  local purchasesByItemId = {}
  local purchasesByNameLower = {}
  local invoices = Journalator.Archiving.GetRange(fromTime, "Invoices")
  for _, inv in ipairs(invoices) do
    if inv.time >= fromTime and inv.invoiceType ~= "seller" then
      local itemId = nil
      local itemLink = inv.itemLink
      if not itemLink and Journalator.GetPostedItemLink then
        local unitPrice = inv.count and inv.count > 0 and math.floor((inv.value or 0) / inv.count) or nil
        local unitDeposit = inv.count and inv.count > 0 and math.floor((inv.deposit or 0) / inv.count) or nil
        itemLink = Journalator.GetPostedItemLink(inv.itemName, unitPrice, unitDeposit, inv.time, fromTime)
      end
      if itemLink then
        itemId = tonumber(string.match(itemLink or "", "|Hitem:(%d+):"))
      end
      local amount = inv.value or 0
      local count = (inv.count and inv.count > 0) and inv.count or 1
      local unitPrice = math.floor(amount / count)

      if itemId then
        spentByItemId[itemId] = (spentByItemId[itemId] or 0) + amount
        purchasesByItemId[itemId] = purchasesByItemId[itemId] or {}
        table.insert(purchasesByItemId[itemId], {
          amount = amount,
          time = inv.time or time(),
          price = unitPrice,
          quantity = count,
        })
      end
      if inv.itemName then
        local key = string.lower(tostring(inv.itemName))
        spentByNameLower[key] = (spentByNameLower[key] or 0) + amount
        purchasesByNameLower[key] = purchasesByNameLower[key] or {}
        table.insert(purchasesByNameLower[key], {
          amount = amount,
          time = inv.time or time(),
          price = unitPrice,
          quantity = count,
        })
      end
    end
  end

  -- Apply totals to any portfolio items that reference the same itemID
  for _, portfolio in pairs(JOURNALATOR_INVEST_O_NATOR_DATA.portfolios or {}) do
    for itemId, item in pairs(portfolio.items or {}) do
      local spent = 0
      if type(itemId) == "number" and itemId > 0 then
        spent = spentByItemId[itemId] or 0
      end
      if (spent == 0 or spent == nil) and item.name then
        spent = spentByNameLower[string.lower(item.name)] or 0
      end
      if spent and spent > 0 then
        item.purchasedAmount = spent
        item.remainingAmount = math.max(0, (item.targetAmount or 0) - item.purchasedAmount)
        -- Attach purchase history for stats
        local history = nil
        if type(itemId) == "number" and itemId > 0 then
          history = purchasesByItemId[itemId]
        end
        if (history == nil or #history == 0) and item.name then
          history = purchasesByNameLower[string.lower(item.name)]
        end
        item.purchaseHistory = history or {}
        if #item.purchaseHistory > 0 then
          item.lastPurchaseTime = item.purchaseHistory[#item.purchaseHistory].time
        end
      else
        Journalator.Debug.Message("InvestONator: No spend found for", tostring(itemId), tostring(item.name))
      end
    end
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
    -- Synthetic IDs are used only when callers don't provide a real item ID
    -- (e.g. sentinel 0). Start negative to avoid collisions with real IDs.
    nextSyntheticItemId = -1,
    createdTime = time()
  }
  
  return portfolioId
end

---Rename a portfolio
---@param portfolioId number
---@param newName string
---@return boolean
function Journalator.InvestONator.RenamePortfolio(portfolioId, newName)
  local portfolio = JOURNALATOR_INVEST_O_NATOR_DATA.portfolios[portfolioId]
  if not portfolio or not newName or newName == "" then
    return false
  end
  portfolio.name = newName
  return true
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
  
  local portfolio = JOURNALATOR_INVEST_O_NATOR_DATA.portfolios[portfolioId]
  portfolio.items = portfolio.items or {}

  -- Determine final item ID:
  -- - If caller provides a non-positive/sentinel value, generate a unique synthetic ID.
  -- - If caller provides an existing positive ID that already exists, do not overwrite.
  local finalItemId = tonumber(itemId)
  if not finalItemId or finalItemId <= 0 then
    local candidate = portfolio.nextSyntheticItemId or -1
    -- Ensure uniqueness by stepping further negative if needed
    while portfolio.items[candidate] ~= nil do
      candidate = candidate - 1
    end
    finalItemId = candidate
    portfolio.nextSyntheticItemId = candidate - 1
  else
    if portfolio.items[finalItemId] ~= nil then
      Journalator.Debug.Message("InvestONator: Item ID " .. tostring(finalItemId) .. " already exists in portfolio " .. tostring(portfolioId))
      return false
    end
  end

  portfolio.items[finalItemId] = {
    name = itemName,
    targetAmount = targetAmount,
    purchasedAmount = 0,
    remainingAmount = targetAmount,
    lastPurchaseTime = nil,
    purchaseHistory = {}
  }
  
  return true
end

---Update a portfolio item's target amount
---@param portfolioId number
---@param itemId number
---@param newTargetAmount number -- copper
---@return boolean
function Journalator.InvestONator.UpdateItemTargetAmount(portfolioId, itemId, newTargetAmount)
  local portfolio = JOURNALATOR_INVEST_O_NATOR_DATA.portfolios[portfolioId]
  if not portfolio or not portfolio.items[itemId] then
    return false
  end
  if not newTargetAmount or newTargetAmount <= 0 then
    return false
  end
  local item = portfolio.items[itemId]
  item.targetAmount = newTargetAmount
  item.remainingAmount = math.max(0, item.targetAmount - (item.purchasedAmount or 0))
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
    Journalator.Debug.Message("InvestONator: Portfolio " .. tostring(portfolioId) .. " not found")
    return false
  end
  
  local portfolio = JOURNALATOR_INVEST_O_NATOR_DATA.portfolios[portfolioId]
  if not portfolio.items[itemId] then
    Journalator.Debug.Message("InvestONator: Item " .. tostring(itemId) .. " not found in portfolio " .. tostring(portfolioId))
    return false
  end
  
  -- Validate input parameters
  if not amount or not price or not quantity or amount <= 0 or price <= 0 or quantity <= 0 then
    Journalator.Debug.Message("InvestONator: Invalid purchase parameters")
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
  
  -- Update amounts with validation
  local newPurchasedAmount = item.purchasedAmount + amount
  if newPurchasedAmount > item.targetAmount then
    Journalator.Debug.Message("InvestONator: Purchase exceeds target amount for item " .. tostring(itemId))
  end
  
  item.purchasedAmount = newPurchasedAmount
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

---Update total investment for a portfolio
---@param portfolioId number
---@param newTotal number -- copper
---@return boolean
function Journalator.InvestONator.UpdatePortfolioTotal(portfolioId, newTotal)
  local portfolio = JOURNALATOR_INVEST_O_NATOR_DATA.portfolios[portfolioId]
  if not portfolio or not newTotal or newTotal <= 0 then
    return false
  end
  portfolio.totalInvestment = newTotal
  return true
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

  -- Trim
  input = input:match("^%s*(.-)%s*$")

  -- Accept simple numbers and treat them as GOLD (not copper)
  local plainNumber = tonumber(input)
  if plainNumber then
    return plainNumber * 10000
  end

  -- Tokenize segments like "100g", "50s", "25c" in any order; case-insensitive; spaces optional
  local gold = 0
  local silver = 0
  local copper = 0

  for value, suffix in string.gmatch(input, "(%d+)%s*([gGsScC]?)") do
    local n = tonumber(value) or 0
    if suffix == "g" or suffix == "G" or suffix == "" then
      -- Default unit is gold if no suffix provided inside a composite string
      gold = gold + n
    elseif suffix == "s" or suffix == "S" then
      silver = silver + n
    elseif suffix == "c" or suffix == "C" then
      copper = copper + n
    end
  end

  -- Normalize and compute total copper
  local total = gold * 10000 + silver * 100 + copper
  return total
end