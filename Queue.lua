-- Pure queue model: no WoW API calls, so it can be tested outside the game.
local _, ns = ...
ns = ns or {}

local Queue = {}
ns.Queue = Queue

local MAX_COUNT = 999

function Queue.New()
	return { target = nil, entries = {} }
end

-- Appends recipeID x count. If the last entry is the same recipe, its count grows instead.
-- Returns the entry, or nil plus a reason.
function Queue.Add(q, recipeID, name, count)
	count = tonumber(count)
	if type(recipeID) ~= "number" then return nil, "no recipe selected" end
	if not count or count < 1 or count ~= math.floor(count) then return nil, "count must be a whole number of 1 or more" end
	count = math.min(count, MAX_COUNT)

	local last = q.entries[#q.entries]
	if last and last.recipeID == recipeID then
		last.remaining = math.min(last.remaining + count, MAX_COUNT)
		return last
	end

	local entry = { recipeID = recipeID, name = name or ("Recipe " .. recipeID), remaining = count }
	table.insert(q.entries, entry)
	return entry
end

function Queue.Remove(q, index)
	if q.entries[index] then
		table.remove(q.entries, index)
		return true
	end
	return false
end

function Queue.Clear(q)
	q.entries = {}
	q.target = nil
end

function Queue.Head(q)
	return q.entries[1]
end

function Queue.Total(q)
	local n = 0
	for _, e in ipairs(q.entries) do n = n + e.remaining end
	return n
end

-- Called when the player successfully casts spellID. Decrements the head entry if it
-- matches, otherwise the first matching entry (so manual casts in checklist mode count too).
-- Returns the entry that was decremented, or nil if spellID isn't queued.
function Queue.OnCastSucceeded(q, spellID)
	for i, e in ipairs(q.entries) do
		if e.recipeID == spellID then
			e.remaining = e.remaining - 1
			if e.remaining <= 0 then table.remove(q.entries, i) end
			return e
		end
	end
	return nil
end

return Queue
