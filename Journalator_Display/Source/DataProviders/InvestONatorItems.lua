local LAYOUT = {
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = AUCTIONATOR_L_NAME,
    headerParameters = { "itemName" },
    cellTemplate = "AuctionatorStringCellTemplate",
    cellParameters = { "itemName" },
    width = 250,
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

local function FindRootWithFilters(frame)
  local current = frame
  while current do
    if current.Filters ~= nil then
      return current
    end
    current = current.GetParent and current:GetParent() or nil
  end
  return nil
end

function JournalatorInvestONatorItemsDataProviderMixin:OnLoad()
  JournalatorDisplayDataProviderMixin.OnLoad(self)
  self.portfolioId = nil
  self.results = {}
end

function JournalatorInvestONatorItemsDataProviderMixin:SetPortfolioId(pid)
  self.portfolioId = pid
  self:SetDirty()
end

function JournalatorInvestONatorItemsDataProviderMixin:Refresh()
  self.onPreserveScroll()
  self:Reset()

  local pid = self.portfolioId
  if not pid then
    self:AppendEntries({}, true)
    return
  end

  local portfolio = Journalator.InvestONator.GetPortfolio(pid)
  if not portfolio then
    self:AppendEntries({}, true)
    return
  end

  local results = {}
  -- Defensive: ensure items is a table
  local items = portfolio.items or {}
  local any = false
  for itemId, item in pairs(items) do
    any = true
    table.insert(results, {
      itemName = item.name,
      target = item.targetAmount,
      spent = item.purchasedAmount,
      remaining = item.remainingAmount,
      index = itemId,
      selected = (self.IsSelected and self:IsSelected(itemId)) or false,
    })
  end

  if not any then
    -- Show a placeholder so we can verify the table renders rows
    table.insert(results, {
      itemName = "No items in this portfolio",
      target = 0,
      spent = 0,
      remaining = 0,
      index = 0,
      selected = false,
    })
  end

  table.sort(results, function(a, b) return a.itemName < b.itemName end)

  self:AppendEntries(results, true)
end

function JournalatorInvestONatorItemsDataProviderMixin:GetTableLayout()
  return LAYOUT
end

local COMPARATORS = {
  itemName = Auctionator.Utilities.StringComparator,
  target = Auctionator.Utilities.NumberComparator,
  spent = Auctionator.Utilities.NumberComparator,
  remaining = Auctionator.Utilities.NumberComparator,
}

function JournalatorInvestONatorItemsDataProviderMixin:Sort(fieldName, sortDirection)
  local comparator = COMPARATORS[fieldName](sortDirection, fieldName)
  table.sort(self.results or {}, function(left, right)
    return comparator(left, right)
  end)
  self:SetDirty()
end

-- Override to be robust to where this provider is attached in the view tree
function JournalatorInvestONatorItemsDataProviderMixin:Filter(item)
  -- Invest-o-nator items are portfolio configuration entries, not archived log
  -- rows; they aren't affected by date/character/realm filters. Always show.
  return true
end

function JournalatorInvestONatorItemsDataProviderMixin:GetTimeForRange()
  local root = FindRootWithFilters(self)
  if root and root.Filters then
    return root.Filters:GetTimeForRange()
  end
  return time() - 60 * 60 * 24 * 30
end


