# MILESTONE 2 — AUTHORITATIVE STATE

**Read this document before modifying anything.**

This is a record of the *real* project state, verified against the files on disk, not a
record of what was planned. Nothing below is marked implemented because it was designed —
only because the files prove it. Where a system is half-built it says so and says which
half.

Last verified: 2026-08-25.

---

## 1. WHAT IS ACTUALLY LEFT

**Milestone 2 is not closed.** The dedicated boss swoosh asset is now in and wired, and
most of the live verification has been done (§12). What is left is the remainder of that
verification list — nothing here is unbuilt:

1. **The Camp Streak stash (§6.1)** — implemented, never watched in play
2. **The rest of the §12 list** — the parts marked *still owed* there

The dedicated boss swoosh asset (§10) is **done**: `Sound/Efect/Boss/BossBladeSwoosh.WAV`
exists, is wired into `EnemyAttackAudio.boss_swoosh_sounds` on `Scenes/Enemy/Enemy.tscn`,
and was heard playing on the Boss Charge swing in the running game.

The six death / run-failure cleanup bugs (§11) are **fixed**, each reproduced in the
running game before the fix and watched again after it.

**Startup is clean.** The `Unrecognized UID: uid://d2gydhh7i03dm` and `Can't save resource
to empty path` errors are gone and stayed gone: `audio/buses/default_bus_layout` is a
`res://` path again rather than a UID, so `AudioServer` loads the layout on boot (3 buses —
Master, Game, Snap) instead of silently falling back to one. A headless boot of the project
prints no errors and no warnings.

Everything else in this document is implemented and present on disk.

---

## 2. THE PLAYABLE AREA — authoritative

The playable area is measured from the wall inner faces and is **authoritative**:

```
Rect2(-1449.6, -815.4, 2899.2, 1630.8)
```

Verified present on **both** `CameraBounds.region` and `EnemySpawner.arena_bounds` in
`Scenes/World/World.tscn`.

- **Do NOT resize this back to 1920×1080.**
- The Arena/Bounds walls in `World.tscn` remain the source of truth; every other system is
  derived from them rather than the reverse.
- Mini Boss placement and support placement use this same rectangle, and the boss's own
  fight has since moved onto a map of its own — see §7.

---

## 3. MILESTONE 2 — IMPLEMENTED

- Bounty system and locked rewards
- Knowledge system
- Camp / Wagon integration
- Travel system
- Ambush system
- Mini Boss system, including its persistent random visual identity from the MiniBoss1
  assets and its wanted-poster face (§7)
- Mini Boss debug controls, inside the existing P debug panel
- Playable area reduced; current Arena/Bounds authoritative (see §2)
- Mini Boss support count is 5
- Trouble no longer uses the 75% flee rule (`rout_fraction = 0.0` — every man must be killed)
- A Trouble Danger opens with 4 enemies in view and keeps spawning up to its configured total
- Danger scaling by Danger number and by region exists
- Shift fast travel input exists, and `TravelDirector` runs while the Travel screen is active
- Sleep, in full (§5)
- The Knife / Bone throwable weapon system and its audio (§3.3)
- The cursor / crosshair system (§3.4)
- The revolver spin system (§3.5)
- The developer Test Map, its entry gate at the bottom of the Desert and its Spawn Station
  (§12.3)

### 3.1 — Music state system and combat audio (implemented, live-tested)

- Base / Travel / Camp / Sleep / Trouble each keep their own remembered playback position
- Transitions use the agreed slow-and-fade with overlap; a state never restarts on return
- Death has no separate death music
- The Run Start screen and "Maceraya çıkılıyor" are implemented
- Enemy1 attack audio and swoosh timing are implemented, synchronised to the blade strike
- Mini Boss attack audio is implemented
- The BossDefeat sound plays exactly when the boss name is struck through

### 3.2 — Difficulty: the round curve is retired

`Scripts/Enemy/round_scaling.gd` still exists and is still what spawns read, but
`health_growth` and `damage_growth` are both authored at **1.0**: the round number no longer
makes an enemy tougher or harder hitting. Strength now comes from the part of the desert the
enemy is standing in (`DangerDirector.region_health_multiplier`, 1.8) and from the player's
own level.

The machinery was deliberately kept rather than deleted — the two growths are the one place a
round curve would be switched back on, and `spawn_growth` (1.06) plus the
`extra_*_multiplier` seam the travel road lays its own difficulty on with are both still in
use.

**Trouble enemy count growth is 1.18** — `DangerDirector.count_growth`, compounded per
Danger.

### 3.3 — Knife / Bone throwables

`Scripts/Weapons/throwable_weapon.gd` (`ThrowableWeapon`) extends `CarriedWeapon`, so
carrying, aiming, swaying and holstering are the shared behaviour every other weapon already
has and only the throw is new. One throw and the weapon is spent: the fire key sends it and
the same press hands the player's own weapon back through
`WeaponMount.drop_temporary`.

**Files:** `throwable_weapon.gd`, `thrown_weapon.gd`, `throwable_audio.gd`,
`Scenes/Weapons/{Knife,Bone}.tscn`, `Scenes/World/Pickups/{KnifePickup,BonePickup}.tscn`,
`Scenes/Projectile/{ThrownKnife,ThrownBone}.tscn`,
`Resources/Projectiles/{knife,bone}_throw_profile.tres`,
`Resources/Break/{knife_throw,knife_drop,bone_throw}_break.tres`.
Audio: `Sound/Efect/Guns/Throwable/{Knife,Bone}/*.WAV` — a throw and a hit for each.

### 3.4 — Cursor / crosshair

`Scripts/UI/{game_cursor,crosshair,crosshair_ammo,crosshair_style}.gd`, with a
`CrosshairStyle` resource per weapon in `Resources/Crosshairs/` — revolver, shotgun and lever
action. Both `Crosshair` (carrying its own `Ammo` label) and `GameCursor` are present on
`RunHUD.tscn`.

