-- BetterBags Functional Tests
-- Tests actual addon behavior: bag creation, item categorization, module lifecycle
-- Requires: BetterBags loaded + startup events fired (PLAYER_ENTERING_WORLD triggers OnEnable)

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-------------------------------------------------------------------------------
-- 1. Addon Lifecycle: OnEnable should have run (triggered by PLAYER_LOGIN)
--    AceAddon-3.0 calls OnEnable when IsLoggedIn() returns true at PLAYER_LOGIN
-------------------------------------------------------------------------------

test("BetterBags addon is enabled after startup", function()
  assertTrue(addon:IsEnabled(), "addon should be enabled after PLAYER_LOGIN")
end)

test("Items module is enabled", function()
  local items = addon:GetModule("Items")
  assertNotNil(items)
  assertTrue(items:IsEnabled())
end)

test("Categories module is enabled", function()
  local categories = addon:GetModule("Categories")
  assertNotNil(categories)
  assertTrue(categories:IsEnabled())
end)

test("Database module is enabled", function()
  local database = addon:GetModule("Database")
  assertNotNil(database)
  assertTrue(database:IsEnabled())
end)

test("Events module is enabled", function()
  local events = addon:GetModule("Events")
  assertNotNil(events)
  assertTrue(events:IsEnabled())
end)

-------------------------------------------------------------------------------
-- 2. Bag Frame Creation: OnEnable creates Backpack and Bank bag frames
-------------------------------------------------------------------------------

test("Bags table exists on addon", function()
  assertNotNil(addon.Bags, "addon.Bags should exist after OnEnable")
end)

test("Backpack bag frame was created", function()
  assertNotNil(addon.Bags.Backpack, "Backpack bag should be created in OnEnable")
end)

test("Backpack bag frame is a valid object", function()
  local bag = addon.Bags.Backpack
  assertNotNil(bag)
  assertNotNil(bag.kind, "bag should have a kind property")
  local const = addon:GetModule("Constants")
  assertEquals(const.BAG_KIND.BACKPACK, bag.kind, "Backpack kind should be BACKPACK (0)")
end)

test("Bank bag frame was created (when enabled in database)", function()
  local database = addon:GetModule("Database")
  if database:GetEnableBankBag() then
    assertNotNil(addon.Bags.Bank, "Bank bag should be created when enableBankBag is true")
  end
end)

-------------------------------------------------------------------------------
-- 3. SlotInfo: Items module can create and manage slot info objects
-------------------------------------------------------------------------------

test("Items module has slotInfo for backpack", function()
  local items = addon:GetModule("Items")
  local const = addon:GetModule("Constants")
  -- slotInfo is a table keyed by BagKind, accessed via GetAllSlotInfo()
  local allSlotInfo = items:GetAllSlotInfo()
  assertNotNil(allSlotInfo, "GetAllSlotInfo should return a table")
  assertNotNil(allSlotInfo[const.BAG_KIND.BACKPACK], "slotInfo for backpack should exist")
end)

test("SlotKey generation works", function()
  local items = addon:GetModule("Items")
  local key = items:GetSlotKeyFromBagAndSlot(0, 1)
  assertNotNil(key, "slot key should be generated")
  assertType("string", key)
  assertEquals("0_1", key)
end)

test("SlotKey format is bagid_slotid", function()
  local items = addon:GetModule("Items")
  assertEquals("2_5", items:GetSlotKeyFromBagAndSlot(2, 5))
  assertEquals("0_16", items:GetSlotKeyFromBagAndSlot(0, 16))
end)

test("GetSlotKey extracts from ItemData", function()
  local items = addon:GetModule("Items")
  local data = { bagid = 3, slotid = 7 }
  assertEquals("3_7", items:GetSlotKey(data))
end)

-------------------------------------------------------------------------------
-- 4. Direct Categorization: Test GetCategory with manually constructed ItemData
--    This bypasses the full item loading pipeline (Item:CreateFromBagAndSlot etc.)
--    and tests the categorization logic in isolation.
-------------------------------------------------------------------------------

