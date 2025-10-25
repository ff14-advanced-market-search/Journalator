JournalatorMonitorInvestONatorMixin = CreateFromMixins(JournalatorDisplayMixin)

function JournalatorMonitorInvestONatorMixin:OnLoad()
  JournalatorDisplayMixin.OnLoad(self)
  
  self:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULT_UPDATED")
  self:RegisterEvent("AUCTION_HOUSE_CLOSED")
  self:RegisterEvent("ITEM_PURCHASED")
end

function JournalatorMonitorInvestONatorMixin:OnEvent(eventName, ...)
  if eventName == "ITEM_PURCHASED" then
    self:OnItemPurchased(...)
  end
end

function JournalatorMonitorInvestONatorMixin:OnItemPurchased(itemID, itemLink, quantity, price)
  -- Check if this item is in any investment portfolio
  local portfolios = Journalator.InvestONator.GetAllPortfolios()
  
  for portfolioId, portfolio in pairs(portfolios) do
    if portfolio.items[itemID] then
      local item = portfolio.items[itemID]
      local totalAmount = price * quantity
      
      -- Record the purchase
      Journalator.InvestONator.RecordPurchase(portfolioId, itemID, totalAmount, price, quantity)
      
      -- Show notification
      local remaining = Journalator.InvestONator.FormatGold(item.remainingAmount)
      local itemName = GetItemInfo(itemID) or item.name or "Unknown Item"
      
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