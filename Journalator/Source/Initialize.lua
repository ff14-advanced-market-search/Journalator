-- Creates and configures monitoring frames according to user configuration and game edition.
-- 
-- For each enabled monitor option this function instantiates the corresponding monitor frame(s):
-- - Auction House: auction mail and posting monitors.
-- - Vendoring: vendor items, vendor repairs, taxis, and training costs monitors.
-- - Crafting Orders: crafting order placing, fulfilling, and mail monitors (only on non-Classic).
-- - Questing: reputation monitor and either the Classic or Mainline quests monitor; links the quests monitor to the reputation monitor.
-- - Trading Post: trading post monitor (only on non-Classic).
-- - Looting: loot containers monitor and, on non-Classic, right-click-to-open monitor.
-- - WoW Tokens: WoW Tokens monitor if commerce status is available.
-- - Basic Mail: basic mail send and receive monitors.
-- - Trades: trades monitor.
-- - Mission Tables: mission tables monitor (only on non-Classic).
-- - Invest-O-Nator: Invest-O-Nator monitor.
-- 
-- If a monitor option is disabled, a debug message is emitted indicating that the specific monitoring category is disabled.
local function SetupMonitors()
  if Journalator.Config.Get(Journalator.Config.Options.MONITOR_AUCTION_HOUSE) then
    CreateFrame("Frame", "JNRAuctionMailMonitor", nil, "JournalatorAuctionMailMonitorTemplate")
    CreateFrame("Frame", "JNRAuctionPostingMonitor", nil, "JournalatorAuctionPostingMonitorTemplate")
  else
    Journalator.Debug.Message("AH monitoring disabled")
  end

  if Journalator.Config.Get(Journalator.Config.Options.MONITOR_VENDORING) then
    CreateFrame("Frame", "JNRVendorItemsMonitor", nil, "JournalatorVendorItemsMonitorTemplate")
    CreateFrame("Frame", "JNRVendorRepairsMonitor", nil, "JournalatorVendorRepairsMonitorTemplate")
    CreateFrame("Frame", "JNRTaxisMonitor", nil, "JournalatorTaxisMonitorTemplate")
    CreateFrame("Frame", "JNRTrainingCostsMonitor", nil, "JournalatorTrainingCostsMonitorTemplate")
  else
    Journalator.Debug.Message("vendor monitoring disabled")
  end

  if Journalator.Config.Get(Journalator.Config.Options.MONITOR_CRAFTING_ORDERS) then
    if not Journalator.Constants.IsClassic then
      CreateFrame("Frame", "JNRCraftingOrderPlacingMonitor", nil, "JournalatorCraftingOrderPlacingMonitorTemplate")
      CreateFrame("Frame", "JNRCraftingOrderFulfillingMonitor", nil, "JournalatorCraftingOrderFulfillingMonitorTemplate")
      CreateFrame("Frame", "JNRCraftingOrderMailMonitor", nil, "JournalatorCraftingOrderMailMonitorTemplate")
    end
  else
    Journalator.Debug.Message("crafting orders monitoring disabled")
  end

  if Journalator.Config.Get(Journalator.Config.Options.MONITOR_QUESTING) then
    local repMonitor = CreateFrame("Frame", "JNRReputationMonitor", nil, "JournalatorReputationMonitorTemplate")
    if Journalator.Constants.IsClassic then
      CreateFrame("Frame", "JNRQuestsMonitor", nil, "JournalatorQuestsClassicMonitorTemplate")
    else
      CreateFrame("Frame", "JNRQuestsMonitor", nil, "JournalatorQuestsMainlineMonitorTemplate")
    end
    JNRQuestsMonitor:SetReputationMonitor(repMonitor)
  else
    Journalator.Debug.Message("quest monitoring disabled")
  end

  if Journalator.Config.Get(Journalator.Config.Options.MONITOR_TRADING_POST) then
    if not Journalator.Constants.IsClassic then
      CreateFrame("Frame", "JNRTradingPostMonitor", nil, "JournalatorTradingPostMonitorTemplate")
    end
  else
    Journalator.Debug.Message("trading post monitor disabled")
  end

  if Journalator.Config.Get(Journalator.Config.Options.MONITOR_LOOTING) then
    CreateFrame("Frame", "JNRLootContainersMonitor", nil, "JournalatorLootContainersMonitorTemplate")
    if not Journalator.Constants.IsClassic then
      CreateFrame("Frame", "JNRLootRightClickToOpenMonitor", nil, "JournalatorLootRightClickToOpenMonitorTemplate")
    end
  else
    Journalator.Debug.Message("looting monitor disabled")
  end

  if Journalator.Config.Get(Journalator.Config.Options.MONITOR_WOW_TOKENS) then
    if C_WowTokenPublic.GetCommerceSystemStatus() then
      CreateFrame("Frame", "JNRWoWTokensMonitor", nil, "JournalatorWoWTokensMonitorTemplate")
    end
  else
    Journalator.Debug.Message("wow token monitor disabled")
  end

  if Journalator.Config.Get(Journalator.Config.Options.MONITOR_BASIC_MAIL) then
    CreateFrame("Frame", "JNRBasicMailSendMonitor", nil, "JournalatorBasicMailSendMonitorTemplate")
    CreateFrame("Frame", "JNRBasicMailReceiveMonitor", nil, "JournalatorBasicMailReceiveMonitorTemplate")
  else
    Journalator.Debug.Message("basic mail monitor disabled")
  end

  if Journalator.Config.Get(Journalator.Config.Options.MONITOR_TRADES) then
    CreateFrame("Frame", "JNRTradesMonitor", nil, "JournalatorTradesMonitorTemplate")
  else
    Journalator.Debug.Message("trades monitor disabled")
  end

  if Journalator.Config.Get(Journalator.Config.Options.MONITOR_MISSION_TABLES) then
    if not Journalator.Constants.IsClassic then
      CreateFrame("Frame", "JNRMissionTablesMonitor", nil, "JournalatorMissionTablesMonitorTemplate")
    end
  else
    Journalator.Debug.Message("mission tables monitor disabled")
  end

  if Journalator.Config.Get(Journalator.Config.Options.MONITOR_INVEST_O_NATOR) then
    CreateFrame("Frame", "JNRInvestONatorMonitor", nil, "JournalatorInvestONatorMonitorTemplate")
  else
    Journalator.Debug.Message("invest-o-nator monitor disabled")
  end
