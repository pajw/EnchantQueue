-- The panel: target slot, recipe picker, queue rows, Next / Clear, status line.
local _, ns = ...

local UI = {}
ns.UI = UI

local MAX_ROWS = 8
local panel, targetSlot, targetText, selectedText, countBox, addButton, nextButton, clearButton, statusText, moreText
local rows = {}

local function recipeName(recipeID)
	local info = recipeID and C_TradeSkillUI.GetRecipeInfo(recipeID)
	return info and info.name
end

local function setTargetFromCursor()
	if not C_Cursor or not C_Cursor.GetCursorItem then return end
	local loc = C_Cursor.GetCursorItem()
	if loc then
		ClearCursor()
		ns.SetTarget(loc)
	end
end

local function buildTargetSlot()
	targetSlot = CreateFrame("Button", nil, panel)
	targetSlot:SetSize(40, 40)
	targetSlot:SetPoint("TOPLEFT", 14, -30)
	targetSlot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	targetSlot.icon = targetSlot:CreateTexture(nil, "ARTWORK")
	targetSlot.icon:SetAllPoints()
	targetSlot.border = targetSlot:CreateTexture(nil, "OVERLAY")
	targetSlot.border:SetAtlas("bags-glow-white")
	targetSlot.border:SetAllPoints()
	targetSlot:SetScript("OnReceiveDrag", setTargetFromCursor)
	targetSlot:SetScript("OnClick", function(_, mouse)
		if mouse == "RightButton" then ns.SetTarget(nil) else setTargetFromCursor() end
	end)
	targetSlot:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		local t = ns.db.queue.target
		if t and t.link then
			GameTooltip:SetHyperlink(t.link)
		else
			GameTooltip:SetText("Drop an item here, or Alt-click one in your bags.")
		end
		GameTooltip:AddLine("Right-click to clear.", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	targetSlot:SetScript("OnLeave", GameTooltip_Hide)

	targetText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	targetText:SetPoint("LEFT", targetSlot, "RIGHT", 8, 0)
	targetText:SetPoint("RIGHT", panel, "RIGHT", -12, 0)
	targetText:SetJustifyH("LEFT")
end

local function buildAddRow()
	selectedText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	selectedText:SetPoint("TOPLEFT", targetSlot, "BOTTOMLEFT", 0, -10)
	selectedText:SetPoint("RIGHT", panel, "RIGHT", -12, 0)
	selectedText:SetJustifyH("LEFT")

	countBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
	countBox:SetSize(40, 20)
	countBox:SetPoint("TOPLEFT", selectedText, "BOTTOMLEFT", 6, -6)
	countBox:SetAutoFocus(false)
	countBox:SetNumeric(true)
	countBox:SetMaxLetters(3)
	countBox:SetText("1")
	countBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); addButton:Click() end)

	addButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	addButton:SetSize(90, 22)
	addButton:SetPoint("LEFT", countBox, "RIGHT", 8, 0)
	addButton:SetText("+ Queue")
	addButton:SetScript("OnClick", function()
		ns.AddSelected(tonumber(countBox:GetText()) or 1)
	end)
end

local function buildRows()
	for i = 1, MAX_ROWS do
		local row = CreateFrame("Frame", nil, panel)
		row:SetSize(232, 20)
		row:SetPoint("TOPLEFT", countBox, "BOTTOMLEFT", -6, -8 - (i - 1) * 20)
		row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.text:SetPoint("LEFT")
		row.text:SetPoint("RIGHT", -24, 0)
		row.text:SetJustifyH("LEFT")
		row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		row.remove:SetSize(20, 18)
		row.remove:SetPoint("RIGHT")
		row.remove:SetText("x")
		row.remove:SetScript("OnClick", function() ns.RemoveEntry(i) end)
		rows[i] = row
	end
	moreText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	moreText:SetPoint("TOPLEFT", rows[MAX_ROWS], "BOTTOMLEFT", 0, -2)
end

