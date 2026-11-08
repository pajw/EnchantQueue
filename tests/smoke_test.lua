-- Loads the whole addon against a stubbed WoW API and drives one flow in mode A.
-- This catches nil errors and wiring mistakes; it says nothing about taint or real API behaviour.
-- Run from the addon folder: lua5.1 tests/smoke_test.lua

-- Frame stub: any method is a no-op, but attributes, scripts, enabled/text state are recorded.
local frames = {}
local function newFrame(kind, name)
	local f = { attrs = {}, scripts = {}, enabled = true, shown = false, kind = kind }
	local methods = {
		SetAttribute = function(self, k, v) self.attrs[k] = v end,
		GetAttribute = function(self, k) return self.attrs[k] end,
		SetScript = function(self, k, fn) self.scripts[k] = fn end,
		HookScript = function(self, k, fn) self.scripts[k] = fn end,
		Enable = function(self) self.enabled = true end,
		Disable = function(self) self.enabled = false end,
		SetEnabled = function(self, v) self.enabled = v and true or false end,
		SetText = function(self, t) self.text = t end,
		GetText = function(self) return self.text end,
		Show = function(self) self.shown = true end,
		Hide = function(self) self.shown = false end,
		IsShown = function(self) return self.shown end,
		IsVisible = function(self) return self.shown end,
		IsEnabled = function(self) return self.enabled end,
		SetShown = function(self, v) self.shown = v end,
		RegisterEvent = function(self, e) rawset(self, "registered", rawget(self, "registered") or {}); self.registered[e] = true end,
		RegisterUnitEvent = function(self, e) rawset(self, "registered", rawget(self, "registered") or {}); self.registered[e] = true end,
		CreateFontString = function() return newFrame("FontString") end,
		CreateTexture = function() return newFrame("Texture") end,
		GetEffectiveScale = function(self) return rawget(self, "scale") or 1 end,
		GetLeft = function(self) return rawget(self, "left") end,
		GetRight = function(self) return rawget(self, "right") end,
		GetHeight = function(self) return rawget(self, "height") end,
		SetHeight = function(self, h) self.height = h end,
		SetPoint = function(self, ...) self.point = { ... } end,
		GetChildren = function(self) return unpack(rawget(self, "children") or {}) end,
		Click = function(self) if self.scripts.OnClick then self.scripts.OnClick(self, "LeftButton") end end,
	}
	setmetatable(f, { __index = function(_, k) return methods[k] or (k:match("^%u") and function() end or nil) end })
	if name then _G[name] = f; frames[name] = f end
	return f
end
CreateFrame = newFrame

