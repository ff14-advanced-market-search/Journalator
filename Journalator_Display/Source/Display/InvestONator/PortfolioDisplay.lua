---@class JournalatorInvestONatorPortfolioDisplayMixin
JournalatorInvestONatorPortfolioDisplayMixin = {}

-- Create a very simple, cross-client dialog frame without relying on Blizzard
-- templates that may not exist on all versions (e.g. DialogBoxFrameTemplate).
local function CreateBasicDialog(parent, width, height)
  local dialog = CreateFrame("Frame", nil, parent)
  dialog:SetSize(width, height)
  dialog:SetPoint("CENTER")
  dialog:SetFrameStrata("DIALOG")
  dialog:Hide()

  local bg = dialog:CreateTexture(nil, "BACKGROUND")
  bg:SetColorTexture(0, 0, 0, 0.85)
  bg:SetAllPoints()

  local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOP", 0, -10)
  -- Expose a Title-like field for callers that expect dialog.Title
  dialog.Title = title

  return dialog
end

-- Attempt to walk up the parent chain to find the root display that owns Filters
local function FindRootWithFilters(frame)
  local current = frame
  while current do
    if current.Filters ~= nil then
      return current
    end
    current = current:GetParent()
  end
  return nil
end

-- Build and cache an index of items (name -> { name, itemID, itemLink })
-- sourced from Journalator logs within the active time range.
function JournalatorInvestONatorPortfolioDisplayMixin:BuildItemSearchIndex()
  local root = FindRootWithFilters(self)
  local fromTime = root and root.Filters and root.Filters:GetTimeForRange() or time() - 60 * 60 * 24 * 90

  -- Avoid rebuilding if the time range hasn't changed
  if self.ItemIndex and self.ItemIndexFromTime == fromTime then
    return
  end

  self.ItemIndex = {}
  self.ItemIndexFromTime = fromTime

  -- Ensure archives up to the selected time are loaded
  Journalator.Archiving.LoadUpTo(fromTime)

  local invoices = Journalator.Archiving.GetRange(fromTime, "Invoices")
  for _, entry in ipairs(invoices) do
    if entry.time >= fromTime and entry.itemName then
      local name = tostring(entry.itemName)
      local lower = string.lower(name)
      if self.ItemIndex[lower] == nil then
        local itemID = nil
        if entry.itemLink then
          itemID = tonumber(string.match(entry.itemLink, "|Hitem:(%d+):"))
        end
        if not itemID and C_Item and C_Item.GetItemInfoInstant then
          local id = C_Item.GetItemInfoInstant(entry.itemLink or name)
          if type(id) == "number" then
            itemID = id
          elseif type(id) == "table" then
            itemID = id and id
          end
        end
        self.ItemIndex[lower] = {
          name = name,
          itemID = itemID,
          itemLink = entry.itemLink,
        }
      end
    end
  end
end

-- Return up to maxResults suggestions matching the provided query (substring, case-insensitive)
function JournalatorInvestONatorPortfolioDisplayMixin:GetItemSuggestions(query, maxResults)
  if not query or query == "" then
    return {}
  end
  self:BuildItemSearchIndex()
  local results = {}
  local needle = string.lower(query)
  for lowerName, entry in pairs(self.ItemIndex or {}) do
    if string.find(lowerName, needle, 1, true) then
      table.insert(results, entry)
      if #results >= (maxResults or 10) then
        break
      end
    end
  end
  table.sort(results, function(a, b) return a.name < b.name end)
  return results
end

-- Delete-confirmation popup for removing a portfolio
if not StaticPopupDialogs["JOURNALATOR_CONFIRM_DELETE_PORTFOLIO"] then
  StaticPopupDialogs["JOURNALATOR_CONFIRM_DELETE_PORTFOLIO"] = {
    text = (JOURNALATOR_L_DELETE_PORTFOLIO or "Delete Portfolio") .. " %s?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data)
      if data and type(data.deleteFunc) == "function" then
        pcall(data.deleteFunc)
      end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
  }
end

---Initialize the portfolio display
-- Initialize the InvestONator portfolio display.
-- Calls the base OnLoad, sets up the portfolio list and the create-portfolio dialog, and refreshes the displayed portfolios.
function JournalatorInvestONatorPortfolioDisplayMixin:OnLoad()
  self:SetupPortfolioList()
  self:SetupRefreshButton()
  self:SetupCreatePortfolioDialog()
  self:RefreshPortfolioList()
