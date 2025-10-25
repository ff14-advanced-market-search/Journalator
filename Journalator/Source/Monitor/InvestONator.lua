---@class JournalatorMonitorInvestONatorMixin
JournalatorMonitorInvestONatorMixin = CreateFromMixins(JournalatorDisplayMixin)

---Initialize the Invest-O-Nator monitor
---Sets up event handlers for tracking purchases
function JournalatorMonitorInvestONatorMixin:OnLoad()
  JournalatorDisplayMixin.OnLoad(self)
  
  self:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULT_UPDATED")
  self:RegisterEvent("AUCTION_HOUSE_CLOSED")
  self:RegisterEvent("ITEM_PURCHASED")
end

---Handle events for the Invest-O-Nator monitor
---@param eventName string The name of the event
---@param ... any Event arguments
function JournalatorMonitorInvestONatorMixin:OnEvent(eventName, ...)
  if eventName == "ITEM_PURCHASED" then
    self:OnItemPurchased(...)
  end
end

---Handle item purchase events and update portfolio tracking
---@param itemID number The ID of the purchased item
---@param itemLink string The item link
---@param quantity number The quantity purchased
---@param price number The price per unit in copper
function JournalatorMonitorInvestONatorMixin:OnItemPurchased(itemID, itemLink, quantity, price)
  -- Validate input parameters
  if not itemID or not quantity or not price or quantity <= 0 or price <= 0 then
    return
  end
  
  -- Check if this item is in any investment portfolio
  local portfolios = Journalator.InvestONator.GetAllPortfolios()
  
  -- Early exit if no portfolios exist
  if not portfolios or next(portfolios) == nil then
    return
  end
  
  local totalAmount = price * quantity
  local itemName = GetItemInfo(itemID) or "Unknown Item"
  
  for portfolioId, portfolio in pairs(portfolios) do
    if portfolio.items[itemID] then
      local item = portfolio.items[itemID]
      
      -- Record the purchase
      if Journalator.InvestONator.RecordPurchase(portfolioId, itemID, totalAmount, price, quantity) then
        -- Show notification
        local remaining = Journalator.InvestONator.FormatGold(item.remainingAmount)
        
        Journalator.Utilities.Message(string.format(
          "Invest-o-nator: Purchased %dx %s for %s. Remaining budget: %s",
          quantity,
          itemName,
          Journalator.InvestONator.FormatGold(totalAmount),
          remaining
        ))
      end
    end
  end
end