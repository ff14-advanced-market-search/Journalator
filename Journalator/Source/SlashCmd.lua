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

function Journalator.SlashCmd.Debug(...)
  Journalator.Config.Set(Journalator.Config.Options.DEBUG, not Journalator.Config.Get(Journalator.Config.Options.DEBUG))
  if Journalator.Config.Get(Journalator.Config.Options.DEBUG) then
    Journalator.Utilities.Message("Debug mode on")
  else
    Journalator.Utilities.Message("Debug mode off")
  end
end

local COMMANDS = {
  ["c"] = Journalator.SlashCmd.Config,
  ["config"] = Journalator.SlashCmd.Config,
  ["d"] = Journalator.SlashCmd.Debug,
  ["debug"] = Journalator.SlashCmd.Debug,
  ["invest"] = function(sub, ...)
    local cmd = sub or ""
    if cmd == "" or cmd == "help" then
      Journalator.Utilities.Message("Invest commands: create <name> <perItemBudget>, delete <name>, addids <name> <id,id,...>, addnames <name> <name|name|...>, setbudget <name> <amount>, list")
      return
    end

    if cmd == "create" then
      local name = ...
      local budgetText
      if select("#", ...) >= 2 then
        local arr = {...}
        name = arr[1]
        budgetText = arr[2]
      end
      if not name then
        Journalator.Utilities.Message("Usage: /jnr invest create <name> <perItemBudget>")
        return
      end
      local copper = Journalator.Investing.ParseMoney(budgetText or "0")
      Journalator.Investing.CreateGroup(name, copper)
      return
    end

    if cmd == "delete" then
      local name = ...
      if not name then
        Journalator.Utilities.Message("Usage: /jnr invest delete <name>")
        return
      end
      Journalator.Investing.DeleteGroup(name)
      return
    end

    if cmd == "addids" then
      local name, idsCsv = ...
      if not name or not idsCsv then
        Journalator.Utilities.Message("Usage: /jnr invest addids <name> <id,id,...>")
        return
      end
      local ids = {}
      for token in string.gmatch(idsCsv, "[^,]+") do
        table.insert(ids, token)
      end
      Journalator.Investing.AddIDs(name, ids)
      return
    end

    if cmd == "addnames" then
      local name, namesJoined = ...
      if not name or not namesJoined then
        Journalator.Utilities.Message("Usage: /jnr invest addnames <name> <name|name|...>")
        return
      end
      local names = {}
      for token in string.gmatch(namesJoined, "[^|]+") do
        table.insert(names, token)
      end
      Journalator.Investing.AddNames(name, names)
      return
    end

    if cmd == "setbudget" then
      local name, amountText = ...
      if not name or not amountText then
        Journalator.Utilities.Message("Usage: /jnr invest setbudget <name> <amount>")
        return
      end
      local copper = Journalator.Investing.ParseMoney(amountText)
      Journalator.Investing.SetPerItemBudget(name, copper)
      return
    end

    if cmd == "list" then
      Journalator.Investing.ListGroups()
      return
    end

    Journalator.Utilities.Message("Unknown invest command: " .. tostring(cmd))
  end,
}
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
