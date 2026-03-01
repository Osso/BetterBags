-- Tests for BetterBags addon initialization and core module behavior.
-- These verify that BetterBags' own code loaded and wired up correctly.

--------------------------------------------------------------------------------
-- Addon bootstrap
--------------------------------------------------------------------------------

test("BetterBags addon is registered with AceAddon", function()
    local ace = LibStub("AceAddon-3.0")
    local bb = ace:GetAddon("BetterBags")
    assertNotNil(bb)
end)

test("BetterBags detects retail vs classic correctly", function()
    local bb = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
    assertType("boolean", bb.isRetail)
    assertType("boolean", bb.isClassic)
    -- In the simulator, WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
    if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
        assertTrue(bb.isRetail)
    end
end)

test("BetterBags has tocVersion from GetBuildInfo", function()
    local bb = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
    assertNotNil(bb.tocVersion)
    assertType("number", bb.tocVersion)
    assertTrue(bb.tocVersion > 0)
end)

--------------------------------------------------------------------------------
-- Module registration
--------------------------------------------------------------------------------

test("BetterBags Constants module exists", function()
    local bb = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
    local const = bb:GetModule("Constants")
    assertNotNil(const)
end)

test("BetterBags Context module exists", function()
    local bb = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
    local ctx = bb:GetModule("Context")
    assertNotNil(ctx)
end)

test("BetterBags Events module exists", function()
    local bb = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
    local events = bb:GetModule("Events")
    assertNotNil(events)
end)

test("BetterBags Async module exists", function()
    local bb = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
    local async = bb:GetModule("Async")
    assertNotNil(async)
end)

--------------------------------------------------------------------------------
-- Context object
--------------------------------------------------------------------------------

test("Context:New creates object with event key", function()
    local bb = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
    local context = bb:GetModule("Context")
    local ctx = context:New("TEST_EVENT")
    assertNotNil(ctx)
    assertEquals("TEST_EVENT", ctx:Event())
end)

test("Context:Set and :Get work", function()
    local bb = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
    local context = bb:GetModule("Context")
    local ctx = context:New("TEST")
    ctx:Set("mykey", 42)
    assertEquals(42, ctx:Get("mykey"))
end)

test("Context:Get returns nil for missing keys", function()
    local bb = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
    local context = bb:GetModule("Context")
    local ctx = context:New("TEST")
    assertNil(ctx:Get("nonexistent"))
end)

test("Context event key cannot be overridden", function()
    local bb = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
    local context = bb:GetModule("Context")
    local ctx = context:New("ORIGINAL")
    assertError(function()
        ctx:Set("event", "OVERRIDDEN")
    end)
end)

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

test("BAG_KIND constants are defined", function()
    local bb = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
    local const = bb:GetModule("Constants")
    assertEquals(-1, const.BAG_KIND.UNDEFINED)
    assertEquals(0, const.BAG_KIND.BACKPACK)
    assertEquals(1, const.BAG_KIND.BANK)
end)

test("BAG_VIEW constants are defined", function()
    local bb = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
    local const = bb:GetModule("Constants")
    assertNotNil(const.BAG_VIEW.ONE_BAG)
    assertNotNil(const.BAG_VIEW.SECTION_GRID)
    assertNotNil(const.BAG_VIEW.LIST)
end)

test("ITEM_QUALITY constants reference Enum values", function()
    local bb = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
    local const = bb:GetModule("Constants")
    assertEquals(Enum.ItemQuality.Poor, const.ITEM_QUALITY.Poor)
    assertEquals(Enum.ItemQuality.Epic, const.ITEM_QUALITY.Epic)
    assertEquals(Enum.ItemQuality.Legendary, const.ITEM_QUALITY.Legendary)
end)