### 3.5 — Revolver spin

`Scripts/Weapons/revolver_spin.gd` with `spin_stage.gd` and three authored stages,
`Resources/SpinStages/spin_stage_{2x,3x,4x}.tres`. Present on `Revolver.tscn` as the `Spin`
node with its own `SpinLoop` audio player; the multiplier is shown on `RunHUD.tscn` as
`SpinMultiplier`.

---

## 4. TROUBLE — IMPLEMENTED

### The search itself

- Search for Trouble flow
- Trouble intro / walking transition
- Trouble arena
- Normal player-follow camera
- Danger progression and Danger scaling
- CONTINUE / STOP
- Trouble advances the DayClock by **one day segment**, not a full day
- No horse is visible during the encounter
- Trouble uses its own music state

### 4.1 — DangerFinale (implemented and wired)

`Scripts/World/danger_finale.gd` is written, internally consistent and validates clean. It
hangs off signals only — `EnemySpawner.spawned` → each enemy's `Health.died` →
`EnemyHeadPop.piece_separated` — so no enemy, ambush or death code is modified. It claims the
ending only when the ambush reports nobody standing and nobody owed, and only while
`DangerDirector` is mid-fight, which is what keeps the effect out of arena rounds, road
ambushes and the mini boss.

Wiring, verified in the files:

- `danger_director.gd:135` — `@export var finale_path: NodePath = ^"../DangerFinale"`
- `danger_director.gd:996` — `_resolve_finale()`, falling back to `DangerFinale.get_active()`
  by group when the path does not resolve
- `danger_director.gd:590-605` — the end of `_on_danger_cleared` is split: `next` is chosen
  first, then `presentation_finished` is awaited with `CONNECT_ONE_SHOT` in place of the
  normal `end_delay` timer whenever `DangerFinale.is_playing_out()` is true
- The Danger 10 auto-end is preserved: `next` is set to `_end_sequence` **before** the finale
  branch, so both paths hand over through the same seam and the reward behaviour is unchanged
- `danger_director.gd:462` — `hand_back_speed()` is called on walk-on, so the world cannot be
  left slowed
- `World.tscn:273` — the `DangerFinale` node is present, immediately after `DangerDirector`
- Its references resolve on the script's export defaults, with no scene overrides needed

**Play-verified 2026-08-25** — the head, the slow-motion, the freeze, CONTINUE / STOP and a
clean hand-back. Three details are still owed; see §12.

### 4.2 — Reward, chest and horse return (implemented and live-verified)

All files are present on disk and wired into `World.tscn` (`TroubleReward` node, carrying
the chest scene and all three tiers).

- STOP ends the sequence cleanly and leaves the player where they stand, horse still away
- The reward chest falls from above, shakes the camera on impact through the existing shake
  system, and bounces
- Reward tiers by highest Danger cleared: 1–3 → 500–1500 Blood; 4–7 → 1 item + 500–1500;
  8–10 → 3 items + 2000–3000. Blood goes to **carried** Blood, not the bank
- Danger 10 auto-ends with no CONTINUE / STOP and drops its chest
- Chest collection uses the existing interaction convention and cannot be collected twice
- After collection: the notice "Buralarda belasını bulacak senden başka kimse kalmadı",
  then RETURN TO CAMP
- A roughly 3-second walking return transition, on foot, with no horse shown
- `E — CALL HORSE`, with a random 3–6 second delay, entering from a random side, parking
  beside the player and becoming the new Camp/Wagon location
- Full Trouble state cleanup on arrival

**Files:** `Scripts/World/trouble_reward_director.gd`, `Scripts/World/reward_chest.gd`,
`Scripts/World/trouble_reward_tier.gd`, `Scenes/World/RewardChest.tscn`,
`Resources/Trouble/reward_tier_{1,2,3}.tres`,
`Assets/World/Trouble/reward_chest{,_open}.png`.

#### Two judgment calls recorded here on purpose

1. **Chest item rewards currently use `AmmoCrate.tscn`** as `RewardChest.item_scene`, because
   there is no final item placeholder and no item/inventory system in the project yet. When a
   real item system exists this is one Inspector field to repoint — nothing in the chest knows
   what an item is.
2. **The Wagon/Camp visual is hidden while the horse is away**, via `Camp.hides_while_away`.
   This is what makes the arrival in `E — CALL HORSE` mean anything, and it changes what
   Trouble looks like before the reward: the wagon is not left standing where it was.

### 4.3 — Ammunition during a search (implemented and wired)

Ammunition reaches a search through the crate supply the boss arena already had, not through
a second system. Both files exist, compile and are present in `World.tscn`.

**`Scripts/World/ammo_crate_spawner.gd`** (`AmmoCrateSpawner`) — the one way a crate reaches
the ground. It hangs off `BossArena.locked` / `unlocked`, drops one crate every 10 seconds
(`first_delay` 10, `interval` 10) while no more than `max_uncollected` (3) are standing, and
places them in an edge band (`edge_band` 0.62–0.94) away from the player and from each other.
`spawn_crate_in(area, into)` is the public seam that lets anything else ask for a crate inside
its own rectangle and get the same placing, ceiling and wiring. Present as
`World.tscn:296` — node `AmmoCrates`, group `ammo_crate_spawner`, `crate_scene` set to
`Scenes/World/AmmoCrate.tscn`.

