-- The one item the queue enchants: stored by GUID, located again before every cast.
local _, ns = ...

local Target = {}
ns.Target = Target

local FIRST_BAG, LAST_BAG = 0, NUM_BAG_SLOTS or 4 -- reagent bag can't hold gear
local FIRST_EQUIP, LAST_EQUIP = INVSLOT_FIRST_EQUIPPED or 1, INVSLOT_LAST_EQUIPPED or 19

local function exists(loc)
	return loc and loc:IsValid() and C_Item.DoesItemExist(loc)
end

local function guidAt(loc)
	if exists(loc) then return C_Item.GetItemGUID(loc) end
end

local function locationOf(t)
	if t.equipSlot then return ItemLocation:CreateFromEquipmentSlot(t.equipSlot) end
	if t.bag and t.slot then return ItemLocation:CreateFromBagAndSlot(t.bag, t.slot) end
end

local function setLocation(t, loc)
	t.equipSlot, t.bag, t.slot = nil, nil, nil
	if loc:IsEquipmentSlot() then
		t.equipSlot = loc:GetEquipmentSlot()
	else
		t.bag, t.slot = loc:GetBagAndSlot()
	end
end

-- Builds a saved-variable-safe target table from an ItemLocation.
function Target.FromLocation(loc)
	if not exists(loc) then return nil end
	local t = {
		guid = C_Item.GetItemGUID(loc),
		itemID = C_Item.GetItemID(loc),
		link = C_Item.GetItemLink(loc),
		icon = C_Item.GetItemIcon(loc),
	}
	setLocation(t, loc)
	return t
end

-- Returns the target's current ItemLocation (updating t if the item moved), or nil if it's gone.
function Target.Locate(t)
	if not t or not t.guid then return nil end

	local loc = locationOf(t)
	if loc and guidAt(loc) == t.guid then return loc end

	for slot = FIRST_EQUIP, LAST_EQUIP do
		loc = ItemLocation:CreateFromEquipmentSlot(slot)
		if guidAt(loc) == t.guid then setLocation(t, loc); return loc end
	end
	for bag = FIRST_BAG, LAST_BAG do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
			if guidAt(loc) == t.guid then setLocation(t, loc); return loc end
		end
	end
	return nil
end

-- Arguments for the /use macro command: "9" for an equipped slot, "0 3" for bag 0 slot 3.
function Target.UseArgs(t)
	if t.equipSlot then return tostring(t.equipSlot) end
	return t.bag .. " " .. t.slot
end