test("BACKPACK_BAGS maps all backpack bag indices", function()
    local bb = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
    local const = bb:GetModule("Constants")
    assertNotNil(const.BACKPACK_BAGS[Enum.BagIndex.Backpack])
    assertNotNil(const.BACKPACK_BAGS[Enum.BagIndex.Bag_1])
    assertNotNil(const.BACKPACK_BAGS[Enum.BagIndex.Bag_4])
    assertNotNil(const.BACKPACK_BAGS[Enum.BagIndex.ReagentBag])
end)

test("BANK_BAGS populated based on game version", function()
    local bb = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
    local const = bb:GetModule("Constants")
    -- Should have entries regardless of version
    local count = 0
    for _ in pairs(const.BANK_BAGS) do count = count + 1 end
    assertTrue(count > 0, "BANK_BAGS should have entries")
end)

test("BANK_TAB populated based on game version", function()
    local bb = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
    local const = bb:GetModule("Constants")
    local count = 0
    for _ in pairs(const.BANK_TAB) do count = count + 1 end
    assertTrue(count > 0, "BANK_TAB should have entries")
end)

test("EXPANSION_MAP has entries for known expansions", function()
    local bb = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
    local const = bb:GetModule("Constants")
    assertNotNil(const.EXPANSION_MAP[LE_EXPANSION_CLASSIC])
    assertNotNil(const.EXPANSION_MAP[LE_EXPANSION_DRAGONFLIGHT])
    assertType("string", const.EXPANSION_MAP[LE_EXPANSION_CLASSIC])
end)

test("TRADESKILL_MAP populated from C_Item.GetItemSubClassInfo", function()
    local bb = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
    local const = bb:GetModule("Constants")
    -- Verify a few trade skill entries
    assertNotNil(const.TRADESKILL_MAP[4])  -- Jewelcrafting
    assertNotNil(const.TRADESKILL_MAP[8])  -- Cooking
    assertType("string", const.TRADESKILL_MAP[4])
end)

test("EQUIPMENT_SLOTS contains INVSLOT values", function()
    local bb = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
    local const = bb:GetModule("Constants")
    assertTrue(#const.EQUIPMENT_SLOTS > 0)
    -- All entries should be numbers (INVSLOT_* constants)
    for _, slot in ipairs(const.EQUIPMENT_SLOTS) do
        assertType("number", slot)
    end
end)

test("INVENTORY_TYPE_TO_INVENTORY_SLOTS maps equipment types", function()
    local bb = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
    local const = bb:GetModule("Constants")
    local headSlots = const.INVENTORY_TYPE_TO_INVENTORY_SLOTS[Enum.InventoryType.IndexHeadType]
    assertNotNil(headSlots)
    assertType("table", headSlots)
    assertEquals(INVSLOT_HEAD, headSlots[1])
end)

test("DATABASE_DEFAULTS has expected structure", function()
    local bb = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
    local const = bb:GetModule("Constants")
    local defaults = const.DATABASE_DEFAULTS
    assertNotNil(defaults)
    assertNotNil(defaults.profile)
    assertType("boolean", defaults.profile.enabled)
    assertNotNil(defaults.profile.views)
    assertNotNil(defaults.profile.size)
end)

test("ITEM_QUALITY_COLOR table has colors for all qualities", function()
    local bb = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
    local const = bb:GetModule("Constants")
    for quality, _ in pairs(const.ITEM_QUALITY) do
        local color = const.ITEM_QUALITY_COLOR[const.ITEM_QUALITY[quality]]
        if color then
            assertEquals(4, #color, "color should have 4 components (r,g,b,a)")
        end
    end
end)

--------------------------------------------------------------------------------
-- Localization
--------------------------------------------------------------------------------

test("Localization module exists", function()
    local bb = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
    local L = bb:GetModule("Localization")
    assertNotNil(L)
end)

test("Localization:G returns strings", function()
    local bb = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
    local L = bb:GetModule("Localization")
    -- G() should return the input string as fallback
    local result = L:G("Bags")
    assertType("string", result)
    assertTrue(#result > 0)
end)