end

---Handle the display being shown
---Refreshes the portfolio list
function JournalatorInvestONatorPortfolioDisplayMixin:OnShow()
  -- Re-sync portfolio purchases from invoices using the active time filter
  local root = FindRootWithFilters(self)
  local fromTime = root and root.Filters and root.Filters:GetTimeForRange() or 0
  Journalator.Archiving.LoadUpTo(fromTime)
  Journalator.InvestONator.RecalculateAllPurchases(fromTime)
  -- Navigate AH → Invoices to ensure invoices are fully loaded and consistent
  Auctionator.EventBus
    :RegisterSource(self, "InvestONator_AutoSwitch")
    :Fire(self, Journalator.Events.RequestTabSwitch, { root = "AuctionHouse", child = "Invoices" })
    :UnregisterSource(self)
  self:RefreshPortfolioList()
end

---Set up the scrollable portfolio list
function JournalatorInvestONatorPortfolioDisplayMixin:SetupPortfolioList()
  -- Create scroll frame for portfolio list
  local scrollFrame = CreateFrame("ScrollFrame", nil, self, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 20, -50)
  scrollFrame:SetPoint("BOTTOMRIGHT", -20, 50)
  
  local content = CreateFrame("Frame", nil, scrollFrame)
  content:SetSize(scrollFrame:GetWidth(), 0)
  scrollFrame:SetScrollChild(content)
  
  self.ScrollFrame = scrollFrame
  self.Content = content
  self.PortfolioFramePool = { free = {}, inUse = {} }
end

