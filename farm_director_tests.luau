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
test("budget exhausted and low health retreats", function()
	assert(manager:RetreatReason(0.2, {boss = true}, 50, 45, 50, 25) ~= nil)
end)
test("budget exhausted while healthy keeps fighting", function()
	assert(manager:RetreatReason(0.9, {boss = true}, 50, 46, 50, 25) == nil)
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
		hopMode = true, session = {}, BeginReturn = function() returned = true end}
	manager.FinishBoss(fake, "low health", false)
	assert(returned and fake.failedBossSpawns.test_boss == "spawn_3")
end)

test("boss death waits for loot then transitions to completion", function()
	local completed = false
	local fake = {enabled = true, travel = {active = false}, hop = {}, bossSpawnKeys = {},
		Character = function() return {}, {Health = 100, MaxHealth = 100} end,
		session = {kind = "boss", stage = "fight", arrivedAt = os.clock()},
		plan = {id = "test_boss", model = {Parent = true, GetAttribute = function(_, key) return key == "HP" and 0 or "spawn" end}},
		Watch = function() end, FinishBoss = function(_, _, killed) completed = killed end,
		CurrentBossPresence = function() return "countdown", 100 end}
	setmetatable(fake, {__index = function(_, key) if type(manager[key]) == "function" then return manager[key] end end})
	fake:Tick()
	assert(not completed and fake.bossLootUntil > os.clock())
	fake.bossLootUntil = os.clock() - 1
	fake:Tick()
	assert(completed)
end)

