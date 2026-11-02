-- Run after farm_control_center.luau in the connected client.
-- These checks inspect live access rules and exercise selection logic without
-- moving the character, granting items, or sending dungeon entry requests.
local runtime = getgenv().__CodexFarmCenter
assert(runtime and runtime.manager, "Load Farm Control Center first")
local manager = runtime.manager
local results = {passed = 0, failed = 0, checks = {}}

local function test(name, callback)
	local ok, message = pcall(callback)
	table.insert(results.checks, {name = name, passed = ok, error = not ok and tostring(message) or nil})
	if ok then results.passed += 1 else results.failed += 1 end
end

local function dungeon(required, free, used, id)
	return {Id = id or "halloween", MinLevel = required, Free = free, Used = used}
end

test("reject level below dungeon requirement", function()
	assert(manager:ChooseDungeon({IsLeader = true, Dungeons = {dungeon(90, 2, 0)}}, 31) == nil)
end)
test("accept available first free run", function()
	local selected = manager:ChooseDungeon({IsLeader = true, Dungeons = {dungeon(90, 2, 0)}}, 90)
	assert(selected and selected.Id == "halloween")
end)
test("reject exhausted free runs even with keys", function()
	assert(manager:ChooseDungeon({IsLeader = true, Keys = 99, Dungeons = {dungeon(90, 2, 2)}}, 99) == nil)
end)
test("reject non-leader", function()
	assert(manager:ChooseDungeon({IsLeader = false, Dungeons = {dungeon(90, 2, 0)}}, 99) == nil)
end)
test("reject missing leader authorization", function()
	assert(manager:ChooseDungeon({Dungeons = {dungeon(90, 2, 0)}}, 99) == nil)
end)
test("reject underleveled party member", function()
	assert(manager:ChooseDungeon({IsLeader = true, Party = {{Level = 89}}, Dungeons = {dungeon(90, 2, 0)}}, 99) == nil)
end)
test("reject missing free-run counters", function()
	assert(manager:ChooseDungeon({IsLeader = true, Dungeons = {{Id = "halloween", MinLevel = 90}}}, 99) == nil)
end)
test("use definition ID instead of array index", function()
	local selected = manager:ChooseDungeon({IsLeader = true, Dungeons = {dungeon(90, 2, 1, "actual_id")}}, 99)
	assert(selected and selected.Id == "actual_id")
end)
test("pick highest eligible dungeon with free runs", function()
	local selected = manager:ChooseDungeon({IsLeader = true, Dungeons = {
		dungeon(20, 2, 0, "low"), dungeon(60, 2, 0, "high"), dungeon(90, 2, 0, "locked"),
	}}, 70)
	assert(selected and selected.Id == "high")
end)
test("unknown map is blocked", function()
	assert(manager:CanAccess("unknown_test_map") == false)
end)
test("live selected monster respects level and access", function()
	local plan = manager:SelectPlan()
	assert(plan, "no eligible monster currently loaded")
	assert(plan.level <= (game.Players.LocalPlayer:GetAttribute("Level") or 1))
	assert(manager:CanAccess(plan.zone))
end)
test("EXP gain survives a level rollover", function()
	local required = require(game.ReplicatedStorage.Shared.ExpTable).BaseNeed(30)
	local before = manager:TotalExp(30, 12483)
	local after = manager:TotalExp(31, 319)
	assert(after - before == required - 12483 + 319)
	assert(after > before)
end)

test("retreat below 35 percent health", function()
	assert(manager:RetreatReason(0.34, {boss = false}) ~= nil)
end)
test("retreat after five healing potions on a boss", function()
	assert(manager:RetreatReason(0.9, {boss = true}, 50, 45) ~= nil)
end)
test("allow four potions without triggering the boss budget", function()
	assert(manager:RetreatReason(0.9, {boss = true}, 50, 46) == nil)
end)
test("boss potion budget does not interrupt normal monsters", function()
	assert(manager:RetreatReason(0.9, {boss = false}, 50, 40) == nil)
end)

getgenv().__CodexFarmDirectorTests = results
