# Boss Assistant — functional test results

## Version 3.3.0-boss-sustain — 2026-11-02

The fixed five-potion retreat and three-minute deadline have been replaced with user-controlled HP threshold, potion slot, per-boss use budget, retreat HP after resources are exhausted, and optional fight duration. The game accepts HP auto-drink thresholds up to 90% in steps of 5. Budget tracking accumulates inventory decreases separately for each HP potion and disables native HP auto-drinking at the cap. Healthy players keep fighting after the cap; low HP can recover while selected potions remain in budget. Stop/home restore the user's previous game potion slot and threshold.

Boss detection now uses a loaded living model first, a positive respawn countdown second, and room scouting when there is no countdown. An empty scouted room triggers hopping in hop mode. Turning on hop mode while stopped starts the assistant. Potion settings continue across hops. Cooldowns, pending connections and errors are visible. A resource failure returns home and stops that run.

Nearby E actions open tagged LootBox parts and collect Drop parts within the game reach, with owner protection, pickup delay and throttled retries. Confirmation is reported from tag/parent/state changes rather than assuming a remote request succeeded. Native Auto still handles farm movement.

Validation:

- **52 policy/regression checks** cover healing with remaining budget, no-heal and exhausted-budget retreat, exact-cap auto-drink disable, per-type inventory accounting, scout/countdown/model precedence, empty-room hopping, hop-mode start, drop protection and previous travel/dungeon policies.
- **Actual Gorilla King kill passed** with a Lv.35 character: HP **32,614 → 0**, configured Red Potion (M), HP threshold **90%**, budget **25**, observed use **17 potions**. This exceeded the old 5-potion limit and completed the fight. Loot delay, home return and original BotJson/potion/Auto restoration all passed. Original slot **red_potion** and threshold **50%** returned; native Auto was on as before. At return completion, distance to recorded home was **0.88 studs**.
- During that run, nearby item/box state confirmations reached 26. Remote inspection identified actual `OpenLootBox` calls from the helper; these are separate from material pickup requests. Further per-kind counters are now included in runtime state.
- Main script loaded without a runtime error. Worker routing and all 9 PNG asset tests passed.

Inventory accounting observes net server updates: use and receipt of the exact same item in one update can conceal consumption. A native potion request already in flight may complete around the cap. No stronger claim of an atomic server-enforced budget is made. Full dungeon completion remains untested at this character level.

## Version 3.2.0-boss-assistant — 2026-11-02

Customer feedback identified two travel bugs: destinations were rejected when their streamed Column was missing, and walking polled short waypoints at the slow director interval. The previous source-offset tolerance could also finish outside the actual pillar interaction distance. Travel now uses persistent model pivots, acknowledges `PillarOpen`, checks distance to the source itself, shares arrival tolerances and advances waypoints in a cancellable Heartbeat worker.

Normal target selection has been removed from the assistant. Start records the farm point and leaves native Auto alone while waiting. A selected-boss trip temporarily changes combat filters, waits for loot, then returns to that exact point and restores the prior settings. Optional Merchant trips, free dungeon entry and public-server hopping are separate controls, off by default.

Verified so far:

- **38/38 deterministic regression checks**: level/free-run/party checks, unstreamed destination routing, arrival tolerance, idle movement ownership, recorded return coordinates, boss death/loot/return vs hop transitions, failed-boss retreat, server filtering, payload expiry/server identity, hop-limit return, same-pillar routing, the 100-entry filter cap and Stop cancellation.
- Main script compiles/loads in the connected client without runtime errors.
- Live Town warp and return succeeded; return ended **0.56 studs** from the recorded position. The return cost **1,000 Silver** (5,876 → 4,876). The first stricter-acknowledgement test failed server confirmation; a retry succeeded. Source approach was subsequently tightened to 6 studs and passed in the full Merchant trip below.
- A live field walk completed without the old 9-vs-10-stud dead zone.
- While waiting for a dead boss for **167 seconds**, the assistant had no navigation worker, native Auto stayed on and `BotJson` remained byte-for-byte unchanged.
- Live boss-entry test exposed that the pillar is outside the room; automatic trips now walk into the boss zone after arriving at its pillar. Another live check found the server retains at most **100** exclusions, while the old request sent **111**. Filters now prioritize nearby/adjacent-zone monsters and cap at 100, with native combat restricted to a 60-stud fixed area.
- With those fixes, the live Lv.31 character entered the room, attacked Gorilla King (**32,614 → 21,964 HP observed**), retreated at the five-potion budget, returned home and resumed native Auto. Every saved Auto setting compared equal after restoration (semantic table comparison, independent of JSON key order). The boss was not killed in this run. The test then stopped the assistant/native Auto.
- Full automatic Merchant trip passed: **180 junk items / 4,088 Silver**, comprising glacier_fur ×56, borealis_tail ×123 and briar_thorn ×1 (all `Kind=etc`). Town warp → walk to Merchant → sell → paid return → original point. Silver **13,177 → 16,265**, net **+3,088** after the 1,000 return fee. Distance at return completion was **6.76 studs**, within the 7-stud tolerance. No other item IDs changed in the before/after inventory comparison. The assistant was stopped after the test.
- The published GitHub HTTP loader loaded version **3.2.0-boss-assistant** successfully in the actual client.
- **One real public-server hop passed**, with the test capped at one hop: job `011c6201-3b29-462b-a852-56bcbe7b3fca` → `81dbbaa6-b05e-4f79-8f8a-7ef1463607ef`. The executor reinjected, the HTTP loader automatically loaded 3.2.0, the assistant retained selected `terra_colossus`, hop count 1/max 1 and original home `(15.607, 60.4, -774.495)`. It reached the selected boss's fight stage without manual re-execution, then automatically retreated after the five-potion budget and returned to the recorded point (0 studs at final inspection). The assistant/native Auto were stopped. All **38 checks passed again in the new server**, with no runtime error and no travel worker left active.
- The public-server endpoint responded successfully from the actual client and the picker found an eligible different server. This read-only check does not prove teleport/reinjection works on every executor.
- Endpoint/asset tests: `node deployment/worker.test.mjs` passes for all 9 PNG assets and response handling.

Limits: the connected test character was Lv.31–32 during these runs, whereas the customer's screenshots show Lv.99. Full dungeon completion cannot be validated with this character. Boss death/loot transitions are covered by isolated tests; actual boss defeat/card collection and repeated kill/loot/hop cycles were not verified. One real hop and automatic continuation were verified on this executor only. Official warp unlocks, game fees and executor capability still apply.

## Historical 3.0–3.1 tests (superseded normal-farm director)

Date: 2026-11-02

Entry point: `farm_control_center.luau` / version `3.1.0-travel`
Policy checks: `farm_director_tests.luau`

## What changed

The default screen now has one Start/Stop button, the selected target and current activity, two options (boss detours and free dungeon entry), and live kill/EXP/Silver counters. Advanced settings remain on their existing pages.

The director chooses the highest-level living non-boss monster at or below the player's level that can be reached through the current gates. Leaders are included. It uses `SetBotSettings` to filter targets and the game's native Auto combat/skills/loot. Movement uses ordinary Humanoid movement and pathfinding. A blocked route is temporarily excluded instead of being retried continuously.

Low HP or slow kills cause a retreat/difficulty reduction. Bosses have their own timeout, healing-potion budget, and failed-spawn memory. A failed boss is skipped for that spawn; the timed cooldown also prevents immediate retries. A confirmed boss kill reserves five seconds for native Auto Loot before resuming ordinary farming.

## Live farming test

Initial level: 30; class: Archer. Current access allowed Bear Forest; the next ordinary field was behind the Gorilla King gate.

| Measurement | Start | After 75 seconds |
|---|---:|---:|
| Level | 30 | 31 |
| EXP within current level | 12,483 | 319 |
| Total EXP gained, including level rollover | — | 4,103 |
| Silver | 3,759 | 4,741 |
| Confirmed target HP-to-zero events | — | 11 |

This is an observed run, not a guaranteed farming rate. Drops, monster competition, buffs and party effects can change the result.

Stopping the director disabled native Auto and restored the original target exclusions (zero excluded IDs) while preserving the Archer skill list.

## Live boss test

