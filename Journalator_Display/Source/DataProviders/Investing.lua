local INVESTING_DATA_PROVIDER_LAYOUT = {
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = JOURNALATOR_L_GROUP,
    headerParameters = { "groupName" },
    cellTemplate = "AuctionatorStringCellTemplate",
    cellParameters = { "groupName" },
    width = 200,
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = JOURNALATOR_L_PER_ITEM_BUDGET,
    headerParameters = { "perItemBudget" },
    cellTemplate = "JournalatorPriceCellTemplate",
    cellParameters = { "perItemBudget" },
    width = 160,
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = JOURNALATOR_L_SPENT,
    headerParameters = { "spent" },
    cellTemplate = "JournalatorPriceCellTemplate",
    cellParameters = { "spent" },
    width = 160,
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = JOURNALATOR_L_REMAINING,
    headerParameters = { "remaining" },
    cellTemplate = "JournalatorPriceCellTemplate",
    cellParameters = { "remaining" },
    width = 160,
  },
}

JournalatorInvestingDataProviderMixin = CreateFromMixins(JournalatorDisplayDataProviderMixin)

local function matchesGroupItem(itemName, itemLink, group)
  if not group or not group.items then return false end
  if itemLink then
    local itemID = tonumber((itemLink:match("item:(%d+)")))
    if itemID and group.items["id:" .. itemID] then return true end
  end
  if itemName then
    local nameKey = "name:" .. string.lower(itemName)
    if group.items[nameKey] then return true end
  end
  return false
end

function JournalatorInvestingDataProviderMixin:Refresh()
  self.onPreserveScroll()
  self:Reset()

  local results = {}
  local groups = Journalator.Investing and Journalator.Investing.GetConfig() or {}

  -- Precompute spent per group from Invoices (purchases only)
  local rangeTime = self:GetTimeForRange()
  local spentByGroup = {}

  for _, entry in ipairs(Journalator.Archiving.GetRange(rangeTime, "Invoices")) do
    if entry.invoiceType == "buyer" then
      local filterItem = {
        itemName = entry.itemName,
        time = entry.time,
        source = entry.source,
        playerCheck = entry.playerName,
        playerName = entry.playerName,
      }
      if self:Filter(filterItem) then
        for groupName, group in pairs(groups) do
          if matchesGroupItem(entry.itemName, entry.itemLink, group) then
            local moneyOut = entry.value or 0
            spentByGroup[groupName] = (spentByGroup[groupName] or 0) + moneyOut
          end
        end
      end
    end
  end

  for groupName, group in pairs(groups) do
    local perItemBudget = group.perItemBudget or 0
    local spent = spentByGroup[groupName] or 0
    local remaining = perItemBudget - spent
    table.insert(results, {
      groupName = groupName,
      perItemBudget = perItemBudget,
      spent = spent,
      remaining = remaining,
      index = groupName,
      value = remaining,
      searchTerm = groupName,
    })
  end

  -- Stable ordering by group name
  table.sort(results, function(a, b) return a.groupName < b.groupName end)

  self:AppendEntries(results, true)
end

function JournalatorInvestingDataProviderMixin:GetTableLayout()
  return INVESTING_DATA_PROVIDER_LAYOUT
end

local COMPARATORS = {
  groupName = Auctionator.Utilities.StringComparator,
  perItemBudget = Auctionator.Utilities.NumberComparator,
  spent = Auctionator.Utilities.NumberComparator,
  remaining = Auctionator.Utilities.NumberComparator,
}

function JournalatorInvestingDataProviderMixin:Sort(fieldName, sortDirection)
  local comparator = COMPARATORS[fieldName](sortDirection, fieldName)
  table.sort(self.results, function(left, right)
    return comparator(left, right)
  end)
  self:SetDirty()
end

Journalator.Config.Create("COLUMNS_INVESTING", "columns_investing", {})

function JournalatorInvestingDataProviderMixin:GetColumnHideStates()
  return Journalator.Config.Get(Journalator.Config.Options.COLUMNS_INVESTING)
end
