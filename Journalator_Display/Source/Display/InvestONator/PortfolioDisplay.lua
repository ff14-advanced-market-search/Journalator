JournalatorInvestONatorPortfolioDisplayMixin = CreateFromMixins(JournalatorDisplayMixin)

function JournalatorInvestONatorPortfolioDisplayMixin:OnLoad()
  JournalatorDisplayMixin.OnLoad(self)
  
  self:SetupPortfolioList()
  self:SetupCreatePortfolioDialog()
  self:RefreshPortfolioList()
end

function JournalatorInvestONatorPortfolioDisplayMixin:OnShow()
  self:RefreshPortfolioList()
end

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

function JournalatorInvestONatorPortfolioDisplayMixin:RefreshPortfolioList()
  -- Clear existing frames
  for _, frame in pairs(self.PortfolioFrames) do
    frame:Hide()
    frame:SetParent(nil)
  end
  self.PortfolioFrames = {}
  
  local portfolios = Journalator.InvestONator.GetAllPortfolios()
  local yOffset = 0
  
  for portfolioId, portfolio in pairs(portfolios) do
    local frame = self:CreatePortfolioFrame(portfolioId, portfolio)
    frame:SetPoint("TOPLEFT", self.Content, "TOPLEFT", 0, -yOffset)
    yOffset = yOffset + frame:GetHeight() + 10
  end
  
  -- Update content height
  self.Content:SetHeight(yOffset)
  
  -- Show create button if no portfolios exist
  if not self.CreateButton then
    self.CreateButton = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
    self.CreateButton:SetSize(150, 30)
    self.CreateButton:SetPoint("TOPLEFT", 20, -20)
    self.CreateButton:SetText(JOURNALATOR_L_CREATE_PORTFOLIO)
    self.CreateButton:SetScript("OnClick", function()
      self.CreateDialog:Show()
    end)
  end
end

function JournalatorInvestONatorPortfolioDisplayMixin:CreatePortfolioFrame(portfolioId, portfolio)
  local frame = CreateFrame("Frame", nil, self.Content)
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

function JournalatorInvestONatorPortfolioDisplayMixin:ShowAddItemDialog(portfolioId)
  -- This would show a dialog to add items to the portfolio
  -- For now, we'll just show a simple message
  Journalator.Utilities.Message("Add Item dialog not implemented yet. Use the API to add items programmatically.")
end