-- World: bag 0 slot 1 holds our bracer; equipment empty.
local items = { ["bag:0:1"] = { guid = "Item-1", id = 100, link = "[Bracer]" } }
local function key(loc) return loc.equip and ("equip:" .. loc.equip) or ("bag:" .. loc.bag .. ":" .. loc.slot) end
local Loc = {}
Loc.__index = Loc
function Loc:IsValid() return true end
function Loc:IsEquipmentSlot() return self.equip ~= nil end
function Loc:GetEquipmentSlot() return self.equip end
function Loc:GetBagAndSlot() return self.bag, self.slot end
ItemLocation = {
	CreateFromBagAndSlot = function(_, b, s) return setmetatable({ bag = b, slot = s }, Loc) end,
	CreateFromEquipmentSlot = function(_, e) return setmetatable({ equip = e }, Loc) end,
}
C_Item = {
	DoesItemExist = function(l) return items[key(l)] ~= nil end,
	GetItemGUID = function(l) return items[key(l)].guid end,
	GetItemID = function(l) return items[key(l)].id end,
	GetItemLink = function(l) return items[key(l)].link end,
	GetItemIcon = function() return 1 end,
}
C_Container = { GetContainerNumSlots = function() return 4 end }
C_Spell = { GetSpellName = function(id) return ({ [7418] = "Enchant Bracer - Minor Health", [7457] = "Enchant Bracer - Minor Stamina" })[id] end }
local selected = 7418
C_TradeSkillUI = {
	GetRecipeInfo = function(id) return { recipeID = id, name = C_Spell.GetSpellName(id) } end,
	GetBaseProfessionInfo = function() return { professionID = 333 } end,
	OpenRecipe = function(id) staged.recipeID = id end,
}
-- Blizzard's Enchanting window: records what the addon stages into it.
staged = {}
Item = { CreateFromItemLocation = function(_, loc) return { loc = loc } end }
local createBtn = newFrame("Button")
-- Window spans x 0..600, scale 1.25; the tab strip hangs off the right edge (600..660).
ProfessionsFrame = newFrame("Frame")
ProfessionsFrame.scale, ProfessionsFrame.left, ProfessionsFrame.right, ProfessionsFrame.height = 1.25, 0, 600, 560
ProfessionsFrame.CraftingPage = {
	CreateButton = createBtn,
	SchematicForm = { GetTransaction = function() return { SetEnchantAllocation = function(_, item) staged.loc = item.loc end } end },
}
local function tab(left, right) local t = newFrame("Button"); t.scale, t.left, t.right, t.shown = 1.25, left, right, true; return t end
ProfessionsFrame.Professions1Tab = tab(598, 650)
ProfessionsFrame.Professions2Tab = tab(598, 660)
local nineSlice = tab(0, 600) -- full-width child: must not count as attached
ProfessionsFrame.children = { nineSlice, ProfessionsFrame.Professions1Tab, ProfessionsFrame.Professions2Tab }
C_AddOns = { IsAddOnLoaded = function() return false end }
C_Cursor = {}
EventRegistry = { RegisterCallback = function() end }
UIParent, GameTooltip, UISpecialFrames = newFrame(), newFrame(), {}
GameTooltip_Hide = function() end
SlashCmdList = {}
InCombatLockdown = function() return false end
GetTime = function() return 0 end
IsAltKeyDown = function() return false end
local hooks = {}
hooksecurefunc = function(name, fn) hooks[name] = fn end
local popup = newFrame("Frame"); popup.button1 = newFrame("Button")
StaticPopup_Show = function() end
StaticPopup_FindVisible = function() return popup end
tinsert = table.insert
issecretvalue = function() return false end
GetBuildInfo = function() return "1.16.0", "70000", "Nov 2026", 16001 end

-- Load in TOC order with a shared namespace, as the client does.
-- Core.lua's event frame is the only unnamed plain Frame, so capture it as it's created.
local eventFrame
local baseCreateFrame = CreateFrame
CreateFrame = function(kind, name, ...)
	local f = baseCreateFrame(kind, name, ...)
	if kind == "Frame" and not name and ... == nil then eventFrame = f end
	return f
end
local ns = {}
for line in io.lines("EnchantQueue.toc") do
	if line:match("%.lua$") then assert(loadfile(line))("EnchantQueue", ns) end
end
CreateFrame = baseCreateFrame
local function fire(event, ...) eventFrame.scripts.OnEvent(eventFrame, event, ...) end

local function check(cond, msg) if not cond then error("FAIL: " .. msg, 2) end print("ok  " .. msg) end

fire("ADDON_LOADED", "EnchantQueue")
fire("PLAYER_LOGIN")
local btn = frames.EnchantQueueNextButton
check(btn ~= nil, "Next button created with its binding name")
check(not btn.enabled, "Next disabled with an empty queue")

ns.SetTarget(ItemLocation:CreateFromBagAndSlot(0, 1))
check(EnchantQueueDB.queue.target.guid == "Item-1", "target stored by GUID")

ns.GetSelectedRecipeID = function() return selected end
ns.AddSelected(2)
selected = 7457
ns.AddSelected(1)
check(#EnchantQueueDB.queue.entries == 2, "two entries queued")
check(btn.enabled and btn.attrs.type == "click" and btn.attrs.clickbutton == createBtn, "Next armed to click the Enchant button")

local function press() btn.scripts.PreClick(btn, "LeftButton", true) end
press()
check(staged.recipeID == 7418 and staged.loc.bag == 0 and staged.loc.slot == 1, "press stages head recipe and bag 0 slot 1 as target")

fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 7418)
check(EnchantQueueDB.queue.entries[1].remaining == 1, "success decrements head")