**`Scripts/World/trouble_ammo_drop.gd`** (`TroubleAmmoDrop`) — decides *when* a search is owed
a crate and asks `AmmoCrateSpawner` for it inside `EnemySpawner.arena_bounds`. Two independent
triggers: a promised crate `drop_delay` (3 s) after a Danger opens, `once_per_search` by
default; and an emergency crate when the equipped weapon's reserve falls below
`emergency_threshold` (0.1 of maximum), then deaf for `emergency_cooldown` (25 s). Both pass
through one `one_at_a_time` gate. Crates are drawn at `crate_scale` 0.62 and are worth
`refill_fraction` 0.2 of the weapon's **maximum** capacity, so they keep reading correctly when
a capacity upgrade raises that ceiling. It listens to `DangerDirector.sequence_started` /
`danger_started` / `sequence_ended` only — nothing in the search was modified. Present as
`World.tscn:333`, on export defaults.

**Note:** `AmmoCrate.tscn` is also still `RewardChest.item_scene` (see judgment call 1 above),
so the same crate scene serves three callers.

**Play-verified 2026-08-25** — the promised crate drops when a Danger opens. The emergency
crate is still owed; see §12.2.

---

## 5. SLEEP — IMPLEMENTED

Sleep is built, wired and complete. `Scripts/World/sleep_director.gd` (`SleepDirector`) is
present as `World.tscn:336`; `Scripts/UI/sleep_menu.gd` is present as the `SleepMenu` node on
`RunHUD.tscn`, in group `sleep_menu`; `Scripts/Player/player_sleep.gd` is present on
`Player.tscn` as `PlayerSleep`, registered in the player's own
`speed_modifier_paths` alongside `DeathSequence` and `TerrainSlow`.

**Nothing is rebuilt and nowhere is gone to.** The player stays in the region they are already
in, on the ground the map already drew, beside the wagon already standing there. What changes
is what the player is looking at: a full-screen presentation — the third after the journey and
the walk out to a Danger — showing the man lying down, the letters coming off him, and the
region's own ground behind them.

- **Lying down** is `PlayerSleep`, through the player's own speed seam
- **How long** is chosen on `SleepMenu`, up to `max_segments` (**4**). WAKE UP is on that
  screen from the first frame
- **Each segment** is `segment_time` (**5 s**) of real time — taken outside the time scale and
  outside the tree's pause — and then exactly one stage on the run's clock through
  `RunSessionState.advance_days`, the same call the road and a cleared Danger spend their hours
  with. A segment is not a day and not a round; the round counter is deliberately untouched
- **Ambush** is one roll per segment against the road's own `TravelEvent` table (`sleep_events`
  empty by default, so there is one set of odds for the country). Anything that is not a quiet
  day is an ambush fought by the existing `AmbushWaveDirector` — the same fight, the same
  enemies, the same ending. The word goes up on the sleep screen for `ambush_hold` (1.1 s)
  first, then the screen comes down on the camp the player fell asleep at. **Sleep does not
  resume afterwards**
- **Bounty interruption** asks `MiniBossDirector.can_begin()` between segments — the game's one
  answer to "is he here" — and puts the question on the borrowed `TravelEventMenu`:
  "O ŞEREFSİZ ŞİMDİ BURADA.", with UYUMAYA DEVAM ET / ÇIK, O ŞEREFSİZE GÜNÜNÜ GÖSTER. Staying
  resumes the night from where it stopped, keeping the segments already slept; leaving ends the
  night and hands over to `MiniBossDirector.begin()`. `asks_once_per_contract` stops the same
  man stopping the same night twice
- **At the limit** the character says "Uykumu kaçırdı şerefsizler." on the shared
  `KnowledgeNotice` panel, under a SLEEP heading
- **Every way out is the same way out.** Waking early, sleeping the night through, the
  four-segment limit, an ambush, a bounty and a death all end at `_end_sleep()`: the player gets
  up, timers are made unreachable by token, the screen comes down, the death watch is dropped
  and the time scale is written back. `_exit_tree()` repeats the teardown, so a world torn down
  mid-night cannot hand the next one a player who cannot move
- The camp panel is put back up only after the three endings the player is standing still for —
  never over a fight or a hunt
- `Camp` refuses to be used at all while `SleepDirector.is_sleeping()` is true

The Sleep music state exists and preserves its playback position across entering and leaving,
like every other music state.

**Play-verified 2026-08-25** — the screen, the ambush at the camp and the bounty question.
The rest of the night is still owed; see §12.2.

---

## 6. BLOOD / STREAK

- Blood gained during gameplay goes into carried Blood
- The Camp deposit is a third total, `CampBlood`, kept apart from carried Blood and the
  base's `BloodBank`
- The boss bounty reward is given on boss defeat
- Killing the boss corpse gives 50 Blood
- Base cash-out is carried Blood × Streak, counted out on `CashOutScreen`
- Streak resets after a successful Base cash-out, and is lost with the player on death

### 6.1 The Camp Streak deposit — implemented

Stashing at a camp now pays the Streak, the same way the ride home does.
`CampMenu.deposit_blood()` follows `CashOutScreen._bank_the_run()` exactly: what the player
carried is **transferred** through `BloodWallet.transfer_to`, and only the Streak's own
share is minted with `CampBlood.add(bonus)` from `StreakCounter.get_bonus()`, so a stash at
a Streak of 1 is still a plain transfer with nothing invented.

- `get_streak_multiplier()` — 1 when the camp does not pay a streak, so every figure below
  is the same arithmetic either way
- `get_deposit_amount()` — what leaves the player's hands. The camp's room is measured
  against **what the camp ends up holding**, so the room is divided by the multiplier: a
  camp with 300 of room takes 100 out of the hands of a player on a Streak of 3
- `get_deposit_payout()` — what the camp receives, asked of `StreakCounter.apply_to()`, so
  the figure on the button and the figure that lands in the pile are one calculation
- `_stashed_here` counts what the camp holds, Streak share included, so the per-camp
  ceiling is not multiplied around

Inspector fields, all on `CampMenu`:

| Field | Default | What it does |
|---|---|---|
| `streak_path` | `/root/Streak` | The counter the stash is paid at |
| `pays_streak` | `true` | Off is a plain transfer — the old behaviour |
| `stash_clears_streak` | `false` | On makes a stash a payout in its own right and ends the Streak |
| `deposit_streak_format` | `STASH %d BLOOD  -  x%d  =  %d  -  ROOM %d` | Used only while the multiple is above 1 |

**A stash does not spend the Streak.** The camp pays the multiple and leaves the Streak
standing, so putting blood somewhere safe on the way through cannot silently cost the
player the multiple the rest of the run is riding on. What stops it being free money is
`camp_blood_capacity` — a camp takes 300 and no more, however good the Streak is.
`stash_clears_streak` flips this without a code change.

The menu follows `Streak.changed` the same way it follows the wallet, so the button redraws
when the count moves. Doc comments on `StreakCounter`, `CashOutScreen` and `CampBlood` were
corrected — they previously said the base was the *only* place a Streak was ever worth
anything.

**Not yet play-verified** — see §12.2. This is the last system in Milestone 2 that has
never been run.

---

## 7. MINI BOSS

- The Mini Boss is the bounty target
- 2 hearts of damage, flat, whatever rung he is on
- The bounty completes immediately on defeat and disappears from TAB
- The reward is added immediately to carried Blood
- The corpse remains, may be used for Knowledge from **other** active bounties, and may later
  be killed for 50 Blood
- Boss XP / progression behaviour belongs to Milestone 3

### 7.1 — Health comes from the reward, not from Knowledge

**The price on the poster is the difficulty.** `MiniBossDirector.boss_health_curve` maps blood
to a multiple of an ordinary enemy's authored pool, read in order and interpolated between:

```
 500 → 50x     750 → 60x    1000 → 75x    1250 → 90x
1500 → 105x   1750 → 125x   2000 → 150x
```

Rewards below the first point and above the last are held to that point's multiplier rather
than extrapolated, so the two ends of the curve are the two ends of the range.

- **Player-level seam:** `boss_health_per_level` = 0.05 — five percent a level, read off the
  `RunProgress` autoload. Level 1 is the curve exactly. Mild on purpose: the reward is what
  decides the fight, and this only keeps a cheap contract from becoming trivial to a grown
  player. Set to 0 the curve is the whole of it
- **Ceiling:** `boss_health_cap` = 150.0, so no combination of contract and level carries a
  boss past the top of the curve

**Knowledge now sets size only.** The `MiniBossTier` resources
(`Resources/Enemy/mini_boss_tier_{0,1,2,3}.tres`) carry `scale_multiplier` and optional speed
and support-count overrides, and no health multiplier at all: Knowledge 3 → 1.5×,
Knowledge 2 → 1.8×, Knowledge 1 → 2.0×, Knowledge 0 → 2.5×. The old "Knowledge 3 → 50× HP"
ladder is retired and replaced by the curve above.

### 7.2 — Reward range and region weighting

`BountySettings` — `reward_minimum` **500**, `reward_maximum` **2000**, `reward_step` 100.

Rewards lean on the difficulty of the region the poster names:
`region_reward_influence` = 0.45 and `reward_bias_strength` = 2.6, read against
`MapRegion.difficulty` (A 0.0, B 0.25, C 0.5, D 0.75, E 1.0). **The country decides what is
likely, never what is possible** — region A can still print a 2000-blood poster and region E a
500-blood one, which is what keeps the region line worth buying.

### 7.3 — The wanted poster is the man himself

`wanted_poster.gd:210` `_print_the_outlaw()` prints the face out of the very parts the boss
will be wearing: both halves of the answer — `MiniBossDirector.wardrobe` and
`MiniBossDirector.look_key_for(bounty)` — are read off the director that will build the body,
drawn through `MiniBossPortrait` into the poster's `Mugshot` node. The draw is a pure function
of that key (`MiniBossWardrobe.indices_for`), so the same contract prints the same man every
time without a result being stored. A world with no director, or a director with no wardrobe,
falls back to `BountyTarget.portrait` exactly as the board did before.

**Files:** `Scripts/UI/mini_boss_portrait.gd`, `Scripts/Enemy/mini_boss_appearance.gd`,
`Scripts/Enemy/mini_boss_wardrobe.gd`, `Resources/Enemy/mini_boss1_wardrobe.tres`,
`Scenes/UI/WantedPoster.tscn`.

### 7.4 — The encounter map

`Scripts/World/boss_encounter_map.gd` (`BossEncounterMap`), present as `World.tscn:279`
instancing `Scenes/World/BossEncounterMap.tscn`.

**It is a place, not a mode.** The whole encounter is carried into it the moment the player
reaches the outlaw — the player, the boss and every man standing with him, the group keeping
its shape — and carried back out on `BossDefeat.arena_released`. It is a
`TeleportDestination`, the same thing the base already is: a scene sitting a few thousand
pixels off in the same world, stating its own arrival point and its own playable rectangle. No
second viewport, no scene change and no second world file, which is why the run, the ledger,
the wallet, the HUD and the way home all survive the trip without knowing it happened. The
camera's limits and `EnemySpawner.arena_bounds` are taken over by this map's own rectangle for
the duration and handed back on the way out.

### 7.5 — Reaching him, and the framing

- **`trigger_radius` is 750** — two and a half times what it was. A mark on a man standing in
  open desert was being walked straight past. It is the reach of the encounter and nothing
  else: it does not touch the boss, his swing, his size or the fight's own ground
- **The fight zoom-out is removed.** `BossArena.fight_zoom` = **1.0** — the ordinary gameplay
  framing, with the normal player-follow camera. The boss intro's own pull in on the boss
  (`intro_zoom` 2.0) is untouched
