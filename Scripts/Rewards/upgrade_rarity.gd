class_name UpgradeRarity
extends Resource
## One rarity a reward card can carry - Common, Uncommon, Rare, Epic, Legendary,
## Legendary Upgrade - and everything that follows from it: how strong it makes
## the card, what it is called, its colour, its stinger and its particles.
##
## [b]Nothing anywhere branches on which rarity it is.[/b] A card asks its rarity
## for [member strength_multiplier], [member color], [member stinger] and the
## particle numbers; a new rarity is a new [code].tres[/code] of this. How often a
## rarity is rolled is not here - that belongs to the pool that rolls it (see
## [RewardRarityChance]).

## A handle for readouts and smoke checks - never read to decide anything.
@export var id: StringName = &""
## The player-facing name on the card, in Turkish - "EPİK".
@export var display_name: String = ""
## Where it sits in the ladder, lowest first. Only for ordering and readouts.
@export var tier: int = 0
## The rarity's colour: the rarity line, the rim glow, the particles and the
## mouse-following glare are all drawn in it.
@export var color: Color = Color.WHITE

@export_group("Strength")
## How many times a card of this rarity applies its upgrade's per-level effect -
## +10% DAMAGE is +40% at 4. Applied as that many run levels through
## [method WeaponDefinition.raise_run_level], so the upgrade itself is authored
## once.
@export_range(1, 32) var strength_multiplier: int = 1

@export_group("Stinger")
## The western guitar stinger played once the card has turned face up is
## [member stinger_hits] strikes of [member stinger_hit] - one more per step up
## the ladder, so the count is exact rather than left to a recording.
@export var stinger_hit: AudioStream
## How many guitar hits the stinger is.
@export_range(0, 16) var stinger_hits: int = 1
## Seconds between hits - shorter is more urgent.
@export var stinger_interval: float = 0.16
## Pitch of each hit in turn, as a playback scale; the last entry repeats.
## Rising steps make the run musical rather than a repeated sample.
@export var stinger_pitches: PackedFloat32Array = PackedFloat32Array([1.0])
## Level offset for the hits, in decibels.
@export var stinger_volume_db: float = 0.0
## An optional extra recording layered under the final hit (or played alone when
## there are no hits) - a rarity's own identity on top of the count.
@export var stinger_layer: AudioStream
@export var stinger_layer_volume_db: float = -4.0


## The pitch of hit [param index].
func stinger_pitch(index: int) -> float:
	if stinger_pitches.is_empty():
		return 1.0
	return stinger_pitches[clampi(index, 0, stinger_pitches.size() - 1)]

@export_group("Particles")
## How many particles drift around the card's edge at once.
@export_range(0, 256) var particle_amount: int = 16
## Particle size, in pixels.
@export var particle_size: float = 3.0
## How far outside the card's edge they start, in pixels.
@export var particle_spread: float = 6.0
## How fast they drift outward, in pixels a second.
@export var particle_speed: float = 14.0
## How long one lives, in seconds.
@export var particle_lifetime: float = 1.2
## Opacity multiplier - higher rarities may burn a little brighter.
@export_range(0.0, 1.0, 0.01) var particle_intensity: float = 0.5

@export_group("Rim")
## How far the soft glow around the card reaches, in pixels.
@export var rim_size: float = 10.0
## How strong it is.
@export_range(0.0, 1.0, 0.01) var rim_intensity: float = 0.35
## The extra flare of the rim as the card is revealed, over [member rim_intensity].
@export_range(0.0, 2.0, 0.01) var reveal_flare: float = 0.5
