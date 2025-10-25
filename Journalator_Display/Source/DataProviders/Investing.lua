local INVESTING_DATA_PROVIDER_LAYOUT = {
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = AUCTIONATOR_L_NAME,
    headerParameters = { "itemName" },
    cellTemplate = "AuctionatorStringCellTemplate",
    cellParameters = { "itemNamePretty" },
    width = 300,
  },
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

local function getItemIDFromLink(itemLink)
  return tonumber((itemLink or ""):match("item:(%d+)"))
end

function JournalatorInvestingDataProviderMixin:Refresh()
  self.onPreserveScroll()
  self:Reset()

  local results = {}
  local groups = Journalator.Investing and Journalator.Investing.GetConfig() or {}

  -- Precompute spent per item within each group from Invoices (purchases only)
  local rangeTime = self:GetTimeForRange()
  local spentByGroupItem = {}

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
        -- Ensure we have a usable link for ID matching if possible
        local link = entry.itemLink or Journalator.GetPostedItemLink(entry.itemName, math.floor(entry.value / math.max(1, entry.count or 1)), 0, entry.time, rangeTime)
        local itemID = getItemIDFromLink(link)
        local lowerName = entry.itemName and string.lower(entry.itemName) or nil

        for groupName, group in pairs(groups) do
          if group and group.items then
            local matchedKey
            if itemID and group.items["id:" .. itemID] then
              matchedKey = "id:" .. itemID
            elseif lowerName and group.items["name:" .. lowerName] then
              matchedKey = "name:" .. lowerName
            end
            if matchedKey then
              spentByGroupItem[groupName] = spentByGroupItem[groupName] or {}
              local key = matchedKey
              spentByGroupItem[groupName][key] = (spentByGroupItem[groupName][key] or 0) + (entry.value or 0)
            end
          end
        end
      end
    end
  end

  -- Build rows for every item in groups (including not yet purchased)
  for groupName, group in pairs(groups) do
    local perItemBudget = group.perItemBudget or 0
    for key, _ in pairs(group.items or {}) do
      local spent = (spentByGroupItem[groupName] and spentByGroupItem[groupName][key]) or 0
      local itemName = nil
      local itemLink = nil
      if key:sub(1, 3) == "id:" then
        local id = tonumber(key:sub(4))
        if id then
          itemLink = "item:" .. id
          itemName = (C_Item.GetItemInfo(itemLink)) or ("Item ID " .. tostring(id))
        end
      elseif key:sub(1, 5) == "name:" then
        itemName = key:sub(6)
      end
      itemName = itemName or "Unknown"
      local remaining = perItemBudget - spent

      local pretty = itemName
      if itemLink then
        pretty = Journalator.ApplyQualityColor(Journalator.Utilities.AddQualityIconToItemName(itemName, itemLink), itemLink)
      end

      table.insert(results, {
        groupName = groupName,
        itemName = itemName,
        itemNamePretty = pretty,
        itemLink = itemLink,
        perItemBudget = perItemBudget,
        spent = spent,
        remaining = remaining,
        index = groupName .. ":" .. key,
        value = remaining,
        searchTerm = itemName,
      })
    end
  end

  -- Stable ordering by group name
  table.sort(results, function(a, b)
    if a.groupName == b.groupName then
      return a.itemName < b.itemName
    else
      return a.groupName < b.groupName
    end
  end)

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
