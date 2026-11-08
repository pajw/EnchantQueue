-- Wiring: saved variables, events, slash commands, and the operations the UI calls.
local addonName, ns = ...
local Queue, Target, Cast, UI = ns.Queue, ns.Target, ns.Cast, ns.UI

local PREFIX = "|cff66bbffEnchantQueue|r:"
local ENCHANTING_SKILL_LINE = 333
local ERROR_WINDOW = 3 -- seconds after a Next press during which UI errors are shown as status

function ns.Print(...) print(PREFIX, ...) end
function ns.Debug(...) if ns.db and ns.db.debug then print(PREFIX, "|cff888888[debug]|r", ...) end end

-- Runs fn and prints any error to chat, because WoW hides Lua errors by default.
function ns.SafeCall(label, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then print(PREFIX, "|cffff4040error in " .. label .. ":|r", tostring(err)) end
	return ok
end

local lastSelectedRecipeID

-- Midnight-era "secret values": in combat some event payloads can't be compared or printed.
local function isSecret(v)
	return issecretvalue ~= nil and issecretvalue(v)
end

function ns.GetSelectedRecipeID()
	local pf = ProfessionsFrame
	local form = pf and pf.CraftingPage and pf.CraftingPage.SchematicForm
	if form and form.GetRecipeInfo then
		local info = form:GetRecipeInfo()
		if info and info.recipeID then return info.recipeID end
	end
	return lastSelectedRecipeID
end

local function isEnchantingOpen()
	local info = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
	if not info then return false end
	return info.professionID == ENCHANTING_SKILL_LINE
		or (Enum.Profession and Enum.Profession.Enchanting and info.profession == Enum.Profession.Enchanting)
end

function ns.QueueActive()
	return ns.db and ns.db.queue.target ~= nil and #ns.db.queue.entries > 0
end

function ns.CurrentHeadAndLocation()
	local q = ns.db.queue
	return Queue.Head(q), Target.Locate(q.target)
end

function ns.Refresh()
	local q = ns.db.queue
	local loc = Target.Locate(q.target)
	Cast.Prepare(Queue.Head(q), q.target, loc)
	UI.Render(q, loc ~= nil)
end

function ns.SetStatus(msg) UI.SetStatus(msg) end

function ns.SetTarget(loc)
	local q = ns.db.queue
	if loc == nil then
		q.target = nil
	else
		local t = Target.FromLocation(loc)
		if not t then ns.SetStatus("Couldn't read that item."); return end
		q.target = t
		ns.SetStatus("Target: " .. (t.link or "?"))
	end
	ns.Refresh()
end

function ns.AddSelected(count)
	local recipeID = ns.GetSelectedRecipeID()
	local info = recipeID and C_TradeSkillUI.GetRecipeInfo(recipeID)
	local entry, err = Queue.Add(ns.db.queue, recipeID, info and info.name, count)
	ns.SetStatus(entry and ("Queued " .. entry.name) or err)
	ns.Refresh()
end

function ns.RemoveEntry(i)
	Queue.Remove(ns.db.queue, i)
	ns.Refresh()
end

function ns.ClearQueue()
	Queue.Clear(ns.db.queue)
	ns.SetStatus("Queue cleared.")
	ns.Refresh()
end

local events = {}

function events.ADDON_LOADED(name)
	if name == addonName then
		EnchantQueueDB = EnchantQueueDB or {}
		ns.db = EnchantQueueDB
		ns.db.queue = ns.db.queue or Queue.New()
		if ns.db.version ~= 3 then ns.db.debug = false; ns.db.mode = nil; ns.db.version = 3 end
	elseif name == "Blizzard_Professions" then
		EventRegistry:RegisterCallback("ProfessionsRecipeListMixin.Event.OnRecipeSelected", function(_, recipeInfo)
			lastSelectedRecipeID = recipeInfo and recipeInfo.recipeID
			if ns.db then ns.Refresh() end
		end, ns)
	end
end

function events.PLAYER_LOGIN()
	ns.SafeCall("panel", UI.Init)
	ns.SafeCall("alt-click hook", UI.HookAltClick)
	ns.SafeCall("popup hook", Cast.HookPopups)
	local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
	if isLoaded("Blizzard_Professions") then events.ADDON_LOADED("Blizzard_Professions") end
	ns.SafeCall("refresh", ns.Refresh)
	ns.SafeCall("slash check", ns.checkSlashClash)
end

function events.TRADE_SKILL_SHOW()
	if isEnchantingOpen() then UI.ShowDocked() else UI.Hide() end
end

function events.TRADE_SKILL_CLOSE()
	UI.Hide()
end

-- While the player is casting, Next does nothing, so scrolling the wheel quickly is harmless.
local function setCasting(v)
	if ns.casting == v then return end
	ns.casting = v
	if ns.db then ns.Refresh() end
end
function events.UNIT_SPELLCAST_START() setCasting(true) end
function events.UNIT_SPELLCAST_STOP() setCasting(false) end
function events.UNIT_SPELLCAST_INTERRUPTED() setCasting(false) end

function events.UNIT_SPELLCAST_SUCCEEDED(_, _, spellID)
	if isSecret(spellID) then return end
	ns.Debug("cast succeeded, spellID", spellID)
	local entry = Queue.OnCastSucceeded(ns.db.queue, spellID)
	if entry then
		local left = Queue.Total(ns.db.queue)
		ns.SetStatus(entry.name .. " done. " .. (left > 0 and (left .. " left.") or "Queue finished."))
		ns.Refresh()
	end
end

function events.UNIT_SPELLCAST_FAILED(_, _, spellID)
	setCasting(false)
	if isSecret(spellID) then return end
	local head = Queue.Head(ns.db.queue)
	if head and head.recipeID == spellID then
		ns.SetStatus("|cffff4040Cast failed.|r Queue paused at " .. head.name .. ".")
	end
end

function events.UI_ERROR_MESSAGE(_, message)
	if isSecret(message) then return end
	if ns.lastPress and GetTime() - ns.lastPress < ERROR_WINDOW and message then
		ns.SetStatus("|cffff4040" .. message .. "|r")
	end
end

function events.PLAYER_REGEN_ENABLED() Cast.OnCombatEnded() end

-- Bag moves and gear swaps can change the target's location.
function events.BAG_UPDATE_DELAYED() if ns.db then ns.Refresh() end end
function events.PLAYER_EQUIPMENT_CHANGED() if ns.db then ns.Refresh() end end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, ...) ns.SafeCall(event, events[event], ...) end)
for event in pairs(events) do
	local ok = pcall(function()
		if event:find("^UNIT_") then
			frame:RegisterUnitEvent(event, "player")
		else
			frame:RegisterEvent(event)
		end
	end)
	if not ok then print(PREFIX, "|cffff4040couldn't listen for " .. event .. "|r") end
