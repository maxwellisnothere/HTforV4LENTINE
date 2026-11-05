# DUKE HUB — Hunting Together RPG

Current version: **3.5.0-exploits**.

New **Exploits tab** with 37 one-tap buttons (no dropdowns — everything is shown directly), grouped into 7 sections:
- **Rewards**: claim C8 / Monthly / Online / Makeup, and use EXP / Drop / Haste / Awakening potions (or all four at once).
- **Achievements**: claim all ready achievements, grant the War Rabbit mount, and cycle equipped titles.
- **Combat**: Auto Combat (lock nearest + native Auto), **Auto Dodge** (auto-steps out of boss AoE warning circles to save HP/potions), Anchor (knockback immunity), Noclip, and a skill button.
- **Camera**: max zoom-out / reset.
- **Warp**: Town and Boss01–05, plus a pillar-warp.
- **Shop & Storage**: sell junk, expand bag, go to storage, deposit/withdraw refine stones, refine +1.
- **Utility**: clear cheat tag, save loadout, sit & rest, stand up, and grab nearby loot boxes/drops.

All other pages now open fully expanded — the old click-to-expand sections no longer hide their buttons.

Previous: Anti-AFK toggle (VirtualUser every 55s), return-to-farm resume retry, island ramp routing.

## Run

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/maxwellisnothere/HTforV4LENTINE/main/loader.luau"))()
```

The loader installs the supplied logo/icons into `duke_hub_assets` and launches the control center. It does not require the original Windows artwork paths. The executor must support `loadstring` and HTTP requests. File/custom-asset APIs enable the bundled images; text fallbacks are available otherwise.

## Controls

- **เฝ้าบอส**: stand at your farming spot, configure/enable the game's Auto, select one boss in **บอส 10 นาที**, then press **จำจุดนี้และเริ่มเฝ้าบอส**. The assistant leaves normal farming to the game. When the selected eligible boss appears, it saves your Auto settings, travels to the boss, uses native combat, waits for loot, returns to the recorded coordinates and restores your settings.
- **จำจุดฟาร์มนี้** updates the return point while idle. A trip in progress cannot overwrite it. Stop cancels assistant movement; stopping while idle leaves the game's Auto running. Stopping during a trip pauses combat and restores its filters; use the Travel page to return manually.
- **Auto Equip**: enabled by default; the game's server chooses equipment by its own Combat Power policy. This does not guarantee the best DEX/CRIT build.
- **วาร์ป / กลับ**: choose a destination, then return to the position saved before departure. Town is free; unlocked boss pillars show their Silver fee. A nearby unlocked pillar can shorten travel to a field, followed by walking. The Return button also shows any pillar fee. Other routes use pathfinding. Level and boss gates remain enforced.
- **ล่าบอสข้ามเซิร์ฟ** is optional and off initially. Turning it on while stopped also starts the assistant. It hunts only the selected boss, then moves to another public server after the loot delay. A positive respawn countdown triggers a new-server search; with no countdown, it enters the room and looks for the actual boss before deciding the room is empty. Empty rooms also trigger hopping. The UI shows cooldown, pending connection and failure reasons. It skips full/current/recently visited servers, limits successful hops to 10 per run, returns home at that limit and backs off on errors. A resource/health failure returns home and stops the run so it does not repeat an unaffordable fight. The executor must support `queue_on_teleport`/`queueonteleport` (or `syn.queue_on_teleport`) and reinjection after teleport. Selected boss, original point, Auto settings and the healing configuration carry forward to the intended server.
- **กลับเมืองขาย Junk** is optional and off initially. Premium/nearby Merchant sales happen in place; otherwise the assistant visits the Merchant and returns. It sells only the game's official unlocked junk. It waits for at least 25 items and enough estimated value to cover the return warp plus 100 Silver. It does not sell equipment or boss cards.
- **ยาและงบต่อบอส**: set the native HP auto-drink threshold (5–90%, in steps of 5), potion type (current game slot / Red S / Red M / Red L), maximum HP potions per boss (0–9,999; 0 means no potions), retreat HP (1–80%) and optional fight time (0–60 minutes; 0 means no time limit). Defaults: 70%, current slot, 50 potions, retreat at 25%, unlimited time. Low HP alone does not interrupt a boss fight while selected potions remain within budget. At the budget, auto-drinking is disabled; the player can keep fighting while healthy and retreats when HP reaches the chosen limit. The original game potion slot/threshold and Auto settings are restored at home or on Stop. A manual Start permits retrying the selected boss with revised settings. Inventory decreases are counted separately per HP potion type, so a different potion drop does not hide use; a server update that combines use and receipt of the exact same item can still conceal the net decrease. An already in-flight game request may consume a potion around the cap.
- **เดินเปิดกล่อง E (70 studs) และเก็บของ**: enabled initially. While the game's Auto is running, a tagged loot box within 70 studs on the same floor can trigger a short collection trip. The assistant pauses Auto, remembers the current position, walks within 5 studs, uses the box's E prompt (or its game remote), waits for `OpenTitle`/removal confirmation, walks back and restores Auto. It observes owner protection, respects a 12-stud height difference, throttles retries and times out blocked paths. Boss/dungeon/warp/server-hop movement takes priority; a box trip already underway finishes before the waiting boss planner continues. Turning this toggle off or pressing Cancel Travel cancels the collection trip and restores Auto. Material Drop pickup remains limited to the game's nearby reach. It does not walk after boxes while native Auto is stopped.
- **ลงดันด้วยรอบฟรี** is optional and off initially. Entry requires level, party and free-run checks. The observed Crypt requires level 90 and is restricted in this test universe; full dungeon combat/completion and continuation across dungeon teleports are not implemented or verified. No keys are bought or consumed by the assistant.
- **RightControl** hides/shows the window.

Native Auto may consume healing potions configured in the game. Warp fees follow the game; repeat boss trips and server hopping can spend Silver. Auto Equip has its own switch. Reward and quest helpers remain separate opt-in controls.

Travel no longer requires a loaded destination Column: it uses the persistent pillar model pivot and waits for the source pillar's `PillarOpen` acknowledgement. Walking advances continuously in one cancellable worker. Fields without pillars use ordinary paths; locked gates remain enforced.

Warp travel selects a reachable standing point 8.5 studs beside the solid pillar, rather than pathfinding into its center. Waypoints use horizontal precision with allowance for the avatar's normal height above the floor. A stalled path can take a short collision-checked sidestep and replan, up to three attempts. Boss travel waits for the room zone to stream in and approaches its near edge. Potions are configured before departure. Boss engagement and native target radius account for model size: the 72-size Volcano Turtle no longer has to satisfy the same center-distance check as 16-size bosses, and its elevated center does not prevent Auto from starting.

Roblox references used for the server browser and failure handling: [public server endpoints](https://create.roblox.com/docs/cloud/reference/domains/games), [TeleportService](https://create.roblox.com/docs/reference/engine/classes/TeleportService).

## Custom domain

Desired entry point:

```lua
loadstring(game:HttpGet("https://api.dukehub.lol/loader"))()
```

That URL already serves a different live DUKE HUB/Luarmor loader. Publishing this repository alone does not change it. Add the snippet in [`deployment/loader-dispatch.luau`](deployment/loader-dispatch.luau) at the top of the existing endpoint response so HT routes here and other games retain their existing loader. Domain/backend access is required for that deployment.

[`deployment/worker.mjs`](deployment/worker.mjs) is an optional dedicated endpoint implementation. It is not automatically deployed and should not overwrite the existing multi-game service without integration.

## Verification

See [`FARM_TEST_RESULTS.md`](FARM_TEST_RESULTS.md). `farm_director_tests.luau` runs deterministic policy checks after the main script is loaded.

Client-side security test observations and remaining coverage gaps are recorded in [`SECURITY_TEST_RESULTS.md`](SECURITY_TEST_RESULTS.md), updated 2026-11-04. This documentation update does not change the runtime version or deploy server-side fixes.

Endpoint/asset verification: `node deployment/worker.test.mjs`.

The supplied PNG artwork is bundled for this user-requested project. No asset license beyond the original owner's rights is asserted here.