- `boss_distance_fraction` is 0.35–0.62 of the playable area's **shorter side** rather than a
  flat pixel distance, so the roll means the same thing on a wide map as on a square one and
  every roll no longer ends in whichever corner the bearing pointed at
- Standing room is `body_radius` (90) × his rung's size + `wall_clearance` (60), so a 2.5×
  boss is held further off the wall than a 1.5× one with no second number authored

**Play-verified 2026-08-25** — the poster face, the reward-driven health, the 750 approach
trigger, the carry into the encounter map with the camera limits and `arena_bounds` handed
over, and the carry back out again. The health curve was read at one point only (1000 →
75×); the rest of its range is still owed, see §12.2.

---

## 8. TRAVEL

- The existing `TravelDirector` / `TravelMenu` is the travel system
- The Travel Map is retired
- The Travel day screen has Continue Travel
- An Ambush returns to the Travel screen after combat
- Shift fast travel uses 1.5× speed with automatic Continue
- Travel music preserves its position

**Play-verified 2026-08-25** — a full journey: `TravelMenu` → RIDE OUT → `TravelLoading` →
the day stop → arrival in the destination region, with the HUD back to gameplay,
`is_travelling()` false and `Engine.time_scale` at 1.0. Fast travel was not exercised.

### 8.1 — Arrival clamp and framing (implemented)

`Scripts/World/region_arrival.gd` (`RegionArrival`, `World.tscn:276`) reads the map's own
extent through `CameraBounds.get_world_region()` — the same rectangle the camera is limited to
— and clamps the arrival inside it by `arrival_inset`, so an arrival can never be made outside
the world or standing in the walls. A world with no `CameraBounds` clamps nothing and arrives
exactly where the region said, which is how this behaved before the clamp existed.

An arrival is not a round: `WaveManager` is never started for one. Whether it is a fight is
the map's business (`MapDefinition.arrival_combat_chance`), and how many are waiting is
`MapDefinition.get_arrival_enemy_count`.

### 8.2 — The day transition dial (implemented and wired)

**`Scripts/UI/day_transition_dial.gd`** (`DayTransitionDial`) — the hour turning over, drawn as
a disk as wide as the screen and hinged on the bottom edge, with the hour being left on the
face that is up and the hour being walked into buried below. It is raised over a transition,
told how long that transition lasts, and emits `turned` on the beat the halves swap.

- It decides nothing about the clock. Both faces are **read** from `DayCycleDirector`
  (`get_stage_at_offset(0)` and `(1)`), the same source as the HUD corner and the round intro,
  and the hour is spent by the caller on `turned` — so what the player watches and what the
  game believes are one event.
- `DangerDirector` drives it: `day_dial_path` at `danger_director.gd:227`
  (`^"../RunHUD/DayTransitionDial"`), `_resolve_day_dial()` at `:1003`, `_turn_the_day()` at
  `:940` connecting `turned` → `_spend_the_day()` with `CONNECT_ONE_SHOT`, called from `:497`.
- With `enabled` off, or with no dial in the world, `turned` fires immediately and the hour
  moves exactly as it did before the dial existed.
- Timing: `anticipation_time` 0.5 s / `anticipation_degrees` 10° the wrong way, then
  `turn_time` 0.6 s / `turn_degrees` 180° to the left, landing the swap at `turn_at` 0.5 of the
  transition — the frame the walker crosses the middle of the screen.
- Present on `RunHUD.tscn`, full-rect, `process_mode = 3` (always) so it runs over the
  frozen world, `z_index` 260, with `NowFace` and `NextFace` each carrying an `Icon` and a
  `Name`. Colours are the game's red-on-dark.

**Play-verified 2026-08-25** — hidden at rest, turns through 180° on `play()`, hidden again
on `stop()`.

---

## 9. REGIONAL PROPS — IMPLEMENTED

Regions are dressed by their own scatter resources rather than by anything in the shared world
scene, so a region's identity is one Inspector entry.

- **The Dead** — `Scenes/World/Props/Desert/Regions/TheDeadStake.tscn`, scattered by
  `Resources/Maps/Desert/Regions/scatter_the_dead_stakes.tres`, referenced from `region_e.tres`
- **Dust Camp** — `Scenes/World/Props/Desert/Regions/DustCampTent.tscn`, scattered by
  `Resources/Maps/Desert/Regions/scatter_dust_camp_tents.tres`, referenced from `region_a.tres`

---

## 10. MUSIC / AUDIO

- Music assets live in `Sound/Music`; effects in `Sound/Efect`
- The music state system is implemented
- BossDefeat audio plays on the boss-name strike-through
  (`Sound/Efect/Boss/BossDefeatSound.wav`)
- The boss attack sound exists (`Sound/Efect/Boss/Atack (1).mp3`), as do his footsteps
- Enemy1 swoosh is synchronised to the blade-strike timing
  (`Sound/Efect/Atack/Enemy1/BladeSwoosh.WAV`)
- Knife and Bone each have a throw and a hit sound
- Death has no separate music

**The dedicated boss swoosh asset is in — verified in play.**
`Sound/Efect/Boss/BossBladeSwoosh.WAV` sits in `EnemyAttackAudio.boss_swoosh_sounds` on
`Scenes/Enemy/Enemy.tscn` at `boss_swoosh_volume_db` −3, beside the boss attack shout in
`boss_attack_sounds`. Nothing was added to carry it: the array was already there and
already fell back to Enemy1's `BladeSwoosh.WAV` while it was empty, exactly as
`enemy_attack_audio.gd` was written to.

