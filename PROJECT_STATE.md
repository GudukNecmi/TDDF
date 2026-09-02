# PROJECT_STATE.md — World Map Expansion / Travel Portals / Bandit AI

Change-set snapshot for the task **"World Map Expansion + Travel Portals + Improved Bandit AI"**.
Written to help diagnose a **World Map performance regression** reported after this task landed —
this file is a record only, nothing here has been modified, reverted, or optimized.

Plan this task followed: `C:\Users\rdplm\.claude\plans\dazzling-herding-badger.md`

---

## 1. World Map size + region layout

**File:** `Scenes/World/WorldMap.tscn`

- `WorldMap.bounds`: `Rect2(-3000,-2000,6000,4000)` → `Rect2(-5000,-5000,10000,10000)` (24M px² →
  100M px², ~4.17× area, now square instead of 6:4).
- `Terrain/Floor` (`TiledSurface`): position/polygon/`surface_size` resized to match new bounds
  (`texture_scale` kept at `(4,4)`).
- `Terrain/Bounds` walls (TopWall/BottomWall/LeftWall/RightWall): positions + `RectangleShape2D`
  sizes moved to new edges (±5032, 10128×64 / 64×10128).
- `Camera/Zone` (`WorldZone.region`): updated to `Rect2(-5000,-5000,10000,10000)`.
- `Regions/RegionA`–`RegionE` (`WorldMapRegionZone.area`): each grew from 1200×4000 to
  **2000×10000**, still 5 contiguous west→east vertical bands:
  - A `Rect2(-5000,-5000,2000,10000)`, B `Rect2(-3000,-5000,2000,10000)`,
    C `Rect2(-1000,-5000,2000,10000)`, D `Rect2(1000,-5000,2000,10000)`,
    E `Rect2(3000,-5000,2000,10000)`.
- `Terrain/Boundaries/Rock0`–`Rock51` (52 nodes): repositioned via a "nearest-border-delta"
  transform (x shifted by the fixed per-border delta appropriate to old→new edges; y scaled ×2.5).
- `WorldBandits/Routes/*` (13 routes × 3 points) and `WorldBandits/Groups/*` (13 bandit spawns):
  positions transformed via a per-region affine (non-uniform scale + translate about each region's
  own center) to keep the same relative arrangement in the larger region footprint.
- `Roads/MainSpine`: scale `(187.5,4.6875)` → `(625,7.5)`.
- `Roads/AltPassBC`: position `(-650,700)`→`(-1050,1750)`, scale `(46.875,3.75)`→`(78.125,6)`.
- `Roads/AltPassCD`: position `(650,-700)`→`(1050,-1750)`, scale `(46.875,3.75)`→`(78.125,6)`.
- `Player/SpawnPoint`: `(-2600,0)` → `(-4333.3333,0)`.
- `ReturnGate`: `(-2600,420)` → `(-4333.3333,1050)`.
- Region `.tres` files (`region_a.tres`…`region_e.tres`) `map_position`/`map_size` fractions:
  **not modified** — old (1200/6000=0.2) and new (2000/10000=0.2) west→east proportions are
  identical, so no change was needed.

**Deviation from the plan's literal wording:** the plan described a "settlement pocket + open
buffer margin" layout inside each expanded region band. What was actually implemented is a full
proportional affine stretch of *all* existing content (props, routes, rocks, locations) across the
whole new band — simpler, avoids visual-misalignment risk, still satisfies "square, ~4× area, no
squeezing, more room to travel." Flagging this here since it changes the *distribution* of content
across the map versus what the plan described.

---

## 2. New terrain nodes on `WorldMap.tscn` (relevant to a perf regression)

Under `Terrain`, 5 new **`Polygon2D` (`TiledSurface`)** background layers, drawn above the base
`Floor`, one per region, each `2000×10000`, `texture_scale=(4,4)`, `tile_size=1000.0`:
`GroundA`, `GroundB`, `GroundC`, `GroundD`, `GroundE` (Dust Camp / Old Mine / Ghost Town /
Red River / The Dead background PNGs respectively).