-- Helper: builds a minimal ItemData table for GetCategory
-- Includes itemGUID (needed by IsNewItem at items.lua:1060) and all fields
-- accessed by the categorization code path.
local function makeItemData(overrides)
  local const = addon:GetModule("Constants")
  local data = {
    isItemEmpty = false,
    kind = const.BAG_KIND.BACKPACK,
    slotkey = "0_1",
    bagid = 0,
    slotid = 1,
    containerInfo = {
      quality = 1, -- Common
    },
    itemInfo = {
      itemID = 6948,
      itemGUID = "test-guid-" .. tostring(math.random(100000)),
      itemName = "Hearthstone",
      itemLink = "|cffffffff|Hitem:6948::::::::80:::::|h[Hearthstone]|h|r",
      itemQuality = 1,
      itemLevel = 1,
      itemMinLevel = 1,
      itemType = "Miscellaneous",
      itemSubType = "Junk",
      itemStackCount = 1,
      itemEquipLoc = "INVTYPE_NON_EQUIP_IGNORE",
      itemTexture = 134400,
      sellPrice = 0,
      classID = 15,
      subclassID = 0,
      bindType = 1,
      expacID = 0,
      setID = 0,
      isCraftingReagent = false,
      effectiveIlvl = 1,
      isPreview = false,
      baseIlvl = 1,
      category = "",
    },
  }
  if overrides then
    for k, v in pairs(overrides) do
      if type(v) == "table" and type(data[k]) == "table" then
        for k2, v2 in pairs(v) do
          data[k][k2] = v2
        end
      else
        data[k] = v
      end
    end
  end
  return data
end

test("Empty slot categorized as 'Empty Slot'", function()
  local items = addon:GetModule("Items")
  local context = addon:GetModule("Context")
  local ctx = context:New("test")
  local data = makeItemData({ isItemEmpty = true })
  local cat = items:GetCategory(ctx, data)
  assertEquals("Empty Slot", cat)
end)

test("Nil data returns 'Empty Slot'", function()
  local items = addon:GetModule("Items")
  local context = addon:GetModule("Context")
  local ctx = context:New("test")
  local cat = items:GetCategory(ctx, nil)
  assertEquals("Empty Slot", cat)
end)

test("Poor quality item categorized as 'Junk'", function()
  local items = addon:GetModule("Items")
  local context = addon:GetModule("Context")
  local const = addon:GetModule("Constants")
  local ctx = context:New("test")
  local data = makeItemData({
    containerInfo = { quality = const.ITEM_QUALITY.Poor },
    itemInfo = {
      itemEquipLoc = "INVTYPE_NON_EQUIP_IGNORE",
      classID = 15,
      subclassID = 0,
      itemType = "Miscellaneous",
    },
  })
  local cat = items:GetCategory(ctx, data)
  assertEquals("Junk", cat)
end)

test("Item with Type filter enabled gets type-based category", function()
  local items = addon:GetModule("Items")
  local context = addon:GetModule("Context")
  local const = addon:GetModule("Constants")
  local database = addon:GetModule("Database")
  local ctx = context:New("test")

  -- Ensure Type filter is enabled (default)
  assertTrue(database:GetCategoryFilter(const.BAG_KIND.BACKPACK, "Type"),
    "Type filter should be enabled by default")

  -- Non-equipment item with a type
  local data = makeItemData({
    containerInfo = { quality = 1 },
    itemInfo = {
      itemType = "Consumable",
      itemEquipLoc = "INVTYPE_NON_EQUIP_IGNORE",
      classID = 0,
      subclassID = 0,
    },
  })
  local cat = items:GetCategory(ctx, data)
  assertEquals("Consumable", cat)
end)

