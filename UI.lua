-- The panel: target slot, recipe picker, queue rows, Next / Clear, status line.
local _, ns = ...

local UI = {}
ns.UI = UI

local MAX_ROWS = 24           -- rows built; how many show depends on the panel's height
local ROW_H = 22
local PANEL_W, PANEL_H = 290, 360
local BOTTOM_RESERVE = 84     -- Next / Clear, the status line and "+N more"
local panel, targetSlot, targetText, targetLabel, selectedText, countBox, addButton, nextButton, clearButton, statusText, moreText
local rows = {}
UI.rows = rows -- for tests
local top = 30                -- content top: below the title bar, or below the portrait

local function recipeInfo(recipeID)
	return recipeID and C_TradeSkillUI.GetRecipeInfo(recipeID)
end

local function recipeName(recipeID)
	local info = recipeInfo(recipeID)
	return info and info.name
end

local function itemQualityColor(link)
	if not link then return nil end
	local q = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(link)
	if not q and GetItemInfo then q = select(3, GetItemInfo(link)) end
	if not q then return nil end
	if C_Item and C_Item.GetItemQualityColor then return C_Item.GetItemQualityColor(q) end
	local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
	if c then return c.r, c.g, c.b end
end

local function setTargetFromCursor()
	if not C_Cursor or not C_Cursor.GetCursorItem then return end
	local loc = C_Cursor.GetCursorItem()
	if loc then
		ClearCursor()
		ns.SetTarget(loc)
	end
end

local function label(text, y)
	local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") -- Blizzard's gold "Reagents:" style
	fs:SetPoint("TOPLEFT", 14, -y)
	fs:SetText(text)
	return fs
end

local function buildTargetSlot()
	targetLabel = label("Item to enchant", top)

	targetSlot = CreateFrame("Button", nil, panel)
	targetSlot:SetSize(40, 40)
	targetSlot:SetPoint("TOPLEFT", 14, -(top + 14))
	targetSlot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	targetSlot.empty = targetSlot:CreateTexture(nil, "BACKGROUND")
	targetSlot.empty:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
	targetSlot.empty:SetAllPoints()
	targetSlot.icon = targetSlot:CreateTexture(nil, "ARTWORK")
	targetSlot.icon:SetAllPoints()
	targetSlot.border = targetSlot:CreateTexture(nil, "OVERLAY")
	targetSlot.border:SetTexture("Interface\\Common\\WhiteIconFrame")
	targetSlot.border:SetAllPoints()
	targetSlot:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
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
	targetText:SetPoint("RIGHT", panel, "RIGHT", -14, 0)
	targetText:SetJustifyH("LEFT")
end

local function buildAddRow()
	selectedText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	selectedText:SetPoint("TOPLEFT", 14, -(top + 62))
	selectedText:SetPoint("RIGHT", panel, "RIGHT", -14, 0)
	selectedText:SetJustifyH("LEFT")
	selectedText:SetWordWrap(false)

	countBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
	countBox:SetSize(40, 20)
	countBox:SetPoint("TOPLEFT", 20, -(top + 80))
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

local ROWS_TOP -- set in buildRows

local function buildRows()
	label("Queue", top + 112)
	ROWS_TOP = top + 128
	for i = 1, MAX_ROWS do
		local row = CreateFrame("Button", nil, panel)
		row:SetHeight(ROW_H)
		row:SetPoint("TOPLEFT", 10, -(ROWS_TOP + (i - 1) * ROW_H))
		row:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
		row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(18, 18)
		row.icon:SetPoint("LEFT", 2, 0)
		row.remove = CreateFrame("Button", nil, row)
		row.remove:SetSize(16, 16)
		row.remove:SetPoint("RIGHT", -2, 0)
		row.remove:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
		row.remove:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Down")
		row.remove:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight", "ADD")
		row.remove:SetScript("OnClick", function() ns.RemoveEntry(i) end)
		row.remove:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText("Remove from queue")
			GameTooltip:Show()
		end)
		row.remove:SetScript("OnLeave", GameTooltip_Hide)
		row.count = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		row.count:SetPoint("RIGHT", row.remove, "LEFT", -6, 0)
		row.count:SetJustifyH("RIGHT")
		row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
		row.text:SetPoint("RIGHT", row.count, "LEFT", -6, 0)
		row.text:SetJustifyH("LEFT")
		row.text:SetWordWrap(false)
		rows[i] = row
	end
	moreText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
