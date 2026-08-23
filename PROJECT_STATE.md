# Gotik — Project State

Snapshot of the project as it stands. Factual inventory only; no design proposals beyond the
single recommended next milestone at the end.

Engine: Godot 4.7, Forward+, D3D12 on Windows. Main scene: `res://Scenes/World/World.tscn`.
Autoloads (`project.godot`): `Blood` (`Scripts/Currency/blood_wallet.gd`),
`BloodBank` (`Scripts/Currency/blood_bank.gd`), `RunProgress` (`Scripts/Run/run_progress.gd`),
`MusicMemory` (`Scripts/Common/music_memory.gd`), `ArenaMusic`
(`Scenes/Common/ArenaMusic.tscn`), plus the three `godot_mcp` service singletons.

---

## 1. Completed systems

- **Player movement** — constant-speed 8-directional WASD, no acceleration. Optional speed
  modifier hook.
- **Shotgun** — follow/sway/aim, fire → spent → pump-back → pump-forward cycle, pellet spread,
  holster (stow/unstow) driven by one blend value.
- **Projectiles** — swept-step pellets with a `ProjectileProfile` resource driving damage, speed,
  colour, glow and light by distance travelled.
- **Damage** — `Health` pool + `Hitbox` areas with per-hitbox damage multipliers (head vs body).
  `HitReaction` (flash/knockback/slow), `DeathFade`, `PlayerDamageFeedback` (sound, screen flash,
  hit-stop freeze, camera punch).
- **Enemies** — chase AI with collision-based separation, knife slash with contact damage,
  per-enemy random appearance via `VariantPicker`, staged defeat sequence.
- **Waves** — timed run with exponentially growing waves, off-screen edge spawning.
- **Blood** — permanent `MultiMesh` decal field, thrown `MultiMesh` spray, in-flight `MultiMesh`
  stream, automatic liquid-flow collection (no input), two persistent currency totals.
- **Base hub** — full scene with blood pool (deposit/withdraw), teleport pit / run portal, saloon
  and four shop stations, parallax pipes, torches.
- **Teleport** — B-key transition between arena and base with audio mute, camera zoom and camera
  limit reassignment.
- **Feedback layer** — `CameraController` (shake / zoom impulse / rotation, always self-righting),
  `ScreenFlash`, `SoundBank`, `LoopingSound`, `MusicDirector` crossfade, torches, casings,
  cutaway buildings, cigarette smoke.
- **HUD** — run timer, carried-blood counter, pause/run-end menu.

---

## 2. Base implementation

`Scenes/Base/Base.tscn`, instanced into `World.tscn` as node `Base` at world position
`(0, 2400)` — i.e. a real area in the same world space, not a separate level file.

Contents:

| Node | Scene | Script | Role |
| --- | --- | --- | --- |
| `Ground/Backdrop`, `Ground/Floor` | — | — | Art |
| `Ground/Bounds` | — | — | `StaticBody2D` with four wall shapes |
| `HubLight` | — | — | `PointLight2D` ambient |
| `BloodPool` | `BloodPool.tscn` | `blood_pool.gd` | Stored-blood pool, group `blood_pool` |
| `TeleportPit` | `TeleportPit.tscn` | `teleport_destination.gd` | Arrival point, `id = base_pit` |
| `TeleportPit/Portal` | — | `run_portal.gd` | Starts the next run, `radius = 78` |
| `TeleportPit/TorchProximity` | — | `torch_proximity.gd` | Torches light as the player nears |
| `Saloon` | `Saloon.tscn` | `cutaway_building.gd` | Walk-in building; `Bar` child is a station |
| `Shops/*` | `Tent.tscn` / `Shop.tscn` | `shop_station.gd` + `cutaway_building.gd` | Four stations |
| `Parallax/PipeLayer` | — | `parallax_drift.gd` | Blood pipes running to each building |

Shop station ids: `gunsmith`, `trader` (tents), `apothecary`, `undertaker` (shops),
`saloon_bar` (inside the saloon). All join group `shop_station`.

---

## 3. Blood architecture

Three separate concerns, deliberately not aware of each other:

**Visuals**
- `BloodField` (`Scripts/World/blood_field.gd`) — `MultiMeshInstance2D`, group `blood_field`,
  found via `BloodField.get_active()`. Permanent floor decals, capacity 8000, one draw call, no
  collision. `add_splash()` stamps blood, `add_speck_at()` stamps one where it landed,
  `make_speck()` / `make_splash_speck()` build a matching speck without staining the floor,
  `take_specks_near()` removes and hands specks back out (currently unused — kept as the seam a
  future "lift settled blood" upgrade would hang off). Cleared only by rebuilding the World scene.
- `BloodSpray` (`Scripts/World/blood_spray.gd`) — `MultiMeshInstance2D`, group `blood_spray`.
  Blood on its way *out* of a body: thrown along the killing hit, arced, and offered to
  `BloodMagnet` where it comes down (falling through to a `BloodField` stain if there is no magnet
  or it is full).
- `BloodStream` (`Scripts/Player/blood_stream.gd`) — `MultiMeshInstance2D` holding specks flowing
  towards a target point. Used three times: on the player (`Player/BloodStream`), and twice in the
  pool (`DepositStream`, `WithdrawStream`).
  The motion is deliberately *liquid*, not particulate: a speck is carried along the straight line
  to the target and drawn a small, hard-capped offset to one side of it (`wave_strength` /
  `max_deviation`, tightening to zero inside `focus_distance`), turned to face its travel and
  stretched along it. The heading is steered rather than recomputed, so a moving target is
  followed on a curve. `add_speck(speck, hold_time, glow_time)` optionally leaves it lying still —
  drawn with its own floor colour, indistinguishable from a stain — then glows it, then sets it
  off, with the glow peaking exactly at launch.

**Carried blood** — `Blood` autoload, class `BloodWallet` (`Scripts/Currency/blood_wallet.gd`).
Signals `changed` / `deposited` / `spent`; API `add`, `spend`, `can_afford`, `transfer_to`,
`reset`. Persistent because it is an autoload — it survives `reload_current_scene()`, which is
how blood carries between runs.

**Stored blood** — `BloodBank` autoload, `Scripts/Currency/blood_bank.gd`, which `extends
BloodWallet` and adds no behaviour. Declares no `class_name` (autoload name collision).

**Flow** — collection is fully automatic. There is no key, no mode and no cone.

1. Enemy dies → `BloodEmitter` listens to `Health.died` → `BloodSpray.launch()` throws
   `blood_value` pieces out along the killing hit (+ a one-shot particle burst). With
   `throw_death_blood` off, the emitter spills `make_splash_speck()`s to the magnet directly
   instead, so the amount collected is identical either way.
2. Each piece lands → offered to `BloodMagnet` (`Scripts/Player/blood_magnet.gd`, on the player,
   group `blood_magnet`, found via `BloodMagnet.get_active()`) through `absorb()`. It hands the
   piece to `BloodStream` with a rolled hold (`ground_delay` 0.2 s ± 0.07) and glow
   (`glow_time` 0.13 s ± 0.04). Anything it refuses stains the floor instead — blood is never lost.
3. The piece lies still looking like ordinary floor blood → glows red → flows to the player,
   following them as they walk (the magnet re-targets the stream every frame).
4. It reaches the player → `BloodStream.specks_arrived` → `BloodMagnet` adds to `Blood`.
   This is the *only* place a visual speck becomes currency.

A kill therefore leaves **nothing** on the ground: the enemy's `damage_blood_value` is `0`, so
wounding and killing it drop no permanent stains and every piece a death spills flows to the
player. The mechanism is kept (the player still uses it, at `6`, for their own trail) — turning an
enemy back into a bleeder is one number in the inspector.