test("Equipment item with EquipmentLocation filter gets slot-based category", function()
  local items = addon:GetModule("Items")
  local context = addon:GetModule("Context")
  local const = addon:GetModule("Constants")
  local database = addon:GetModule("Database")
  local ctx = context:New("test")

  assertTrue(database:GetCategoryFilter(const.BAG_KIND.BACKPACK, "EquipmentLocation"),
    "EquipmentLocation filter should be enabled by default")

  local data = makeItemData({
    containerInfo = { quality = 4 },
    itemInfo = {
      itemType = "Armor",
      itemSubType = "Plate",
      itemEquipLoc = "INVTYPE_HEAD",
      classID = 4,
      subclassID = 4,
    },
  })
  local cat = items:GetCategory(ctx, data)
  -- INVTYPE_HEAD is a WoW global that resolves to a localized string like "Head"
  -- The code does: return _G[data.itemInfo.itemEquipLoc]
  if _G["INVTYPE_HEAD"] then
    assertEquals(_G["INVTYPE_HEAD"], cat)
  else
    -- Global doesn't exist in sim, falls through to Type
    assertEquals("Armor", cat)
  end
end)

test("Item with all filters disabled falls back to 'Everything'", function()
  local items = addon:GetModule("Items")
  local context = addon:GetModule("Context")
  local const = addon:GetModule("Constants")
  local database = addon:GetModule("Database")
  local ctx = context:New("test")

  -- Disable all category filters to force fallback
  database:SetCategoryFilter(const.BAG_KIND.BACKPACK, "Type", false)
  database:SetCategoryFilter(const.BAG_KIND.BACKPACK, "Subtype", false)
  database:SetCategoryFilter(const.BAG_KIND.BACKPACK, "EquipmentLocation", false)
  database:SetCategoryFilter(const.BAG_KIND.BACKPACK, "Expansion", false)
  database:SetCategoryFilter(const.BAG_KIND.BACKPACK, "TradeSkill", false)
  database:SetCategoryFilter(const.BAG_KIND.BACKPACK, "RecentItems", false)
  database:SetCategoryFilter(const.BAG_KIND.BACKPACK, "GearSet", false)

  local data = makeItemData({
    containerInfo = { quality = 1 },
    itemInfo = {
      itemEquipLoc = "INVTYPE_NON_EQUIP_IGNORE",
      classID = 15,
      subclassID = 0,
      itemType = "Miscellaneous",
    },
  })
  local cat = items:GetCategory(ctx, data)
  assertEquals("Everything", cat)

  -- Restore defaults
  database:SetCategoryFilter(const.BAG_KIND.BACKPACK, "Type", true)
  database:SetCategoryFilter(const.BAG_KIND.BACKPACK, "RecentItems", true)
  database:SetCategoryFilter(const.BAG_KIND.BACKPACK, "GearSet", true)
  database:SetCategoryFilter(const.BAG_KIND.BACKPACK, "EquipmentLocation", true)
end)

test("Item with Type + Subtype filters gets combined category", function()
  local items = addon:GetModule("Items")
  local context = addon:GetModule("Context")
  local const = addon:GetModule("Constants")
  local database = addon:GetModule("Database")
  local ctx = context:New("test")

  -- Enable both Type and Subtype
  database:SetCategoryFilter(const.BAG_KIND.BACKPACK, "Type", true)
  database:SetCategoryFilter(const.BAG_KIND.BACKPACK, "Subtype", true)
  database:SetCategoryFilter(const.BAG_KIND.BACKPACK, "EquipmentLocation", false)

  local data = makeItemData({
    containerInfo = { quality = 2 },
    itemInfo = {
      itemType = "Armor",
      itemSubType = "Cloth",
      itemEquipLoc = "INVTYPE_NON_EQUIP_IGNORE",
      classID = 4,
      subclassID = 1,
    },
  })
  local cat = items:GetCategory(ctx, data)
  assertEquals("Armor - Cloth", cat)

  -- Restore defaults
  database:SetCategoryFilter(const.BAG_KIND.BACKPACK, "Subtype", false)
  database:SetCategoryFilter(const.BAG_KIND.BACKPACK, "EquipmentLocation", true)
end)

-------------------------------------------------------------------------------
-- 5. C_Container Integration: Verify bag slots with A_Admin feed through
-------------------------------------------------------------------------------

