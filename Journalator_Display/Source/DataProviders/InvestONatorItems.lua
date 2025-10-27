local LAYOUT = {
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = AUCTIONATOR_L_NAME,
    headerParameters = { "itemName" },
    cellTemplate = "AuctionatorStringCellTemplate",
    cellParameters = { "itemName" },
    width = 260,
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = JOURNALATOR_L_TARGET_AMOUNT,
    headerParameters = { "target" },
    cellTemplate = "AuctionatorPriceCellTemplate",
    cellParameters = { "target" },
    width = 140,
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = JOURNALATOR_L_TOTAL,
    headerParameters = { "spent" },
    cellTemplate = "AuctionatorPriceCellTemplate",
    cellParameters = { "spent" },
    width = 140,
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = JOURNALATOR_L_REMAINING_BUDGET or "Remaining",
    headerParameters = { "remaining" },
    cellTemplate = "AuctionatorPriceCellTemplate",
    cellParameters = { "remaining" },
    width = 140,
  },
}

JournalatorInvestONatorItemsDataProviderMixin = CreateFromMixins(JournalatorDisplayDataProviderMixin)

function JournalatorInvestONatorItemsDataProviderMixin:OnLoad()
  JournalatorDisplayDataProviderMixin.OnLoad(self)
  self.portfolioId = nil
  self.results = {}
end

function JournalatorInvestONatorItemsDataProviderMixin:SetPortfolioId(pid)
  self.portfolioId = pid
  self:SetDirty()
end

function JournalatorInvestONatorItemsDataProviderMixin:GetTableLayout()
  return LAYOUT
end

function JournalatorInvestONatorItemsDataProviderMixin:Refresh()
  self.onPreserveScroll()
  self:Reset()

  local pid = self.portfolioId
  local results = {}
  if pid ~= nil then
    local portfolio = Journalator.InvestONator.GetPortfolio(pid)
    if portfolio and type(portfolio.items) == "table" then
      for itemId, item in pairs(portfolio.items) do
        table.insert(results, {
          itemName = item.name,
          target = item.targetAmount or 0,
          spent = item.purchasedAmount or 0,
          remaining = item.remainingAmount or 0,
          index = itemId,
          value = (item.purchasedAmount or 0),
          selected = self:IsSelected(itemId),
        })
      end
    end
  end

  table.sort(results, function(a, b)
    return (a.itemName or "") < (b.itemName or "")
  end)

  if #results == 0 then
    table.insert(results, {
      itemName = "No items in this portfolio",
      target = 0,
      spent = 0,
      remaining = 0,
      index = 0,
      selected = false,
    })
  end

  self:AppendEntries(results, true)
end

local COMPARATORS = {
  itemName = Auctionator.Utilities.StringComparator,
  target = Auctionator.Utilities.NumberComparator,
  spent = Auctionator.Utilities.NumberComparator,
  remaining = Auctionator.Utilities.NumberComparator,
}

function JournalatorInvestONatorItemsDataProviderMixin:Sort(fieldName, sortDirection)
  local comparator = COMPARATORS[fieldName](sortDirection, fieldName)
  table.sort(self.results, function(left, right)
    return comparator(left, right)
  end)
  self:SetDirty()
end

-- Portfolio items are configuration; don’t filter them by global filters
function JournalatorInvestONatorItemsDataProviderMixin:Filter(_)
  return true
end


