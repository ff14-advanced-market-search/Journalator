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
  self.PortfolioFrames = {}
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
  createButton:SetText("Create")
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
  cancelButton:SetText("Cancel")
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
  for _, frame in pairs(self.PortfolioFrames) do
    if frame and frame:IsValid() then
      frame:Hide()
      frame:SetParent(nil)
      frame:ClearAllPoints()
    end
  end
  self.PortfolioFrames = {}
  
  local portfolios = Journalator.InvestONator.GetAllPortfolios()
  local yOffset = 0
  
  -- Handle empty state
  if not portfolios or next(portfolios) == nil then
    if not self.EmptyStateText then
      self.EmptyStateText = self.Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      self.EmptyStateText:SetPoint("CENTER", self.Content, "CENTER")
      self.EmptyStateText:SetText("No portfolios found. Create one to get started!")
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
<<<<<<< HEAD
-- Creates a UI frame that represents a portfolio, including its header, progress summary, a list of up to five items, and action buttons.
-- The created frame is added to the mixin's PortfolioFrames list and has its `PortfolioId` field set.
-- @param portfolioId number The identifier of the portfolio to display.
-- @param portfolio table The portfolio data (expected fields: `name`, `items`).
-- @return Frame The created portfolio frame with `PortfolioId` set and appended to `self.PortfolioFrames`.
=======
---@return Frame|nil frame The created portfolio frame, or nil if creation failed
>>>>>>> cb84b01 (Auto-commit pending changes before rebase - PR synchronize)
function JournalatorInvestONatorPortfolioDisplayMixin:CreatePortfolioFrame(portfolioId, portfolio)
  if not portfolioId or not portfolio then
    Journalator.Debug.Message("InvestONator: Invalid portfolio data for frame creation")
    return nil
  end
  
  local frame = CreateFrame("Frame", nil, self.Content)
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
  if progress then
    local progressText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
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
  itemsFrame:SetPoint("TOPLEFT", progressText, "BOTTOMLEFT", 0, -10)
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
    moreText:SetText("... and more")
  end
  
  -- Action buttons
  local deleteButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  deleteButton:SetSize(100, 25)
  deleteButton:SetPoint("BOTTOMRIGHT", -10, 10)
  deleteButton:SetText(JOURNALATOR_L_DELETE_PORTFOLIO)
  deleteButton:SetScript("OnClick", function()
    Journalator.InvestONator.DeletePortfolio(portfolioId)
    self:RefreshPortfolioList()
  end)
  
  local addItemButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  addItemButton:SetSize(100, 25)
  addItemButton:SetPoint("RIGHT", deleteButton, "LEFT", -10, 0)
  addItemButton:SetText(JOURNALATOR_L_ADD_ITEM)
  addItemButton:SetScript("OnClick", function()
    self:ShowAddItemDialog(portfolioId)
  end)
  
  frame.PortfolioId = portfolioId
  table.insert(self.PortfolioFrames, frame)
  
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
  -- This would show a dialog to add items to the portfolio
  -- For now, we'll just show a simple message
  Journalator.Utilities.Message("Add Item dialog not implemented yet. Use the API to add items programmatically.")
end