function UI.Init()
	panel = CreateFrame("Frame", "EnchantQueueFrame", UIParent, "BasicFrameTemplateWithInset")
	panel:SetSize(260, 360)
	panel:SetPoint("CENTER")
	panel:SetMovable(true)
	panel:EnableMouse(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
	panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
	panel:Hide()
	tinsert(UISpecialFrames, "EnchantQueueFrame") -- Esc closes it

	panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	panel.title:SetPoint("TOP", 0, -5)

	buildTargetSlot()
	buildAddRow()
	buildRows()

	nextButton = ns.Cast.Init(panel)
	nextButton:SetPoint("BOTTOMLEFT", 12, 34)

	clearButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	clearButton:SetSize(80, 24)
	clearButton:SetPoint("LEFT", nextButton, "RIGHT", 8, 0)
	clearButton:SetText("Clear")
	clearButton:SetScript("OnClick", function() ns.ClearQueue() end)

	statusText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	statusText:SetPoint("BOTTOMLEFT", 14, 10)
	statusText:SetPoint("BOTTOMRIGHT", -14, 10)
	statusText:SetJustifyH("LEFT")
	statusText:SetWordWrap(true)
end

-- Alt-click an item in your bags to make it the target (character sheet: drag it instead).
function UI.HookAltClick()
	if type(HandleModifiedItemClick) ~= "function" then ns.Debug("no HandleModifiedItemClick; use drag-and-drop for the target"); return end
	hooksecurefunc("HandleModifiedItemClick", function(_, itemLocation)
		if IsAltKeyDown() and panel and panel:IsShown() and type(itemLocation) == "table" and itemLocation.IsValid then
			ns.SetTarget(itemLocation)
		end
	end)
end

function UI.SetStatus(msg)
	if statusText then statusText:SetText(msg or "") end
end

function UI.Render(q, located)
	if not panel or not ns.db then return end
	panel.title:SetText("Enchant Queue")

	local t = q.target
	if t then
		targetSlot.icon:SetTexture(t.icon)
		targetText:SetText((t.link or "?") .. (located and "" or "\n|cffff4040Item not found|r"))
	else
		targetSlot.icon:SetTexture(nil)
		targetText:SetText("|cff888888Drop the item to enchant here|r")
	end

	local selected = ns.GetSelectedRecipeID()
	selectedText:SetText("Selected: " .. (recipeName(selected) or "|cff888888pick an enchant in the Professions window|r"))
	addButton:SetEnabled(selected ~= nil)

	for i, row in ipairs(rows) do
		local e = q.entries[i]
		if e then
			row.text:SetText(i .. ". " .. e.name .. "  |cffffd100x" .. e.remaining .. "|r")
			row:Show()
		else
			row:Hide()
		end
	end
	local extra = #q.entries - MAX_ROWS
	moreText:SetText(extra > 0 and ("+" .. extra .. " more") or "")
end

function UI.Toggle()
	if not panel or InCombatLockdown() then return end
	panel:SetShown(not panel:IsShown())
	if panel:IsShown() then ns.Refresh() end
end

-- Docking: Forever hangs a vertical strip of profession tabs off the Professions window's
-- right edge (ProfessionsFrame.Professions<N>Tab, seen with /fstack). Sit right of them.
local DOCK_GAP = 6        -- px between the rightmost tab and the panel
local DOCK_FALLBACK = 64  -- px from ProfessionsFrame's right edge when nothing is found
local MIN_HEIGHT = 360
UI.dock = { method = "not docked yet" }

-- Right edge in screen pixels, or nil if the frame isn't laid out yet.
local function screenRight(f)
	local r = f.GetRight and f:GetRight()
	return r and r * f:GetEffectiveScale()
end

-- A frame counts as attached to the right if it's shown and starts at or past
-- (20 px inside) the window's right edge. Full-width children like NineSlice don't.
local function attachedRight(f, edge)
	if type(f) ~= "table" or f == panel or not f.IsShown or not f:IsShown() or not f.GetLeft then return nil end
	local l, r = f:GetLeft(), f:GetRight()
	if not l or not r then return nil end
	local s = f:GetEffectiveScale()
	if l * s >= edge - 20 * s then return r * s end
end

-- Screen-pixel offset from ProfessionsFrame's right edge to the panel's left edge.
local function dockOffset(pf)
	local edge = screenRight(pf)
	if not edge then return nil, "fallback (window not laid out)" end
	local best
	for i = 1, 12 do
		local r = attachedRight(pf["Professions" .. i .. "Tab"], edge)
		if r and (not best or r > best) then best = r end
	end
	local method = "profession tabs"
	if not best and pf.GetChildren then
		for _, child in ipairs({ pf:GetChildren() }) do
			local r = attachedRight(child, edge)
			if r and (not best or r > best) then best = r end
		end
		method = "child scan"
	end
	if not best then return nil, "fallback (nothing attached)" end
	return best - edge, method
end

local function dock()
	local pf = ProfessionsFrame
	if not panel or not pf or InCombatLockdown() then return end
	local ratio = pf:GetEffectiveScale() / panel:GetEffectiveScale()
	local offset, method = dockOffset(pf)
	local x = offset and (offset / panel:GetEffectiveScale() + DOCK_GAP) or DOCK_FALLBACK * ratio
	panel:ClearAllPoints()
	panel:SetPoint("TOPLEFT", pf, "TOPRIGHT", x, 0)
	local h = pf:GetHeight()
	panel:SetHeight(math.max(MIN_HEIGHT, h and h * ratio or 0))
	UI.dock = { method = method, x = x }
end

-- Dock beside the Professions window while Enchanting is open.
function UI.ShowDocked()
	if not panel or InCombatLockdown() or not ProfessionsFrame then return end
	dock()
	panel:Show()
	ns.Refresh()
	-- The tab strip can lay out a frame after TRADE_SKILL_SHOW; measure again then.
	if C_Timer and C_Timer.After then C_Timer.After(0, function() if panel:IsShown() then dock() end end) end
end

function UI.Hide()
	if panel and not InCombatLockdown() then panel:Hide() end
end