-- Build dynamic tabs for portfolios
function JournalatorInvestONatorPortfolioDisplayMixin:RebuildTabs()
  self.Tabs = self.Tabs or {}
  for _, b in ipairs(self.Tabs) do b:Hide() end
  local portfolios = Journalator.InvestONator.GetAllPortfolios()
  local last
  local index = 1
  for portfolioId, portfolio in pairs(portfolios) do
    local tab = self.Tabs[index]
    if not tab then
      tab = CreateFrame("Button", nil, self, "JournalatorTabButtonTemplate")
      self.Tabs[index] = tab
    end
    tab:Show()
    tab.displayMode = tostring(portfolioId)
    tab.title = portfolio.name
    tab:SetText(portfolio.name)
    tab:SetScript("OnClick", function()
      self:SetDisplayMode(tab.displayMode)
    end)
    tab:ClearAllPoints()
    if not last then
      tab:SetPoint("BOTTOMLEFT", 20, 8)
    else
      tab:SetPoint("LEFT", last, "RIGHT", -15, 0)
    end
    last = tab
    index = index + 1
  end
  PanelTemplates_SetNumTabs(self, #self.Tabs)
end

-- Handle clicking a portfolio tab: displayMode is the portfolioId as string
function JournalatorInvestONatorPortfolioDisplayMixin:SetDisplayMode(displayMode)
  local pid = tonumber(displayMode)
  if pid then
    self.ActivePortfolioId = pid
  end
  -- Highlight the active tab
  if self.Tabs then
    for index, tab in ipairs(self.Tabs) do
      if tab.displayMode == displayMode then
        PanelTemplates_SetTab(self, index)
        break
      end
    end
  end
  self:RefreshPortfolioList()
end

-- Create a manual Refresh button to (re)load archives and recalculate purchases
function JournalatorInvestONatorPortfolioDisplayMixin:SetupRefreshButton()
  if self.RefreshButton then
    return
  end
  local btn = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
  btn:SetSize(90, 22)
  btn:SetPoint("TOPRIGHT", -30, -20)
  btn:SetText("Refresh")
  btn:SetScript("OnClick", function()
    self:ForceRefresh()
  end)
  self.RefreshButton = btn
end

-- Force a reload of archives up to the active time range and update UI
function JournalatorInvestONatorPortfolioDisplayMixin:ForceRefresh()
  local root = FindRootWithFilters(self)
  local fromTime = root and root.Filters and root.Filters:GetTimeForRange() or 0
  Journalator.Utilities.Message("Invest-o-nator: refreshing from time " .. tostring(fromTime))
  Journalator.Archiving.LoadUpTo(fromTime, function()
    Journalator.InvestONator.RecalculateAllPurchases(fromTime)
    self:RefreshPortfolioList()
  end)
end

-- Acquire a reusable portfolio frame from the pool, creating one if necessary
function JournalatorInvestONatorPortfolioDisplayMixin:AcquirePortfolioFrame()
  if not self.PortfolioFramePool then
    self.PortfolioFramePool = { free = {}, inUse = {} }
  end
  local frame = table.remove(self.PortfolioFramePool.free) or CreateFrame("Frame", nil, self.Content)
  frame:SetParent(self.Content)
  -- Clear previous contents and anchors to avoid stacking/leaks
  for _, child in ipairs({ frame:GetChildren() }) do
    child:Hide()
    child:SetParent(nil)
  end
  for _, region in ipairs({ frame:GetRegions() }) do
    region:Hide()
    region:SetParent(nil)
  end
  frame:ClearAllPoints()
  frame:Show()
  table.insert(self.PortfolioFramePool.inUse, frame)
  return frame
end

-- Release all in-use portfolio frames back to the pool
function JournalatorInvestONatorPortfolioDisplayMixin:ReleaseAllPortfolioFrames()
  if not self.PortfolioFramePool then
    return
  end
  for i = 1, #self.PortfolioFramePool.inUse do
    local frame = self.PortfolioFramePool.inUse[i]
    if frame then
      -- Hide, detach and clear contents to prepare for reuse
      frame:Hide()
      frame:ClearAllPoints()
      for _, child in ipairs({ frame:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
      end
      for _, region in ipairs({ frame:GetRegions() }) do
        region:Hide()
        region:SetParent(nil)
      end
      frame:SetParent(nil)
      table.insert(self.PortfolioFramePool.free, frame)
    end
  end
  self.PortfolioFramePool.inUse = {}
end

-- Creates and configures the portfolio creation dialog used to add new portfolios.
-- The dialog includes inputs for portfolio name and total investment, plus Create and Cancel buttons.
-- Stores dialog and input widgets on the mixin as `CreateDialog`, `NameEditBox`, and `InvestmentEditBox`.
function JournalatorInvestONatorPortfolioDisplayMixin:SetupCreatePortfolioDialog()
  -- Create portfolio creation dialog
  local dialog = CreateBasicDialog(self, 400, 300)
  
  dialog.Title:SetText(JOURNALATOR_L_CREATE_PORTFOLIO)
  
  -- Portfolio name input
  local nameLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  nameLabel:SetPoint("TOPLEFT", 20, -60)
  nameLabel:SetText(JOURNALATOR_L_PORTFOLIO_NAME)
  
  local nameEditBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
  nameEditBox:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -5)
  nameEditBox:SetSize(300, 30)
  nameEditBox:SetAutoFocus(false)
  
  -- Total investment input
  local investmentLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  investmentLabel:SetPoint("TOPLEFT", nameEditBox, "BOTTOMLEFT", 0, -20)
  investmentLabel:SetText(JOURNALATOR_L_TOTAL_INVESTMENT)
  
  local investmentEditBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
  investmentEditBox:SetPoint("TOPLEFT", investmentLabel, "BOTTOMLEFT", 0, -5)
  investmentEditBox:SetSize(300, 30)
  investmentEditBox:SetAutoFocus(false)
  
  -- Create button
  local createButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
  createButton:SetSize(100, 30)
  createButton:SetPoint("BOTTOMRIGHT", -20, 20)
  createButton:SetText(JOURNALATOR_L_CREATE)
  createButton:SetScript("OnClick", function()
    local name = nameEditBox:GetText()
    local investment = Journalator.InvestONator.ParseGoldInput(investmentEditBox:GetText())
    
    if name and name ~= "" and investment > 0 then
      Journalator.InvestONator.CreatePortfolio(name, investment)
      self:RefreshPortfolioList()
      dialog:Hide()
      nameEditBox:SetText("")
      investmentEditBox:SetText("")
    end
  end)
  
  -- Cancel button
  local cancelButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
  cancelButton:SetSize(100, 30)
  cancelButton:SetPoint("RIGHT", createButton, "LEFT", -10, 0)
  cancelButton:SetText(JOURNALATOR_L_CANCEL)
  cancelButton:SetScript("OnClick", function()
    dialog:Hide()
    nameEditBox:SetText("")
    investmentEditBox:SetText("")
  end)
  
  self.CreateDialog = dialog
  self.NameEditBox = nameEditBox
  self.InvestmentEditBox = investmentEditBox
end

---Refresh the portfolio list display
-- Rebuilds the portfolio list UI from current portfolio data.
-- Hides and detaches any existing portfolio frames, creates and positions a frame for each portfolio, and updates the content container height.
-- Ensures a "Create" button exists to open the portfolio creation dialog.
function JournalatorInvestONatorPortfolioDisplayMixin:RefreshPortfolioList()
  -- Clear existing frames
  self:ReleaseAllPortfolioFrames()
  
  local portfolios = Journalator.InvestONator.GetAllPortfolios()
  -- (Re)build tabs to reflect current portfolios
  self:RebuildTabs()
  local yOffset = 0

  -- When tabs are present, show only the active portfolio
  local activePortfolioId = self.ActivePortfolioId
  if not activePortfolioId then
    -- default to first key
    for pid, _ in pairs(portfolios) do activePortfolioId = pid break end
  end
  self.ActivePortfolioId = activePortfolioId
  
  -- Ensure Create button exists (also for empty state)
  if not self.CreateButton then
    self.CreateButton = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
    self.CreateButton:SetSize(150, 30)
    self.CreateButton:SetPoint("TOPLEFT", 20, -20)
    self.CreateButton:SetText(JOURNALATOR_L_CREATE_PORTFOLIO)
    self.CreateButton:SetScript("OnClick", function()
      if self.CreateDialog then
        self.CreateDialog:Show()
      end
    end)
  end
  
  -- Handle empty state
  if not portfolios or next(portfolios) == nil then
    if not self.EmptyStateText then
      self.EmptyStateText = self.Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      self.EmptyStateText:SetPoint("CENTER", self.Content, "CENTER")
      self.EmptyStateText:SetText(JOURNALATOR_L_NO_PORTFOLIOS_FOUND or "No portfolios found. Create one to get started!")
    end
    self.EmptyStateText:Show()
    self.Content:SetHeight(100)
    if self.CreateButton then
      self.CreateButton:Show()
    end
    return
  else
    if self.EmptyStateText then
      self.EmptyStateText:Hide()
    end
  end
  
  if activePortfolioId and portfolios[activePortfolioId] then
    local frame = self:CreatePortfolioFrame(activePortfolioId, portfolios[activePortfolioId])
    if frame then
      frame:SetPoint("TOPLEFT", self.Content, "TOPLEFT", 0, -yOffset)
      yOffset = yOffset + frame:GetHeight() + 10
    end
  end
  
  -- Update content height
  self.Content:SetHeight(math.max(yOffset, 100))
  
end

---Create a frame for displaying a portfolio
---@param portfolioId number The ID of the portfolio
---@param portfolio PortfolioData The portfolio data
---@return Frame|nil frame The created portfolio frame, or nil if creation failed
-- Creates a UI frame for a portfolio with header, optional progress summary,
-- up to five items, and action buttons. The returned frame has `PortfolioId`
-- set and is tracked via `self.PortfolioFramePool.inUse`.
function JournalatorInvestONatorPortfolioDisplayMixin:CreatePortfolioFrame(portfolioId, portfolio)
  if not portfolioId or not portfolio then
    Journalator.Debug.Message("InvestONator: Invalid portfolio data for frame creation")
    return nil
  end
  
  local frame = self:AcquirePortfolioFrame()
  if not frame then
    Journalator.Debug.Message("InvestONator: Failed to create portfolio frame")
    return nil
  end
  
  frame:SetSize(self.Content:GetWidth() - 40, 200)
  
  -- Portfolio header
  local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  header:SetPoint("TOPLEFT", 10, -10)
  header:SetText(portfolio.name)

  local editNameButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  editNameButton:SetSize(70, 20)
  editNameButton:SetPoint("LEFT", header, "RIGHT", 8, 0)
  editNameButton:SetText("Rename")
  editNameButton:SetScript("OnClick", function()
    StaticPopupDialogs["JNR_EDIT_PORTFOLIO_NAME"] = StaticPopupDialogs["JNR_EDIT_PORTFOLIO_NAME"] or {
      text = "Rename portfolio",
      button1 = OKAY,
      button2 = CANCEL,
      hasEditBox = true,
      OnShow = function(self)
        local eb = self.editBox or self.EditBox
        if eb then
          eb:SetText(portfolio.name)
          eb:SetFocus()
          eb:HighlightText()
        end
      end,
      OnAccept = function(self, data)
        local eb = self.editBox or self.EditBox
        local text = eb and eb:GetText() or ""
        if Journalator.InvestONator.RenamePortfolio(data.portfolioId, text) then
          data.owner:RefreshPortfolioList()
        end
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      preferredIndex = 3,
    }
    StaticPopup_Show("JNR_EDIT_PORTFOLIO_NAME", nil, nil, { portfolioId = portfolioId, owner = self })
  end)
  
  -- Progress info
  local progress = Journalator.InvestONator.GetPortfolioProgress(portfolioId)
  local progressText
  if progress then
    progressText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    progressText:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -10)
    progressText:SetText(string.format(
      "Progress: %s / %s (%d%%) | Remaining: %s | Items: %d/%d",
      Journalator.InvestONator.FormatGold(progress.totalSpent),
      Journalator.InvestONator.FormatGold(progress.totalTarget),
      math.floor(progress.completionPercentage),
      Journalator.InvestONator.FormatGold(progress.remainingBudget),
      progress.completedItems,
      progress.totalItems
    ))
  end

  -- Edit total investment button
  local editTotalBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  editTotalBtn:SetSize(80, 18)
  editTotalBtn:SetPoint("LEFT", progressText, "RIGHT", 8, 0)
  editTotalBtn:SetText("Edit Total")
  editTotalBtn:SetScript("OnClick", function()
    StaticPopupDialogs["JNR_EDIT_PORTFOLIO_TOTAL"] = StaticPopupDialogs["JNR_EDIT_PORTFOLIO_TOTAL"] or {
      text = "New portfolio total (gold)",
      button1 = OKAY,
      button2 = CANCEL,
      hasEditBox = true,
      OnShow = function(self)
        local eb = self.editBox or self.EditBox
        if eb then
          eb:SetText(tostring(math.floor((portfolio.totalInvestment or 0) / 10000)))
          eb:HighlightText()
          eb:SetFocus()
        end
      end,
      OnAccept = function(self, data)
        local eb = self.editBox or self.EditBox
        local g = eb and tonumber(eb:GetText()) or 0
        if g > 0 then
          if Journalator.InvestONator.UpdatePortfolioTotal(data.portfolioId, g * 10000) then
            data.owner:RefreshPortfolioList()
          end
        end
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      preferredIndex = 3,
    }
    StaticPopup_Show("JNR_EDIT_PORTFOLIO_TOTAL", nil, nil, { portfolioId = portfolioId, owner = self })
  end)
  
  -- Items list with pagination
  local itemsFrame = CreateFrame("Frame", nil, frame)
  local itemsAnchor = progressText or header
  itemsFrame:SetPoint("TOPLEFT", itemsAnchor, "BOTTOMLEFT", 0, -10)
  itemsFrame:SetSize(frame:GetWidth() - 20, 100)

  -- Build a sortable array of items, then sort alphabetically (case-insensitive)
  local sortedItems = {}
  for itemId, item in pairs(portfolio.items) do
    table.insert(sortedItems, { id = itemId, item = item })
  end
  table.sort(sortedItems, function(a, b)
    local an = a.item and a.item.name or ""
    local bn = b.item and b.item.name or ""
    return string.lower(an) < string.lower(bn)
  end)

  local rows = {}
  local rowHeight = 20
  local itemsPerPage = 12
  local currentPage = 1

  local pageLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  pageLabel:SetPoint("TOPRIGHT", itemsFrame, "BOTTOMRIGHT", -110, -6)

  local nextButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  nextButton:SetSize(70, 20)
  nextButton:SetPoint("RIGHT", pageLabel, "LEFT", -8, 0)
  nextButton:SetText(NEXT)

  local prevButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  prevButton:SetSize(70, 20)
  prevButton:SetPoint("RIGHT", nextButton, "LEFT", -8, 0)
  prevButton:SetText(PREVIOUS)

  local function acquireRow(index)
    if rows[index] then return rows[index] end
    local r = self:CreateItemFrame(0, { name = "", purchasedAmount = 0, targetAmount = 0, remainingAmount = 0 }, itemsFrame, portfolioId)
    r:SetPoint("TOPLEFT", itemsFrame, "TOPLEFT", 0, -(index - 1) * rowHeight)
    rows[index] = r
    return r
  end

  local function renderPage()
    local total = #sortedItems
    local totalPages = math.max(1, math.ceil(total / itemsPerPage))
    if currentPage > totalPages then currentPage = totalPages end
    if currentPage < 1 then currentPage = 1 end

    local startIndex = (currentPage - 1) * itemsPerPage + 1
    local endIndex = math.min(startIndex + itemsPerPage - 1, total)
    local displayCount = endIndex >= startIndex and (endIndex - startIndex + 1) or 0

    -- Populate rows
    local rowIndex = 1
    for i = startIndex, endIndex do
      local entry = sortedItems[i]
      local r = acquireRow(rowIndex)
      -- Rebuild the row with real data
      for _, child in ipairs({ r:GetChildren() }) do child:Hide() end
      for _, region in ipairs({ r:GetRegions() }) do region:Hide() end
      r:Hide()
      local filled = self:CreateItemFrame(entry.id, entry.item, itemsFrame, portfolioId)
      filled:SetPoint("TOPLEFT", itemsFrame, "TOPLEFT", 0, -(rowIndex - 1) * rowHeight)
      rows[rowIndex] = filled
      filled:Show()
      rowIndex = rowIndex + 1
    end
    -- Hide extra rows
    local idx = rowIndex
    while rows[idx] do
      rows[idx]:Hide()
      idx = idx + 1
    end

    -- Resize container
    itemsFrame:SetHeight(displayCount * rowHeight)

    -- Update page controls
    pageLabel:SetText(string.format("%d / %d", currentPage, totalPages))
    prevButton:SetEnabled(currentPage > 1)
    nextButton:SetEnabled(currentPage < totalPages)

    -- Adjust overall frame height
    local baseHeight = 130 -- header + progress + spacing
    local controlsHeight = 30
    frame:SetHeight(math.max(baseHeight + itemsFrame:GetHeight() + controlsHeight, 220))
  end

  prevButton:SetScript("OnClick", function()
    currentPage = currentPage - 1
    renderPage()
  end)
  nextButton:SetScript("OnClick", function()
    currentPage = currentPage + 1
    renderPage()
  end)

  renderPage()
  
  -- Action buttons (placed on header row, to the right of Rename)
  local addItemButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  addItemButton:SetSize(100, 25)
  addItemButton:SetPoint("LEFT", editNameButton, "RIGHT", 10, 0)
  addItemButton:SetText(JOURNALATOR_L_ADD_ITEM)
  addItemButton:SetScript("OnClick", function()
    self:ShowAddItemDialog(portfolioId)
  end)

  local deleteButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  deleteButton:SetSize(100, 25)
  deleteButton:SetPoint("LEFT", addItemButton, "RIGHT", 10, 0)
  deleteButton:SetText(JOURNALATOR_L_DELETE_PORTFOLIO)
  deleteButton:SetScript("OnClick", function()
    StaticPopup_Show("JOURNALATOR_CONFIRM_DELETE_PORTFOLIO", portfolio.name, nil, {
      deleteFunc = function()
        Journalator.InvestONator.DeletePortfolio(portfolioId)
        self:RefreshPortfolioList()
      end
    })
  end)

  -- Reposition pagination controls at the top next to Delete Portfolio
  pageLabel:ClearAllPoints()
  pageLabel:SetPoint("LEFT", deleteButton, "RIGHT", 10, 0)
  prevButton:ClearAllPoints()
  prevButton:SetPoint("LEFT", pageLabel, "RIGHT", 10, 0)
  nextButton:ClearAllPoints()
  nextButton:SetPoint("LEFT", prevButton, "RIGHT", 6, 0)
  
  frame.PortfolioId = portfolioId
  
  return frame
end

---Create a frame for displaying an item within a portfolio
---@param itemId number The ID of the item
---@param item ItemData The item data
---@param parent Frame The parent frame
-- Creates a compact row that displays an item's name and its purchase progress.
-- @param itemId number The item's identifier.
-- @param item table Table with fields `name`, `purchasedAmount`, `targetAmount`, and `remainingAmount`.
-- @param parent Frame The parent frame that will contain the item row; the row width matches the parent's width.
-- @return Frame The created item frame.
function JournalatorInvestONatorPortfolioDisplayMixin:CreateItemFrame(itemId, item, parent, portfolioId)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(parent:GetWidth(), 20)
  local ownerView = self
  
  local itemName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  itemName:SetPoint("LEFT", 0, 0)
  itemName:SetText(item.name)
  
  local progressText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  progressText:SetPoint("RIGHT", 0, 0)
  progressText:SetText(string.format(
    "%s / %s (%s remaining)",
    Journalator.InvestONator.FormatGold(item.purchasedAmount),
    Journalator.InvestONator.FormatGold(item.targetAmount),
    Journalator.InvestONator.FormatGold(item.remainingAmount)
  ))

  -- Edit target button
  local editBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  editBtn:SetSize(60, 18)
  editBtn:SetPoint("RIGHT", progressText, "LEFT", -8, 0)
  editBtn:SetText("Edit")
  editBtn:SetScript("OnClick", function()
    StaticPopupDialogs["JNR_EDIT_ITEM_TARGET"] = StaticPopupDialogs["JNR_EDIT_ITEM_TARGET"] or {
      text = "New target amount (gold)",
      button1 = OKAY,
      button2 = CANCEL,
      hasEditBox = true,
      OnShow = function(self)
        local eb = self.editBox or self.EditBox
        if eb then
          eb:SetText(tostring(math.floor((item.targetAmount or 0) / 10000)))
          eb:HighlightText()
          eb:SetFocus()
        end
      end,
      OnAccept = function(self, data)
        local eb = self.editBox or self.EditBox
        local g = eb and tonumber(eb:GetText()) or 0
        if g > 0 then
          if Journalator.InvestONator.UpdateItemTargetAmount(data.portfolioId, data.itemId, g * 10000) then
            data.owner:RefreshPortfolioList()
          end
        end
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      preferredIndex = 3,
    }
    StaticPopup_Show("JNR_EDIT_ITEM_TARGET", nil, nil, { portfolioId = portfolioId, itemId = itemId, owner = ownerView })
  end)

  -- Remove item button
  local removeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  removeBtn:SetSize(60, 18)
  removeBtn:SetPoint("RIGHT", editBtn, "LEFT", -6, 0)
  removeBtn:SetText("Remove")
  removeBtn:SetScript("OnClick", function()
    StaticPopupDialogs["JNR_DELETE_ITEM"] = StaticPopupDialogs["JNR_DELETE_ITEM"] or {
      text = "Remove item from portfolio?",
      button1 = YES,
      button2 = NO,
      OnAccept = function(self, data)
        if Journalator.InvestONator.DeleteItemFromPortfolio(data.portfolioId, data.itemId) then
          data.owner:RefreshPortfolioList()
        end
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      preferredIndex = 3,
    }
    StaticPopup_Show("JNR_DELETE_ITEM", nil, nil, { portfolioId = portfolioId, itemId = itemId, owner = ownerView })
  end)
  
  return frame
end

---Show dialog for adding items to a portfolio
-- Shows the Add Item dialog for the given portfolio.
-- Currently this function only displays a message that the dialog is not implemented and suggests using the API to add items programmatically.
-- @param portfolioId number The ID of the portfolio to add items to.
function JournalatorInvestONatorPortfolioDisplayMixin:ShowAddItemDialog(portfolioId)
  if not portfolioId then
    return
  end

  if not self.AddItemDialog then
    local dialog = CreateBasicDialog(self, 420, 320)

    dialog.Title:SetText(JOURNALATOR_L_ADD_ITEM or "Add Item")

    -- Item input
    local itemLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemLabel:SetPoint("TOPLEFT", 20, -60)
    itemLabel:SetText(JOURNALATOR_L_ITEM_LINK_OR_ID)

    local itemEditBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    itemEditBox:SetPoint("TOPLEFT", itemLabel, "BOTTOMLEFT", 0, -5)
    itemEditBox:SetSize(360, 30)
    itemEditBox:SetAutoFocus(false)

    -- Suggestions list under the item box
    local suggestionsFrame = CreateFrame("Frame", nil, dialog)
    suggestionsFrame:SetPoint("TOPLEFT", itemEditBox, "BOTTOMLEFT", 0, -2)
    suggestionsFrame:SetSize(360, 108)
    suggestionsFrame:Hide()

    local suggestionsBG = suggestionsFrame:CreateTexture(nil, "BACKGROUND")
    suggestionsBG:SetColorTexture(0, 0, 0, 0.8)
    suggestionsBG:SetAllPoints()

    suggestionsFrame.buttons = {}
    local function acquireButton()
      for _, b in ipairs(suggestionsFrame.buttons) do
        if not b:IsShown() then
          return b
        end
      end
      local b = CreateFrame("Button", nil, suggestionsFrame, "UIPanelButtonTemplate")
      b:SetSize(340, 20)
      if #suggestionsFrame.buttons == 0 then
        b:SetPoint("TOPLEFT", 10, -6)
      else
        b:SetPoint("TOPLEFT", suggestionsFrame.buttons[#suggestionsFrame.buttons], "BOTTOMLEFT", 0, -4)
      end
      table.insert(suggestionsFrame.buttons, b)
      return b
    end

    function dialog:ShowSuggestions(items)
      -- Hide all existing buttons
      for _, b in ipairs(suggestionsFrame.buttons) do
        b:Hide()
      end
      if not items or #items == 0 then
        suggestionsFrame:Hide()
        return
      end
      suggestionsFrame:Show()
      local shown = 0
      for _, entry in ipairs(items) do
        local b = acquireButton()
        b:SetText(entry.name)
        b:SetScript("OnClick", function()
          itemEditBox:SetText(entry.name)
          dialog.SelectedItemId = entry.itemID
          dialog.SelectedItemName = entry.name
          suggestionsFrame:Hide()
        end)
        b:Show()
        shown = shown + 1
        if shown >= 6 then break end
      end
    end

    itemEditBox:SetScript("OnTextChanged", function()
      dialog.SelectedItemId = nil
      dialog.SelectedItemName = nil
      local query = itemEditBox:GetText()
      local items = self:GetItemSuggestions(query, 10)
      dialog:ShowSuggestions(items)
    end)

    -- Amount input
    local amountLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    amountLabel:SetPoint("TOPLEFT", suggestionsFrame, "BOTTOMLEFT", 0, -10)
    amountLabel:SetText((JOURNALATOR_L_TARGET_AMOUNT or "Target Amount") .. " (gold)")

    local amountEditBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    amountEditBox:SetPoint("TOPLEFT", amountLabel, "BOTTOMLEFT", 0, -5)
    amountEditBox:SetSize(360, 30)
    amountEditBox:SetAutoFocus(false)
    amountEditBox:SetNumeric(true)

    -- Add button
    local addButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    addButton:SetSize(100, 30)
    -- Place just below the amount field, not at dialog bottom, to avoid overlap
    addButton:SetPoint("TOPRIGHT", amountEditBox, "BOTTOMRIGHT", 0, -10)
    addButton:SetText(JOURNALATOR_L_ADD_ITEM or "Add")
    addButton:SetScript("OnClick", function()
      local itemArg = itemEditBox:GetText()
      local amountText = amountEditBox:GetText()
      local amountValue = Journalator.InvestONator.ParseGoldInput(amountText)

      if not itemArg or itemArg == "" then
        Journalator.Utilities.Message("Please enter an item link or numeric ID.")
        return
      end

      if not amountValue or amountValue <= 0 then
        Journalator.Utilities.Message("Invalid amount. Enter a gold number, e.g. 100")
        return
      end

      local itemId = dialog.SelectedItemId
      if not itemId and type(itemArg) == "string" then
        itemId = tonumber(itemArg:match("|Hitem:(%d+):"))
          or tonumber(itemArg:match("item:(%d+)"))
          or tonumber(itemArg:match("^(%d+)$"))
      end

      if not itemId then
        Journalator.Utilities.Message("Invalid item. Provide an item link or numeric item ID (e.g. 3575).")
        return
      end

      local resolvedName = dialog.SelectedItemName or (GetItemInfo and GetItemInfo(itemId)) or (itemArg:match("%[(.-)%]")) or tostring(itemArg)

      if Journalator.InvestONator.AddItemToPortfolio(self.ActivePortfolioId or portfolioId, itemId, resolvedName, amountValue) then
        self:RefreshPortfolioList()
        dialog:Hide()
        itemEditBox:SetText("")
        amountEditBox:SetText("")
      else
        Journalator.Utilities.Message("Failed to add item to portfolio. Check your input.")
      end
    end)

    -- Cancel button
    local cancelButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    cancelButton:SetSize(100, 30)
    cancelButton:SetPoint("RIGHT", addButton, "LEFT", -10, 0)
    cancelButton:SetText(JOURNALATOR_L_CANCEL or "Cancel")
    cancelButton:SetScript("OnClick", function()
      dialog:Hide()
      itemEditBox:SetText("")
      amountEditBox:SetText("")
    end)

    self.AddItemDialog = dialog
    self.ItemEditBox = itemEditBox
    self.AmountEditBox = amountEditBox
  end

  self.ActivePortfolioId = portfolioId
  self.AddItemDialog:Show()
  if self.ItemEditBox then
    self.ItemEditBox:SetFocus()
  end
end