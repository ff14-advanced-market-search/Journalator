Journalator.InvestONator = {}

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

function Journalator.InvestONator.Initialize()
  if JOURNALATOR_INVEST_O_NATOR_DATA == nil then
    JOURNALATOR_INVEST_O_NATOR_DATA = {
      portfolios = {},
      nextPortfolioId = 1
    }
  end
end

function Journalator.InvestONator.CreatePortfolio(name, totalInvestment)
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

function Journalator.InvestONator.AddItemToPortfolio(portfolioId, itemId, itemName, targetAmount)
  if not JOURNALATOR_INVEST_O_NATOR_DATA.portfolios[portfolioId] then
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

function Journalator.InvestONator.GetPortfolio(portfolioId)
  return JOURNALATOR_INVEST_O_NATOR_DATA.portfolios[portfolioId]
end

function Journalator.InvestONator.GetAllPortfolios()
  return JOURNALATOR_INVEST_O_NATOR_DATA.portfolios
end

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

function Journalator.InvestONator.DeletePortfolio(portfolioId)
  if JOURNALATOR_INVEST_O_NATOR_DATA.portfolios[portfolioId] then
    JOURNALATOR_INVEST_O_NATOR_DATA.portfolios[portfolioId] = nil
    return true
  end
  return false
end

function Journalator.InvestONator.DeleteItemFromPortfolio(portfolioId, itemId)
  if JOURNALATOR_INVEST_O_NATOR_DATA.portfolios[portfolioId] and 
     JOURNALATOR_INVEST_O_NATOR_DATA.portfolios[portfolioId].items[itemId] then
    JOURNALATOR_INVEST_O_NATOR_DATA.portfolios[portfolioId].items[itemId] = nil
    return true
  end
  return false
end

-- Helper function to format gold amounts
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

-- Helper function to parse gold input (supports formats like "100g", "10000s", "1000000c")
function Journalator.InvestONator.ParseGoldInput(input)
  if not input or input == "" then
    return 0
  end
  
  local amount = 0
  local gold, silver, copper = input:match("(%d*)g%s*(%d*)s%s*(%d*)c")
  
  if gold then
    amount = amount + (tonumber(gold) or 0) * 10000
  end
  if silver then
    amount = amount + (tonumber(silver) or 0) * 100
  end
  if copper then
    amount = amount + (tonumber(copper) or 0)
  end
  
  -- If no match, try to parse as a single number (assume copper)
  if amount == 0 then
    amount = tonumber(input) or 0
  end
  
  return amount
end