It reaches the Boss Charge for free, because the charge has no swing of its own —
`BossCharge._begin_swing()` runs the boss's own `KnifeSlash` faster for one arc, and that
blade's `strike_started` is what `EnemyAttackAudio._on_strike()` listens to. `_is_boss()`
sees the `MiniBoss` component on the body and picks the boss array. Watched in the running
game: a charge thrown with `BossCharge.charge_now()` played
`Sound/Efect/Boss/Atack (1).mp3` on the swing and
`Sound/Efect/Boss/BossBladeSwoosh.WAV` on the strike, through the component's own
`SoundBank`.

---

## 11. DEATH / RUN-FAILURE CLEANUP — FIXED

All six are fixed and each was reproduced in the running game before the fix and watched
again after it. `PlayerDeathSequence` is still the authoritative death flow and nothing
about its beats, its timings or its presentation changed; what changed is what each
system does when it hears the player fall.

**The rule the fixes follow:** every system stands *itself* down on the player's own
`Health.died`, through the method it already had for standing down — the pattern
`AmbushWaveDirector`, `DangerDirector`, `BossPhases` and `SleepDirector` already used.
Nothing new was written that a system could already do, and there is no second teardown
anywhere that could disagree with a system's own.

| Bug | Root cause | Fix |
|---|---|---|
| Weapon unusable after death | A picked-up throwable was never given back, so the player woke in the base carrying a knife with their own weapon stowed at the belt behind it and nothing left to draw it. `PlayerDeathSequence` also still named the retired `../../Shotgun` node in `shotgun_path` and `input_blocked_paths`; since weapons are built by `WeaponMount` neither path resolved, so the weapon was never holstered and never silenced — it stayed drawn and fireable on a corpse | The borrow is spent through `WeaponMount.drop_temporary()` on the killing hit — the same call the throw makes. `shotgun_path` is now `weapon_path`, resolved through `WeaponMount` exactly as `PlayerLoadout` does, and the trigger is silenced with it and handed back in `_finish()` |
| A Travel Ambush death must cancel Travel cleanly | `TravelDirector` had **no** player-death handling at all — its own doc comment referred to an `_on_player_died` that was never written. A death on the road left the state at `IN_EVENT`, the ambush placing men round a body, `Engine.time_scale` at fast travel's 1.5, the day's stop or the black still up, and the session still claiming somebody was travelling — which is a permanently dead TRAVEL button, because `begin_travel()` refuses a journey already under way | `TravelDirector` now follows `Health.died` with the same three-method pattern every other system uses, and puts the ride back through the calls it already makes: the dial handed back, the stop and the screens closed, the ride taken off through `TravelLoading.stop()`, and the journey abandoned through `RunSessionState.abandon_travel()`. The destination stays marked. `travel_cancelled` is deliberately not emitted — it means the player is standing at the waggon again |
| A Camp Ambush death must cancel Camp / Sleep cleanly | Two faults. `SleepDirector` ended the night by calling `PlayerSleep.get_up()`, which stood the body up with a tween racing the death's own fall on the same `Visual` node, handed the keys back and let `PlayerLoadout` redraw the gun over a corpse; it also wrote `Engine.time_scale` back to 1 on the frame the death was slowing the world down. Separately, `Camp` never learned the player had died, so a death out looking for trouble left the waggon invisible and the whole map answering "press E to whistle" for ever | `PlayerSleep.get_up(rises)` — false lets the night go without touching the body, the keys or the gun, which is what a death passes; every other ending is unchanged. The time-scale write is skipped for `REASON_LOST`. `Camp` now follows `Health.died` and calls its own `end_trouble_search()`, which was completed to put the waggon and the pending whistle back as well as the flag |
| Carried Blood and Streak must reset correctly | The reset itself was right, but blood is banked the instant it reaches the player, and a death leaves a stream of it — the player's own spray included — already lifting off the ground. Every piece of it landed *after* `BloodWallet.reset()` and was added back on top | `BloodMagnet.release_all()` — which existed for exactly this and had no caller — is asked first, so the pull is empty before the purse is |
| The player must return cleanly to Base | Two faults. `_travel_home()` called the public `Teleporter.teleport()`, which is the player's *contextual* B key: dying in the pit at the foot of the base took the run-portal branch, raised the map screen over the corpse, moved nobody and never emitted `teleported` — so the sequence waited at `TRAVELLING` for good and the player was left dead on a black screen. And nothing ever ended the run, so the player stood in the base in a world that still believed a run was happening | `teleport()` takes a `use_portal` argument and returns whether a journey home actually began; a body being carried home refuses the portal and falls back to reviving on the spot rather than stranding. `PlayerDeathSequence` ends the run on `RunSessionState` the moment the body is home — the same call the ride home makes |
| No stale active states may survive a death | The round kept spawning into an arena nobody was in. `AmbushWaveDirector._on_player_died` only wrote off what was owed, and `_check_cleared()` needs an empty field as well as an empty debt — so `cleared` never fired and a dozen men chased a body that had left the world. The bounty fight kept the camera limits and `EnemySpawner.arena_bounds` clamped to the boss's own map | `WaveManager` follows the death and calls its own `stop()`, whose `run_finished` sends the arena home through `RunEndDefeat` exactly as the clock running out does. The ambush now breaks: a public `rout()` completes the existing `rout_fraction` machinery, and `TravelDirector` / `DangerDirector` release the ambush on a death rather than `stop()`ping it, because `stop()` drops the very death watch that plays the break. The bounty fight is closed behind the black, in the death sequence, through `BossArena.unlock()` → `BossDefeat.reset()` → `MiniBossDirector.reset_encounter()` — the same three calls, in the same order, winning the fight makes |

**Why the boss teardown is the one thing the death sequence reaches out for:** unwinding
an encounter puts the bodies and the player back where they were found and hands the
camera its old limits back. On the killing hit that is a body dragged across the desert
in full view; after the arrival it would overwrite the base's own camera limits with a
rectangle in the middle of nowhere. The only moment it is neither is with the screen
fully black and the trip home not yet started, and nothing but the death sequence knows
when that is.