end

local function yesno(v) return v and "|cff40ff40yes|r" or "|cffff4040no|r" end

function ns.PrintStatus()
	local q = ns.db.queue
	local _, build, _, interface = GetBuildInfo()
	ns.Print("---- status ----")
	ns.Print("game interface", interface, "build", build, "| addon .toc says 16001")
	ns.Print("debug", ns.db.debug and "on" or "off", "| in combat", yesno(InCombatLockdown()))
	ns.Print("Professions window loaded", yesno(ProfessionsFrame ~= nil), "| Enchanting open", yesno(isEnchantingOpen()))
	local sel = ns.GetSelectedRecipeID()
	ns.Print("selected recipe", tostring(sel))
	local t = q.target
	ns.Print("target", t and (t.link or "?") or "none", "| found", yesno(t and Target.Locate(t) ~= nil),
		t and ("| use args " .. Target.UseArgs(t)) or "")
	for i, e in ipairs(q.entries) do ns.Print("  " .. i .. ".", e.name, "id", e.recipeID, "x" .. e.remaining) end
	local form = ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.SchematicForm
	local create = ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.CreateButton
	ns.Print("Create button found", yesno(create ~= nil), create and create.GetDebugName and ("(" .. tostring((create:GetDebugName())) .. ")") or "",
		"| enchant target slot", yesno(form and form.enchantSlot ~= nil), "shown", yesno(form and form.enchantSlot and form.enchantSlot:IsShown()))
	local d = UI.dock
	ns.Print("dock", d.method, d.x and string.format("x %.1f", d.x) or "", "| frame", tostring(UI.chrome))
	ns.Print("old-style TradeSkillFrame", yesno(TradeSkillFrame ~= nil), "| TradeSkillCreateButton", yesno(TradeSkillCreateButton ~= nil))
	local head = Queue.Head(q)
	if head then
		local spell = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(head.recipeID)
		ns.Print("next recipe id", head.recipeID, "| spell name", tostring(spell))
	end
	local b = EnchantQueueNextButton
	if b then
		ns.Print("Next button: enabled", yesno(b:IsEnabled()), "| visible", yesno(b:IsVisible()), "| type", tostring(b:GetAttribute("type")))
		ns.Print("macro:", tostring(b:GetAttribute("macrotext")))
	else
		ns.Print("Next button: |cffff4040missing|r")
	end
end

-- Warn if another addon also claims /eq (whichever registers first wins).
local function checkSlashClash()
	for key, value in pairs(_G) do
		if type(key) == "string" and key:find("^SLASH_") and not key:find("^SLASH_ENCHANTQUEUE")
			and type(value) == "string" and value:lower() == "/eq" then
			ns.Print("another addon also uses /eq (" .. key .. "). Use /enchantqueue or /eqq instead.")
		end
	end
end
ns.checkSlashClash = checkSlashClash

SLASH_ENCHANTQUEUE1 = "/eq"
SLASH_ENCHANTQUEUE2 = "/enchantqueue"
SLASH_ENCHANTQUEUE3 = "/eqq"
SlashCmdList.ENCHANTQUEUE = function(msg) ns.SafeCall("/eq", function()
	local cmd, arg = (msg or ""):lower():match("^(%S*)%s*(.-)$")
	if cmd == "" then
		UI.Toggle()
	elseif cmd == "clear" then
		ns.ClearQueue()
	elseif cmd == "debug" then
		ns.db.debug = not ns.db.debug
		ns.Print("debug", ns.db.debug and "on" or "off")
	elseif cmd == "status" then
		ns.PrintStatus()
	else
		ns.Print("/eqq  toggle panel | /eqq status | /eqq clear | /eqq debug")
	end
end) end
