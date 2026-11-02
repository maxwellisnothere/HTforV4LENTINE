# DUKE HUB — Hunting Together RPG

## Run

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/maxwellisnothere/HTforV4LENTINE/main/loader.luau"))()
```

The loader installs the supplied logo/icons into `duke_hub_assets` and launches the control center. It does not require the original Windows artwork paths. The executor must support `loadstring` and HTTP requests. File/custom-asset APIs enable the bundled images; text fallbacks are available otherwise.

## Controls

- **เริ่มฟาร์ม**: one-button target planning, native auto combat, skills, rewards and quest claims. Start is off initially.
- **Auto Equip**: enabled by default; the game's server chooses equipment by its own Combat Power policy. This does not guarantee the best DEX/CRIT build.
- **วาร์ป / กลับ**: choose a destination, then return to the position saved before departure. Town is free; unlocked boss pillars show their Silver fee. A nearby unlocked pillar can shorten travel to a field, followed by walking. The Return button also shows any pillar fee. Other routes use pathfinding. Level and boss gates remain enforced.
- Boss detours stop on low health, slow kills or the five-potion boss budget. Failed boss spawns are remembered.
- Dungeon requests require level, party and free-run checks. The observed Crypt requires level 90; end-to-end completion has not been verified.
- **RightControl** hides/shows the window.

Native Auto may consume healing potions configured in the game. Press Stop to stop the director and restore its original monster filters. Auto Equip has its own switch.

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
