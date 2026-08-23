# MILESTONE 2 — AUTHORITATIVE STATE

**Read this document before modifying anything.**

This is a record of the *real* project state, verified against the files on disk, not a
record of what was planned. Nothing below is marked implemented because it was designed —
only because the files prove it. Where a system is half-built it says so and says which
half.

Last verified: 2026-08-23.

---

## 1. WHAT IS ACTUALLY LEFT

Milestone 2 is close to closed. Three things are genuinely unbuilt or unfixed, and they are
the whole of the outstanding work:

1. **The six death / run-failure cleanup bugs** (§11)
2. **The dedicated boss swoosh asset** (§10)
3. **Live play verification** of the systems listed in §12, which are built and wired but
   whose behaviour has not been watched end to end and written down here

The Camp Streak Blood deposit multiplier (§6) is now **implemented** and awaits play
verification.

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

**Not yet play-verified** — see §12.

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

**Not yet play-verified** — see §12.

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

**Not yet play-verified** — see §12.

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

**Not yet play-verified** — see §12.

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

---

## 8. TRAVEL

- The existing `TravelDirector` / `TravelMenu` is the travel system
- The Travel Map is retired
- The Travel day screen has Continue Travel
- An Ambush returns to the Travel screen after combat
- Shift fast travel uses 1.5× speed with automatic Continue
- Travel music preserves its position

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

**Not yet play-verified** — see §12.

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

**STILL MISSING — the dedicated boss swoosh asset.** There is no boss swoosh file under
`Sound/`; only Enemy1's `BladeSwoosh.WAV` exists. The boss swoosh should use its own asset
once one is available.

---

## 11. DEATH BUGS STILL TO FIX

None of these six is recorded as fixed. The seams they would be fixed at do exist —
`PlayerDeathSequence` empties the carried wallet and resets the streak, `TravelDirector`,
`AmbushWaveDirector` and `SleepDirector` each follow the player's `Health.died` — but the
bugs themselves have not been worked or verified:

- Weapon unusable after death
- A Travel Ambush death must cancel Travel cleanly
- A Camp Ambush death must cancel Camp / Sleep cleanly
- Carried Blood and Streak must reset correctly
- The player must return cleanly to Base
- No stale active states may survive a death

---

## 12. LIVE VERIFICATION STILL OWED

These are built and wired. What is missing is watching them run and writing the result down
here. **Built is not verified**, and this project's standing rule is that behaviour is
confirmed by running the game, not by the code compiling.

### The Camp Streak stash (§6.1)

- The STASH button reads `x<streak>` and the multiplied figure while a Streak is standing
- A Streak of 3 with 300 of camp room takes 100 out of the player's hands and leaves the
  camp holding 300
- The camp refuses more once its 300 is full, whatever the Streak is
- The Streak is still standing after a stash, and the base still pays it on the ride home
- Carried Blood, `CampBlood` and `BloodBank` still sum correctly — nothing minted beyond the
  Streak bonus

### DangerFinale (§4.1)

- Final enemy head separation
- `Engine.time_scale` drops to 0.5
- Camera follows the detached head at roughly 2×
- CONTINUE / STOP appears about 3 seconds later
- The head is still visible when it appears
- `time_scale` returns to 1.0
- Camera returns to the player
- Danger 10 auto-end still works
- Mid-fight STOP still works
- No stale finale state survives — no lingering slow-motion, camera follow, borrowed pause or
  suppressed `TravelEventMenu.pauses_game` after the ending, on any exit path

### Sleep (§5)

- The full-screen presentation, the sleeper and the letters
- 5 seconds per segment, one day stage each, the HUD and the world darkness following
- WAKE UP at any point, including before a length is chosen
- The 4-segment limit and "Uykumu kaçırdı şerefsizler."
- An ambush waking the player at the exact spot they lay down, wagon present, and **not**
  resuming afterwards
- The bounty question, both answers, and a stayed-with night keeping its slept segments
- The camp panel returning only after the three quiet endings
- A death during sleep leaving nothing asleep behind it

### Also owed

- The 2.18C Travel / Trouble / HUD end-to-end pass
- The 2.20C ammunition drops (§4.3) — the promised crate and the emergency crate
- The day transition dial (§8.2)
- The boss encounter map round trip (§7.4) — carried in, fought, carried back out, with the
  camera limits and `arena_bounds` handed back
- The boss health curve and region-weighted rewards in play (§7.1, §7.2)

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

1. **Fix death / run-failure cleanup** — all six bugs (§11)
2. **Get the dedicated boss swoosh asset in** (§10)
3. **Work through the live verification list** (§12) and close Milestone 2
4. Start Milestone 3 with the XP/Level and permanent upgrade foundation

### Milestone 2 items confirmed unfinished by the current files

- All six death / run-failure cleanup bugs (§11)
- The dedicated boss swoosh asset (§10)
- The live verification listed in §12

**Do not assume any unfinished item above is implemented merely because it was planned. Use
the current files as the truth.**