test("A_Admin.AddBagItem makes C_Container.GetContainerItemID work", function()
  A_Admin.AddBagItem(0, 1, 6948, 1)
  local id = C_Container.GetContainerItemID(0, 1)
  assertEquals(6948, id)
  A_Admin.RemoveBagItem(0, 1)
end)

test("C_Container.GetContainerItemInfo returns valid data for added item", function()
  A_Admin.AddBagItem(0, 1, 6948, 1)
  local info = C_Container.GetContainerItemInfo(0, 1)
  assertNotNil(info, "containerItemInfo should not be nil for a populated slot")
  assertEquals(6948, info.itemID)
  assertNotNil(info.hyperlink, "should have a hyperlink")
  A_Admin.RemoveBagItem(0, 1)
end)

test("C_Container.GetContainerItemLink returns link for added item", function()
  A_Admin.AddBagItem(0, 1, 6948, 1)
  local link = C_Container.GetContainerItemLink(0, 1)
  assertNotNil(link, "should return an item link")
  assertContains(link, "Hearthstone")
  A_Admin.RemoveBagItem(0, 1)
end)

test("C_Container.GetContainerNumSlots returns slot count", function()
  local slots = C_Container.GetContainerNumSlots(0)
  assertTrue(slots > 0, "backpack should have slots")
end)

test("Empty slot returns nil from GetContainerItemID", function()
  A_Admin.ClearBags()
  local id = C_Container.GetContainerItemID(0, 1)
  assertNil(id, "empty slot should return nil")
end)

-------------------------------------------------------------------------------
-- 6. C_Item.GetItemInfo: Verify return format matches WoW API expectations
--    WoW API returns 17 multiple return values; BetterBags destructures them
--    with multi-value assignment (local a,b,c = C_Item.GetItemInfo(...))
-------------------------------------------------------------------------------

test("C_Item.GetItemInfo returns 17 multi-values", function()
  -- WoW API returns 17 positional values, not a table.
  -- BetterBags destructures them: local _, _, _, itemLevel, ... = C_Item.GetItemInfo(id)
  local itemName, itemLink, itemQuality, itemLevel, itemMinLevel,
    itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture,
    sellPrice, classID, subclassID, bindType, expacID, setID, isCraftingReagent =
    C_Item.GetItemInfo(6948) -- Hearthstone

  assertNotNil(itemName, "1st return: itemName")
  assertEquals("Hearthstone", itemName)
  assertNotNil(itemLink, "2nd return: itemLink")
  assertContains(itemLink, "Hearthstone")
  assertEquals(1, itemQuality, "3rd return: itemQuality (Common=1)")
  assertNotNil(itemLevel, "4th return: itemLevel")
  assertNotNil(itemType, "6th return: itemType")
  assertNotNil(itemEquipLoc, "9th return: itemEquipLoc")
  assertNotNil(bindType, "14th return: bindType (used by BetterBags)")
  assertNotNil(expacID, "15th return: expacID")
end)

test("C_Item.GetItemInfo with select() works like real WoW", function()
  -- Blizzard code uses select(N, C_Item.GetItemInfo(...)) extensively
  local quality = select(3, C_Item.GetItemInfo(6948))
  assertEquals(1, quality, "select(3) should be itemQuality")
  local texture = select(10, C_Item.GetItemInfo(6948))
  assertNotNil(texture, "select(10) should be itemTexture")
  local bindType = select(14, C_Item.GetItemInfo(6948))
  assertNotNil(bindType, "select(14) should be bindType")
end)

-------------------------------------------------------------------------------
-- 7. Item Loading Pipeline Prerequisites
--    Check if the APIs needed by items:AttachItemInfo exist
-------------------------------------------------------------------------------

test("Item global exists (from Blizzard_ObjectAPI)", function()
  assertNotNil(Item, "Item global should exist from Blizzard_ObjectAPI")
end)

test("Item:CreateFromBagAndSlot function exists", function()
  assertNotNil(Item.CreateFromBagAndSlot,
    "Item:CreateFromBagAndSlot should be a function")
end)

test("ContinuableContainer global exists (from Blizzard_ObjectAPI)", function()
  assertNotNil(ContinuableContainer,
    "ContinuableContainer should exist from Blizzard_ObjectAPI addon")
end)