All blood — floor stains, thrown spray, and the pieces flowing to the player — is stamped with one
shared asset, `Assets/Efects/Blood/BloodPiece.PNG` (a white irregular splatter, tinted per speck by
`BloodField`'s palette). It is set on `Arena/BloodField` and propagates through
`adopt_texture_from()`; `BloodStream` also exposes `piece_texture` / `piece_tint` / `piece_scale`
for dressing a single stream differently. A `MultiMesh` with no texture draws bare quads, which
reads on screen as plain squares — so something must always fill this in.
4. In the base, clicking `BloodPool`: left = deposit (`Blood.transfer_to(BloodBank, …)`),
   right = withdraw (the reverse). Accounting lands on the click; the flying specks are purely a
   consequence. Pool capacity 600; fill artwork is picked from the exported `fill_textures`
   array (5 entries), stage 0 reserved for exactly empty.

Neither total is ever cleared by a run transition. Nothing is written to disk — both totals reset
when the process exits.

---

## 4. Player and weapon systems

`Scenes/Player/Player.tscn`, root `CharacterBody2D` in group `player`.

- `player.gd` — speed 220, reads `move_*` actions, folds in the `get_speed_multiplier()` of
  `DeathSequence` and `TerrainSlow`.
- `Health` — max 3, `free_owner_on_death = false`, `invulnerable_seconds = 2.0`.
- `Camera2D` (`camera_controller.gd`) — the shared feedback camera, found via
  `CameraController.get_active()`.
- Visual stack: `Visual/Legs` (`LegAnimator`), `Visual/Body`, `Visual/Head` (with `Cigarette` and
  its `Smoke`), `AnimationPlayer` (`squash_idle.gd`), `FacingFlip`.
- `BloodMagnet` + `BloodStream` — automatic blood collection, see section 3.
- `CollectorHand` — **inert**. Blood is no longer collected by hand, so nothing drives, shows or
  rotates this node; it is kept whole (artwork, pose exports, blood-reaction glow, halo, cone
  drawing) as the basis of a future off-hand weapon. To put it back in play, something must
  position it, show it, and feed it `set_collecting()` / `set_cone()`.
- `CollectorAudio` drives `SuckLoop` (`LoopingSound`) off `BloodMagnet.get_flowing_count()`.
  `HandLoop` is left in the scene but nothing sets its level, so it stays silent.
- `Teleporter` + `SnapSounds` — see section 6.
- `DamageFeedback`, `BloodEmitter`, `Sounds`, `PlayerLight`.

**Shotgun** is `Scenes/Weapons/Shotgun.tscn`, a sibling of the player in `World.tscn` (not
parented to it) that trails `../Player`. Nodes: `Art/Body`, `Art/Pump`, `Muzzle`, `MuzzleLight`,
`Sounds`, `Feedback` (`shotgun_feedback.gd`), `ArtFlip` (`held_item_flip.gd`). 6 pellets, 12°
spread; pellets are added to `get_tree().current_scene`. Input: `fire` = LMB, `pump` = Space.

---

## 5. Enemy and wave systems

`Scenes/Enemy/Enemy.tscn`, root `CharacterBody2D` in group `enemies`. Speed 90, slash range 44,
slash interval 1.0, contact damage 1. Children: `Appearance` (`enemy1_appearance.gd`), `Health`,
`HitReaction`, `BloodEmitter`, `Defeat` (`enemy_defeat.gd`), `DeathFade`, `BodyHitbox`,
`HeadHitbox`, `SquashPlayer`, `LegAnimator`, `HeadAim/Head/DeadEyes`,
`KnifeAim/KnifeSlash` + `KnifeAim/KnifeHand/Knife`.

`WaveManager` (`World/WaveManager`) — `run_duration = 60`, `base_enemy_count = 2`,
`enemy_count_multiplier = 1.08`, `time_between_waves = 3.5`, `spawn_interval = 0.18`. A wave is
"done" once spawned, not once cleared. When the clock expires it only *stops spawning* and emits
`run_finished`; the run continues into the blood-collection phase.

`EnemySpawner` (`World/EnemySpawner`) — picks a screen edge that has genuine off-screen room,
clamps into `arena_bounds = Rect2(-800, -450, 1600, 900)`, spaces spawns apart, parents enemies
into `World/Enemies`, and hands each one the chase target before it enters the tree.

`RunEndDefeat` (`World/RunEndDefeat`) — on `run_finished`, staggers `EnemyDefeat.defeat()` across
every living enemy so they play out their ending rather than being deleted where they stand.

**Kills vs. removals.** `Health` has two ways to end a character, and they are mechanically the
same death — identical signals, identical order, identical values — so every listener (`DeathFade`,
`EnemyHeadPop`, `EnemyDefeat`, the smoke, the freeing) fires unchanged either way:

- `Health.kill()` — a kill. What a weapon does. `BloodEmitter` spills the full `blood_value`.
- `Health.remove()` — a removal. Marks the death, which `Health.was_removed()` reports and
  `BloodEmitter` reads to spill **nothing at all**: no stain, no thrown blood, no burst.

`EnemyDefeat` ends its sequence with `remove()` unless its `counts_as_kill` is on (it is off).
So the 60-second clock clearing the arena, and `ZoneEnemyGuard` clearing enemies out of the base,
are both worth nothing — the player did not beat those enemies. Only a weapon kill pays. Nothing is
told to keep quiet: systems that should not answer a removal check `was_removed()` themselves, so
adding another one later costs nothing in `Health`.

`MusicDirector` crossfades the `ArenaMusic` autoload → `BaseMusic`, and only a death does it:
`auto_switch_on_clear` is off, so a run ending leaves the arena track playing.

The arena soundtrack is the `ArenaMusic` autoload (`Scenes/Common/ArenaMusic.tscn`,
`Scripts/Common/music_player.gd`) rather than a node in the world, so rebuilding the world for the
next round does not take it down: one playback instance carries the whole session. Each run opens
at `run_start_pitch = 0.80` and climbs to `run_end_pitch = 1.25` exactly as the run clock reaches
zero; the clock reaching zero winds it back to 0.80 over `run_end_slowdown_time = 3.0` s and holds
it there through the collection phase, the portal and the upgrade menu. A new `WaveManager`
appearing is what tells the player a round has begun, and it re-opens the climb without touching
the playback position.

The whole speed curve is read off the run clock every frame inside `music_player.gd` rather than
driven by a `run_finished` listener or a tween, so there is no signal to miss and anything that
writes `pitch_scale` and stops is corrected on the next frame. `MusicDirector` owns only the death
slowdown, the pause duck, and the crossfades between the two tracks.

When the director does drive the speed it takes a **timed lease** on it
(`MusicPlayer.suspend_ramp()`) rather than switching the programme off. The lease counts itself
down, so a killed tween or a director freed with its world can no longer leave the programme
switched off and the music stranded at whatever speed it was last set to. A death is the one
open-ended hold (`HOLD_UNTIL_NEXT_RUN`), cleared by `begin_run()`.

Leaving the run with B hands the soundtrack over too: `Teleporter.drive_music` asks
`MusicDirector.switch_to_base()` as the journey starts, using the length of its own bus mute as the
crossfade time, so the player arrives in the base to the base track. The death sequence's teleport
is exempt — it runs its own longer handover at the revival.

---

## 6. Teleport / Base transition

Input action `teleport` = **B**, handled by `Player/Teleporter` (`Scripts/Player/teleporter.gd`),
with `destination_id = "base_pit"`.

Pressing B does one of two things, decided purely by where the player is standing:

- **Standing inside `RunPortal`** (the pit, radius 78) → plays the snap, then after
  `start_delay = 0.55` s calls `get_tree().reload_current_scene()`. Nothing is muted on this path.
  Both blood autoloads survive, so carried blood comes into the new run and banked blood stays
  banked. The pit's `Glow` sprite fades up while the player stands in it.
- **Anywhere else** → snap sound on the `Snap` bus (reverb/delay), `Game` bus muted (muted in
  place, never stopped, so playback positions survive), camera zooms in over `travel_time = 0.75`
  s, body is moved to the destination's `SpawnPoint` with `reset_physics_interpolation()`, camera
  limits are moved to the destination's bounds (grown to at least a screenful), then after
  `silence_hold_time = 1.1` s the audio fades back.

Destinations are `TeleportDestination` nodes in group `teleport_destination`, looked up by `id` —
so adding a place to go is a scene, not code. The mute is restored in `_exit_tree()` so a reload
mid-teleport cannot leave the next run silent.

**Note:** with `destination_id` fixed to `base_pit`, B only ever travels arena → base. Returning
to the arena happens only by starting a new run from the portal, which rebuilds the world.

---

## 7. Known bugs and unfinished work

- **No player-death handling.** `Player/Health` has `free_owner_on_death = false` and nothing
  connects its `died` signal. At 0 HP the player simply becomes un-damageable and play continues;
  there is no game-over, respawn or run-failure path.
- **Shops are markers only.** `ShopStation` exposes `player_entered` / `player_exited` /
  `is_player_present()` and nothing consumes them. No stock, prices, purchases, or any reference
  to `BloodBank` — the upgrade system does not exist yet.
- **No persistence to disk.** `Blood` and `BloodBank` survive scene reloads but not process exit.
  No save/load system.
- **`Scenes/World/Sanctum.tscn` is orphaned.** It is a complete `TeleportDestination` with
  `id = "sanctum"` but is not instanced anywhere; the base's `TeleportPit` superseded it.
- **Debug prints in the shotgun.** `Scripts/Weapons/shotgun.gd:190` prints `"Fire"` and
  `:244` prints the state name on every state change.
- **Static appearance pickers.** `Enemy1Appearance`'s `VariantPicker`s are `static`, so their
  usage counts persist for the whole process across runs. Intentional, but worth knowing.
- **One hand-placed enemy** sits in `World/Enemies/Enemy` at `(420, -220)` in addition to
  everything the spawner produces.
- **No enemy variety.** A single enemy scene and a single weapon; no difficulty scaling beyond
  wave count.
- **Empty run-end state.** After the 60 s clock expires and `RunEndDefeat` clears the arena,
  nothing signals the player that the collection phase has begun.

---

## 8. Important scene and node names

| Scene | Notable nodes |
| --- | --- |
| `Scenes/World/World.tscn` | `Darkness`, `Arena/Bounds`, `Arena/Floor`, `Arena/TileGround`, `Arena/TileGroundDecor`, `Arena/BloodField`, `Arena/TileWalls`, `Arena/TileProps`, `Arena/Torches/*`, `Base`, `Player`, `Shotgun`, `Enemies`, `BaseMusic`, `MusicDirector`, `EnemySpawner`, `WaveManager`, `RunEndDefeat`, `RunHUD` |
| `Scenes/Base/Base.tscn` | `Ground/Bounds`, `HubLight`, `BloodPool`, `TeleportPit`, `Saloon`, `Shops/Shop*`, `Parallax/PipeLayer` |
| `Scenes/Base/BloodPool.tscn` | `Art/Basin`, `Art/Fill`, `ClickArea`, `DepositStream`, `WithdrawStream`, `Counter` |
| `Scenes/Base/TeleportPit.tscn` | `Art/Pit`, `Art/Glow`, `SpawnPoint`, `Portal`, `Torches/*`, `TorchProximity` |
| `Scenes/Player/Player.tscn` | `Visual/{Legs,Body,Head}`, `Camera2D`, `CollectorHand` (inert), `BloodStream`, `Health`, `Teleporter/SnapSounds`, `BloodMagnet`, `CollectorAudio` |
| `Scenes/Enemy/Enemy.tscn` | `Appearance`, `Health`, `Defeat`, `DeathFade`, `BodyHitbox`, `HeadHitbox`, `HeadAim/Head/DeadEyes`, `KnifeAim/KnifeSlash` |
| `Scenes/Weapons/Shotgun.tscn` | `Art/Body`, `Art/Pump`, `Muzzle`, `MuzzleLight`, `Feedback` |
| `Scenes/UI/RunHUD.tscn` | `TimerLabel`, `BloodCounter`, `ScreenFlash`, `EndScreen/Menu/Buttons/{NextRunButton,ExitButton}` |
| Others | `Scenes/Base/{Saloon,Shop,Tent}.tscn`, `Scenes/World/Props/Torch.tscn`, `Scenes/Effects/{BloodSplash,Casing,DeathSmoke,MuzzleFlash}.tscn`, `Scenes/Projectile/Projectile.tscn`, `Scenes/World/Sanctum.tscn` (unused) |

**Groups in use:** `player`, `enemies`, `blood_field`, `blood_spray`, `blood_magnet`,
`blood_pool`, `run_portal`, `teleport_destination`, `shop_station`, `screen_flash` (via
`ScreenFlash.get_active`).

**Input actions:** `move_up/down/left/right` (WASD), `fire` (LMB), `pump` (Space),
`pause_menu` (Esc), `teleport` (B). `collect_toggle` (Ctrl) and `collect_exit` (1) are still
*defined* in `project.godot` but nothing listens to them — blood collection is automatic, and
`project.godot` is not hand-edited.

**Physics layers:** 1 `world`, 2 `enemy`, 3 `projectile`, 4 `enemy_body`, 5 `interactable`.

**Text:** every piece of text in the game inherits one project-wide theme —
`Resources/game_theme.tres`, wired up as `gui/theme/custom` in `project.godot`. Its `default_font`
is `Fonts/WesternBangBang-Regular.ttf`, and that single line is the whole of the game's typeface.
No scene or script sets `theme_override_fonts/font` or calls `add_theme_font_override()`, and
nothing keeps a theme of its own, so changing the font anywhere else is always wrong — change it
there and every existing and future label, button and counter follows. Sizes, colours and outlines
are deliberately *not* in the theme: they stay as per-node `theme_override_font_sizes` /
`theme_override_colors` / `theme_override_constants`, which is why swapping the typeface leaves all
of them untouched. `Fonts/Cowboy Movie.ttf` (the previous face) and `Fonts/Arvo-Regular.ttf` are
still in the project but unused.

**Audio buses:** `Game` (everything mutable by the teleport), `Snap` (reverb/delay for the snap).

---

## 9. Scripts and where they live

```
Scripts/
  Common/     camera_controller, death_fade, facing_flip, health, held_item_flip, hitbox,
              hit_reaction, knife_slash, leg_animator, look_at_target, looping_sound,
              music_director, music_player, soft_follow, sound_bank, squash_idle, variant_picker
  Currency/   blood_wallet (Blood autoload), blood_bank (BloodBank autoload)
  Effects/    casing, one_shot_particles
  Enemy/      enemy, enemy1_appearance, enemy_defeat, enemy_spawner, run_end_defeat, wave_manager
  Player/     blood_magnet, blood_stream, cigarette, collector_audio, collector_hand, player,
              player_damage_feedback, teleporter
  Projectile/ projectile, projectile_profile
  UI/         blood_counter, run_end_screen, run_timer, screen_flash
  Weapons/    shotgun, shotgun_feedback
  World/      blood_emitter, blood_field, blood_pool, cutaway_building, parallax_drift,
              run_portal, shop_station, teleport_destination, tiled_surface, torch,
              torch_proximity
```

`TiledSurface` (`Scripts/World/tiled_surface.gd`) is the arena's floor and walls: a `@tool`
`Polygon2D` that tiles a texture across an exported `surface_size`, with `tile_size` (world pixels
per tile), `tile_stretch` (along/across the grain) and `texture_angle` as inspector dials, and the
node's own `color` for tinting. `Arena/Floor` runs `Assets/floor_grid.jpg` at `tile_size = 200`;
the four `Arena/Walls/*` run `Assets/Wall.jpg` at 192 with `tile_stretch = (3.5, 1)` for long
boards, `texture_angle = 90` on the left and right so the grain runs along them, and
`color = (0.45, 0.4, 0.38)` to keep them darker than the floor. Both JPGs are imported with
mipmaps and a 1024 size limit. `Scenes/World/Sanctum.tscn` still uses the older
`floor_grid.svg` / `wall.svg`.

Other content: `Assets/{Base,Enemies,Environments,Guns,Main Character}/`, `Sound/` (WAV/MP3),
`Resources/` (`character_idle.tres`, `enemy1_idle.tres`, `shotgun_pellet_profile.tres`,
`Tilesets/building_tileset.tres`), `Shaders/`, `addons/godot_mcp/` (editor tooling, not gameplay).

All wiring is done in code via `@export` NodePaths and group lookups — there is not a single
`[connection]` entry in any scene file.

---

## 10. Next recommended milestone

**Make the shop stations spend `BloodBank`: one working upgrade purchase at the Gunsmith.**

Everything the milestone needs already exists and is unused — `ShopStation.player_entered` /
`is_player_present()`, `BloodWallet.can_afford()` / `spend()`, and `ShopStation.get_by_id()` for a
UI to find every station without being wired to any of them. It is the single largest gap: blood
can currently be earned, carried, banked and withdrawn, but never spent on anything.

Scope for the milestone:

1. An `Upgrade` resource (`Resources/Upgrades/`) holding id, display name, cost, icon and one
   tunable effect value, so a new upgrade is a `.tres` file dropped into an exported array.
2. An exported array of those resources on each `ShopStation`, driving stock per station from the
   Inspector rather than from code.
3. A prompt + purchase UI raised on `player_entered` and dismissed on `player_exited`, paying
   through `BloodBank.spend()` so the pool visibly drains and its fill artwork steps back down.
4. A persistent `UpgradeState` autoload alongside `Blood` / `BloodBank` recording what has been
   bought, plus one applied effect (e.g. shotgun `pellet_count` or player `speed`) read on run start.
5. Placeholder PNG art for the shop counter/prompt, consistent with the existing base placeholders.

This closes the run→collect→bank→spend loop, and it is a prerequisite for anything that would make
`Blood` and `BloodBank` worth saving to disk.
