Journalator.Investing = {}

local function ensureConfig()
  if JOURNALATOR_CONFIG == nil then
    Journalator.Config.InitializeData()
  end
  if JOURNALATOR_CONFIG[Journalator.Config.Options.INVESTING_GROUPS] == nil then
    JOURNALATOR_CONFIG[Journalator.Config.Options.INVESTING_GROUPS] = {}
  end
  return JOURNALATOR_CONFIG[Journalator.Config.Options.INVESTING_GROUPS]
end

local function moneyToString(amount)
  return GetMoneyString(amount or 0, true)
end

-- Accepts strings like:
--  "100g", "2500s", "12c", "40k", "3m", "10,000g", "10000"
-- Returns copper
local function parseMoney(input)
  if type(input) ~= "string" then
    return tonumber(input) or 0
  end
  local s = input:lower():gsub(",", ""):gsub("%s+", "")
  if s == "" then return 0 end

  -- Handle plain numbers: assume gold
  if s:match("^%d+$") then
    return tonumber(s) * 10000
  end

  -- Handle k/m suffix (gold)
  local num, suffix = s:match("^(%d+)%s*([km])$")
  if num and suffix then
    local n = tonumber(num)
    if suffix == "k" then
      return n * 1000 * 10000
    else
      return n * 1000000 * 10000
    end
  end

  local g = tonumber((s:match("(%d+)g"))) or 0
  local sc = tonumber((s:match("(%d+)s"))) or 0
  local c = tonumber((s:match("(%d+)c"))) or 0

  if g > 0 or sc > 0 or c > 0 then
    return g * 10000 + sc * 100 + c
  end

  -- Fallback: try number again
  return tonumber(s) or 0
end

function Journalator.Investing.CreateGroup(name, perItemBudgetCopper)
  local groups = ensureConfig()
  if name == nil or name == "" then
    error("Group name required")
  end
  if groups[name] ~= nil then
    Journalator.Utilities.Message("Group already exists: " .. name)
    return
  end
  groups[name] = {
    perItemBudget = tonumber(perItemBudgetCopper) or 0,
    items = {}, -- keys like "id:12345" or "name:linen cloth"
    lastUpdated = time(),
  }
  Journalator.Utilities.Message("Created group '" .. name .. "' with per-item target " .. moneyToString(groups[name].perItemBudget))
end

function Journalator.Investing.DeleteGroup(name)
  local groups = ensureConfig()
  groups[name] = nil
  Journalator.Utilities.Message("Deleted group '" .. (name or "") .. "'")
end

local function normalizeID(id)
  if type(id) == "number" then return tostring(id) end
  if type(id) == "string" then
    local n = id:match("item:(%d+)") or id:match("^(%d+)$")
    if n then return n end
  end
  return nil
end

local function keyForID(id)
  local n = normalizeID(id)
  if n then return "id:" .. n end
  return nil
end

local function keyForName(name)
  if type(name) ~= "string" then return nil end
  local trimmed = name:lower():gsub("^%s+", ""):gsub("%s+$", "")
  if trimmed == "" then return nil end
  return "name:" .. trimmed
end

function Journalator.Investing.AddIDs(name, ids)
  local groups = ensureConfig()
  local g = groups[name]
  if not g then
    Journalator.Utilities.Message("Unknown group: " .. tostring(name))
    return
  end
  local added = 0
  for _, id in ipairs(ids) do
    local key = keyForID(id)
    if key then
      if not g.items[key] then added = added + 1 end
      g.items[key] = true
    end
  end
  g.lastUpdated = time()
  Journalator.Utilities.Message(("Added %d IDs to '%s'"):format(added, name))
end

function Journalator.Investing.AddNames(name, names)
  local groups = ensureConfig()
  local g = groups[name]
  if not g then
    Journalator.Utilities.Message("Unknown group: " .. tostring(name))
    return
  end
  local added = 0
  for _, n in ipairs(names) do
    local key = keyForName(n)
    if key then
      if not g.items[key] then added = added + 1 end
      g.items[key] = true
    end
  end
  g.lastUpdated = time()
  Journalator.Utilities.Message(("Added %d names to '%s'"):format(added, name))
end

function Journalator.Investing.RemoveIDs(name, ids)
  local groups = ensureConfig()
  local g = groups[name]
  if not g then
    Journalator.Utilities.Message("Unknown group: " .. tostring(name))
    return
  end
  local removed = 0
  for _, id in ipairs(ids) do
    local key = keyForID(id)
    if key and g.items[key] then
      g.items[key] = nil
      removed = removed + 1
    end
  end
  g.lastUpdated = time()
  Journalator.Utilities.Message(("Removed %d IDs from '%s'"):format(removed, name))
end

function Journalator.Investing.SetPerItemBudget(name, amount)
  local groups = ensureConfig()
  local g = groups[name]
  if not g then
    Journalator.Utilities.Message("Unknown group: " .. tostring(name))
    return
  end
  g.perItemBudget = tonumber(amount) or 0
  g.lastUpdated = time()
  Journalator.Utilities.Message("Set per-item target for '" .. name .. "' to " .. moneyToString(g.perItemBudget))
end

function Journalator.Investing.ListGroups()
  local groups = ensureConfig()
  local names = {}
  for k, _ in pairs(groups) do table.insert(names, k) end
  table.sort(names)
  for _, n in ipairs(names) do
    local g = groups[n]
    local count = 0
    for _ in pairs(g.items) do count = count + 1 end
    Journalator.Utilities.Message( ("%s: %d items, per-item target %s"):format(n, count, moneyToString(g.perItemBudget)) )
  end
end

-- Utility for slash handler
function Journalator.Investing.ParseMoney(text)
  return parseMoney(text)
end

-- Expose for display addon
function Journalator.Investing.GetConfig()
  return ensureConfig()
end