Dying to a bounty target deliberately leaves his contract standing on the board. He is
still wanted.

**Files changed:** `Scripts/Player/{player_death_sequence,teleporter,player_sleep}.gd`,
`Scripts/World/{travel_director,camp,sleep_director,danger_director}.gd`,
`Scripts/Enemy/{ambush_wave_director,wave_manager}.gd`.

### Still owed here

A weapon is drawn again on the lying body when a death interrupts a sleep, because
`PlayerLoadout` owns "is the weapon drawn" and reads only which zone the player is
standing in. The trigger stays silenced throughout and the state on arrival is correct,
so this is cosmetic. The other five paths holster correctly.

---

## 12. LIVE VERIFICATION

**Built is not verified**, and this project's standing rule is that behaviour is confirmed
by running the game, not by the code compiling. What follows separates what has now been
watched from what has not.

### 12.1 — Verified in play (2026-08-25)

Each of these was driven in the running game and the result read back off the live tree.

- **Sleep screen.** `SleepDirector.begin()` raises `SleepMenu` and puts the night in
  CHOOSING; `choose_duration(1)` moves it to SLEEPING with the segment count recorded;
  `wake_up()` returns it to IDLE and takes the screen down.
- **Sleep Ambush at the real Camp location.** The alarm ends the night first and then opens
  the ambush around whoever is in the `player` group: with the player standing at
  (200, −300) the men came down 526 and 700 pixels away and the player never moved a pixel.
  The night does **not** resume afterwards. (Sprung from the Base, well outside the playable
  rectangle, the men are placed at its edge instead — the spawner's own clamp, not a fault
  of this system, and not reachable from a camp inside a region.)
- **Sleep Bounty interruption.** `_bounty_stops_the_night()` pauses the night, puts the
  question up on `TravelEventMenu` reading the outlaw's own name — `BONE-SAW MAUDE`,
  `O ŞEREFSİZ ŞİMDİ BURADA.` — with both answers present. Answering *leave* ended the night
  and ran `MiniBossDirector.begin()`.
- **Bounty / Mini Boss encounter map.** The boss was built at Knowledge 3, scale 1.5, with a
  `MiniBoss`, a `MiniBossAppearance` and a `DestinationMarker` on the body. Walking into him
  carried the whole encounter into `BossEncounterMap`: player at (−980, −8000),
  `EnemySpawner.arena_bounds` handed over to the map's own rectangle
  `[P: (−2400, −9350), S: (4800, 2700)]`, camera limits with it, `BossArena` locked. Dying
  in there carried everything back out — arena unlocked, phase back to NONE, field cleared,
  run ended — which is §11's teardown watched again.
- **Boss 2.5× approach trigger.** `trigger_radius` reads 750 in play and fired from 400.
- **Boss fight has no zoom-out.** `BossArena.fight_zoom` is 1.0 and `intro_zoom` is still
  2.0; the camera's zoom-layer table holds only `damage` — there is no fight layer.
- **Wanted Poster uses the actual Boss appearance.** Board posters carry a
  `MiniBossPortrait` drawn from the director's own wardrobe and look key
  (`rider head 14 body 7 weapon 19`, `preacher head 8 body 3 weapon 11`). For the accepted
  contract the wardrobe answered `(16, 7, 8)` for key `butcher`, and the boss that was
  actually built carried that same wardrobe and that same key.
- **Boss HP uses Blood reward + level scaling.** A 1000-blood contract produced 22500 max
  health — 75× the ordinary enemy's authored 300, which is the curve's 1000 point exactly.
  `boss_health_per_level` 0.05 at player level 1 is ×1.0; `boss_health_cap` 150.
- **DangerFinale.** The last man's head came off, `Engine.time_scale` slid down and froze at
  0, the camera took the severed head, and CONTINUE / STOP came up with the head still
  visible. Answering it put `time_scale` back to 1.0, left `get_tree().paused` false, closed
  the question and returned the director to idle with the Danger counted as cleared — no
  stale slow-motion, camera hold or borrowed pause.
- **Day Transition Dial.** Hidden at rest; `play(1)` shows it and turns the face through
  −180° with `has_turned()` true; `stop()` hides it again.
- **Trouble Ammo Drops.** Opening Danger 1 dropped the promised crate — `has_dropped()`
  true with a standing `AmmoCrate` in the field.
- **Travel / Trouble / HUD transitions.** Trouble: camp search → Danger 1 with its men in
  the field and the HUD on `RoundBar` / `AmmoCounter` / `BloodCounter` / `HeartBar`.
  Travel: `TravelDirector.request()` → `TravelMenu` → RIDE OUT → `TravelLoading` → the
  day stop (`HEALTH FULL`, `BUY 10 SHELLS`, `WEAPONS`, `CONTINUE TRAVEL`) → arrival in
  region B with the player placed in the world, `is_travelling()` false, the HUD back to
  gameplay and `time_scale` at 1.0.
- **Test Map.** See §12.3.

### 12.2 — Still owed

#### The Camp Streak stash (§6.1) — none of this has been watched

- The STASH button reads `x<streak>` and the multiplied figure while a Streak is standing
- A Streak of 3 with 300 of camp room takes 100 out of the player's hands and leaves the
  camp holding 300
- The camp refuses more once its 300 is full, whatever the Streak is
- The Streak is still standing after a stash, and the base still pays it on the ride home
- Carried Blood, `CampBlood` and `BloodBank` still sum correctly — nothing minted beyond the
  Streak bonus

#### DangerFinale details

- Camera follows the detached head at roughly 2× — the follow itself was seen, the framing
  was not measurable in the check that was run
- Danger 10 auto-end
- Mid-fight STOP