4 new **`Mountain.tscn`** instances (new prop scene, see §4): `MountainB1`, `MountainA1`,
`MountainC1`, `MountainD1` — replacing the single old hand-authored `Terrain/Mountain1` node
(**deleted**).

New **`Scenery`** container (parent `.`) with 3 `PropScatter` nodes (script `prop_scatter.gd`):
- `SharedScatter` — `region = Rect2(-5000,-5000,10000,10000)` (**the full 100M px² map**), layers
  `scatter_worldmap_cacti.tres` (count 420), `scatter_worldmap_bushes.tres` (count 520),
  `scatter_worldmap_bones.tres` (count 280) → **up to 1220 scattered prop instances** across the
  whole map, each going through `PropFooting`/`PropArt`/`PropTouch`/`ShadowCaster`.
- `DustCampScatter` — region A pocket, `scatter_dust_camp_tents.tres`.
- `DeadScatter` — region E pocket, `scatter_the_dead_stakes.tres`.

New **`TravelPortals`** container (parent `.`) with 7 `TravelPortal.tscn` instances (see §5), each
running a `_process()` swirl/pulse animation continuously.

New **`WorldMapTravelService`** node (script `world_map_travel_service.gd`).

> **Perf-regression note:** the single largest new cost surface is almost certainly
> `SharedScatter`'s **1220** new prop instances spread over the whole map (vs. the old map's much
> smaller total footprint), plus the 5 new full-band `TiledSurface` background layers, plus 7
> `TravelPortal` instances each ticking `_process()` every frame. None of these existed before this
> task. The Arena's own pre-existing `PropScatter` usage (in `World.tscn`) was left untouched at its
> original counts (48/60/33) and is not implicated.

---

## 3. New ext_resources added to `WorldMap.tscn`

`prop_scatter.gd`, `scatter_layer.gd`, `scatter_worldmap_cacti.tres`, `scatter_worldmap_bushes.tres`,
`scatter_worldmap_bones.tres`, `scatter_dust_camp_tents.tres`, `scatter_the_dead_stakes.tres`,
`Mountain.tscn`, `TravelPortal.tscn`, `world_map_travel_service.gd`, and 5 region background PNGs
(Dust Camp / Old Mine / Ghost Town / Red River / The Dead).

New standalone resource files (new, not edits to shared Arena scatter resources):
- `Resources/Maps/Desert/scatter_worldmap_cacti.tres` (count=420, scale_range 0.85–1.2,
  min_separation=320)
- `Resources/Maps/Desert/scatter_worldmap_bushes.tres` (count=520, min_separation=230)
- `Resources/Maps/Desert/scatter_worldmap_bones.tres` (count=280, min_separation=300)

---

## 4. New scene: `Scenes/World/Props/Desert/Mountain.tscn`

Extracted from the old hand-placed `Terrain/Mountain1`. Root `Sprite2D` "Mountain"
(`groups=["impassable_terrain"]`, `z_index=-12`, texture `Mountain1.PNG`), child `StaticBody2D`
"Collision" (`collision_layer=32, collision_mask=0`), child `CollisionPolygon2D` "Shape" (same
40-point polygon as the original). 4 instances placed on `WorldMap.tscn` (§2).

---

## 5. New Travel Portal system

**New scene:** `Scenes/World/TravelPortal.tscn` — root `Node2D` (script `travel_portal.gd`,
`interaction_radius=190.0`), child `Icon` (placeholder dot), child `PortalArt` = instance of
`ArenaPortal.tscn` with `script = null` override (art/light kept, `arena_portal.gd` behavior
stripped), nested overrides `PortalArt/Light.energy=1.6`, `PortalArt/Prompt.visible=false`.

**New script:** `Scripts/World/travel_portal.gd` — `class_name TravelPortal extends
WorldMapLocation`. Runs a continuous `_process()` swirl/pulse (rotation + scale + light energy
oscillation) on every instance. Exports `destination: NodePath`, `arrival_offset`.

