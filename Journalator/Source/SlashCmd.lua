Journalator.SlashCmd = {}

function Journalator.SlashCmd.Initialize()
  SlashCmdList["Journalator"] = Journalator.SlashCmd.Handler
  SLASH_Journalator1 = "/journalator"
  SLASH_Journalator2 = "/jnr"
end

local INVALID_OPTION_VALUE = "Wrong config value type %s (required %s)"
function Journalator.SlashCmd.Config(optionName, value1, ...)
  if optionName == nil then
    Journalator.Utilities.Message("No config option name supplied")
    for _, name in pairs(Journalator.Config.Options) do
      Journalator.Utilities.Message(name .. ": " .. tostring(Journalator.Config.Get(name)))
    end
    return
  end

  local currentValue = Journalator.Config.Get(optionName)
  if currentValue == nil then
    Journalator.Utilities.Message("Unknown config: " .. optionName)
    return
  end

  if value1 == nil then
    Journalator.Utilities.Message("Config " .. optionName .. ": " .. tostring(currentValue))
    return
  end

  if type(currentValue) == "boolean" then
    if value1 ~= "true" and value1 ~= "false" then
      Journalator.Utilities.Message(INVALID_OPTION_VALUE:format(type(value1), type(currentValue)))
      return
    end
    Journalator.Config.Set(optionName, value1 == "true")
  elseif type(currentValue) == "number" then
    if tonumber(value1) == nil then
      Journalator.Utilities.Message(INVALID_OPTION_VALUE:format(type(value1), type(currentValue)))
      return
    end
    Journalator.Config.Set(optionName, tonumber(value1))
  elseif type(currentValue) == "string" then
    Journalator.Config.Set(optionName, strjoin(" ", value1, ...))
  else
    Journalator.Utilities.Message("Unable to edit option type " .. type(currentValue))
    return
  end
  Journalator.Utilities.Message("Now set " .. optionName .. ": " .. tostring(Journalator.Config.Get(optionName)))
end

-- Toggles the DEBUG configuration option and notifies the user.
-- When debug is enabled, sends "Debug mode on"; when disabled, sends "Debug mode off".
function Journalator.SlashCmd.Debug(...)
  Journalator.Config.Set(Journalator.Config.Options.DEBUG, not Journalator.Config.Get(Journalator.Config.Options.DEBUG))
  if Journalator.Config.Get(Journalator.Config.Options.DEBUG) then
    Journalator.Utilities.Message("Debug mode on")
  else
    Journalator.Utilities.Message("Debug mode off")
  end
end

---Handle Invest-O-Nator slash commands
---Supports create, add, and list subcommands
-- Handles Invest-O-Nator slash subcommands: `create`, `add`, `list`, and prints usage help.
-- @param ... Command arguments where the first argument is the subcommand:
--   - "create", name, investment: create a new portfolio named `name` with `investment` (gold format like `100g`, `10000s`, `1000000c`, or plain number).
--   - "add", portfolioId, itemName, amount: add an item with `itemName` and target `amount` to the portfolio identified by `portfolioId`.
--   - "list": list all portfolios with their spent/target and completion percentage.
-- Unrecognized subcommands cause the function to emit the invest usage/help messages.
function Journalator.SlashCmd.InvestONator(...)
  local command = select(1, ...)
  
  if command == "create" then
    local name = select(2, ...)
    local investment = select(3, ...)
    
    if not name or not investment then
      Journalator.Utilities.Message("Usage: /jnr invest create <name> <investment>")
      Journalator.Utilities.Message("Example: /jnr invest create \"Materials\" 3000000")
      Journalator.Utilities.Message("Gold formats: 100g, 10000s, 1000000c, or plain numbers")
      return
    end
    
    local investmentAmount = Journalator.InvestONator.ParseGoldInput(investment)
    if investmentAmount <= 0 then
      Journalator.Utilities.Message("Invalid investment amount. Use formats like 100g, 10000s, or 1000000c")
      return
    end
    
    local portfolioId = Journalator.InvestONator.CreatePortfolio(name, investmentAmount)
    if portfolioId then
      Journalator.Utilities.Message("Created portfolio '" .. name .. "' with " .. Journalator.InvestONator.FormatGold(investmentAmount) .. " investment")
    else
      Journalator.Utilities.Message("Failed to create portfolio. Check your input.")
    end
    
  elseif command == "add" then
    local portfolioId = tonumber(select(2, ...))
    local itemName = select(3, ...)
    local amount = select(4, ...)
    
    if not portfolioId or not itemName or not amount then
      Journalator.Utilities.Message("Usage: /jnr invest add <portfolioId> <itemName> <amount>")
      return
    end
    
    local amountValue = Journalator.InvestONator.ParseGoldInput(amount)
    if amountValue <= 0 then
      Journalator.Utilities.Message("Invalid amount")
      return
    end
    
    -- Get item ID from name (simplified - would need better item lookup)
    local itemId = 0 -- This would need proper item ID lookup
    if Journalator.InvestONator.AddItemToPortfolio(portfolioId, itemId, itemName, amountValue) then
      Journalator.Utilities.Message("Added " .. itemName .. " with " .. Journalator.InvestONator.FormatGold(amountValue) .. " target to portfolio")
    else
      Journalator.Utilities.Message("Failed to add item to portfolio")
    end
    
  elseif command == "list" then
    local portfolios = Journalator.InvestONator.GetAllPortfolios()
    if next(portfolios) == nil then
      Journalator.Utilities.Message("No portfolios found")
      return
    end
    
    Journalator.Utilities.Message("Portfolios:")
    for portfolioId, portfolio in pairs(portfolios) do
      local progress = Journalator.InvestONator.GetPortfolioProgress(portfolioId)
      Journalator.Utilities.Message(string.format(
        "%d. %s - %s / %s (%d%%)",
        portfolioId,
        portfolio.name,
        Journalator.InvestONator.FormatGold(progress.totalSpent),
        Journalator.InvestONator.FormatGold(progress.totalTarget),
        math.floor(progress.completionPercentage)
      ))
    end
    
  else
    Journalator.Utilities.Message("Invest-o-nator commands:")
    Journalator.Utilities.Message("/jnr invest create <name> <investment> - Create a new portfolio")
    Journalator.Utilities.Message("/jnr invest add <portfolioId> <itemName> <amount> - Add item to portfolio")
    Journalator.Utilities.Message("/jnr invest list - List all portfolios")
  end
end

local COMMANDS = {
  ["c"] = Journalator.SlashCmd.Config,
  ["config"] = Journalator.SlashCmd.Config,
  ["d"] = Journalator.SlashCmd.Debug,
  ["debug"] = Journalator.SlashCmd.Debug,
  ["invest"] = Journalator.SlashCmd.InvestONator,
}
-- Handles top-level slash command input for the Journalator addon.
-- Dispatches the first token as a subcommand, passing remaining tokens as arguments.
-- If `input` is empty, toggles the Journalator view if available or shows a disabled message.
-- @param input The raw command string provided after the slash command (may be empty).
function Journalator.SlashCmd.Handler(input)
  if input == "" then
    if Journalator.ToggleView then
      Journalator.ToggleView()
    else
      Journalator.Utilities.Message(JOURNALATOR_L_DISPLAY_DISABLED)
    end
    return
  end

  local split = {strsplit("\a", (input:gsub("%s+","\a")))}

  local root = split[1]
  if COMMANDS[root] ~= nil then
    table.remove(split, 1)
    COMMANDS[root](unpack(split))
  else
    Journalator.Utilities.Message("Unknown command '" .. root .. "'")
  end
end