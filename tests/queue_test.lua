-- Run from the addon folder: lua5.1 tests/queue_test.lua
local Queue = dofile("Queue.lua")

local passed = 0
local function test(name, fn)
	fn()
	passed = passed + 1
	print("ok  " .. name)
end

test("adds entries in order", function()
	local q = Queue.New()
	Queue.Add(q, 1, "A", 2)
	Queue.Add(q, 2, "B", 1)
	assert(#q.entries == 2 and q.entries[1].name == "A" and Queue.Total(q) == 3)
end)

test("merges consecutive adds of the same recipe", function()
	local q = Queue.New()
	Queue.Add(q, 1, "A", 2)
	Queue.Add(q, 1, "A", 3)
	assert(#q.entries == 1 and q.entries[1].remaining == 5)
end)

test("does not merge non-consecutive duplicates", function()
	local q = Queue.New()
	Queue.Add(q, 1, "A", 1); Queue.Add(q, 2, "B", 1); Queue.Add(q, 1, "A", 1)
	assert(#q.entries == 3)
end)

test("rejects bad input", function()
	local q = Queue.New()
	assert(Queue.Add(q, nil, "A", 1) == nil)
	assert(Queue.Add(q, 1, "A", 0) == nil)
	assert(Queue.Add(q, 1, "A", 1.5) == nil)
	assert(Queue.Add(q, 1, "A", "x") == nil)
	assert(#q.entries == 0)
end)

test("caps counts at 999", function()
	local q = Queue.New()
	Queue.Add(q, 1, "A", 998); Queue.Add(q, 1, "A", 5)
	assert(q.entries[1].remaining == 999)
end)

test("cast success decrements head and drops it at zero", function()
	local q = Queue.New()
	Queue.Add(q, 1, "A", 2); Queue.Add(q, 2, "B", 1)
	assert(Queue.OnCastSucceeded(q, 1).remaining == 1)
	Queue.OnCastSucceeded(q, 1)
	assert(Queue.Head(q).recipeID == 2)
	Queue.OnCastSucceeded(q, 2)
	assert(Queue.Head(q) == nil and Queue.Total(q) == 0)
end)

test("cast success matches a later entry (manual casts in mode C)", function()
	local q = Queue.New()
	Queue.Add(q, 1, "A", 1); Queue.Add(q, 2, "B", 1)
	Queue.OnCastSucceeded(q, 2)
	assert(#q.entries == 1 and q.entries[1].recipeID == 1)
end)

test("unrelated spells are ignored", function()
	local q = Queue.New()
	Queue.Add(q, 1, "A", 1)
	assert(Queue.OnCastSucceeded(q, 999) == nil and Queue.Total(q) == 1)
end)

test("remove and clear", function()
	local q = Queue.New()
	q.target = { guid = "x" }
	Queue.Add(q, 1, "A", 1); Queue.Add(q, 2, "B", 1)
	assert(Queue.Remove(q, 1) and q.entries[1].recipeID == 2)
	assert(not Queue.Remove(q, 5))
	Queue.Clear(q)
	assert(#q.entries == 0 and q.target == nil)
end)

print(passed .. " passed")
