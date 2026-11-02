# Smart Farm Director — functional test results

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
