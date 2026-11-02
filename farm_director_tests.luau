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
test("selected plan only targets the selected eligible boss", function()
	local plan = manager:SelectPlan()
	if not plan then return end -- A waiting/defeated boss is not a test failure.
	assert(plan.boss and plan.id == manager.selectedBoss)
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

test("town uses the free official pillar route", function()
	local fake = setmetatable({Character = function() return nil end}, {__index = manager})
	local id, cost = fake:TravelRoute("Town")
	assert(id == "Town" and cost == 0)
end)
test("unknown pillars are not unlocked", function()
	assert(not manager:PillarAvailable("unknown_test_pillar"))
end)
test("unknown destinations do not get a guessed warp route", function()
	local id, cost = manager:TravelRoute("unknown_test_map")
	assert(id == nil and cost == 0)
end)

test("unstreamed unlocked boss pillar still has a warp route", function()
	local fake = setmetatable({
		Character = function() return nil end,
		PillarAvailable = function(_, id) return id == "Boss05" end,
		PillarPosition = function() return nil end,
	}, {__index = manager})
	local id, cost = fake:TravelRoute("Boss05")
	assert(id == "Boss05" and cost == 5000)
end)

test("arrival tolerance is shared by path and caller", function()
	local fake = setmetatable({navBusy = false, Character = function()
		return {Position = Vector3.new(9.5, 0, 0)}, {}
	end}, {__index = manager})
	assert(fake:Walk(Vector3.zero, 10))
end)

test("idle assistant never moves or replaces native farm targets", function()
	local function forbidden() error("idle assistant took ownership of farming") end
	local fake = setmetatable({enabled = true, hop = {}, runDungeons = false, sellTrip = false,
		Character = function() return {}, {Health = 100, MaxHealth = 100} end,
		SelectedDefinition = function() return nil end, SelectPlan = function() return nil end,
		Walk = forbidden, ConfigureTarget = forbidden, BeginSession = forbidden,
	}, {__index = manager})
	-- Avoid inheriting any active trip from the actual UI instance.
	setmetatable(fake, {__index = function(_, key) if type(manager[key]) == "function" then return manager[key] end end})
	fake.travel = {active = false}
	fake:Tick()
	assert(fake.phase ~= nil)
end)

test("return uses the saved farm coordinates rather than a new monster", function()
	local captured
	local home = {zone = "Field03", position = Vector3.new(11, 60, -720)}
	local fake = {session = {}, home = home, Watch = function() end, CancelNavigation = function() end,
		SetNativeAuto = function() end,
		RestoreSettings = function() end,
		TravelTo = function(_, id, position, returning, internal)
			captured = {id, position, returning, internal}; return true
		end,
	}
	manager.BeginReturn(fake, "test")
	assert(fake.session.stage == "return")
	assert(captured[1] == home.zone and captured[2] == home.position and captured[3] and captured[4])
end)

test("server picker skips current full and recently visited servers", function()
	local selected = manager:PickServer({data = {
		{id = "current", playing = 0, maxPlayers = 10},
		{id = "full", playing = 10, maxPlayers = 10},
		{id = "seen", playing = 1, maxPlayers = 10},
		{id = "valid", playing = 3, maxPlayers = 10},
	}}, {seen = 200}, "current", 100)
	assert(selected == "valid")
end)

test("server picker allows expired visits and prefers low population", function()
	assert(manager:PickServer({data = {
		{id = "busy", playing = 8, maxPlayers = 10},
		{id = "expired", playing = 1, maxPlayers = 10},
	}}, {expired = 99}, "current", 100) == "expired")
end)

test("server picker returns no target for an exhausted page", function()
	assert(manager:PickServer({data = {{id = "full", playing = 10, maxPlayers = 10}}}, {}, "current", 100) == nil)
end)

test("resume rejects unrelated and expired payloads", function()
	assert(not manager:ValidResume(nil))
	assert(not manager:ValidResume({version = 1, user = game.Players.LocalPlayer.UserId,
		place = game.PlaceId, target = game.JobId, at = os.time() - 601}))
end)

test("resume preserves selected boss and original home for correct server", function()
	local data = {version = 1, user = game.Players.LocalPlayer.UserId, place = game.PlaceId,
		target = game.JobId, at = os.time(), selected = "terra_colossus", count = 1,
		home = {zone = "Field03", x = 11, y = 60, z = -720}, bot = {}}
	assert(manager:ValidResume(data))
	data.target = "some-other-server"
	assert(not manager:ValidResume(data))
end)

test("a completed boss returns home when hop mode is off", function()
	local reason
	local fake = {plan = {id = "test_boss", spawnKey = "spawn_1"}, failedBossSpawns = {}, cooldowns = {},
		BeginReturn = function(_, text) reason = text end}
	manager.FinishBoss(fake, "defeated", true)
	assert(reason == "defeated" and fake.failedBossSpawns.test_boss == "spawn_1")
end)

test("a completed boss schedules hopping only in hop mode", function()
	local fake = {plan = {id = "test_boss", spawnKey = "spawn_2"}, failedBossSpawns = {}, cooldowns = {},
		hopMode = true, session = {}, hop = {}, SetNativeAuto = function() end, Watch = function() end,
		RestoreSettings = function() end}
	manager.FinishBoss(fake, "defeated", true)
	assert(fake.session.stage == "hop" and fake.plan == nil and fake.hop.nextAt > os.clock())
end)

test("failed boss returns home instead of chaining more boss fights", function()
	local returned = false
	local fake = {plan = {id = "test_boss", spawnKey = "spawn_3"}, failedBossSpawns = {}, cooldowns = {},
		hopMode = true, BeginReturn = function() returned = true end}
	manager.FinishBoss(fake, "low health", false)
	assert(returned and fake.failedBossSpawns.test_boss == "spawn_3")
end)

test("boss death waits for loot then transitions to completion", function()
	local completed = false
	local fake = {enabled = true, travel = {active = false}, hop = {}, bossSpawnKeys = {},
		Character = function() return {}, {Health = 100, MaxHealth = 100} end,
		session = {kind = "boss", stage = "fight", arrivedAt = os.clock()},
		plan = {id = "test_boss", model = {Parent = true, GetAttribute = function(_, key) return key == "HP" and 0 or "spawn" end}},
		Watch = function() end, FinishBoss = function(_, _, killed) completed = killed end}
	setmetatable(fake, {__index = function(_, key) if type(manager[key]) == "function" then return manager[key] end end})
	fake:Tick()
	assert(not completed and fake.bossLootUntil > os.clock())
	fake.bossLootUntil = os.clock() - 1
	fake:Tick()
	assert(completed)
end)

test("Stop cancels pending hops without touching idle native farming", function()
	local fake = {enabled = true, hop = {token = 7, busy = true}, travel = {active = false},
		CancelNavigation = function() end, Watch = function() end}
	manager.SetEnabled(fake, false)
	assert(not fake.enabled and not fake.hop.busy and fake.hop.token == 8)
end)

test("do not request or charge a warp back to the source pillar", function()
	local fake = setmetatable({Character = function() return {Position = Vector3.zero} end,
		PillarAvailable = function() return true end, PillarPosition = function() return Vector3.new(0, 0, 100) end,
		NearestPillar = function() return {Parent = {GetAttribute = function() return "Boss01" end}} end,
	}, {__index = manager})
	local id, cost = fake:TravelRoute("Boss01")
	assert(id == nil and cost == 0)
end)

test("hop limit returns home then stops even when final server has no boss", function()
	local returned = false
	local fake = {hop = {count = 10, max = 10, nextAt = 0}, hopMode = true, homeBot = {},
		BeginReturn = function() returned = true end}
	manager.HopServer(fake)
	assert(returned and not fake.hopMode and fake.session.stopAfterReturn)
end)

test("target filter honors server cap and keeps nearby exclusions", function()
	local definitions = {boss = {}}
	for index = 1, 120 do definitions["monster_" .. index] = {} end
	local excludes = manager:BuildTargetExclusions("boss", {monster_119 = true, monster_120 = true}, definitions)
	local count = 0
	for _ in pairs(excludes) do count += 1 end
	assert(count == 100 and excludes.monster_119 and excludes.monster_120 and not excludes.boss)
end)

test("too many nearby exclusions fails rather than silently dropping them", function()
	local definitions, nearby = {}, {}
	for index = 1, 101 do local id = "monster_" .. index; definitions[id] = {}; nearby[id] = true end
	assert(manager:BuildTargetExclusions("boss", nearby, definitions) == nil)
end)

test("restored settings compare values rather than JSON key order", function()
	assert(manager:SameSettings({Mode = "fight", Exclude = {a = true, b = true}}, {Exclude = {b = true, a = true}, Mode = "fight"}))
	assert(not manager:SameSettings({Range = 60, Skills = {{Id = "a"}}}, {Range = 70, Skills = {{Id = "a"}}}))
end)

getgenv().__CodexFarmDirectorTests = results