end

-- Blizzard's Professions window uses the portrait frame; fall back to the plain one if
-- this client doesn't have it.
local function createPanel()
	local ok, f = pcall(CreateFrame, "Frame", "EnchantQueueFrame", UIParent, "ButtonFrameTemplate")
	if ok and f then
		if f.SetPortraitToAsset then f:SetPortraitToAsset("Interface\\Icons\\Trade_Engraving")
		elseif type(f.portrait) == "table" and SetPortraitToTexture then SetPortraitToTexture(f.portrait, "Interface\\Icons\\Trade_Engraving") end
		if f.SetTitle then f:SetTitle("Enchant Queue") end
		if ButtonFrameTemplate_HideButtonBar then pcall(ButtonFrameTemplate_HideButtonBar, f) end
		if type(f.Inset) == "table" then -- after HideButtonBar, which re-anchors it
			f.Inset:ClearAllPoints()
			f.Inset:SetPoint("TOPLEFT", 4, -60)
			f.Inset:SetPoint("BOTTOMRIGHT", -6, 60)
		end
		return f, 66, "portrait"
	end
	f = CreateFrame("Frame", "EnchantQueueFrame", UIParent, "BasicFrameTemplateWithInset")
	f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	f.title:SetPoint("TOP", 0, -5)
	f.title:SetText("Enchant Queue")
	return f, 30, "basic"
end

