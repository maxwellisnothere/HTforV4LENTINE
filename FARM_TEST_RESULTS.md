# Boss Assistant — functional test results

## Version 3.3.3-farm-resume — 2026-11-04

Customer feedback: the character returned to the saved farm location but did not resume attacking.

- Found a stale-state path: server hopping used the Auto value saved when the watcher started, so enabling Auto afterward could still leave the return state OFF. Idle changes now refresh the farm snapshot; active trips and teleport continuation keep it frozen.
- Return handling now reapplies the farm settings after arrival, waits for filter/potion acknowledgement, resets native Auto to refresh its target/fixed-area anchor, and requires one second of stable Auto-state confirmation. A 12-second Auto acknowledgement timeout reports failure. The completion check confirms Auto state, not guaranteed monster availability or damage.
- **Live controlled return-leg check passed:** started the watcher with Auto OFF, enabled Auto afterward, confirmed the updated snapshot, applied the real boss target filter, made a short local departure, then used `BeginReturn` and the real travel/restore path. The saved farm filters returned; native Auto selected **Gem Armadillo**, whose observed HP fell **9,136 -> 6,863**. A temporary farm radius of 60 was used to ensure available targets. HP observation confirms combat activity but is not per-attacker damage attribution.
- Cleanup restored the original radius/settings and Auto state, stopped the assistant and returned within **5.62 studs** of the original location. No warp fee was incurred by the local test. The existing boss-kill/hop tests below are historical; a fresh full boss kill/hop/dungeon cycle was not run for this patch.
- Deterministic policy regression suite: **72 passed, 0 failed**, including late Auto changes, explicit Auto OFF, snapshot preservation during trips, restart acknowledgement and delayed acknowledgement.
- Loader routing/error handling and all nine bundled PNG assets passed the existing Node checks.

## Version 3.3.2-boss-entry — 2026-11-03

Customer feedback: Volcano Turtle required a manual Auto click; walks toward warp pillars often stalled.

Confirmed causes and changes:

- The warp goal was inside the solid Column/pedestal. A live Field10 → Boss03 source walk stalled at the sky bridge rail (`x≈10.91, z≈-2795.05`) after pathfinding could not reach the pillar center. The new approach planner tests up to eight ground points **8.5 studs beside the pillar**, chooses a reachable path and checks actual prompt range. The revised path crossed the bridge and the source opened at **7.93 studs**, followed by a confirmed Boss05 warp.
- The connected game's avatar has **JumpPower=0 / JumpHeight=0**. Paths previously allowed jumps and could lead into the Town event booth crates. Navigation now matches the avatar's jump capability, uses tighter horizontal waypoint completion, detects lack of progress toward the waypoint (rather than counting sideways/jumping jitter), and permits up to three plans with collision-checked lateral recovery. Recovery briefly preserves facing direction so the avatar can strafe out of a tight corner; AutoRotate is restored afterward.
- Ordinary bosses use Size **16**, while the Turtle is Size **72** and its PrimaryPart was observed at **Y≈317**, over 30 studs above the player's **Y≈284**. The old fixed 24-stud 3D gate could never be satisfied. Engagement now uses a size-aware horizontal distance (52 for the Turtle, 24 for ordinary bosses), and native target range scales to **92** for the Turtle. Native combat owns fighting after engagement.
- Boss-room travel waits up to eight seconds for the zone to stream in, approaches the near arena edge rather than the spawn center and sets potions before departure. The first manual scouting run waited at the arena center and died as the boss spawned; it used free Town respawn. No boss kill is inferred from that failed run.

Verified so far:

- The revised Town → Boss05 journey completed, including a source acknowledgement at **10.00 studs**.
- Auto **turned on without manual input**, selected **Volcano Turtle King**, and boss HP decreased from **1,330,000 to 1,255,483** in the first observed combat sample. Native HP potion use was active.
- **66/66 regression checks** cover pillar clearance, giant-boss range/height, near-edge entry, horizontal waypoints and disabled jumping in addition to previous policies. Endpoint/artwork checks pass.
- The Lv.99 Thief test character subsequently **died during the Turtle fight** after using six HP potions. The observed HP decrease above verifies automatic targeting/attack, not a completed kill. The assistant was stopped, native HP settings returned to **70%**, and free Town respawn was used. Full Turtle defeat is not verified for this build; level 99 alone did not provide sufficient survivability in this run.
- A further **Town → Boss03** warp completed after the jump-capability fix, with source acknowledgement at **9.43 studs**. The character then walked back across the sky bridge to its original Field10 point, using the middle of the bridge instead of the rail where the baseline stalled. Final distance **4.42 studs**, HP **5,823/5,823**, native Auto **OFF**, native potion threshold **70%**, assistant stopped and no active travel/error.