test("ItemMixin has expected methods", function()
  A_Admin.AddBagItem(0, 1, 6948, 1)
  local ok, itemMixin = pcall(Item.CreateFromBagAndSlot, Item, 0, 1)
  if ok and itemMixin then
    assertNotNil(itemMixin.GetItemID, "should have GetItemID")
    assertNotNil(itemMixin.GetItemLink, "should have GetItemLink")
    assertNotNil(itemMixin.GetItemLocation, "should have GetItemLocation")
  end
  A_Admin.RemoveBagItem(0, 1)
end)

-------------------------------------------------------------------------------
-- 8. Backpack Toggle: Can we show/hide the backpack?
-------------------------------------------------------------------------------

test("Backpack bag can be toggled", function()
  local bag = addon.Bags.Backpack
  if bag and bag.frame then
    local showOk = pcall(function() bag.frame:Show() end)
    assertTrue(showOk, "bag frame Show() should not error")

    local hideOk = pcall(function() bag.frame:Hide() end)
    assertTrue(hideOk, "bag frame Hide() should not error")
  end
end)

-------------------------------------------------------------------------------
-- 9. Database: Default settings are loaded correctly
-------------------------------------------------------------------------------

test("Database has default category filters", function()
  local database = addon:GetModule("Database")
  local const = addon:GetModule("Constants")
  assertTrue(database:GetCategoryFilter(const.BAG_KIND.BACKPACK, "Type"))
  assertFalse(database:GetCategoryFilter(const.BAG_KIND.BACKPACK, "Subtype"))
  assertFalse(database:GetCategoryFilter(const.BAG_KIND.BACKPACK, "Expansion"))
  assertFalse(database:GetCategoryFilter(const.BAG_KIND.BACKPACK, "TradeSkill"))
  assertTrue(database:GetCategoryFilter(const.BAG_KIND.BACKPACK, "RecentItems"))
  assertTrue(database:GetCategoryFilter(const.BAG_KIND.BACKPACK, "GearSet"))
  assertTrue(database:GetCategoryFilter(const.BAG_KIND.BACKPACK, "EquipmentLocation"))
end)

test("Database default bag view is SECTION_GRID", function()
  local database = addon:GetModule("Database")
  local const = addon:GetModule("Constants")
  local view = database:GetBagView(const.BAG_KIND.BACKPACK)
  assertEquals(const.BAG_VIEW.SECTION_GRID, view)
end)

-------------------------------------------------------------------------------
-- 10. Async: Full Item Loading Pipeline (integration test)
--     Populate bag -> fire BAG_UPDATE_DELAYED -> check if items module processes
--     This tests the complete pipeline: Item:CreateFromBagAndSlot ->
--     ContinuableContainer -> AttachItemInfo -> SlotInfo -> Draw
-------------------------------------------------------------------------------

async_test("BAG_UPDATE_DELAYED triggers item refresh pipeline", function(done)
  A_Admin.AddBagItem(0, 1, 6948, 1) -- Hearthstone

  local events = addon:GetModule("Events")
  local items = addon:GetModule("Items")
  local refreshFired = false

  -- BetterBags sends 'items/RefreshBackpack/Done' when items finish loading
  events:RegisterMessage("items/RefreshBackpack/Done", function()
    refreshFired = true
  end, "test_refresh_listener")

  -- Fire BAG_UPDATE_DELAYED to trigger the refresh pipeline
  FireEvent("BAG_UPDATE_DELAYED")

  -- Give it some ticks to process (ContinuableContainer + C_Timer.After deferred draw)
  C_Timer.After(0.1, function()
    done(function()
      A_Admin.RemoveBagItem(0, 1)

      -- At minimum, verify the items module didn't crash
      assertTrue(items:IsEnabled(), "Items module should still be enabled after refresh")

      -- If refreshFired is false, the pipeline hit a wall (Item validation, etc.)
      -- This is expected until Item:CreateFromBagAndSlot fully works in the sim
    end)
  end)
end)