#### Sleep details

- 5 seconds per segment, one day stage each, the HUD and the world darkness following
- WAKE UP before a length is chosen
- The 4-segment limit and "Uykumu kaçırdı şerefsizler."
- The bounty question's *stay* answer keeping its slept segments
- The camp panel returning after the three quiet endings
- A death during sleep leaving nothing asleep behind it

#### Also owed

- The emergency ammunition crate (§4.3) — only the promised crate has been seen
- The boss health curve across its range, and region-weighted rewards (§7.1, §7.2) — only
  the 1000 → 75× point has been read in play

### 12.3 — The Test Map (developer tool, verified in play)

`Scenes/World/TestMap.tscn`, instanced in `World.tscn` at (0, 4200) — its own 5000×3000
walled area between the Desert and the Base, with its own `WorldZone`, floor, `Spawned`
container, weapon table and return gate. It is a `TeleportDestination` (`test_map`), the
same mechanism the Base and the boss map already use.

- **In:** the `TestMapGate` at (−880, 700), the bottom-left of the Desert playable
  rectangle, on E — or the `dev_test_map` shortcut (**U**) from anywhere, which runs the
  identical `travel()` call. Arrival is (0, 5100).
- **Out:** the `ReturnGate` inside the map, which goes to `base_pit`.
- **Placement:** the Spawn Station builds its roster live from the world — the spawner's
  enemy scene plus `extra_enemy_scenes`, then every `MiniBossDirector` rung crossed with
  every `BountySettings` outlaw, 18 entries today. Picking one starts click-to-place;
  everything placed goes through `EnemySpawner.spawn_at`, is reparented under
  `TestMap/Spawned` and joins `test_spawned`.
- **Cleanup exemption:** watched, not read — with three test spawns standing and one
  ordinary enemy beside them, `WorldReset.reset()` freed the ordinary one and left all
  three. `ZoneEnemyGuard.exempt_group` and `RunEndDefeat.exempt_group` both read
  `test_spawned`.

**Repaired 2026-08-25.** The `TestMapGate` instance had gone missing from `World.tscn` —
node and `ext_resource` both — so the Test Map had no way in from the Desert and the
`dev_test_map` shortcut had nothing to answer it. The instance was put back at (−880, 700)
with `destination_id = &"test_map"` and `shortcut_action = &"dev_test_map"`, and the round
trip was walked again. If it disappears a second time, suspect whatever last re-saved
`World.tscn`; the gate scene itself, `Scenes/World/TestMapGate.tscn`, was never touched.

---

## 13. MILESTONE 3 — DESIGNED, NOT IMPLEMENTED

Nothing in this section exists in the project yet, with one exception: the player-level seam
the boss health curve reads (`RunProgress.get_player_level()`, §7.1) is already in place and
waiting for a level system to give it something other than 1.

### Permanent XP / level progression

XP and Level are permanent; returning to Base does not reset them. Run actions award XP,
level-ups give upgrade card choices, upgrades become permanent, and Blood is spent at
Camp/Base to activate and unlock them.

Planned XP sources:

- Day Cycle segment: 50
- Normal enemy kill: 10
- Ambush cleared: 50
- Trouble Danger 1–10: 25 / 30 / 40 / 50 / 60 / 70 / 80 / 90 / 100 / 125
- First new Region: 100
- First new Map: 150
- First Knowledge on a bounty: 10
- Fully completing a bounty's Knowledge: +25
- Bounty completion XP scales by rarity
- Events have event-specific XP
- Mini Boss XP is bounty/difficulty based, not a separate Boss Tier system

### Weapon upgrade decks

Each weapon gets its own deck. Normal upgrades are beneficial but not mandatory, 5 levels
deep, balanced at all 5, scaling off stats, activated with Blood at Camp/Base.

Planned weapon mechanics:

- Shotgun: +1 firing opportunity after the pump
- Revolver: pellet / projectile increase; coin special
- Coin: lethal-face explosion for 25% of direct hit damage as AoE; perfect-timing bounce
- Revolver spin around the trigger/centre point when the mouse is near the player, up to 3
  spin damage stacks, bonus damage when firing within 0.5 s of a spin — **the spin system
  itself is built (§3.5); the upgrade deck on top of it is not**
- Revolver manual reload only with Space; the reload rotates 360° in 0.3 s; the last bullet
  deals 2× damage
- Lever Action: >180° rotation trail, continuing until the 320° reload rotation; finished
  rotation shakes the camera ×1.5; firing within 0.5 s afterwards can produce a tracking shot
  toward the nearest enemy head relative to weapon facing
- Double Pistols tied to the spinning mechanic
- Muzzle particle visuals react to Damage / Projectile Count / Bullet Speed / Spread

### Horse progression

Travel between connected regions, with route length affecting travel time and increasing
Blood cost multiplicatively. Horse fatigue rises with travel day segments and increases Blood
consumption; camp/rest recovers it. Horse upgrades affect speed, Blood efficiency, Ambush
escape chance, fatigue rate and stamina capacity.

---

## 14. NEXT TASKS, IN ORDER

1. **Watch the Camp Streak stash in play** (§6.1, §12.2) — the one system that has never
   been run
2. **Work through the rest of §12.2** and close Milestone 2
3. Start Milestone 3 with the XP/Level and permanent upgrade foundation

### Milestone 2 items confirmed unfinished by the current files

- The live verification listed in §12.2. Nothing in Milestone 2 is unbuilt.

**MILESTONE 2 IS NOT YET COMPLETE.** Every system is implemented and every one listed in
§12.1 has now been watched running, but the §12.2 list — the Camp Streak stash above all —
has not been, and this document does not mark a system verified on the strength of its code.

**Do not assume any unfinished item above is implemented merely because it was planned. Use
the current files as the truth.**