## Version 3.3.1-box-walk — 2026-11-02

The earlier pickup helper only acted inside E reach. It now actively walks to tagged loot boxes within 70 studs while native Auto is running, pauses native movement, opens through the real E prompt, returns to its captured departure point and restores Auto. It keeps the movement owner separate from boss/warp/dungeon trips, rejects different floors, supports cancellation and stops blocked/expired routes. The game's `OpenTitle` attribute now confirms the box result; the previous removal-only detection could miss a successful opening while its animation was still present.

Verified with an actual spawned `LootBox_relic_box`:

- Automatic selection at **15.50 studs**, beyond E reach.
- Walked to **3.20 studs**, then sent **one** opening request through the box prompt.
- Server replicated **OpenTitle = LUCKY DROP!** and its item-drop buff description; the box then disappeared. This is a confirmed opening, not merely a queued request.
- Returned to **2.33 studs** from the departure position and restored native Auto to **ON**.
- The box's ownership interval was respected before collection.
- **59/59 regression checks** pass, including walk eligibility, movement priority, radius/height limits, cancellation/restoration, retained return origin and deduplicated confirmation, plus the previous 52 checks. Main script has no recorded runtime error. Endpoint/artwork checks also pass.

## Version 3.3.0-boss-sustain — 2026-11-02

The fixed five-potion retreat and three-minute deadline have been replaced with user-controlled HP threshold, potion slot, per-boss use budget, retreat HP after resources are exhausted, and optional fight duration. The game accepts HP auto-drink thresholds up to 90% in steps of 5. Budget tracking accumulates inventory decreases separately for each HP potion and disables native HP auto-drinking at the cap. Healthy players keep fighting after the cap; low HP can recover while selected potions remain in budget. Stop/home restore the user's previous game potion slot and threshold.

Boss detection now uses a loaded living model first, a positive respawn countdown second, and room scouting when there is no countdown. An empty scouted room triggers hopping in hop mode. Turning on hop mode while stopped starts the assistant. Potion settings continue across hops. Cooldowns, pending connections and errors are visible. A resource failure returns home and stops that run.

Nearby E actions open tagged LootBox parts and collect Drop parts within the game reach, with owner protection, pickup delay and throttled retries. Confirmation is reported from tag/parent/state changes rather than assuming a remote request succeeded. Native Auto still handles farm movement.

Validation:

- **52 policy/regression checks** cover healing with remaining budget, no-heal and exhausted-budget retreat, exact-cap auto-drink disable, per-type inventory accounting, scout/countdown/model precedence, empty-room hopping, hop-mode start, drop protection and previous travel/dungeon policies.
- **Actual Gorilla King kill passed** with a Lv.35 character: HP **32,614 → 0**, configured Red Potion (M), HP threshold **90%**, budget **25**, observed use **17 potions**. This exceeded the old 5-potion limit and completed the fight. Loot delay, home return and original BotJson/potion/Auto restoration all passed. Original slot **red_potion** and threshold **50%** returned; native Auto was on as before. At return completion, distance to recorded home was **0.88 studs**.
- During that run, nearby item/box state confirmations reached 26. Remote inspection identified actual `OpenLootBox` calls from the helper; these are separate from material pickup requests. Further per-kind counters are now included in runtime state.
- Main script loaded without a runtime error. Worker routing and all 9 PNG asset tests passed.
- Automatic public-server searching passed with a two-hop test cap: `a94802c2-1ba0-40d5-8bfb-4435ef927378` → `d69bdb98-5b5e-4839-8574-efcc0f6c5728` → `4b882ed6-dcdf-4dc0-ba35-bc5db7a1d9f8`. Both new servers automatically loaded 3.3.0. The second continuation retained **HP 90%, budget 25, red_potion_m**, selected boss, visited-server history and the original point `(-50.706, 60.4, -718.887)`. With no countdown in the second server, it entered the room instead of waiting outside.
- That final server's Gorilla King was **killed with 16 M potions**. At the two-hop limit, the assistant returned home (**0.85 studs**), restored **red_potion / 50%**, disabled hop mode and stopped without an active travel worker or runtime error. Native Auto was off as recorded before that test. This verifies real automatic skip/continuation, a subsequent kill and bounded return; an unlimited repeated kill/hop run was not attempted.
- Visual inspection in the real client confirmed the HP, budget, retreat, time and potion-choice controls render and show the configured values. Auto is suspended throughout assistant travel, and its bindable menu action runs at the game's script identity to avoid executor-context toggle failures.

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