-- Move the bracer to bag 2 slot 3, then equip it in the wrist slot.
items["bag:2:3"], items["bag:0:1"] = items["bag:0:1"], nil
fire("BAG_UPDATE_DELAYED"); press()
check(staged.loc.bag == 2 and staged.loc.slot == 3, "target follows the item to its new bag slot")
items["equip:9"], items["bag:2:3"] = items["bag:2:3"], nil
fire("PLAYER_EQUIPMENT_CHANGED"); press()
check(staged.loc.equip == 9, "target follows the item when equipped")

-- Replace-enchant popup: the next press clicks Yes, and staging is skipped.
hooks.StaticPopup_Show("REPLACE_TRADESKILL_ENCHANT")
check(btn.attrs.clickbutton == popup.button1 and btn.text == "Confirm replace", "replace popup arms Next to click Yes")
staged.recipeID = nil; press()
check(staged.recipeID == nil, "no staging while confirming")
popup.scripts.OnHide()
check(btn.attrs.clickbutton == createBtn, "popup closing re-arms the Enchant button")
hooks.StaticPopup_Show("SOME_OTHER_POPUP")
check(btn.attrs.clickbutton == createBtn, "unrelated popups are ignored")

-- During a cast Next is disarmed, so wheel-spam does nothing; it re-arms when the cast stops.
fire("UNIT_SPELLCAST_START", "player", "cast-2", 7418)
check(not btn.enabled and btn.attrs.type == nil and btn.text == "Casting...", "Next disarmed while casting")
staged.recipeID = nil; press()
check(staged.recipeID == nil, "no staging while casting")
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 7418)
fire("UNIT_SPELLCAST_STOP", "player", "cast-2", 7418)
check(btn.enabled and btn.attrs.clickbutton == createBtn, "Next re-armed when the cast stops")
press()
check(staged.recipeID == 7457, "advances to the next recipe")

items["equip:9"] = nil
fire("PLAYER_EQUIPMENT_CHANGED")
check(not btn.enabled, "Next disabled when the target item is gone")

-- Combat defers attribute changes.
items["equip:9"] = { guid = "Item-1", id = 100, link = "[Bracer]" }
InCombatLockdown = function() return true end
fire("PLAYER_EQUIPMENT_CHANGED")
check(not btn.enabled, "no attribute changes during combat")
InCombatLockdown = function() return false end
fire("PLAYER_REGEN_ENABLED")
check(btn.enabled, "deferred prepare runs when combat ends")

-- Docking: tab strip ends at 660 * 1.25 = 825 screen px, window edge at 750; panel scale 1.
local panel = EnchantQueueFrame
fire("TRADE_SKILL_SHOW")
check(panel.shown, "panel shown when Enchanting opens")
check(panel.point[2] == ProfessionsFrame and panel.point[3] == "TOPRIGHT" and panel.point[4] == 81 and panel.point[5] == 0,
	"docked right of the profession tabs, top-aligned")
check(panel.height == 700, "panel height matches the Professions window")
check(ns.UI.dock.method == "profession tabs", "tabs found by name")

ProfessionsFrame.Professions1Tab.shown, ProfessionsFrame.Professions2Tab.shown = false, false
local strip = tab(598, 670); ProfessionsFrame.children[#ProfessionsFrame.children + 1] = strip
fire("TRADE_SKILL_SHOW")
check(ns.UI.dock.method == "child scan" and panel.point[4] == 670 * 1.25 - 750 + 6, "falls back to scanning children")

strip.shown = false
fire("TRADE_SKILL_SHOW")
check(ns.UI.dock.method:match("^fallback") and panel.point[4] == 64 * 1.25, "fixed offset when nothing is attached")
ProfessionsFrame.Professions1Tab.shown, ProfessionsFrame.Professions2Tab.shown = true, true

InCombatLockdown = function() return true end
panel.point = nil
fire("TRADE_SKILL_SHOW")
check(panel.point == nil, "no docking in combat")
InCombatLockdown = function() return false end

SlashCmdList.ENCHANTQUEUE("status")
SlashCmdList.ENCHANTQUEUE("clear")
check(EnchantQueueDB.queue.target == nil and #EnchantQueueDB.queue.entries == 0, "/eqq clear empties the queue")
check(not btn.enabled, "Next disabled after clear")
print("smoke test passed")