end

-- Initialize core Journalator subsystems and runtime state on add-on load.
-- Initializes configuration data, the archiving subsystem, and the Invest-O-Nator subsystem;
-- retrieves and stores the add-on version in Journalator.State.CurrentVersion; and initializes slash commands.
local function InitializeBase()
  Journalator.Config.InitializeData()

  Journalator.Archiving.Initialize()
  Journalator.InvestONator.Initialize()

  local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
  Journalator.State.CurrentVersion = GetAddOnMetadata("Journalator", "Version")

  Journalator.SlashCmd.Initialize()
end

local function InitializeMonitoring()
  local faction = UnitFactionGroup("player")
  Journalator.State.Source = {
    realm = GetRealmName(),
    character = GetUnitName("player"),
    faction = faction,
  }

  SetupMonitors()
end

local CORE_EVENTS = {
  "ADDON_LOADED",
  "PLAYER_ENTERING_WORLD",
}
local coreFrame = CreateFrame("Frame")

FrameUtil.RegisterFrameForEvents(coreFrame, CORE_EVENTS)
coreFrame:SetScript("OnEvent", function(self, eventName, name)
  if eventName == "ADDON_LOADED" and name == "Journalator" then
    self:UnregisterEvent("ADDON_LOADED")
    InitializeBase()
  elseif eventName == "PLAYER_ENTERING_WORLD" then
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    InitializeMonitoring()
  end
end)