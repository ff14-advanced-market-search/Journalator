---@class JournalatorInvestONatorPortfolioDisplayMixin
JournalatorInvestONatorPortfolioDisplayMixin = CreateFromMixins(JournalatorDisplayMixin)

---Initialize the portfolio display
-- Initialize the InvestONator portfolio display.
-- Calls the base OnLoad, sets up the portfolio list and the create-portfolio dialog, and refreshes the displayed portfolios.
function JournalatorInvestONatorPortfolioDisplayMixin:OnLoad()
  JournalatorDisplayMixin.OnLoad(self)
  
  self:SetupPortfolioList()
  self:SetupCreatePortfolioDialog()
  self:RefreshPortfolioList()
end

---Handle the display being shown
---Refreshes the portfolio list
function JournalatorInvestONatorPortfolioDisplayMixin:OnShow()
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
  local dialog = CreateFrame("Frame", nil, self, "DialogBoxFrameTemplate")
  dialog:SetSize(400, 300)
  dialog:SetPoint("CENTER")
  dialog:Hide()
  
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
  local yOffset = 0
  
  -- Handle empty state
  if not portfolios or next(portfolios) == nil then
    if not self.EmptyStateText then
      self.EmptyStateText = self.Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      self.EmptyStateText:SetPoint("CENTER", self.Content, "CENTER")
      self.EmptyStateText:SetText(JOURNALATOR_L_NO_PORTFOLIOS_FOUND or "No portfolios found. Create one to get started!")
    end
    self.EmptyStateText:Show()
    self.Content:SetHeight(100)
    return
  else
    if self.EmptyStateText then
      self.EmptyStateText:Hide()
    end
  end
  
  for portfolioId, portfolio in pairs(portfolios) do
    local frame = self:CreatePortfolioFrame(portfolioId, portfolio)
    if frame then
      frame:SetPoint("TOPLEFT", self.Content, "TOPLEFT", 0, -yOffset)
      yOffset = yOffset + frame:GetHeight() + 10
    end
  end
  
  -- Update content height
  self.Content:SetHeight(math.max(yOffset, 100))
  
  -- Show create button if no portfolios exist
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
  
  -- Items list
  local itemsFrame = CreateFrame("Frame", nil, frame)
  local itemsAnchor = progressText or header
  itemsFrame:SetPoint("TOPLEFT", itemsAnchor, "BOTTOMLEFT", 0, -10)
  itemsFrame:SetSize(frame:GetWidth() - 20, 100)
  
  local yOffset = 0
  local itemCount = 0
  for itemId, item in pairs(portfolio.items) do
    if itemCount < 5 then -- Show only first 5 items
      local itemFrame = self:CreateItemFrame(itemId, item, itemsFrame)
      itemFrame:SetPoint("TOPLEFT", itemsFrame, "TOPLEFT", 0, -yOffset)
      yOffset = yOffset + 20
      itemCount = itemCount + 1
    end
  end
  
  if itemCount >= 5 then
    local moreText = itemsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    moreText:SetPoint("TOPLEFT", itemsFrame, "TOPLEFT", 0, -yOffset)
    moreText:SetText(JOURNALATOR_L_AND_MORE or "... and more")
  end
  
  -- Action buttons
  local deleteButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  deleteButton:SetSize(100, 25)
  deleteButton:SetPoint("BOTTOMRIGHT", -10, 10)
  deleteButton:SetText(JOURNALATOR_L_DELETE_PORTFOLIO)
  deleteButton:SetScript("OnClick", function()
    StaticPopup_Show("JOURNALATOR_CONFIRM_DELETE_PORTFOLIO", portfolio.name, nil, {
      deleteFunc = function()
        Journalator.InvestONator.DeletePortfolio(portfolioId)
        self:RefreshPortfolioList()
      end
    })
  end)
  
  local addItemButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  addItemButton:SetSize(100, 25)
  addItemButton:SetPoint("RIGHT", deleteButton, "LEFT", -10, 0)
  addItemButton:SetText(JOURNALATOR_L_ADD_ITEM)
  addItemButton:SetScript("OnClick", function()
    self:ShowAddItemDialog(portfolioId)
  end)
  
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
function JournalatorInvestONatorPortfolioDisplayMixin:CreateItemFrame(itemId, item, parent)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(parent:GetWidth(), 20)
  
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
    local dialog = CreateFrame("Frame", nil, self, "DialogBoxFrameTemplate")
    dialog:SetSize(420, 260)
    dialog:SetPoint("CENTER")
    dialog:Hide()

    dialog.Title:SetText(JOURNALATOR_L_ADD_ITEM or "Add Item")

    -- Item input
    local itemLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemLabel:SetPoint("TOPLEFT", 20, -60)
    itemLabel:SetText(JOURNALATOR_L_ITEM_LINK_OR_ID)

    local itemEditBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    itemEditBox:SetPoint("TOPLEFT", itemLabel, "BOTTOMLEFT", 0, -5)
    itemEditBox:SetSize(360, 30)
    itemEditBox:SetAutoFocus(false)

    -- Amount input
    local amountLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    amountLabel:SetPoint("TOPLEFT", itemEditBox, "BOTTOMLEFT", 0, -20)
    amountLabel:SetText(JOURNALATOR_L_TARGET_AMOUNT or "Target Amount")

    local amountEditBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    amountEditBox:SetPoint("TOPLEFT", amountLabel, "BOTTOMLEFT", 0, -5)
    amountEditBox:SetSize(360, 30)
    amountEditBox:SetAutoFocus(false)

    -- Add button
    local addButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    addButton:SetSize(100, 30)
    addButton:SetPoint("BOTTOMRIGHT", -20, 20)
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
        Journalator.Utilities.Message("Invalid amount. Use formats like 100g, 10000s, or 1000000c")
        return
      end

      local itemId
      if type(itemArg) == "string" then
        itemId = tonumber(itemArg:match("|Hitem:(%d+):"))
          or tonumber(itemArg:match("item:(%d+)"))
          or tonumber(itemArg:match("^(%d+)$"))
      end

      if not itemId then
        Journalator.Utilities.Message("Invalid item. Provide an item link or numeric item ID (e.g. 3575).")
        return
      end

      local resolvedName = (GetItemInfo and GetItemInfo(itemId)) or (itemArg:match("%[(.-)%]")) or tostring(itemArg)

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