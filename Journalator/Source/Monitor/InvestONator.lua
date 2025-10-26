---@class JournalatorMonitorInvestONatorMixin
JournalatorMonitorInvestONatorMixin = {}

---Initialize the Invest-O-Nator monitor
-- Initializes the mixin and registers auction-related events used to monitor purchases.
-- Registers the following events: AUCTION_HOUSE_BROWSE_RESULT_UPDATED, AUCTION_HOUSE_CLOSED, and ITEM_PURCHASED.
function JournalatorMonitorInvestONatorMixin:OnLoad()
  local safeRegister = function(eventName)
    -- Some events don't exist on certain clients/patch levels
    local ok = pcall(self.RegisterEvent, self, eventName)
    if not ok then
      -- Silently ignore unsupported events
      return
    end
  end

  safeRegister("ITEM_PURCHASED")
  -- Retail-only events; guard registration
  safeRegister("AUCTION_HOUSE_BROWSE_RESULT_UPDATED")
  safeRegister("AUCTION_HOUSE_CLOSED")
end

---Handle events for the Invest-O-Nator monitor
---@param eventName string The name of the event
-- Dispatches incoming events to the mixin's handlers; forwards `ITEM_PURCHASED` events to OnItemPurchased.
-- @param eventName string The name of the event being delivered.
-- @param ... any Event-specific arguments forwarded to the handler (passed through to OnItemPurchased for `ITEM_PURCHASED`).
function JournalatorMonitorInvestONatorMixin:OnEvent(eventName, ...)
  if eventName == "ITEM_PURCHASED" then
    self:OnItemPurchased(...)
  elseif eventName == "AUCTION_HOUSE_BROWSE_RESULT_UPDATED" then
    -- Placeholder: browse results updated. Hook here if we need to react to AH scans.
    -- Intentionally no-op for now to match registered event.
    return
  elseif eventName == "AUCTION_HOUSE_CLOSED" then
    -- Placeholder: AH closed. Use this to clear transient state if added in future.
    -- Intentionally no-op for now to match registered event.
    return
  end
end

---Handle item purchase events and update portfolio tracking
---@param itemID number The ID of the purchased item
---@param itemLink string The item link
---@param quantity number The quantity purchased
-- Handle an ITEM_PURCHASED event: record the purchase against any Invest-O-Nator portfolios that contain the item and notify the user.
-- For each matching portfolio the function records the purchase, formats the total cost and remaining budget, and emits a user-facing message.
-- @param itemID number The numeric item identifier.
-- @param itemLink string|nil The item link string (may be nil or unused).
-- @param quantity number The number of units purchased (must be > 0).
-- @param price number The price per unit in copper (must be > 0).
function JournalatorMonitorInvestONatorMixin:OnItemPurchased(itemID, itemLink, quantity, price)
  -- Validate input parameters
  if not itemID or not quantity or not price or quantity <= 0 or price <= 0 then
    return
  end
  
  -- Check if this item is in any investment portfolio
  local portfolios = Journalator.InvestONator.GetAllPortfolios()
  
  -- Early exit if no portfolios exist
  if not portfolios or next(portfolios) == nil then
    return
  end
  
  local totalAmount = price * quantity
  local itemName = GetItemInfo(itemID) or "Unknown Item"
  
  for portfolioId, portfolio in pairs(portfolios) do
    if portfolio.items[itemID] then
      -- Record the purchase
      if Journalator.InvestONator.RecordPurchase(portfolioId, itemID, totalAmount, price, quantity) then
        -- Re-fetch updated item data after mutation to get fresh remaining amount
        local updatedPortfolio = Journalator.InvestONator.GetPortfolio and Journalator.InvestONator.GetPortfolio(portfolioId) or portfolio
        local updatedItem = updatedPortfolio and updatedPortfolio.items and updatedPortfolio.items[itemID]
        local remainingCopper = updatedItem and updatedItem.remainingAmount or 0
        local remaining = Journalator.InvestONator.FormatGold(remainingCopper)

        Journalator.Utilities.Message(string.format(
          "Invest-o-nator: Purchased %dx %s for %s. Remaining budget: %s",
          quantity,
          itemName,
          Journalator.InvestONator.FormatGold(totalAmount),
          remaining
        ))
      end
    end
  end
end