- The director noticed the real Gorilla King spawn using `BossAlive_terra_colossus`, switched from ordinary farming, walked to the boss room and targeted `terra_colossus` through native combat.
- Observed boss HP decreased from 32,614 to at least 14,056.
- The character returned to ordinary farming while the boss was still alive. A full boss kill and its card drop were **not** verified.
- The initial two-minute retry caused another attempt against the same surviving boss. That behavior was changed: failed spawns are now remembered, the cooldown is ten minutes, and five consumed healing potions trigger a retreat.
- During the longer pre-budget test, native Auto used healing potions: the observed red-potion count fell from 248 before testing to 214. The director did not buy replacement items.
- The revised budget was then exercised live: the status recorded the five-potion retreat, the director returned to `borealis_fox`, and a fresh selection still picked the ordinary monster while `BossAlive_terra_colossus` remained true. The failed spawn was recorded, confirming that the same living boss was skipped.
- The main screen's Start/Stop button was clicked through the live GUI to exercise its actual callback.

## Dungeon status

The connected game's `DungeonData` contains Skull King's Crypt with `MinLevel = 90`. The tested character reached level 31. Live dungeon entry and completion therefore remain **unverified**.

The director displays this requirement, checks the NPC's authoritative dungeon list, requires explicit party-leader status, checks every supplied party member's level, uses each definition's `Id` rather than its array index, and requires positive remaining free runs. The entry request selects Easy and never buys or consumes a key automatically. Once eligible, it can walk to the known GateKeeper prompt and request the normal selection UI.

Cross-place teleport continuation is not installed. When entry transfers to a different place, this local script must be loaded there again. The dungeon's own Auto combat is used after loading; full dungeon navigation and loot extraction still need a level-90 test character and a private test run.

## Deterministic checks

16 checks passed, 0 failed:

- Below-level dungeon rejection; valid free-run acceptance; exhausted free runs rejected even when keys exist.
- Non-leader and missing leader authorization rejected.
- Underleveled party member rejected; missing free-run counters rejected.
- Definition ID preserved for array-based lists; highest eligible free dungeon selected.
- Unknown maps rejected; live target satisfies level/access rules.
- EXP accounting across a level rollover.
- Low-health retreat; five-potion boss retreat; four-potion allowance; ordinary combat not subject to the boss-only potion budget.

These checks call selection/calculation methods. They do not send dungeon entry requests, mutate inventories, or simulate a completed dungeon.

## Remaining verification

- Defeat a full boss with sufficient character strength; confirm card ownership and the loot grace period.
- Live dungeon entry, party readiness, cross-place continuation, completion and extracted gear.
- Long-distance route coverage for later zones and long-duration recovery after disconnects.
- Stat-based gear comparison, automatic reroll and automatic refinement are not enabled by the Start button; the existing manual gear tools remain available.

## Travel, Auto Equip and GitHub loader (v3.1)

- Discovered that the older `WarpTo` UI is not the active pillar implementation. A proximity request on that path failed, and the implementation was replaced with the verified `WarpPillarClient` protocol: activate the pillar prompt and call `PillarWarp` with the unlocked pillar ID.
- Live trip from Bear Forest to Town completed through the free pillar route.
- Return used the unlocked Boss01 pillar, paid the official 1,000 Silver fee, then walked back to the saved Field03 position. Arrival was verified within 9.16 studs of the original bookmark. The fee is shown on the applicable destination/Return button.
- Auto Equip was enabled and the server attribute confirmed `true`. It uses the game's equipment policy; it is not a custom stat optimizer and the displayed total Combat Power can change with buffs/equipment.
- Loaded the published GitHub `loader.luau` through `loadstring(game:HttpGet(...))()` in the connected client. Result: `ok=true`, main GUI present, version `3.1.0-travel`, no main/director error, all nine image files available.
- The dedicated HTTP worker's routing, HEAD handling, rejected methods, upstream failure and all nine PNG byte counts/signatures passed local checks. The worker was not deployed.
- `api.dukehub.lol/loader` was observed serving an existing DUKE HUB/Luarmor loader. It was not modified. The repository includes a game-specific dispatch snippet for its backend owner to integrate.
- The deterministic suite now adds three travel-route checks (Town free, unknown pillar locked, unknown destination not guessed), for 19 checks total.