**New script:** `Scripts/World/world_map_travel_service.gd` — `class_name WorldMapTravelService
extends Node`. One instance on `WorldMap.tscn`. Handles the full jump flow: freezes player via
`travel_hold` group, holds all `world_bandit` group members inactive, freezes `WorldClock`
(`freeze_for_combat`/`unfreeze_after_combat(0.0)` — a portal jump never advances world time),
drives `TravelLetterbox`, and calls the new `LoadingCurtain.begin_transition()` (see §7).

**7 portal instances** under `WorldMap.tscn`'s new `TravelPortals` container, chained:
- `DustCamp_Portal` (region A, world_position `(-3150,0)`) → `OldMine_PortalWest`
- `OldMine_PortalWest` (region B, `(-2850,0)`) → `DustCamp_Portal`
- `OldMine_PortalEast` (region B, `(-1150,0)`) → `GhostTown_PortalWest`
- `GhostTown_PortalWest` (region C, `(-850,0)`) → `OldMine_PortalEast`
- `GhostTown_PortalEast` (region C, `(850,0)`) → `RedRiver_Portal`
- `RedRiver_Portal` (region D, `(2200,0)`) → `Dead_Portal`
- `Dead_Portal` (region E, `(3150,0)`) → *(no destination — intentional, single entrance)*

Each backed by a new `[sub_resource type="Resource"]` `MapLocation` block (`location_type = 7`,
new `TRAVEL_PORTAL` enum value).

**Circular-dependency note:** `travel_portal.gd` and `world_map_travel_service.gd` deliberately do
**not** statically type-reference each other's `class_name` (this caused a real compile failure —
see §8) — they use group-lookup + `Object.call(&"method_name", ...)` duck-typing instead.

---

## 6. `map_location.gd` / `world_map_location.gd`

- `Scripts/World/map_location.gd`: added `TRAVEL_PORTAL` to `LocationType` enum (appended after
  `BLOOD_DEPOT`, index 7 — no existing serialized type shifted).
- `Scripts/World/world_map_location.gd`: added `TRAVEL_PORTAL` entries to `COLORS`
  (`Color(0.35,0.75,0.85)`), `SCALES` (`1.4`), `ACTION_LABELS` (`"TRAVEL"`).

---

## 7. `Scripts/Common/loading_screen.gd`

Added new public method `begin_transition(caption, duration, on_ready: Callable, stinger)` for
same-scene Travel Portal jumps — reuses all existing curtain/caption/backdrop/stinger setup and the
existing `_finish()` path. The pre-existing `begin()` (scene-swap loading) path is **unmodified**.

**New file:** `Scripts/Player/travel_hold.gd` — `class_name TravelHold extends Node`, group
`"travel_hold"`, mirrors the existing `ExtractionHold` but is reversible (`set_frozen(true/false)`
instead of one-way). Added as a new node on `Scenes/Player/Player.tscn` (`speed_modifier_paths`
updated to include it).

---

## 8. Automatic impassable-terrain clearance

**File:** `Scripts/World/prop_scatter.gd` — new `@export_group("Impassable clearance")`:
`impassable_group: StringName = &"impassable_terrain"`, `impassable_clearance_margin: float =
80.0`. `_lay_out()` now also collects every node in that group, reads its existing
`CollisionShape2D`/`CollisionPolygon2D` world-space AABB (rotation-safe, 4-corner transform), and
rejects scatter points that fall inside those boxes (+ margin), on top of the existing hand-authored
`keep_clear` rectangle list. Applies to **every** `PropScatter` node in the project, including the
Arena's pre-existing one — additive only, no existing behavior changed there.

---

## 9. Bandit AI changes

**File:** `Scripts/World/world_bandit.gd`

- `enum BehaviorState`: added `DISENGAGE` (was `PATROL, INVESTIGATE, CHASE, FLEE`).
- New exports: `give_up_distance: float = 900.0`; `chase_break_distance` default changed
  **`900.0` → `1400.0`**; `disengage_duration: float = 6.0`.
- New `@export_group("State Speed")`: `roam_speed_multiplier=0.7`, `investigate_speed_multiplier
  =1.05`, `disengage_speed_multiplier=0.65`, `min_turn_rate=0.35`, `max_turn_rate=2.5`.
