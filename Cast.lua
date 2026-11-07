-- The "Next" secure button.
-- Each press puts the next queued recipe and the target item into Blizzard's Enchanting
-- window (insecure PreClick), then securely clicks its Enchant button. Confirmed working
-- in Forever without taint. If a "replace existing enchant?" popup appears, the next press
-- clicks its Yes button instead.
-- Secure attributes can't change in combat, so Prepare defers until combat ends.
local _, ns = ...

local Cast = {}
ns.Cast = Cast

local button
local replaceButton -- a visible "replace enchant?" confirm button, if any
local pendingPrepare = false

-- StaticPopup names treated as "replace existing enchant?". Forever uses the TRADESKILL one.
Cast.REPLACE_POPUPS = { REPLACE_TRADESKILL_ENCHANT = true, REPLACE_ENCHANT = true }

local function createButton()
	local pf = ProfessionsFrame
	return pf and pf.CraftingPage and pf.CraftingPage.CreateButton
end

local function schematicForm()
	local pf = ProfessionsFrame
	return pf and pf.CraftingPage and pf.CraftingPage.SchematicForm
end

-- Selects the head recipe and puts the target item in the window's "Optional Target" slot.
local function stageInProfessionsWindow()
	local entry, loc = ns.CurrentHeadAndLocation()
	if not entry or not loc then return end

	local ok, err = pcall(function()
		C_TradeSkillUI.OpenRecipe(entry.recipeID)
		local form = schematicForm()
		local item = Item:CreateFromItemLocation(loc)
		form:GetTransaction():SetEnchantAllocation(item)
		if form.enchantSlot and form.enchantSlot.SetItem then form.enchantSlot:SetItem(item) end
		if ProfessionsFrame.CraftingPage.ValidateControls then ProfessionsFrame.CraftingPage:ValidateControls() end
	end)
	if ok then ns.Debug("staged", entry.name) else ns.Print("|cffff4040couldn't set up the Enchanting window:|r", tostring(err)) end
end

function Cast.Init(parent)
	button = CreateFrame("Button", "EnchantQueueNextButton", parent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
	button:SetSize(140, 24)
	button:SetText("Next")
	-- Since 10.0 the template acts on down or up per the ActionButtonUseKeyDown CVar.
	button:RegisterForClicks("AnyUp", "AnyDown")
	button:SetScript("PreClick", function(_, mouse, down)
		ns.lastPress = GetTime()
		ns.Debug("Next pressed (" .. tostring(mouse) .. (down and " down" or " up") .. ")")
		if not replaceButton and not ns.casting then stageInProfessionsWindow() end
	end)
	_G.BINDING_HEADER_ENCHANTQUEUE = "Enchant Queue"
	_G["BINDING_NAME_CLICK EnchantQueueNextButton:LeftButton"] = "Cast next queued enchant"
	return button
end

function Cast.Prepare(entry, target, loc)
	if not button then return end
	if InCombatLockdown() then pendingPrepare = true; return end
	pendingPrepare = false
	button:SetAttribute("type", nil)
	button:SetAttribute("clickbutton", nil)

	if replaceButton then
		button:SetAttribute("type", "click")
		button:SetAttribute("clickbutton", replaceButton)
		button:SetText("Confirm replace")
		button:Enable()
		return
	end

	if ns.casting then
		-- Presses during a cast would only trigger "Another action is in progress".
		button:SetText("Casting...")
		button:Disable()
		return
	end

	button:SetText("Next")
	local create = createButton()
	if not entry or not loc or not create then button:Disable(); return end
	button:SetAttribute("type", "click")
	button:SetAttribute("clickbutton", create)
	button:Enable()
end

function Cast.OnCombatEnded()
	if pendingPrepare then ns.Refresh() end
end

local function findConfirmButton(dialog)
	if not dialog then return nil end
	return dialog.button1
		or (dialog.GetButton1 and dialog:GetButton1())
		or (dialog.ButtonContainer and dialog.ButtonContainer.Button1)
end

-- While a "replace enchant?" popup is up, the next press of Next confirms it.
function Cast.HookPopups()
	if type(StaticPopup_Show) ~= "function" then ns.Debug("no StaticPopup_Show; replace confirm disabled"); return end
	hooksecurefunc("StaticPopup_Show", function(which)
		ns.Debug("popup shown:", tostring(which))
		if not Cast.REPLACE_POPUPS[which] or not ns.QueueActive() then return end
		local dialog = StaticPopup_FindVisible and StaticPopup_FindVisible(which)
		local confirm = findConfirmButton(dialog)
		if not confirm then ns.Print("replace popup: couldn't find its Yes button, click it yourself"); return end

		replaceButton = confirm
		if not dialog.enchantQueueHooked then
			dialog.enchantQueueHooked = true
			dialog:HookScript("OnHide", function()
				if replaceButton then replaceButton = nil; ns.Refresh() end
			end)
		end
		ns.SetStatus("Press Next again to replace the existing enchant.")
		ns.Refresh()
	end)
end
