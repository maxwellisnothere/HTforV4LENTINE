# DUKE HUB — Hunting Together RPG

Current version: **3.2.0-boss-assistant**.

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
- **ล่าบอสข้ามเซิร์ฟ** is optional and off initially. Stop the assistant before changing mode. This mode hunts only the selected boss, then moves to another public server after the loot delay; if that boss is absent, it searches again. It must join a server to read boss status. It skips full/current/recently visited servers, limits successful hops to 10 per run and backs off on errors. The executor must support `queue_on_teleport`/`queueonteleport` (or `syn.queue_on_teleport`) and reinjection after teleport. Selected boss, original return point and Auto settings are carried forward only to the intended server. Boss defeat/loot and cross-server continuation still need a full high-level acceptance run.
- **กลับเมืองขาย Junk** is optional and off initially. Premium/nearby Merchant sales happen in place; otherwise the assistant visits the Merchant and returns. It sells only the game's official unlocked junk. It waits for at least 25 items and enough estimated value to cover the return warp plus 100 Silver. It does not sell equipment or boss cards.
- Boss detours stop on low health, slow kills or the five-potion boss budget. Failed boss spawns are remembered; failure returns home instead of chaining fights.
- **ลงดันด้วยรอบฟรี** is optional and off initially. Entry requires level, party and free-run checks. The observed Crypt requires level 90 and is restricted in this test universe; full dungeon combat/completion and continuation across dungeon teleports are not implemented or verified. No keys are bought or consumed by the assistant.
- **RightControl** hides/shows the window.

Native Auto may consume healing potions configured in the game. Warp fees follow the game; repeat boss trips and server hopping can spend Silver. Auto Equip has its own switch. Reward and quest helpers remain separate opt-in controls.

Travel no longer requires a loaded destination Column: it uses the persistent pillar model pivot and waits for the source pillar's `PillarOpen` acknowledgement. Walking advances continuously in one cancellable worker. Fields without pillars use ordinary paths; locked gates remain enforced.

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

Endpoint/asset verification: `node deployment/worker.test.mjs`.

The supplied PNG artwork is bundled for this user-requested project. No asset license beyond the original owner's rights is asserted here.