- CHASE now breaks into new DISENGAGE state at `give_up_distance` (was: straight back to PATROL at
  the old, lower `chase_break_distance`); DISENGAGE resolves back to PATROL once past
  `chase_break_distance` or its timer elapses.
- New turn-rate-limited steering (`_move_along_heading`) replacing instant `move_toward()`-based
  direction changes in both chase and patrol movement — heading rotates at most
  `_effective_turn_rate()` radians/sec, sampled from group size (large groups turn slower).
- New `_effective_speed()` applies the new state multipliers (CHASE/FLEE remain unmultiplied,
  reading the existing `speed_profile` curve directly).
- `get_state_name()` updated with `"DISENGAGE"`.
- 13 existing bandit-group nodes on `WorldMap.tscn` all picked up the new exported defaults above
  (values visible per-instance in the scene file, none overridden away from these defaults).

**File:** `Scripts/World/world_bandit_decision_evaluator.gd` — `evaluate()` gained an optional
`strength_override: float = -1.0` parameter (used when combining group strength via reinforcements,
§10; falls back to `bandit.group_strength` when `< 0`).

---

## 10. Group interception / combined encounters

**File:** `Scripts/World/world_map_combat_bridge.gd`

- New export `reinforcement_radius: float = 640.0`.
- New `_reinforcements: Array[WorldBandit]`, plus `_gather_reinforcements()`,
  `_combined_strength()`, `_release_reinforcements(free_them: bool)`.
- `_open_decision()` now gathers + deactivates nearby active bandit groups as reinforcements up
  front; `_tier_for()` and `_begin_encounter()` now use combined strength (for both the decision
  tier shown to the player and the enemy-count formula); reinforcements are released/freed correctly
  on peaceful resolution, abort, and combat-cleared paths.
- Still funnels into the existing `AmbushWaveDirector.begin_with()` / decision-menu flow — no
  parallel combat system added.

---

## 11. Things explicitly left untouched

Per task constraints: `WorldClock`/`WorldTimeManager` internal logic (only called through its
existing freeze/unfreeze API), combat system, Kill Cam, Horse Cart, inventory, bounty system, Film
Shader/`FilmPostProcess`, `LoadingCurtain`'s existing `begin()` path, `TravelLetterbox`,
`WorldMapCombatBridge`'s existing Arena hand-off (only additively extended), `WorldMapExtractionService`.
The Arena's own `World.tscn`-level `PropScatter` usage and its shared `scatter_cacti.tres` /
`scatter_bushes.tres` / `scatter_bones.tres` resources are untouched at original counts. No
map-cleansing/progression, Dead castle seal, multi-floor castle, Forest/Mountain unlock, or
Base-access systems were started (explicitly out of scope).

---

## 12. Known issues / open items at hand-off

- **No playtest/profiling was performed during this task** — validation was explicitly scoped to
  compile/parse/reference checks only (per the original request: "Do NOT spend time doing long
  gameplay/visual playtests"). No frame-time or memory profiling of the new scatter/portal/ground
  content was ever done, which is the most likely gap relative to the reported performance
  regression — see the perf note in §2.
- During implementation, two real bugs were hit and fixed (documented for completeness, both
  resolved before hand-off, not expected to be regression sources but noted in case they're
  relevant):
  - A circular `class_name` static-type dependency between `travel_portal.gd` and
    `world_map_travel_service.gd` that compiled fine in isolation but failed when loaded together —
    fixed via group-lookup/duck-typing (§5).
  - A `.tscn` structural bug where new `[sub_resource]` blocks were appended after existing `[node]`
    blocks, which is invalid Godot text-scene ordering and silently truncated the parsed scene tree
    past that point — fixed by moving all new sub_resources before the first `[node]` block.
  - The Godot MCP tooling itself (`get_editor_errors`/`reload_project`) was observed returning
    stale/cached results during debugging of the above; worked around via forced
    `ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)` reloads. This is a tooling
    reliability quirk, not a project code issue.
- `find_unused_resources` / a full orphan-resource sweep was not completed before hand-off.