test("Stop cancels pending hops without touching idle native farming", function()
	local fake = {enabled = true, hopMode = true, hop = {token = 7, busy = true}, travel = {active = false},
		CancelNavigation = function() end, Watch = function() end}
	manager.SetEnabled(fake, false)
	assert(not fake.enabled and not fake.hopMode and not fake.hop.busy and fake.hop.token == 8)
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

test("low HP can recover while potions remain in budget", function()
	assert(manager:RetreatReason(0.15, {boss = true}, 7, 30, 50, 25) == nil)
end)

test("empty selected potion and low HP retreats", function()
	assert(manager:RetreatReason(0.2, {boss = true}, 7, 0, 50, 25) ~= nil)
end)

test("zero-potion budget fights while healthy and retreats when low", function()
	assert(manager:RetreatReason(0.8, {boss = true}, 0, 100, 0, 25) == nil)
	assert(manager:RetreatReason(0.2, {boss = true}, 0, 100, 0, 25) ~= nil)
end)

test("potion decreases are not cancelled by loot gains in another type", function()
	assert(manager:ConsumedPotions({red = 20, large = 3}, {red = 18, large = 5}) == 2)
	assert(manager:ConsumedPotions({red = 18}, {red = 25}) == 0)
end)

test("no alive flag or no countdown requires room scouting", function()
	assert(manager:BossPresence(nil, nil, 100, nil) == "scout")
	assert(manager:BossPresence(false, 0, 100, nil) == "scout")
end)

test("positive countdown identifies a waiting boss", function()
	local status, remaining = manager:BossPresence(false, 160, 100, nil)
	assert(status == "countdown" and remaining == 60)
end)

test("living model takes precedence over stale replicated countdown", function()
	local model = {Parent = true, GetAttribute = function() return 100 end}
	assert(manager:BossPresence(false, 200, 100, model) == "alive")
end)

test("empty room triggers server hopping without requiring a kill", function()
	local fake = {plan = {id = "boss", spawnKey = "scout"}, failedBossSpawns = {}, cooldowns = {},
		hopMode = true, session = {}, hop = {}, SetNativeAuto = function() end, Watch = function() end, RestoreSettings = function() end}
	manager.FinishBoss(fake, "empty room", false, true)
	assert(fake.session.stage == "hop" and fake.lastBossResult.missing and not fake.lastBossResult.killed)
end)

test("resource failure stops hopping after returning", function()
	local fake = {plan = {id = "boss", spawnKey = "1"}, failedBossSpawns = {}, cooldowns = {},
		hopMode = true, session = {}, BeginReturn = function() end}
	manager.FinishBoss(fake, "no healing", false)
	assert(fake.session.stopAfterReturn)
end)

test("enabling hop mode starts the stopped assistant", function()
	local started = false
	local fake = {hop = {}, SetEnabled = function(_, enabled) started = enabled end}
	manager.SetHopMode(fake, true)
	assert(started and fake.hopMode)
end)

test("other players drops remain protected until owner timer expires", function()
	local other = game.Players.LocalPlayer.UserId + 1
	assert(not manager:CanPickup(other, 115, 105, 0, 15))
	assert(manager:CanPickup(other, 115, 115, 0, 15))
	assert(manager:CanPickup(game.Players.LocalPlayer.UserId, 115, 105, 0, 15))
end)

test("drop pickup delay also applies to owner", function()
	assert(not manager:CanPickup(game.Players.LocalPlayer.UserId, 115, 100.1, 0.5, 15))
end)

test("reaching the potion cap disables further auto drinks once", function()
	local calls = {}
	local fake = {session = {kind = "boss", potionChanged = true, potionsUsed = 24, potionBudget = 25,
		potionSnapshot = {red = 10}}, HealingSnapshot = function() return {red = 9} end,
		ConsumedPotions = manager.ConsumedPotions, SetHealthAuto = function(_, value) calls[#calls+1] = value end}
	manager.UpdatePotionUsage(fake)
	manager.UpdatePotionUsage(fake)
	assert(fake.session.potionsUsed == 25 and fake.session.potionCapped and #calls == 1 and calls[1] == 0)
end)

test("inventory gains do not refund an already consumed potion budget", function()
	local fake = {session = {kind = "boss", potionChanged = true, potionsUsed = 12, potionBudget = 25,
		potionSnapshot = {red = 10}}, HealingSnapshot = function() return {red = 15} end,
		ConsumedPotions = manager.ConsumedPotions, SetHealthAuto = function() error("unexpected cap") end}
	manager.UpdatePotionUsage(fake)
	assert(fake.session.potionsUsed == 12)
end)

test("a box beyond E reach can request a walk within farming radius", function()
	assert(manager:CanWalkToBox(25, 0, false, true))
	assert(manager:CanWalkToBox(69, 3, false, true))
end)

test("box walks never steal boss or travel movement", function()
	assert(not manager:CanWalkToBox(25, 0, true, true))
end)

test("box walk respects radius height and native Auto pause", function()
	assert(not manager:CanWalkToBox(80, 0, false, true))
	assert(not manager:CanWalkToBox(25, 20, false, true))
	assert(not manager:CanWalkToBox(25, 0, false, false))
	assert(not manager:CanWalkToBox(5, 0, false, true))
end)

test("cancelled box trip releases its path and restores previous Auto", function()
	local cancelled, native
	local fake = {lootTrip = {native = true}, CancelNavigation = function() cancelled = true end,
		Character = function() return nil end, SetNativeAuto = function(_, v) native = v end}
	manager.CancelBoxTrip(fake, true, "cancelled")
	assert(fake.lootTrip == nil and cancelled and native == true)
end)

test("yielding box trip to manual travel cannot restart native Auto", function()
	local fake = {lootTrip = {native = true}, CancelNavigation = function() end,
		Character = function() return nil end, SetNativeAuto = function() error("should remain paused") end}
	manager.CancelBoxTrip(fake, false)
	assert(fake.lootTrip == nil)
end)

test("box return keeps the captured farm origin", function()
	local origin = Vector3.new(12, 60, -700)
	local fake = {lootTrip = {origin = origin, stage = "approach"}, CancelNavigation = function() end}
	manager.ReturnFromBox(fake, "opened")
	assert(fake.lootTrip.stage == "return" and fake.lootTrip.origin == origin and fake.lootTrip.result == "opened")
end)

test("box state confirmation is counted only once", function()
	local object = {}
	local fake = {lootAttempts = {}}
	manager.ConfirmPickup(fake, object, "LootBox")
	manager.ConfirmPickup(fake, object, "LootBox")
	assert(fake.boxesOpened == 1 and fake.pickupConfirmed == 1)
end)

getgenv().__CodexFarmDirectorTests = results