function UI.Init()
	panel, top, UI.chrome = createPanel()
	panel:SetSize(PANEL_W, PANEL_H)
	panel:SetPoint("CENTER")
	panel:SetMovable(true)
	panel:EnableMouse(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
	panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
	panel:Hide()
	tinsert(UISpecialFrames, "EnchantQueueFrame") -- Esc closes it

	-- Closing with X is a choice: stay closed when Enchanting next opens (Esc and closing
	-- Enchanting don't count, so they leave the choice alone).
	if type(panel.CloseButton) == "table" then
		panel.CloseButton:HookScript("OnClick", function() ns.db.hidden = true; UI.UpdateToggleButton() end)
	end

	buildTargetSlot()
	buildAddRow()
	buildRows()

	nextButton = ns.Cast.Init(panel)
	nextButton:SetPoint("BOTTOMLEFT", 12, 32)

	clearButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	clearButton:SetSize(90, 24)
	clearButton:SetPoint("LEFT", nextButton, "RIGHT", 8, 0)
	clearButton:SetText("Clear")
	clearButton:SetScript("OnClick", function() ns.ClearQueue() end)

	statusText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall") -- grey helper text
	statusText:SetPoint("BOTTOMLEFT", 14, 8)
	statusText:SetPoint("BOTTOMRIGHT", -14, 8)
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

-- How many rows fit between the queue heading and the buttons at the bottom.
local function visibleRowCount()
	local h = panel:GetHeight() or PANEL_H
	return math.max(1, math.min(MAX_ROWS, math.floor((h - ROWS_TOP - BOTTOM_RESERVE) / ROW_H)))
end

function UI.Render(q, located)
	if not panel or not ns.db then return end

	local t = q.target
	if t then
		targetSlot.icon:SetTexture(t.icon)
		targetSlot.empty:Hide()
		local r, g, b = itemQualityColor(t.link)
		targetSlot.border:SetVertexColor(r or 1, g or 1, b or 1)
		targetSlot.border:Show()
		targetText:SetText((t.link or "?") .. (located and "" or "\n|cffff4040Item not found|r"))
	else
		targetSlot.icon:SetTexture(nil)
		targetSlot.empty:Show()
		targetSlot.border:Hide()
		targetText:SetText("|cff888888Drop an item here|r")
	end

	local selected = ns.GetSelectedRecipeID()
	selectedText:SetText("|cffffd100Selected:|r " .. (recipeName(selected) or "|cff888888pick an enchant on the left|r"))
	addButton:SetEnabled(selected ~= nil)

	local shown = visibleRowCount()
	for i, row in ipairs(rows) do
		local e = i <= shown and q.entries[i]
		if e then
			local info = recipeInfo(e.recipeID)
			row.icon:SetTexture(info and info.icon or "Interface\\Icons\\Trade_Engraving")
			row.text:SetText(e.name)
			row.count:SetText("x" .. e.remaining)
			row:Show()
		else
			row:Hide()
		end
	end
	local extra = #q.entries - shown
	moreText:ClearAllPoints()
	moreText:SetPoint("TOPLEFT", 14, -(ROWS_TOP + shown * ROW_H + 2))
	moreText:SetText(extra > 0 and ("+" .. extra .. " more") or "")
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
	UI.PlaceToggleButton(pf)
end

-- Toggle button: an icon under the profession tab strip that shows or hides the panel.
local toggleButton

local function buildToggleButton(pf)
	toggleButton = CreateFrame("Button", "EnchantQueueToggleButton", pf)
	toggleButton:SetSize(36, 36)
	toggleButton.icon = toggleButton:CreateTexture(nil, "ARTWORK")
	toggleButton.icon:SetAllPoints()
	toggleButton.icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
	toggleButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	toggleButton:SetScript("OnClick", function() UI.Toggle() end)
	toggleButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Enchant Queue")
		GameTooltip:AddLine(panel:IsShown() and "Click to hide." or "Click to show.", 1, 1, 1)
		GameTooltip:AddLine("Stays the way you leave it next time Enchanting opens.", 0.7, 0.7, 0.7, true)
		GameTooltip:Show()
	end)
	toggleButton:SetScript("OnLeave", GameTooltip_Hide)
end

-- Below the lowest profession tab, or near the top right of the window if there are none.
function UI.PlaceToggleButton(pf)
	if not toggleButton then buildToggleButton(pf) end
	local lowest, lowestBottom
	for i = 1, 12 do
		local tab = pf["Professions" .. i .. "Tab"]
		if type(tab) == "table" and tab.IsShown and tab:IsShown() and tab.GetBottom then
			local b = tab:GetBottom()
			if b and (not lowestBottom or b < lowestBottom) then lowest, lowestBottom = tab, b end
		end
	end
	toggleButton:ClearAllPoints()
	if lowest then
		toggleButton:SetPoint("TOP", lowest, "BOTTOM", 0, -4)
	else
		toggleButton:SetPoint("TOPLEFT", pf, "TOPRIGHT", 8, -40)
	end
	toggleButton:Show()
	UI.UpdateToggleButton()
end

function UI.UpdateToggleButton()
	if not toggleButton then return end
	if panel:IsShown() then toggleButton:LockHighlight() else toggleButton:UnlockHighlight() end
end

-- Show or hide the panel by hand (toggle button or /eqq), and remember the choice.
function UI.Toggle()
	if not panel then return end
	if InCombatLockdown() then ns.Print("can't show or hide the panel in combat"); return end
	ns.db.hidden = panel:IsShown()
	if ns.db.hidden then
		panel:Hide()
	elseif ProfessionsFrame and ProfessionsFrame:IsShown() and toggleButton and toggleButton:IsShown() then
		UI.ShowDocked()
	else
		panel:Show()
		ns.Refresh()
	end
	UI.UpdateToggleButton()
end

-- Dock beside the Professions window while Enchanting is open, unless the user closed it.
function UI.ShowDocked()
	if not panel or InCombatLockdown() or not ProfessionsFrame then return end
	dock()
	panel:SetShown(not ns.db.hidden)
	UI.UpdateToggleButton()
	if panel:IsShown() then ns.Refresh() end
	-- The tab strip can lay out a frame after TRADE_SKILL_SHOW; measure again then.
	if C_Timer and C_Timer.After then C_Timer.After(0, function()
		if toggleButton:IsShown() and not InCombatLockdown() then dock(); if panel:IsShown() then ns.Refresh() end end
	end) end
end

function UI.Hide()
	if InCombatLockdown() then return end
	if panel then panel:Hide() end
	if toggleButton then toggleButton:Hide() end
end
